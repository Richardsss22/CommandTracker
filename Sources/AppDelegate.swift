import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let voiceController = VoiceController()
    var commandWindow: CommandEditorWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = ActionHandler.shared // Acordar logs de comandos
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // Utilizamos 'waveform' para não ser confundido com o microfone laranja do macOS
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "CommandTracker")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Retomar Escuta", action: #selector(resume), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Pausar", action: #selector(pause), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Editar Comandos", action: #selector(openEditor), keyEquivalent: "e"))
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
    
    @objc func openEditor() {
        if commandWindow == nil {
            commandWindow = CommandEditorWindow()
        }
        commandWindow?.showWindow()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Janela de Edição de Comandos
class CommandEditorWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var window: NSWindow!
    var tableView: NSTableView!
    var triggerField: NSTextField!
    var actionPopup: NSPopUpButton!
    var targetField: NSTextField!
    var addBtn: NSButton!
    var commands: [[String: Any]] = []
    var editingRowIndex: Int? = nil
    
    let actionTypes = [
        "open_app", "close_app", "safari_open", "safari_close_tab", "safari_focus",
        "safari_trading", "media_play_pause", "media_next", "media_previous",
        "media_volume_up", "media_volume_down", "media_mute", "print_page", "run_shortcut"
    ]
    
    override init() {
        super.init()
        setupWindow()
        loadCommands()
    }
    
    func setupWindow() {
        let windowRect = NSRect(x: 0, y: 0, width: 650, height: 500)
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CommandTracker — Editor de Comandos"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 550, height: 400)
        
        // Fundo escuro premium
        window.backgroundColor = NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1.0)
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        
        let contentView = window.contentView!
        
        // ─── Tabela de Comandos Existentes ───
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 160, width: 660, height: 320))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        
        tableView = NSTableView()
        tableView.backgroundColor = NSColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1.0)
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.style = .plain
        tableView.rowHeight = 28
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.gridColor = NSColor.gray.withAlphaComponent(0.2)
        
        let col1 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("trigger"))
        col1.title = "Trigger (Voz)"
        col1.width = 280
        tableView.addTableColumn(col1)
        
        let col2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        col2.title = "Ação"
        col2.width = 150
        tableView.addTableColumn(col2)
        
        let col3 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("target"))
        col3.title = "Alvo"
        col3.width = 200
        tableView.addTableColumn(col3)
        
        tableView.dataSource = self
        tableView.delegate = self
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // ─── Painel de Adição / Edição ───
        let panelY: CGFloat = 15
        
        // Linha 1: Input (voz) + Ação
        let triggerLabel = NSTextField(labelWithString: "Input (voz):")
        triggerLabel.frame = NSRect(x: 20, y: panelY + 105, width: 90, height: 20)
        triggerLabel.textColor = .white
        contentView.addSubview(triggerLabel)
        
        triggerField = NSTextField(frame: NSRect(x: 115, y: panelY + 103, width: 300, height: 24))
        triggerField.placeholderString = "ex: open spotify, musica"
        triggerField.focusRingType = .none
        contentView.addSubview(triggerField)
        
        let actionLabel = NSTextField(labelWithString: "Ação:")
        actionLabel.frame = NSRect(x: 430, y: panelY + 105, width: 45, height: 20)
        actionLabel.textColor = .white
        contentView.addSubview(actionLabel)
        
        actionPopup = NSPopUpButton(frame: NSRect(x: 480, y: panelY + 100, width: 180, height: 28))
        actionPopup.addItems(withTitles: actionTypes)
        contentView.addSubview(actionPopup)
        
        // Linha 2: Output (alvo)
        let targetLabel = NSTextField(labelWithString: "Output (alvo):")
        targetLabel.frame = NSRect(x: 20, y: panelY + 70, width: 100, height: 20)
        targetLabel.textColor = .white
        contentView.addSubview(targetLabel)
        
        targetField = NSTextField(frame: NSRect(x: 115, y: panelY + 68, width: 545, height: 24))
        targetField.placeholderString = "ex: Spotify (app) ou URL"
        targetField.focusRingType = .none
        contentView.addSubview(targetField)
        
        // Linha 3: Botões alinhados à direita
        let delBtn = NSButton(frame: NSRect(x: 20, y: panelY + 20, width: 100, height: 32))
        delBtn.title = "🗑 Apagar"
        delBtn.bezelStyle = .rounded
        delBtn.target = self
        delBtn.action = #selector(deleteCommand)
        contentView.addSubview(delBtn)
        
        let newBtn = NSButton(frame: NSRect(x: 450, y: panelY + 20, width: 100, height: 32))
        newBtn.title = "✧ Novo"
        newBtn.bezelStyle = .rounded
        newBtn.target = self
        newBtn.action = #selector(clearFields)
        contentView.addSubview(newBtn)

        addBtn = NSButton(frame: NSRect(x: 560, y: panelY + 20, width: 120, height: 32))
        addBtn.title = "＋ Adicionar"
        addBtn.bezelStyle = .rounded
        addBtn.target = self
        addBtn.action = #selector(saveCommandAction)
        contentView.addSubview(addBtn)
        delBtn.target = self
        delBtn.action = #selector(deleteCommand)
        contentView.addSubview(delBtn)
    }
    
    func showWindow() {
        loadCommands()
        tableView.reloadData()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func loadCommands() {
        let url = URL(fileURLWithPath: ActionHandler.shared.commandsFilePath)
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        commands = json
    }
    
    func saveCommands() {
        let url = URL(fileURLWithPath: ActionHandler.shared.commandsFilePath)
        guard let data = try? JSONSerialization.data(withJSONObject: commands, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: url)
        ActionHandler.shared.loadCommands()
    }
    
    @objc func clearFields() {
        editingRowIndex = nil
        triggerField.stringValue = ""
        targetField.stringValue = ""
        actionPopup.selectItem(at: 0)
        addBtn.title = "＋ Adicionar"
        tableView.deselectAll(nil)
    }
    
    @objc func saveCommandAction() {
        let trigger = triggerField.stringValue.trimmingCharacters(in: .whitespaces)
        let action = actionPopup.titleOfSelectedItem ?? "open_app"
        let target = targetField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !trigger.isEmpty else { return }
        
        var cmdDict: [String: Any] = [
            "voice_triggers": trigger.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() },
            "action": action
        ]
        if !target.isEmpty {
            cmdDict["target"] = target
        }
        
        if let index = editingRowIndex {
            // Modo Edição: Substituir
            commands[index] = cmdDict
        } else {
            // Modo Novo: Append
            commands.append(cmdDict)
        }
        
        saveCommands()
        tableView.reloadData()
        clearFields()
    }
    
    @objc func deleteCommand() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        commands.remove(at: row)
        saveCommands()
        tableView.reloadData()
    }
    
    // MARK: - NSTableView DataSource / Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        return commands.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cmd = commands[row]
        let cellId = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        let cell = NSTextField()
        cell.isBordered = false
        cell.isEditable = false
        cell.drawsBackground = false
        cell.textColor = .white
        cell.font = NSFont.systemFont(ofSize: 12)
        
        switch cellId.rawValue {
        case "trigger":
            let triggers = cmd["voice_triggers"] as? [String] ?? []
            cell.stringValue = triggers.joined(separator: ", ")
        case "action":
            cell.stringValue = cmd["action"] as? String ?? ""
        case "target":
            cell.stringValue = cmd["target"] as? String ?? "—"
        default:
            break
        }
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row >= 0 {
            editingRowIndex = row
            let cmd = commands[row]
            
            let triggers = cmd["voice_triggers"] as? [String] ?? []
            triggerField.stringValue = triggers.joined(separator: ", ")
            
            let action = cmd["action"] as? String ?? ""
            actionPopup.selectItem(withTitle: action)
            
            targetField.stringValue = cmd["target"] as? String ?? ""
            addBtn.title = "💾 Guardar"
        } else {
            editingRowIndex = nil
            addBtn.title = "＋ Adicionar"
        }
    }
}
