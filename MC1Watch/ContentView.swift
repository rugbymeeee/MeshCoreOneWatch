import MC1Services
import SwiftData
import SwiftUI

/// Placeholder home screen until the iPhone bridge lands.
struct ContentView: View {
  @Query private var contacts: [Contact]

  var body: some View {
    NavigationStack {
      List {
        Section {
          Label("Not Connected", systemImage: "antenna.radiowaves.left.and.right.slash")
        } footer: {
          Text("Open MeshCore One on your iPhone to connect a radio.")
        }

        Section {
          LabeledContent("Contacts", value: contacts.count, format: .number)
        }
      }
      .navigationTitle("MeshCore One")
    }
  }
}
