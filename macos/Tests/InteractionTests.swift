import AppKit

final class InteractionClient: MusicClient {
    var available = true
    var requests: [(Result<[Track], Error>) -> Void] = []
    func search(_ query: String, completion: @escaping (Result<[Track], Error>) -> Void) -> Extraction {
        requests.append(completion); return Extraction()
    }
    func mix(_ seed: Track, completion: @escaping (Result<[Track], Error>) -> Void) -> Extraction { Extraction() }
    func stream(_ track: Track, completion: @escaping (Result<URL, Error>) -> Void) -> Extraction { Extraction() }
}

@main struct InteractionTests {
    static func main() throws {
        _ = NSApplication.shared
        let suite = "youtube-music-interaction-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let a = Track(id: "abcdefghijk", title: "A", artist: "Test", duration: 120, isLive: false)
        let b = Track(id: "lmnopqrstuv", title: "B", artist: "Test", duration: 120, isLive: false)
        defaults.set(try JSONEncoder().encode(QueueState(tracks: [a], index: 0)), forKey: "queue")
        let client = InteractionClient()
        let store = PlayerStore(client: client, defaults: defaults, enableMediaControls: false)
        defer { store.shutdown() }
        let controller = PlayerViewController(store: store)
        _ = controller.view
        store.changed = { controller.render() }
        precondition(!controller.searchExpanded && !controller.artwork.isHidden)
        controller.toggleSearch()
        precondition(controller.searchExpanded && !controller.artwork.isHidden, "Revealing search must keep the player visible")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        precondition(controller.searchField.superview!.frame.maxX == 326)
        precondition(controller.searchField.superview!.frame.width == 200)
        precondition(controller.searchField.frame.width > 100, "Search text must expand inside the capsule")
        controller.toggleSearch()
        precondition(!controller.searchExpanded)
        controller.focusSearch()
        controller.searchField.stringValue = "ab"
        controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        precondition(controller.artwork.isHidden && controller.scroll.frame.height == 399)
        precondition(client.requests.isEmpty, "Search must wait for the debounce")
        RunLoop.main.run(until: Date().addingTimeInterval(0.65))
        precondition(client.requests.count == 1)
        client.requests[0](.success([a, b]))
        controller.selectRow(1)
        precondition(store.current == b && !store.showingSearch)
        precondition(!controller.searchExpanded && !controller.artwork.isHidden)
        precondition(controller.scroll.frame.height == 90)
        controller.focusSearch()
        store.search("later")
        store.editQuery("")
        client.requests[1](.success([a]))
        precondition(!store.showingSearch && store.current == b && store.results.isEmpty,
                     "Clearing search must restore the queue and reject the old request")
        precondition(!controller.artwork.isHidden && controller.searchExpanded)
        print("PASS: search reveal/toggle, full results view, debounce, single-action playback, clear-to-queue, stale search rejection")
    }
}
