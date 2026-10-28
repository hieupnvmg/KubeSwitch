import Cocoa

struct Config: Decodable {
    let path: String
    let contexts: [String]
    let current: String?
}

final class App: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    let table = NSTableView()
    let selectedName = NSTextField(labelWithString: "Chọn một kubeconfig")
    let selectedPath = NSTextField(wrappingLabelWithString: "Các context sẽ xuất hiện tại đây.")
    let fileCount = NSTextField(labelWithString: "KUBECONFIG")
    let activity = NSTextField(labelWithString: "Sẵn sàng")
    let folderLabel = NSTextField(labelWithString: "Chọn thư mục chứa kubeconfig")
    let status = NSTextField(wrappingLabelWithString: "")
    let context = NSPopUpButton()
    let activate = NSButton(title: "Kích hoạt context", target: nil, action: nil)
    let scan = NSButton(title: "Quét lại", target: nil, action: nil)
    var configs: [Config] = []
    var folder: String?
    var busy = false
    var lastActivatedContext: String?
    var lastActivatedPath: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 620), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "KubeSwitch"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 860, height: 560)
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        let choose = NSButton(title: "Chọn thư mục…", target: self, action: #selector(chooseFolder))
        choose.bezelStyle = .rounded
        choose.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
        choose.imagePosition = .imageLeading
        scan.target = self; scan.action = #selector(rescan); scan.bezelStyle = .rounded
        scan.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
        scan.imagePosition = .imageLeading
        activate.target = self; activate.action = #selector(applyConfig); activate.isEnabled = false
        activate.bezelStyle = .rounded; activate.bezelColor = .controlAccentColor
        activate.controlSize = .large
        activate.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        activate.imagePosition = .imageLeading
        let icon = NSImageView(image: NSImage(systemSymbolName: "helm", accessibilityDescription: "KubeSwitch") ?? NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)!)
        icon.contentTintColor = .controlAccentColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 34, weight: .medium)
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let title = NSTextField(labelWithString: "KubeSwitch")
        title.font = .systemFont(ofSize: 27, weight: .bold)
        let subtitle = NSTextField(labelWithString: "Chuyển cluster, tiếp tục công việc.")
        subtitle.font = .systemFont(ofSize: 13); subtitle.textColor = .secondaryLabelColor
        let titles = NSStackView(views: [title, subtitle]); titles.orientation = .vertical; titles.alignment = .leading; titles.spacing = 4
        let spacer = NSView()
        let header = NSStackView(views: [icon, titles, spacer, scan, choose]); header.spacing = 12
        folderLabel.lineBreakMode = .byTruncatingMiddle
        folderLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        folderLabel.textColor = .secondaryLabelColor
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        column.width = 430
        table.addTableColumn(column); table.delegate = self; table.dataSource = self
        table.headerView = nil; table.rowHeight = 62; table.intercellSpacing = NSSize(width: 0, height: 5)
        table.style = .sourceList; table.backgroundColor = .clear
        table.allowsEmptySelection = true
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true
        scroll.drawsBackground = false; scroll.borderType = .noBorder
        fileCount.font = .systemFont(ofSize: 11, weight: .semibold); fileCount.textColor = .secondaryLabelColor
        let left = NSStackView(views: [fileCount, scroll]); left.orientation = .vertical; left.alignment = .leading; left.spacing = 12
        selectedName.font = .systemFont(ofSize: 20, weight: .semibold)
        selectedName.lineBreakMode = .byTruncatingMiddle
        selectedPath.font = .systemFont(ofSize: 11); selectedPath.textColor = .secondaryLabelColor
        selectedPath.maximumNumberOfLines = 3; selectedPath.lineBreakMode = .byTruncatingMiddle
        let contextLabel = NSTextField(labelWithString: "CONTEXT")
        contextLabel.font = .systemFont(ofSize: 11, weight: .semibold); contextLabel.textColor = .secondaryLabelColor
        context.controlSize = .large
        let divider = NSBox(); divider.boxType = .separator
        let help = NSTextField(wrappingLabelWithString: "Cấu hình cũ được tự động sao lưu khi chuyển. Bạn cũng có thể chọn nhanh từ biểu tượng trên menu bar.")
        help.font = .systemFont(ofSize: 12); help.textColor = .secondaryLabelColor
        let right = NSStackView(views: [selectedName, selectedPath, divider, contextLabel, context, activate, help, NSView()])
        right.orientation = .vertical; right.alignment = .leading; right.spacing = 16
        let leftCard = card(left); let rightCard = card(right)
        let body = NSStackView(views: [leftCard, rightCard]); body.spacing = 16; body.alignment = .top
        let footnote = NSTextField(wrappingLabelWithString: "Đích: ~/.kube/config  ·  Nếu terminal đặt KUBECONFIG, chạy unset KUBECONFIG.")
        footnote.font = .systemFont(ofSize: 11); footnote.textColor = .tertiaryLabelColor
        activity.font = .systemFont(ofSize: 12, weight: .medium); activity.textColor = .secondaryLabelColor
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        status.maximumNumberOfLines = 2; status.lineBreakMode = .byTruncatingMiddle
        status.isSelectable = true
        let stack = NSStackView(views: [header, folderLabel, body, activity, status, footnote])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 48),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -20),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            body.widthAnchor.constraint(equalTo: stack.widthAnchor),
            folderLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footnote.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
            body.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            leftCard.widthAnchor.constraint(equalTo: body.widthAnchor, multiplier: 0.53),
            rightCard.heightAnchor.constraint(equalTo: leftCard.heightAnchor),
            leftCard.heightAnchor.constraint(equalTo: body.heightAnchor),
            scroll.widthAnchor.constraint(equalTo: left.widthAnchor),
            selectedName.widthAnchor.constraint(equalTo: right.widthAnchor),
            selectedPath.widthAnchor.constraint(equalTo: right.widthAnchor),
            context.widthAnchor.constraint(equalTo: right.widthAnchor),
            divider.widthAnchor.constraint(equalTo: right.widthAnchor),
            help.widthAnchor.constraint(equalTo: right.widthAnchor)
        ])
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "⎈"
        let menu = NSMenu()
        menu.addItem(withTitle: "Mở KubeSwitch", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Chọn thư mục…", action: #selector(chooseFolder), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Thoát", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
        showWindow()
        if let saved = UserDefaults.standard.string(forKey: "scanFolder") {
            folder = saved; rescan()
        }
    }
    func card(_ content: NSView) -> NSView {
        let view = NSView(); view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.borderWidth = 0.5
        view.layer?.borderColor = NSColor.separatorColor.cgColor
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            content.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18)
        ])
        return view
    }
    func menuNeedsUpdate(_ menu: NSMenu) { rebuildMenu() }
    func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        let heading = NSMenuItem(title: busy ? "Đang quét…" : "Chọn kubeconfig → context", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        if configs.isEmpty {
            menu.addItem(withTitle: "Chưa có kubeconfig — hãy chọn thư mục", action: nil, keyEquivalent: "")
        }
        for (index, config) in configs.enumerated() {
            let prefix = folder.map { $0.hasSuffix("/") ? $0 : $0 + "/" } ?? ""
            let label = !prefix.isEmpty && config.path.hasPrefix(prefix) ? String(config.path.dropFirst(prefix.count)) : config.path
            let fileItem = NSMenuItem(title: label, action: nil, keyEquivalent: "")
            fileItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
            fileItem.toolTip = config.path
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            for name in config.contexts {
                let item = NSMenuItem(title: name, action: #selector(activateFromMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = ["path": config.path, "context": name]
                item.tag = index
                item.isEnabled = !busy
                item.state = config.path == lastActivatedPath && name == lastActivatedContext ? .on : .off
                submenu.addItem(item)
            }
            fileItem.submenu = submenu
            menu.addItem(fileItem)
        }
        menu.addItem(.separator())
        if let name = lastActivatedContext {
            menu.addItem(withTitle: "Đã kích hoạt: \(name)", action: nil, keyEquivalent: "")
        }
        menu.addItem(withTitle: "Chọn thư mục…", action: #selector(chooseFolder), keyEquivalent: "").target = self
        let refresh = menu.addItem(withTitle: "Quét lại", action: #selector(rescan), keyEquivalent: "")
        refresh.target = self; refresh.isEnabled = folder != nil && !busy
        menu.addItem(withTitle: "Mở cửa sổ KubeSwitch", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Thoát", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.autoenablesItems = false
        heading.isEnabled = false
        for item in menu.items where item.action == nil && item.submenu == nil { item.isEnabled = false }
    }
    @objc func activateFromMenu(_ sender: NSMenuItem) {
        guard !busy, let selection = sender.representedObject as? [String: String],
              let path = selection["path"], let name = selection["context"] else { return }
        activateConfig(path: path, selected: name)
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func chooseFolder() {
        guard !busy else { return }
        showWindow()
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.prompt = "Quét thư mục này"; panel.message = "Quét cả thư mục con. Bỏ qua thư mục ẩn (trừ .kube), Library và node_modules."
        if panel.runModal() == .OK, let url = panel.url {
            folder = url.path; UserDefaults.standard.set(url.path, forKey: "scanFolder"); rescan()
        }
    }
    func runHelper(_ args: [String]) throws -> Data {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
        process.arguments = [Bundle.main.resourcePath! + "/config.rb"] + args
        let output = Pipe(); process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw NSError(domain: "KubeSwitch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không đọc được cấu hình. Kiểm tra quyền truy cập và định dạng YAML."]) }
        return data
    }
    @objc func rescan() {
        guard let folder = folder, !busy else { return }
        busy = true; scan.isEnabled = false; activate.isEnabled = false
        folderLabel.stringValue = folder; status.stringValue = "Đang tìm kubeconfig trong thư mục đã chọn…"
        activity.stringValue = "Đang quét…"; activity.textColor = .secondaryLabelColor
        rebuildMenu()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try JSONDecoder().decode([Config].self, from: self.runHelper(["scan", folder])) }
            DispatchQueue.main.async {
                self.busy = false; self.scan.isEnabled = true
                switch result {
                case .success(let items):
                    self.configs = items; self.table.reloadData(); self.context.removeAllItems()
                    self.status.stringValue = items.isEmpty ? "Bấm Chọn thư mục… để tìm kubeconfig ở vị trí khác." : "Chọn file bên trái, rồi chọn context để kích hoạt."
                    self.fileCount.stringValue = "KUBECONFIG · \(items.count)"
                    self.activity.stringValue = items.isEmpty ? "Không tìm thấy kubeconfig" : "Sẵn sàng · \(items.count) cấu hình"
                    self.activate.isEnabled = false
                    self.selectedName.stringValue = "Chọn một kubeconfig"
                    self.selectedPath.stringValue = "Các context sẽ xuất hiện tại đây."
                    if !items.isEmpty { self.table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
                case .failure(let error): self.status.stringValue = error.localizedDescription
                }
                self.rebuildMenu()
            }
        }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { configs.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let config = configs[row]
        let cell = NSTableCellView()
        let icon = NSImageView(image: NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)!)
        icon.contentTintColor = .controlAccentColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let name = NSTextField(labelWithString: URL(fileURLWithPath: config.path).lastPathComponent)
        name.font = .systemFont(ofSize: 13, weight: .semibold)
        name.lineBreakMode = .byTruncatingMiddle
        let detail = NSTextField(labelWithString: "\(config.contexts.count) context · \(URL(fileURLWithPath: config.path).deletingLastPathComponent().lastPathComponent)")
        detail.font = .systemFont(ofSize: 11); detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingMiddle
        let labels = NSStackView(views: [name, detail]); labels.orientation = .vertical; labels.alignment = .leading; labels.spacing = 4
        let rowView = NSStackView(views: [icon, labels]); rowView.spacing = 12
        rowView.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(rowView); cell.textField = name; cell.toolTip = config.path
        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            rowView.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            rowView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            name.widthAnchor.constraint(equalTo: labels.widthAnchor),
            detail.widthAnchor.constraint(equalTo: labels.widthAnchor)
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        context.removeAllItems()
        let row = table.selectedRow
        guard configs.indices.contains(row) else { activate.isEnabled = false; return }
        let item = configs[row]; context.addItems(withTitles: item.contexts)
        selectedName.stringValue = URL(fileURLWithPath: item.path).lastPathComponent
        selectedPath.stringValue = item.path
        if let current = item.current { context.selectItem(withTitle: current) }
        activate.isEnabled = !busy
    }
    @objc func applyConfig() {
        let row = table.selectedRow
        guard !busy, configs.indices.contains(row), let selected = context.titleOfSelectedItem else { return }
        activateConfig(path: configs[row].path, selected: selected)
    }
    func activateConfig(path: String, selected: String) {
        do {
            let data = try runHelper(["build", path, selected])
            let fm = FileManager.default
            let dir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".kube")
            try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let destination = dir.appendingPathComponent("config")
            var backup: URL?
            if fm.fileExists(atPath: destination.path) {
                let backupURL = dir.appendingPathComponent("config.kubeswitch-backup-\(UUID().uuidString)")
                let previous = try Data(contentsOf: destination)
                try previous.write(to: backupURL, options: [.atomic])
                try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupURL.path)
                backup = backupURL
            }
            try data.write(to: destination, options: [.atomic])
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            status.stringValue = "Đã kích hoạt: \(selected)" + (backup.map { "\nBản sao lưu: \($0.path)" } ?? "")
            statusItem.button?.toolTip = "Context: \(selected)"
            lastActivatedContext = selected
            lastActivatedPath = path
            activity.stringValue = "✓ Đã kích hoạt: \(selected)"; activity.textColor = .systemGreen
            statusItem.button?.title = "⎈ " + (selected.count > 24 ? String(selected.prefix(21)) + "…" : selected)
            rebuildMenu()
        } catch {
            status.stringValue = "Lỗi: \(error.localizedDescription)"
            activity.stringValue = "Không thể chuyển context"; activity.textColor = .systemRed
            showWindow()
            let alert = NSAlert(); alert.messageText = "Không thể kích hoạt context"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

umask(0o077)
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.run()
