import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: PlayerStore!
    var controller: PlayerViewController!
    var statusItem: NSStatusItem!
    let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Opening a second copy should not create a second audio player.
        let identifier = Bundle.main.bundleIdentifier ?? "io.github.itsdotdev.youtube-music.macos"
        let peers = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
        if let peer = peers.first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            peer.activate(options: [.activateIgnoringOtherApps])
            NSApp.terminate(nil); return
        }
        installMenu()
        store = PlayerStore()
        controller = PlayerViewController(store: store)
        controller.close = { [weak self] in self?.popover.performClose(nil) }
        controller.openMenu = { [weak self] anchor in self?.showMenu(anchor) }
        popover.contentViewController = controller
        popover.contentSize = NSSize(width: 340, height: 460)
        popover.behavior = .transient
        popover.animates = false
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "YouTube Music")
        button.imagePosition = .imageLeading
        button.target = self; button.action = #selector(statusClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        store.changed = { [weak self] in self?.refresh() }
        refresh()
        DispatchQueue.main.async { self.show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func applicationWillTerminate(_ notification: Notification) { store?.shutdown() }
    private func installMenu() {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About YouTube Music", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit YouTube Music", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item)
        let edit = NSMenu(title: "Edit")
        for (name, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: name, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); editItem.submenu = edit; menu.addItem(editItem)
        NSApp.mainMenu = menu
    }
    func show() {
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp, let button = statusItem.button { showMenu(button) }
        else if popover.isShown { popover.performClose(nil) }
        else { show() }
    }
    private func refresh() {
        controller.render()
        guard let button = statusItem.button else { return }
        button.title = ""
        button.toolTip = store.current.map { "\($0.title) · \($0.artist)" } ?? "YouTube Music"
        button.image = NSImage(systemSymbolName: store.playing ? "waveform" : "play.circle", accessibilityDescription: "YouTube Music")
    }

    private func showMenu(_ anchor: NSView) {
        let menu = NSMenu()
        let entries: [(String, Selector)] = [
            ("Show player", #selector(openPlayer)), ("Search…", #selector(focusSearch)),
            ("Play / Pause", #selector(toggle)), ("Next track", #selector(next)),
            ("Retry mix", #selector(retryMix)), ("Open track on YouTube", #selector(openTrack)),
            ("About YouTube Music", #selector(about))
        ]
        for (title, action) in entries {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit YouTube Music", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: anchor.bounds.height), in: anchor)
    }
    @objc private func openPlayer() { show() }
    @objc private func focusSearch() { show(); controller.focusSearch() }
    @objc private func toggle() { store.toggle() }
    @objc private func next() { store.next() }
    @objc private func previous() { store.previous() }
    @objc private func retryMix() { store.retryMix() }
    @objc private func openTrack() { if let url = store.current?.url { NSWorkspace.shared.open(url) } }
    @objc private func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "YouTube Music", .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "A native macOS adaptation of itsdotdev/omarchy-youtube-music.\nPublic YouTube search and mixes. No account required.\nBuilt with yt-dlp and Deno.\nNot affiliated with YouTube or Google.")
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
