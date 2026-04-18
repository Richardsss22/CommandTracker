import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let voiceController = VoiceController()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = ActionHandler.shared // Acordar logs de comandos
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // Utilizamos 'waveform' para não ser confundido com o microfone laranja do macOS
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Vox Mac")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Retomar Escuta", action: #selector(resume), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Pausar", action: #selector(pause), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Encerrar Tracker", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        voiceController.checkPermissionsAndStart()
    }
    
    @objc func pause() {
        voiceController.isPaused = true
        voiceController.stopListening()
        statusItem.button?.image = NSImage(systemSymbolName: "mic.slash.fill", accessibilityDescription: "Paused")
    }
    
    @objc func resume() {
        voiceController.isPaused = false
        voiceController.startListening()
        statusItem.button?.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Listening")
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
