import SwiftUI

// 本地化日期
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

struct RecordUsageView: View {
    @ObservedObject var store: MaterialStore
    @State private var isShowingAddSheet = false
    @State private var modelName = ""
    @State private var makerWorldLink = ""
    @State private var selectedMaterialId: UUID?
    @State private var weightUsed = ""
    @State private var searchText = ""
    @State private var loadedRecordsCount = 20 // 初始加载记录数量
    @State private var showInvalidLinkAlert = false // 添加警告弹窗控制状态
    
    // 只获取有剩余的材料
    private var availableMaterials: [Material] {
        store.materials.filter { $0.remainingWeight > 0 }
    }
    
    // 搜索过滤和排序后的记录
    private var filteredAndSortedRecords: [PrintRecord] {
        let sorted = store.printRecords.sorted(by: { $0.date > $1.date })
        
        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { record in
                record.modelName.localizedCaseInsensitiveContains(searchText) ||
                record.materialName.localizedCaseInsensitiveContains(searchText) ||
                record.makerWorldLink.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // 当前应该显示的记录数量（考虑懒加载）
    private var recordsToShow: [PrintRecord] {
        return Array(filteredAndSortedRecords.prefix(min(loadedRecordsCount, filteredAndSortedRecords.count)))
    }
    
    // 检查链接是否是有效的 Makerworld 链接
    private func isValidMakerWorldLink(_ link: String) -> Bool {
        return link.contains("makerworld.com") || link.contains("makerworld.com.cn")
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(recordsToShow) { record in
                        VStack(alignment: .leading) {
                            Text(record.modelName)
                                .font(.headline)
                                
                            HStack {
                                Text("使用材料: \(record.materialName)")
                                    .font(.caption)
                                Spacer()
                                Text("\(String(format: "%.2f", record.weightUsed))g")
                            }
                            .foregroundColor(.secondary)
                            
                            HStack {
                                Text("成本: ¥\(String(format: "%.2f", store.getCostForRecord(record)))")
                                Spacer()
                                Text("日期: \(dateFormatter.string(from: record.date))")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle()) // 确保整个区域可点击
                        .onTapGesture {
                            if !record.makerWorldLink.isEmpty {
                                if isValidMakerWorldLink(record.makerWorldLink) {
                                    if let url = URL(string: record.makerWorldLink) {
                                        UIApplication.shared.open(url)
                                    }
                                } else {
                                    showInvalidLinkAlert = true
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deletePrintRecord(id: record.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .onAppear {
                            // 如果显示到列表最后几个项目，加载更多数据
                            if record.id == recordsToShow.last?.id && loadedRecordsCount < filteredAndSortedRecords.count {
                                loadMoreContent()
                            }
                        }
                    }
                    
                    // 如果还有更多内容可以加载，显示加载按钮
                    if loadedRecordsCount < filteredAndSortedRecords.count {
                        Button(action: loadMoreContent) {
                            HStack {
                                Spacer()
                                Text("加载更多...")
                                Spacer()
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .searchable(text: $searchText, prompt: "搜索模型名称、材料...")
                // 添加无效链接警告弹窗
                .alert("无效链接", isPresented: $showInvalidLinkAlert) {
                    Button("确定", role: .cancel) { }
                } message: {
                    Text("暂无有效的 Makerworld 链接")
                }
            }
            .navigationTitle("打印记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("模型信息")) {
                            TextField("模型名称", text: $modelName)
                            TextField("Makerworld链接", text: $makerWorldLink)
                        }
                        
                        Section(header: Text("使用材料")) {
                            if availableMaterials.isEmpty {
                                Text("没有可用耗材，请先添加耗材")
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("选择材料", selection: $selectedMaterialId) {
                                    Text("请选择").tag(nil as UUID?)
                                    ForEach(availableMaterials) { material in
                                        HStack {
                                            MaterialColorView(material: material, size: 12, strokeWidth: 0.5)
                                            Text(material.displayNameWithId)
                                        }.tag(material.id as UUID?)
                                    }
                                }
                                
                                if let materialId = selectedMaterialId,
                                   let material = availableMaterials.first(where: { $0.id == materialId }) {
                                    Text("剩余: \(String(format: "%.2f", material.remainingWeight))g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("单价: ¥\(String(format: "%.2f", material.price / material.initialWeight))/g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                TextField("用量(g)", text: $weightUsed)
                                    .keyboardType(.decimalPad)
                                
                                if let materialId = selectedMaterialId,
                                   let material = availableMaterials.first(where: { $0.id == materialId }),
                                   let weight = Double(weightUsed), weight > 0 {
                                    Text("预计成本: ¥\(String(format: "%.2f", (material.price / material.initialWeight) * weight))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    // 添加警告，如果用量超过剩余量
                                    if weight > material.remainingWeight {
                                        Text("警告：用量超过剩余量！最大可用：\(String(format: "%.2f", material.remainingWeight))g")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("记录用量")
                    .navigationBarItems(
                        leading: Button("取消") {
                            isShowingAddSheet = false
                            resetForm()
                        },
                        trailing: Button("保存") {
                            if !modelName.isEmpty && selectedMaterialId != nil && !weightUsed.isEmpty,
                               let weight = Double(weightUsed),
                               let materialId = selectedMaterialId,
                               let material = availableMaterials.first(where: { $0.id == materialId }) {
                                // 限制用量不超过剩余量
                                let actualWeight = min(weight, material.remainingWeight)
                                
                                let newRecord = PrintRecord(
                                    modelName: modelName,
                                    makerWorldLink: makerWorldLink,
                                    materialId: materialId,
                                    materialName: material.fullName,
                                    weightUsed: actualWeight,
                                    date: Date()
                                )
                                store.addPrintRecord(newRecord)
                                isShowingAddSheet = false
                                resetForm()
                            }
                        }
                        .disabled(selectedMaterialId == nil || modelName.isEmpty || weightUsed.isEmpty ||
                                  (selectedMaterialId != nil && Double(weightUsed) ?? 0 <= 0))
                    )
                }
            }
            .onAppear {
                // 重置加载计数器，以确保UI刷新时重新加载
                loadedRecordsCount = min(20, store.printRecords.count)
            }
        }
    }
    
    private func loadMoreContent() {
        // 增加加载的记录数量，每次增加20条
        loadedRecordsCount += 20
    }
    
    private func resetForm() {
        modelName = ""
        makerWorldLink = ""
        selectedMaterialId = nil
        weightUsed = ""
    }
}