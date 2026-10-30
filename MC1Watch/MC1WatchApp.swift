import SwiftUI

@main
struct MC1WatchApp: App {
  /// Activated in `init()` rather than in a view task, so the session also runs when the system
  /// launches the app in the background to deliver iPhone data.
  private let receiver = WatchSnapshotReceiver()

  init() {
    receiver.activate()
  }

  var body: some Scene {
    WindowGroup {
      ContentView(receiver: receiver)
    }
  }
}
