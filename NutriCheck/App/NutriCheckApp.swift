import SwiftData
import SwiftUI

@main
struct NutriCheckApp: App {
    @State private var appState = AppState()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: FoodEntry.self, ExerciseEntry.self, ChatMessage.self)
        } catch {
            fatalError("Could not open the NutriCheck database: \(error)")
        }
        #if DEBUG
        DebugSupport.prepare(container: container)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .fontDesign(.rounded)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @State private var tab = DebugSupport.initialTab
    @State private var showSampleResult = DebugSupport.showSampleResult

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "chart.pie.fill") }
                .tag(0)
            AssistantView()
                .tabItem { Label("Assistant", systemImage: "sparkles") }
                .tag(1)
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.xaxis") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        #if DEBUG
        .sheet(isPresented: $showSampleResult) {
            ScanFlowView(request: ScanRequest(mealType: .lunch, date: .now, debugAnalysis: SampleData.biryani))
        }
        #endif
    }
}
