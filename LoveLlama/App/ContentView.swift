import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "shield.checkered")
                }
                .tag(0)

            ChatAnalysisView()
                .tabItem {
                    Label("Analyze", systemImage: "text.bubble")
                }
                .tag(1)

            PhotoVerificationView()
                .tabItem {
                    Label("Photo", systemImage: "person.crop.circle.badge.questionmark")
                }
                .tag(2)

            ChecklistView()
                .tabItem {
                    Label("Checklist", systemImage: "checklist")
                }
                .tag(3)

            HistoryListView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(4)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(5)
        }
        .tint(Color(red: 0.55, green: 0.11, blue: 0.53))
        .onOpenURL { url in
            if url.scheme == "lovellama", let host = url.host {
                switch host {
                case "home": selectedTab = 0
                case "analyze": selectedTab = 1
                case "photo": selectedTab = 2
                case "checklist": selectedTab = 3
                case "history": selectedTab = 4
                case "settings": selectedTab = 5
                default: break
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChecklistSession.self, Conversation.self, PhotoCheck.self], inMemory: true)
}
