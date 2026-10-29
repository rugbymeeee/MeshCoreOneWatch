import MC1Services
import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.mc1", category: "MC1WatchApp")

@main
struct MC1WatchApp: App {
  /// Same SwiftData schema as the iPhone app, stored locally on the watch.
  /// nil when the store cannot be opened, so the UI can say so instead of crashing.
  private let container: ModelContainer?

  init() {
    do {
      container = try PersistenceStore.createContainer()
    } catch {
      logger.error("Container creation failed: \(error)")
      container = nil
    }
  }

  var body: some Scene {
    WindowGroup {
      if let container {
        ContentView()
          .modelContainer(container)
      } else {
        ContentUnavailableView(
          "Storage Unavailable",
          systemImage: "externaldrive.badge.exclamationmark",
          description: Text("MeshCore One could not open its database.")
        )
      }
    }
  }
}
