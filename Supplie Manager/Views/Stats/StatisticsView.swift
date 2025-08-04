import SwiftUI

struct StatisticsView: View {
    @ObservedObject var store: MaterialStore
    @ObservedObject var authManager: BambuAuthManager
    @ObservedObject var printerManager: BambuPrinterManager
    @State private var showLoginSheet = false
    
    var body: some View {
        NavigationView {
            List {
                // 打印机状态区域 - 仅在登录后显示
                if authManager.isLoggedIn {
                    BambuPrinterStatusView(printerManager: printerManager)
                        .environmentObject(store)
                }
                
                Section(header: Text("总用量统计")) {
                    HStack {
                        Text("累计使用耗材")
                        Spacer()
                        Text(formatWeight(store.getTotalConsumedWeight()))
                                .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("累计消耗金额")
                        Spacer()
                        Text("¥\(String(format: "%.2f", store.getTotalConsumedCost()))")
                            .foregroundColor(.secondary)
                    }
                    
                    if !printerManager.recentTasks.isEmpty {
                        HStack {
                            Text("累计打印次数")
                            Spacer()
                            Text("\(printerManager.totalPrintCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("平均耗材成本")
                        Spacer()
                        let consumedWeight = store.getTotalConsumedWeight()
                        let avgCost = consumedWeight > 0 ? store.getTotalConsumedCost() / consumedWeight : 0
                        Text("¥\(String(format: "%.2f", avgCost))/g")
                            .foregroundColor(.secondary)
                    }
                }
                
                
                Section(header: Text("现有耗材")) {
                    // 只显示有剩余的耗材
                    ForEach(store.materials.filter { $0.remainingWeight > 0 }
                             .sorted(by: {
                                 // 首先按照是否有使用量排序（初始重量-剩余重量>0表示有使用）
                                 let hasUsage1 = $0.initialWeight - $0.remainingWeight > 0
                                 let hasUsage2 = $1.initialWeight - $1.remainingWeight > 0
                                 if hasUsage1 != hasUsage2 {
                                     return hasUsage1 && !hasUsage2
                                 }
                                 // 其次按购入时间降序排序（较新的排在前面）
                                 return $0.purchaseDate > $1.purchaseDate
                             })) { material in
                        HStack {
                            MaterialColorView(material: material, size: 20, strokeWidth: 1)
                            
                            VStack(alignment: .leading) {
                                Text(material.displayNameWithId)
                                    .font(.headline)
                                Text("剩余: \(String(format: "%.2f", material.remainingWeight))g / \(material.formattedWeight)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("单价: ¥\(String(format: "%.2f", material.price / material.initialWeight))/g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // 耗材使用进度条
                            ProgressView(value: 1 - (material.remainingWeight / material.initialWeight))
                                .frame(width: 50)
                        }
                    }
                }
                
                Section(header: Text("最近使用记录")) {
                    if store.printRecords.isEmpty {
                        Text("暂无记录")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.printRecords.sorted(by: { $0.date > $1.date }).prefix(5)) { record in
                            VStack(alignment: .leading) {
                                Text(record.modelName)
                                    .font(.headline)
                                
                                HStack {
                                    Text("使用材料: \(record.materialName)")
                                    Spacer()
                                    Text("\(String(format: "%.2f", record.weightUsed))g")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("成本: ¥\(String(format: "%.2f", store.getCostForRecord(record)))")
                                    Spacer()
                                    Text("日期: \(record.date.formatted(date: .abbreviated, time: .shortened))")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("数据统计")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showLoginSheet = true
                    }) {
                        Text(authManager.isLoggedIn ? "Bambu账号" : "登录")
                    }
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                BambuLoginView(authManager: authManager)
                    .onDisappear {
                        // 登录成功后，自动获取打印机状态
                        if authManager.isLoggedIn {
                            Task {
                                await printerManager.fetchPrinters()
                            }
                        }
                    }
            }
        }
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight >= 1000 {
            return String(format: "%.3f kg", weight / 1000)
        } else {
            return String(format: "%.0f g", weight)
        }
    }
}