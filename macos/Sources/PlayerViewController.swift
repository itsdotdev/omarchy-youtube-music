import AppKit

final class ArtworkView: NSImageView {
    private var request: URLSessionDataTask?
    private var artworkID = ""
    private static let cache = NSCache<NSString, NSImage>()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
        imageScaling = .scaleProportionallyUpOrDown
    }
    required init?(coder: NSCoder) { fatalError() }
    func show(_ track: Track?) {
        guard artworkID != (track?.id ?? "empty") else { return }
        artworkID = track?.id ?? "empty"
        request?.cancel()
        image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Album artwork")
        contentTintColor = .secondaryLabelColor
        guard let track else { return }
        if let cached = Self.cache.object(forKey: track.id as NSString) { image = cached; return }
        request = URLSession.shared.dataTask(with: track.artworkURL) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                Self.cache.setObject(image, forKey: track.id as NSString)
                if self?.artworkID == track.id { self?.image = image }
            }
        }
        request?.resume()
    }
}

func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let view = NSTextField(labelWithString: text)
    view.font = .systemFont(ofSize: size, weight: weight)
    view.textColor = color
    view.lineBreakMode = .byTruncatingTail
    return view
}
func iconButton(_ symbol: String, _ help: String, target: AnyObject?, action: Selector) -> NSButton {
    let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: help)!, target: target, action: action)
    button.bezelStyle = .inline
    button.isBordered = false
    button.imageScaling = .scaleProportionallyDown
    button.toolTip = help
    button.setAccessibilityLabel(help)
    return button
}

final class TrackCell: NSTableCellView {
    let artwork = ArtworkView(frame: NSRect(x: 4, y: 8, width: 32, height: 32))
    let titleLabel = label("", size: 12, weight: .medium)
    let artistLabel = label("", size: 11, color: .secondaryLabelColor)
    let durationLabel = label("", size: 10, color: .secondaryLabelColor)
    var mixButton: NSButton!
    override init(frame: NSRect) {
        super.init(frame: frame)
        [artwork, titleLabel, artistLabel, durationLabel].forEach(addSubview)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        titleLabel.frame = NSRect(x: 44, y: 25, width: bounds.width - 117, height: 17)
        artistLabel.frame = NSRect(x: 44, y: 9, width: bounds.width - 117, height: 15)
        durationLabel.frame = NSRect(x: bounds.width - 70, y: 18, width: 40, height: 16)
        durationLabel.alignment = .right
        mixButton?.frame = NSRect(x: bounds.width - 25, y: 15, width: 24, height: 24)
    }
}

final class PlayerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    let store: PlayerStore
    let searchField = NSSearchField()
    let table = NSTableView()
    let artwork = ArtworkView(frame: .zero)
    let trackTitle = label("Find your next favorite.", size: 14, weight: .semibold)
    let artist = label("Search YouTube. Keep listening from your menu bar.", size: 12, color: .secondaryLabelColor)
    let elapsed = label("0:00", size: 10, color: .secondaryLabelColor)
    let remaining = label("0:00", size: 10, color: .secondaryLabelColor)
    let status = label("", size: 11, color: .secondaryLabelColor)
    let heading = label("Search", size: 12, weight: .semibold)
    let empty = label("Search for a song, artist, or album.", size: 12, color: .secondaryLabelColor)
    let progress = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    let volume = NSSlider(value: 70, minValue: 0, maxValue: 100, target: nil, action: nil)
    let tabs = NSSegmentedControl(labels: ["Up next", "Search"], trackingMode: .selectOne, target: nil, action: nil)
    var play: NSButton!
    private var lastTracks: [Track] = []
    private var lastCurrent = ""
    var openMenu: ((NSView) -> Void)?
    var close: (() -> Void)?
    private var monitor: Any?

    init(store: PlayerStore) { self.store = store; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 460))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        preferredContentSize = view.frame.size

        let name = label("YouTube Music", size: 14, weight: .semibold)
        place(name, x: 16, y: 426, w: 260, h: 20)
        let more = iconButton("ellipsis.circle", "Player menu", target: self, action: #selector(menu(_:)))
        place(more, x: 300, y: 423, w: 26, h: 26)
        searchField.placeholderString = "Songs, artists, albums"
        searchField.font = .systemFont(ofSize: 13)
        searchField.delegate = self
        searchField.target = self; searchField.action = #selector(search)
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = true
        place(searchField, x: 16, y: 388, w: 308, h: 26)

        place(artwork, x: 16, y: 304, w: 72, h: 72)
        trackTitle.alignment = .left; artist.alignment = .left
        trackTitle.maximumNumberOfLines = 2
        trackTitle.lineBreakMode = .byWordWrapping
        place(trackTitle, x: 100, y: 335, w: 224, h: 39)
        place(artist, x: 100, y: 311, w: 224, h: 18)
        place(elapsed, x: 16, y: 277, w: 40, h: 16)
        remaining.alignment = .right
        place(remaining, x: 280, y: 277, w: 44, h: 16)
        progress.target = self; progress.action = #selector(seek)
        progress.isContinuous = false
        progress.setAccessibilityLabel("Playback position")
        place(progress, x: 60, y: 275, w: 214, h: 20)

        let previous = iconButton("backward.end.fill", "Previous track", target: self, action: #selector(previousTrack))
        play = iconButton("play.circle.fill", "Play or pause", target: self, action: #selector(togglePlayback))
        play.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 34, weight: .regular)
        play.contentTintColor = .controlAccentColor
        let next = iconButton("forward.end.fill", "Next track", target: self, action: #selector(nextTrack))
        let mix = iconButton("dot.radiowaves.left.and.right", "Build a mix from this track", target: self, action: #selector(currentMix))
        place(previous, x: 104, y: 233, w: 28, h: 30)
        place(play, x: 150, y: 227, w: 40, h: 40)
        place(next, x: 208, y: 233, w: 28, h: 30)
        place(mix, x: 296, y: 233, w: 28, h: 30)
        let rule = NSBox(); rule.boxType = .separator
        place(rule, x: 16, y: 217, w: 308, h: 1)
        place(heading, x: 16, y: 188, w: 140, h: 19)
        tabs.target = self; tabs.action = #selector(changeTab)
        tabs.controlSize = .small
        place(tabs, x: 166, y: 187, w: 158, h: 24)

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("track"))
        column.width = 300
        column.resizingMask = .autoresizingMask
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 48
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.style = .plain
        table.dataSource = self; table.delegate = self
        table.target = self; table.doubleAction = #selector(activateRow)
        table.setAccessibilityLabel("Tracks. Use arrow keys and Return to play.")
        scroll.documentView = table
        place(scroll, x: 12, y: 45, w: 316, h: 134)
        empty.alignment = .center
        place(empty, x: 20, y: 96, w: 300, h: 42)
        empty.maximumNumberOfLines = 2
        status.lineBreakMode = .byTruncatingTail
        place(status, x: 16, y: 27, w: 308, h: 15)
        let speaker = NSImageView(image: NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "Volume")!)
        place(speaker, x: 17, y: 6, w: 14, h: 14)
        volume.target = self; volume.action = #selector(changeVolume)
        volume.controlSize = .mini
        volume.setAccessibilityLabel("Volume")
        place(volume, x: 37, y: 5, w: 76, h: 17)
        let hint = label("⌘K search    Space play / pause", size: 10, color: .tertiaryLabelColor)
        hint.alignment = .right
        place(hint, x: 124, y: 6, w: 200, h: 15)
        render()
    }
    private func place(_ child: NSView, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        child.frame = NSRect(x: x, y: y, width: w, height: h)
        view.addSubview(child)
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        if store.current == nil { view.window?.makeFirstResponder(searchField) }
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.window === self.view.window else { return event }
                if event.keyCode == 53 { self.close?(); return nil }
                if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "k" {
                    self.focusSearch(); return nil
                }
                let editing = self.view.window?.firstResponder is NSTextView
                if !editing && event.keyCode == 49 { self.store.toggle(); return nil }
                if !editing && event.keyCode == 36 { self.activateRow(); return nil }
                if event.modifierFlags.contains(.command), event.keyCode == 124 { self.store.next(); return nil }
                if event.modifierFlags.contains(.command), event.keyCode == 123 { self.store.previous(); return nil }
                return event
            }
        }
    }
    override func viewDidDisappear() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        super.viewDidDisappear()
    }
    func focusSearch() {
        store.showingSearch = true; render()
        view.window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
    }
    func render() {
        guard isViewLoaded else { return }
        artwork.show(store.current)
        trackTitle.stringValue = store.current?.title ?? "Find your next favorite."
        trackTitle.toolTip = store.current?.title
        artist.stringValue = store.current?.artist ?? "Your music, one click away."
        elapsed.stringValue = clockTime(store.position)
        remaining.stringValue = store.current?.isLive == true ? "LIVE" : clockTime(store.duration)
        progress.maxValue = max(1, store.duration)
        progress.doubleValue = store.position
        progress.isEnabled = store.duration > 0
        volume.floatValue = store.volume * 100
        play.image = NSImage(systemSymbolName: store.playing || store.loading ? "pause.circle.fill" : "play.circle.fill", accessibilityDescription: "Play or pause")
        play.isEnabled = store.current != nil
        heading.stringValue = store.showingSearch ? "Search results" : (store.mixing ? "Building mix…" : "Up next")
        tabs.selectedSegment = store.showingSearch ? 1 : 0
        status.stringValue = store.loading ? "Loading audio…" : store.message
        status.toolTip = store.message
        empty.isHidden = !store.displayedTracks.isEmpty
        empty.stringValue = store.searching ? "Searching YouTube…" : (store.showingSearch ? (store.query.isEmpty ? "Search for a song, artist, or album." : "No tracks found. Try another search.") : "Choose a track to start a mix.")
        if lastTracks != store.displayedTracks || lastCurrent != store.current?.id {
            lastTracks = store.displayedTracks; lastCurrent = store.current?.id ?? ""
            table.reloadData()
            if !store.showingSearch, store.queue.current != nil {
                table.selectRowIndexes(IndexSet(integer: store.queue.index), byExtendingSelection: false)
                table.scrollRowToVisible(store.queue.index)
            } else if !lastTracks.isEmpty && table.selectedRow < 0 {
                table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
        }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { store.displayedTracks.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard store.displayedTracks.indices.contains(row) else { return nil }
        let track = store.displayedTracks[row]
        let cell = TrackCell(frame: NSRect(x: 0, y: 0, width: 300, height: 52))
        cell.artwork.show(track)
        cell.titleLabel.stringValue = track.title
        cell.titleLabel.textColor = track.id == store.current?.id ? .controlAccentColor : .labelColor
        cell.artistLabel.stringValue = track.artist
        cell.alphaValue = !store.showingSearch && row < store.queue.index ? 0.55 : 1
        cell.durationLabel.stringValue = track.durationLabel
        cell.toolTip = "\(track.title)\n\(track.artist)\nDouble-click to play"
        cell.mixButton = iconButton("dot.radiowaves.left.and.right", "Start a mix", target: self, action: #selector(rowMix(_:)))
        cell.mixButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        cell.mixButton.tag = row
        cell.addSubview(cell.mixButton)
        return cell
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveDown(_:)), !store.displayedTracks.isEmpty {
            view.window?.makeFirstResponder(table)
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            return true
        }
        return false
    }
    @objc private func search() { store.search(searchField.stringValue) }
    @objc func activateRow() { if table.selectedRow >= 0 { store.select(table.selectedRow) } }
    @objc private func changeTab() { store.showingSearch = tabs.selectedSegment == 1; render() }
    @objc private func togglePlayback() { store.toggle() }
    @objc private func previousTrack() { store.previous() }
    @objc private func nextTrack() { store.next() }
    @objc private func seek() { store.seek(progress.doubleValue) }
    @objc private func changeVolume() { store.volume = volume.floatValue / 100 }
    @objc private func currentMix() { if let track = store.current { store.startMix(from: track) } }
    @objc private func rowMix(_ sender: NSButton) {
        guard store.displayedTracks.indices.contains(sender.tag) else { return }
        store.startMix(from: store.displayedTracks[sender.tag])
    }
    @objc private func menu(_ sender: NSButton) { openMenu?(sender) }
}
