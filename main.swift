import Cocoa
import Sparkle

struct ScanEvent: Decodable {
    let type: String
    let config: Config?
    let checked: Int?
    let skipped: Int?
    let path: String?
}

final class App: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    let table = NSTableView()
    let search = NSSearchField()
    var visibleConfigs: [Config] = []
    let selectedName = NSTextField(labelWithString: "Chọn một kubeconfig")
    let selectedPath = NSTextField(wrappingLabelWithString: "Các context sẽ xuất hiện tại đây.")
    let fileCount = NSTextField(labelWithString: "KUBECONFIG")
    let activity = NSTextField(labelWithString: "Sẵn sàng")
    let folderLabel = NSTextField(labelWithString: "Chọn thư mục chứa kubeconfig")
    let status = NSTextField(wrappingLabelWithString: "")
    let context = NSPopUpButton()
    let activate = NSButton(title: "Kích hoạt context", target: nil, action: nil)
    let scan = NSButton(title: "Quét lại", target: nil, action: nil)
    let depth = NSPopUpButton()
    let cancel = NSButton(title: "Hủy quét", target: nil, action: nil)
    let spinner = NSProgressIndicator()
    let updateButton = NSButton(title: "Kiểm tra cập nhật…", target: nil, action: nil)
    var updaterController: SPUStandardUpdaterController!
    var updaterObservation: NSKeyValueObservation?
    var scanProcess: Process?
    var scanCancelled = false
    var scanChecked = 0
    var scanSkipped = 0
    var configs: [Config] = []
    var folder: String?
    var busy = false
    var lastActivatedContext: String?
    var lastActivatedPath: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "KubeSwitch"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 860, height: 680)
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
        depth.addItems(withTitles: ["Thư mục con: 1 cấp", "Thư mục con: 3 cấp", "Thư mục con: 6 cấp", "Không giới hạn"])
        let savedDepth = UserDefaults.standard.object(forKey: "scanDepth") as? Int ?? 1
        depth.selectItem(at: min(max(savedDepth, 0), 3))
        depth.target = self; depth.action = #selector(depthChanged)
        cancel.target = self; cancel.action = #selector(cancelScan); cancel.isHidden = true
        cancel.bezelStyle = .rounded
        spinner.style = .spinning; spinner.controlSize = .small; spinner.isDisplayedWhenStopped = false
        let scanOptions = NSStackView(views: [depth, spinner, cancel]); scanOptions.spacing = 10
        search.placeholderString = "Tìm file, đường dẫn hoặc context…"
        search.target = self; search.action = #selector(searchChanged)
        search.sendsWholeSearchString = false
        search.sendsSearchStringImmediately = true
        search.controlSize = .large
        search.setAccessibilityLabel("Tìm kubeconfig hoặc context")
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        column.width = 430
        table.addTableColumn(column); table.delegate = self; table.dataSource = self
        table.headerView = nil; table.rowHeight = 62; table.intercellSpacing = NSSize(width: 0, height: 5)
        table.style = .sourceList; table.backgroundColor = .clear
        table.allowsEmptySelection = true
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true
        scroll.drawsBackground = false; scroll.borderType = .noBorder
        fileCount.font = .systemFont(ofSize: 11, weight: .semibold); fileCount.textColor = .secondaryLabelColor
        let left = NSStackView(views: [fileCount, search, scroll]); left.orientation = .vertical; left.alignment = .leading; left.spacing = 12
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
        updateButton.target = self; updateButton.action = #selector(checkForUpdates)
        updateButton.bezelStyle = .rounded; updateButton.controlSize = .small
        updateButton.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
        let version = NSTextField(labelWithString: "v" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""))
        version.font = .systemFont(ofSize: 11); version.textColor = .secondaryLabelColor
        let footer = NSStackView(views: [version, NSView(), updateButton]); footer.spacing = 12
        let stack = NSStackView(views: [header, folderLabel, scanOptions, body, activity, status, footnote, footer])
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
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            body.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            leftCard.widthAnchor.constraint(equalTo: body.widthAnchor, multiplier: 0.53),
            rightCard.heightAnchor.constraint(equalTo: leftCard.heightAnchor),
            leftCard.heightAnchor.constraint(equalTo: body.heightAnchor),
            scroll.widthAnchor.constraint(equalTo: left.widthAnchor),
            search.widthAnchor.constraint(equalTo: left.widthAnchor),
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
        updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        updaterController.startUpdater()
        updaterObservation = updaterController.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let enabled = updater.canCheckForUpdates
            DispatchQueue.main.async { self?.updateButton.isEnabled = enabled }
        }
        rebuildMenu()
        showWindow()
        if let saved = UserDefaults.standard.string(forKey: "scanFolder") {
            folder = saved; rescan()
        }
    }
    @objc func checkForUpdates() {
        guard updaterController.updater.canCheckForUpdates else { return }
        NSApp.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }
    @objc func toggleAutomaticUpdates() {
        updaterController.updater.automaticallyChecksForUpdates.toggle()
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
    @objc func clearSearch() {
        search.stringValue = ""
        applySearch()
    }
    @objc func focusSearch() {
        showWindow()
        window.makeFirstResponder(search)
        search.selectText(nil)
    }
    @objc func searchChanged() {
        applySearch()
    }
    func applySearch() {
        let previousPath = visibleConfigs.indices.contains(table.selectedRow) ? visibleConfigs[table.selectedRow].path : nil
        let previousContext = context.titleOfSelectedItem
        visibleConfigs = configs.compactMap { $0.matching(search.stringValue) }
        table.deselectAll(nil)
        table.reloadData()
        fileCount.stringValue = "KUBECONFIG · \(visibleConfigs.count)/\(configs.count)"
        if !visibleConfigs.isEmpty {
            let row = previousPath.flatMap { path in visibleConfigs.firstIndex(where: { $0.path == path }) } ?? 0
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            if let previousContext = previousContext, visibleConfigs[row].contexts.contains(previousContext) {
                context.selectItem(withTitle: previousContext)
            }
        } else {
            context.removeAllItems(); activate.isEnabled = false
            selectedName.stringValue = configs.isEmpty ? "Chưa có kubeconfig" : "Không có kết quả"
            selectedPath.stringValue = configs.isEmpty ? "Chọn thư mục để bắt đầu quét." : "Thử từ khóa khác hoặc xóa nội dung tìm kiếm."
        }
    }
    func menuNeedsUpdate(_ menu: NSMenu) { rebuildMenu() }
    func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        let heading = NSMenuItem(title: busy ? "Đang quét · \(scanChecked) file · \(configs.count) kubeconfig" : "Chọn kubeconfig → context", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        let find = menu.addItem(withTitle: "Tìm kiếm…", action: #selector(focusSearch), keyEquivalent: "f")
        find.target = self; find.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        if !search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            menu.addItem(withTitle: "Bộ lọc: " + search.stringValue, action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Xóa bộ lọc", action: #selector(clearSearch), keyEquivalent: "").target = self
        }
        if visibleConfigs.isEmpty {
            menu.addItem(withTitle: configs.isEmpty ? "Chưa có kubeconfig — hãy chọn thư mục" : "Không có kết quả phù hợp", action: nil, keyEquivalent: "")
        }
        for (index, config) in visibleConfigs.enumerated() {
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
        if busy {
            menu.addItem(withTitle: "Hủy quét", action: #selector(cancelScan), keyEquivalent: "").target = self
        }
        menu.addItem(withTitle: "Mở cửa sổ KubeSwitch", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let updates = menu.addItem(withTitle: "Kiểm tra cập nhật…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self; updates.isEnabled = updaterController.updater.canCheckForUpdates
        updates.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
        let automatic = menu.addItem(withTitle: "Tự kiểm tra cập nhật", action: #selector(toggleAutomaticUpdates), keyEquivalent: "")
        automatic.target = self; automatic.state = updaterController.updater.automaticallyChecksForUpdates ? .on : .off
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
        panel.prompt = "Quét thư mục này"; panel.message = "Quét theo độ sâu đã chọn; mặc định 3 cấp thư mục con. Kết quả xuất hiện trong khi quét."
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
    @objc func depthChanged() {
        UserDefaults.standard.set(depth.indexOfSelectedItem, forKey: "scanDepth")
    }
    @objc func cancelScan() {
        guard busy, !scanCancelled, let process = scanProcess else { return }
        scanCancelled = true; cancel.isEnabled = false
        activity.stringValue = "Đang dừng quét…"
        if process.isRunning { process.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if self.scanProcess === process && process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let process = scanProcess, process.isRunning { process.terminate() }
    }
    @objc func rescan() {
        guard let folder = folder, !busy else { return }
        busy = true; scan.isEnabled = false; activate.isEnabled = false
        depth.isEnabled = false; cancel.isHidden = false; cancel.isEnabled = true
        spinner.startAnimation(nil)
        scanCancelled = false; scanChecked = 0; scanSkipped = 0
        configs = []; applySearch()
        selectedName.stringValue = "Chọn một kubeconfig"
        selectedPath.stringValue = "Kết quả sẽ xuất hiện ngay khi tìm thấy."
        fileCount.stringValue = "KUBECONFIG · 0"
        folderLabel.stringValue = folder; status.stringValue = "Ưu tiên file kubeconfig và YAML; có thể hủy bất kỳ lúc nào."
        activity.stringValue = "Đang quét…"; activity.textColor = .secondaryLabelColor
        rebuildMenu()
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
        let levels = [1, 3, 6, -1]
        process.arguments = [Bundle.main.resourcePath! + "/config.rb", "scan", folder, String(levels[depth.indexOfSelectedItem])]
        let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
        scanProcess = process
        do { try process.run() } catch {
            finishScan(success: false); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var pending = Data()
            while true {
                let chunk = output.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                pending.append(chunk)
                var events: [ScanEvent] = []
                while let newline = pending.firstIndex(of: 10) {
                    let line = Data(pending[..<newline])
                    pending.removeSubrange(...newline)
                    if let event = try? JSONDecoder().decode(ScanEvent.self, from: line) { events.append(event) }
                }
                let batch = events
                DispatchQueue.main.async { self.receiveScanEvents(batch) }
            }
            process.waitUntilExit()
            DispatchQueue.main.async { self.finishScan(success: process.terminationStatus == 0) }
        }
    }
    func receiveScanEvents(_ events: [ScanEvent]) {
        guard busy, !scanCancelled else { return }
        var added = false
        for event in events {
            if let item = event.config { configs.append(item); added = true }
            if let count = event.checked { scanChecked = count }
            if let count = event.skipped { scanSkipped = count }
            if let path = event.path { status.stringValue = path }
        }
        activity.stringValue = "Đã kiểm tra \(scanChecked) file · \(configs.count) kubeconfig · bỏ qua \(scanSkipped) mục"
        if added {
            applySearch()
        }
    }
    func finishScan(success: Bool) {
        busy = false; scanProcess = nil; scan.isEnabled = true; depth.isEnabled = true
        cancel.isHidden = true; spinner.stopAnimation(nil)
        activate.isEnabled = visibleConfigs.indices.contains(table.selectedRow)
        let summary = "\(scanChecked) file · \(configs.count) kubeconfig · bỏ qua \(scanSkipped) mục"
        activity.stringValue = (scanCancelled ? "Đã hủy · " : success ? "Hoàn tất · " : "Quét thất bại · ") + summary
        activity.textColor = success || scanCancelled ? .secondaryLabelColor : .systemRed
        status.stringValue = scanCancelled ? "Giữ lại các kết quả đã tìm thấy. Bạn có thể chọn thư mục khác hoặc quét lại." : success ? "Độ sâu có giới hạn có thể bỏ qua file nằm sâu hơn. Tăng độ sâu nếu thiếu cấu hình." : "Không đọc được thư mục. Kiểm tra quyền truy cập hoặc chọn thư mục khác."
        rebuildMenu()
    }
    func numberOfRows(in tableView: NSTableView) -> Int { visibleConfigs.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let config = visibleConfigs[row]
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
        guard visibleConfigs.indices.contains(row) else { activate.isEnabled = false; return }
        let item = visibleConfigs[row]; context.addItems(withTitles: item.contexts)
        selectedName.stringValue = URL(fileURLWithPath: item.path).lastPathComponent
        selectedPath.stringValue = item.path
        if let current = item.current, item.contexts.contains(current) { context.selectItem(withTitle: current) }
        activate.isEnabled = !busy
    }
    @objc func applyConfig() {
        let row = table.selectedRow
        guard !busy, visibleConfigs.indices.contains(row), let selected = context.titleOfSelectedItem else { return }
        activateConfig(path: visibleConfigs[row].path, selected: selected)
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
