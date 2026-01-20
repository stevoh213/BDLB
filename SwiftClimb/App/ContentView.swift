import SwiftUI

@MainActor
struct ContentView: View {
    @State private var selectedTab: Tab = .session

    enum Tab {
        case session
        case logbook
        case insights
        case feed
        case search
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionView()
                .tabItem {
                    Label("Session", systemImage: "figure.climbing")
                }
                .tag(Tab.session)

            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "book.fill")
                }
                .tag(Tab.logbook)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.xyaxis.line")
                }
                .tag(Tab.insights)

            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "rectangle.stack.fill")
                }
                .tag(Tab.feed)

            ProfileSearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)

            MyProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
    }
}

#Preview {
    ContentView()
}
