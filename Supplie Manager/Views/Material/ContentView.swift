import SwiftUI

struct ContentView: View {
    @StateObject private var store = MaterialStore()
    @StateObject private var authManager = BambuAuthManager()
    @StateObject private var printerManager: BambuPrinterManager
    
    init() {
        let auth = BambuAuthManager()
        self._authManager = StateObject(wrappedValue: auth)
        self._printerManager = StateObject(wrappedValue: BambuPrinterManager(authManager: auth))
    }
    
    var body: some View {
        TabView {
            StatisticsView(store: store, authManager: authManager, printerManager: printerManager)
                .tabItem {
                    Label("数据统计", systemImage: "chart.bar.fill")
                }
            
            MyMaterialsView(store: store)
                .tabItem {
                    Label("我的耗材", systemImage: "cylinder.fill")
                }
            
            RecordUsageView(store: store)
                .tabItem {
                    Label("记录用量", systemImage: "pencil")
                }
            
            PresetManagementView(store: store)
                .tabItem {
                    Label("预设管理", systemImage: "paintbrush.fill")
                }
            
            ToolsView()
                .tabItem {
                    Label("工具", systemImage: "wrench.and.screwdriver.fill")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}