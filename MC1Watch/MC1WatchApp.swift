import SwiftUI

@main
struct MC1WatchApp: App {
  @State private var receiver = WatchSnapshotReceiver()

  var body: some Scene {
    WindowGroup {
      ContentView(
        snapshot: receiver.snapshot,
        isPhoneReachable: receiver.isPhoneReachable,
        onRefresh: receiver.requestRefresh
      )
      .task { receiver.activate() }
    }
  }
}
