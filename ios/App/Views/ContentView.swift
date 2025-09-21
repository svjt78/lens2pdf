import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ScanCaptureView()
                .tabItem {
                    Label("Scan", systemImage: "doc.viewfinder")
                }

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "tray.full")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

