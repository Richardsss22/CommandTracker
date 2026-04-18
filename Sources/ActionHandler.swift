import Foundation
import AppKit

struct CommandDefinition: Codable {
    let voiceTriggers: [String]
    let action: String
    let target: String?
    
    enum CodingKeys: String, CodingKey {
        case voiceTriggers = "voice_triggers"
        case action
        case target
    }
}

class ActionHandler {
    static let shared = ActionHandler()
    private var commands: [CommandDefinition] = []
    
    let commandsFilePath = "/Users/ricardo/DevApps/RichieCommandTracker/commands.json"
    
    private init() {
        loadCommands()
    }
    
    func loadCommands() {
        let url = URL(fileURLWithPath: commandsFilePath)
        do {
            let data = try Data(contentsOf: url)
            commands = try JSONDecoder().decode([CommandDefinition].self, from: data)
            print("\n--- 📝 COMANDOS LIDOS DO JSON ---")
            for cmd in commands {
                print("- \(cmd.voiceTriggers.joined(separator: " / ")) -> Ação: \(cmd.action) [\(cmd.target ?? "")]")
            }
            print("----------------------------\n")
        } catch {
            print("Erro crítico ao ler commands.json (verifica o formato do ficheiro): \(error.localizedDescription)")
        }
    }
    
    func processContinuousCommand(_ text: String) -> Bool {
        let commandText = text.lowercased()
        
        // 1. Verificação Estrita Dinâmica para Janelas Específicas do Preview
        let dynamicPrefixes = ["file ", "ficheiro ", "preview ", "documento "]
        for prefix in dynamicPrefixes {
            if commandText.hasPrefix(prefix) {
                let fileName = commandText.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                if !fileName.isEmpty {
                    print("\n✅ [COMANDO DINÂMICO]: Foco no documento -> \(fileName)")
                    let script = """
                    tell application "System Events"
                        tell process "Preview"
                            set frontmost to true
                            repeat with w in windows
                                if (name of w as string) contains "\(fileName)" then
                                    set value of attribute "AXMain" of w to true
                                    perform action "AXRaise" of w
                                    return
                                end if
                            end repeat
                        end tell
                    end tell
                    """
                    executeAppleScriptDirectly(script)
                    return true
                }
            }
        }
        
        // 2. Comandos estáticos do JSON — SEMPRE escolher o trigger MAIS LONGO que faz match
        //    para evitar que "chrome" dispare antes de "close chrome"
        var bestMatch: (cmd: CommandDefinition, trigger: String)?
        
        for cmd in commands {
            for trigger in cmd.voiceTriggers {
                if commandText.contains(trigger.lowercased()) {
                    if bestMatch == nil || trigger.count > bestMatch!.trigger.count {
                        bestMatch = (cmd, trigger)
                    }
                }
            }
        }
        
        if let match = bestMatch {
            print("\n✅ [COMANDO ACIONADO]: \(match.trigger)")
            executeAction(match.cmd)
            return true
        }
        
        return false
    }
    
    private func executeAppleScriptDirectly(_ source: String) {
        DispatchQueue.main.async {
            self.runAppleScript(source)
        }
    }
    
    private func executeAction(_ cmd: CommandDefinition) {
        DispatchQueue.main.async {
            self._executeActionMainThread(cmd)
        }
    }
    
    private func _executeActionMainThread(_ cmd: CommandDefinition) {
        print("Executar ação configurada: \(cmd.action)")
        
        switch cmd.action {
        case "open_app":
            if let targetApp = cmd.target {
                NSWorkspace.shared.launchApplication(targetApp)
            }
            
        case "close_app":
            if let targetApp = cmd.target {
                let appName = targetApp.lowercased()
                if appName == "finder" {
                    let script = "tell application \"Finder\" to close every window"
                    runAppleScript(script)
                } else {
                    let runningApps = NSWorkspace.shared.runningApplications
                    if let app = runningApps.first(where: { 
                        ($0.localizedName?.lowercased() ?? "").contains(appName) || 
                        ($0.bundleURL?.lastPathComponent.lowercased() ?? "").contains(appName) ||
                        appName.contains($0.localizedName?.lowercased() ?? "")
                    }) {
                        app.forceTerminate() // Esmaga o processo ao nível do kernel (Ignora "Unsaved Changes" ou bloqueios nativos)
                    } else {
                        // Fallback absoluto via shell Unix
                        let task = Process()
                        task.launchPath = "/usr/bin/killall"
                        task.arguments = [targetApp]
                        task.launch()
                    }
                }
            }
            
        case "safari_open":
            if let targetUrl = cmd.target, !targetUrl.isEmpty {
                let script = """
                tell application "Safari"
                    if (count of windows) is 0 then
                        make new document with properties {URL:"\(targetUrl)"}
                    else
                        tell front window
                            make new tab with properties {URL:"\(targetUrl)"}
                            set current tab to last tab
                        end tell
                    end if
                    activate
                end tell
                """
                runAppleScript(script)
            } else {
                let script = """
                tell application "Safari"
                    if (count of windows) is 0 then
                        make new document
                    else
                        tell front window
                            make new tab
                            set current tab to last tab
                        end tell
                    end if
                    activate
                end tell
                """
                runAppleScript(script)
            }
            
        case "safari_close_tab":
            if let targetUrl = cmd.target {
                let script = """
                tell application "Safari"
                    set windowCount to count of windows
                    repeat with v from 1 to windowCount
                        set tabCount to count of tabs of window v
                        repeat with i from tabCount to 1 by -1
                            set theTab to tab i of window v
                            try
                                if URL of theTab contains "\(targetUrl)" then
                                    close theTab
                                end if
                            end try
                        end repeat
                    end repeat
                end tell
                """
                runAppleScript(script)
            }
            
        case "run_shortcut":
            if let shortcutName = cmd.target {
                runShortcut(name: shortcutName)
            }
            
        case "safari_trading":
            let script = """
            tell application "Safari"
                activate
                set windowCount to count of windows
                if windowCount is 0 then
                    make new document with properties {URL:"https://live.trading212.com"}
                    return
                end if
                repeat with v from 1 to windowCount
                    set tabCount to count of tabs of window v
                    repeat with i from 1 to tabCount
                        set theTab to tab i of window v
                        if URL of theTab contains "trading212.com" then
                            tell window v
                                set current tab to theTab
                            end tell
                            return
                        end if
                    end repeat
                end repeat
                
                tell window 1 to make new tab with properties {URL:"https://live.trading212.com"}
            end tell
            """
            runAppleScript(script)
            
        case "media_play_pause":
            simulateMediaKey(key: 16) // NX_KEYTYPE_PLAY
            
        case "media_next":
            simulateMediaKey(key: 17) // NX_KEYTYPE_NEXT
            
        case "media_previous":
            simulateMediaKey(key: 18) // NX_KEYTYPE_PREVIOUS
            
        case "media_volume_up":
            simulateMediaKey(key: 0) // NX_KEYTYPE_SOUND_UP
            
        case "media_volume_down":
            simulateMediaKey(key: 1) // NX_KEYTYPE_SOUND_DOWN
            
        case "media_mute":
            simulateMediaKey(key: 7) // NX_KEYTYPE_MUTE
            
        case "print_page":
            // Simula Cmd+P na app em primeiro plano
            let src = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x23, keyDown: true) // 0x23 = 'p'
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x23, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
        default:
            print("Ação desconhecida ou não implementada no Swift: \(cmd.action)")
        }
    }
    
    private func runShortcut(name: String) {
        let task = Process()
        task.launchPath = "/usr/bin/shortcuts"
        task.arguments = ["run", name]
        task.launch()
    }
    
    private func runAppleScript(_ source: String) {
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error = error {
                print("Erro a executar AppleScript: \(error)")
            }
        }
    }
    
    private func simulateMediaKey(key: Int) {
        let HIDPostAuxKey = 8
        let evtDown = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: 0xA00), timestamp: 0, windowNumber: 0, context: nil, subtype: Int16(HIDPostAuxKey), data1: Int((key << 16) | ((0xa) << 8)), data2: -1)
        let evtUp = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: 0xB00), timestamp: 0, windowNumber: 0, context: nil, subtype: Int16(HIDPostAuxKey), data1: Int((key << 16) | ((0xb) << 8)), data2: -1)
        
        evtDown?.cgEvent?.post(tap: .cghidEventTap)
        evtUp?.cgEvent?.post(tap: .cghidEventTap)
    }
}
