import SwiftUI

struct BambuPrinterStatusView: View {
    @ObservedObject var printerManager: BambuPrinterManager
    @EnvironmentObject var store: MaterialStore
    @State private var isRefreshing = false
    @State private var showPrintHistory = false
    
    var body: some View {
        Section(header: Text("打印机状态")) {
            // 显示累计打印数量
            if printerManager.isLoading && printerManager.printers.isEmpty {
                HStack {
                    Spacer()
                    ProgressView("加载中...")
                    Spacer()
                }
                .padding(.vertical, 10)
            } else if let errorMessage = printerManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            } else if printerManager.printers.isEmpty {
                Text("未找到打印机设备")
                    .foregroundColor(.secondary)
            } else {
                // 显示打印机列表
                ForEach(printerManager.printers) { printer in
                    PrinterStatusCard(printer: printer)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 点击打开打印历史
                            showPrintHistory = true
                        }
                }
                
                Button(action: {
                    isRefreshing = true
                    Task {
                        await printerManager.fetchPrinters()
                        isRefreshing = false
                    }
                }) {
                    HStack {
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                                .padding(.trailing, 5)
                        }
                        Text("刷新状态")
                        Spacer()
                    }
                }
                .disabled(isRefreshing || printerManager.isLoading)
            }
        }
        .sheet(isPresented: $showPrintHistory) {
            PrintHistoryView(printerManager: printerManager)
                .environmentObject(store)
        }
    }
}

struct PrinterStatusCard: View {
    let printer: PrinterInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(printer.name)
                    .font(.headline)
                Spacer()
                StatusBadge(status: printer.online ? "在线" : "离线", isOnline: printer.online)
            }
            
            // 打印机状态详情 - 简化版本
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("型号:")
                        Text(printer.modelDescription)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("状态:")
                        Text(printer.detailedStatus.description)
                            .foregroundColor(printer.statusColor)
                        Image(systemName: printer.statusIcon)
                            .foregroundColor(printer.statusColor)
                    }
                    .font(.caption)
                }
                
                Spacer()
                
                // 添加一个小图标表示可以点击查看更多
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    // 根据状态返回颜色
    private func statusColor(for status: String) -> Color {
        switch status {
        case "IDLE":
            return .secondary // 空闲
        case "RUNNING":
            return .blue // 打印中
        case "PAUSE":
            return .orange // 暂停
        case "SUCCESS":
            return .green // 完成
        case "FAILED":
            return .red // 错误
        default:
            return .secondary
        }
    }
}

// 状态标签组件
struct StatusBadge: View {
    let status: String
    let isOnline: Bool
    
    var body: some View {
        Text(status)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isOnline ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
            .foregroundColor(isOnline ? .green : .gray)
            .cornerRadius(8)
    }
}

// 打印历史视图 - 懒加载方式展示历史记录
struct PrintHistoryView: View {
    @ObservedObject var printerManager: BambuPrinterManager
    @EnvironmentObject var store: MaterialStore
    @Environment(\.dismiss) private var dismiss
    @State private var loadedTasksCount = 20 // 初始加载记录数量
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            List {
                if printerManager.recentTasks.isEmpty {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView("正在加载打印记录...")
                            Spacer()
                        }
                    } else {
                        Text("暂无打印记录")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(Array(printerManager.recentTasks.prefix(loadedTasksCount))) { task in
                        PrintTaskRow(task: task)
                            .environmentObject(store)
                            .onAppear {
                                // 如果显示到列表最后几个项目，加载更多数据
                                if task.id == printerManager.recentTasks.prefix(loadedTasksCount).last?.id &&
                                   loadedTasksCount < printerManager.recentTasks.count {
                                    loadMoreTasks()
                                }
                            }
                    }
                    
                    // 如果还有更多内容可以加载，显示加载按钮
                    if loadedTasksCount < printerManager.recentTasks.count {
                        Button("加载更多...") {
                            loadMoreTasks()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("打印历史记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 加载打印任务历史
                if printerManager.recentTasks.isEmpty {
                    isLoading = true
                    Task {
                        await printerManager.fetchRecentTasks()
                        isLoading = false
                    }
                }
            }
        }
    }
    
    private func loadMoreTasks() {
        // 增加加载的记录数量，每次增加20条
        loadedTasksCount += 20
    }
}

// 打印任务行
struct PrintTaskRow: View {
    let task: PrintTaskInfo
    @State private var showAddToStatsSheet = false
    @EnvironmentObject var store: MaterialStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(task.title)
                .font(.headline)
            
            HStack {
                Text("设备: \(task.deviceName)")
                Spacer()
                Text("型号: \(task.deviceModel)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            HStack {
                if let firstMaterial = task.amsDetailMapping.first {
                    Text("材料: \(firstMaterial.filamentType)")
                }
                Spacer()
                Text("用量: \(String(format: "%.2f", task.weight))g")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            HStack {
                Text("开始: \(task.formattedStartTime)")
                Spacer()
                Text("用时: \(task.formattedPrintTime)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // 添加"添加到统计"按钮
            Button(action: {
                showAddToStatsSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("添加到耗材统计")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showAddToStatsSheet) {
            AddPrintTaskToStatsView(task: task, isPresented: $showAddToStatsSheet)
                .environmentObject(store)
        }
    }
}

// 将打印任务添加到统计的视图
struct AddPrintTaskToStatsView: View {
    let task: PrintTaskInfo
    @Binding var isPresented: Bool
    @EnvironmentObject var store: MaterialStore
    
    @State private var selectedMaterialId: UUID?
    @State private var weightUsed: String
    @State private var modelName: String
    @State private var makerWorldLink: String = ""
    
    init(task: PrintTaskInfo, isPresented: Binding<Bool>) {
        self.task = task
        self._isPresented = isPresented
        // 初始化状态变量
        self._weightUsed = State(initialValue: String(format: "%.2f", task.weight))
        self._modelName = State(initialValue: task.title)
    }
    
    // 只获取有剩余的材料
    private var availableMaterials: [Material] {
        store.materials.filter { $0.remainingWeight > 0 }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("打印模型信息")) {
                    TextField("模型名称", text: $modelName)
                    TextField("Makerworld链接", text: $makerWorldLink)
                }
                
                Section(header: Text("耗材信息")) {
                    if availableMaterials.isEmpty {
                        Text("没有可用耗材，请先添加耗材")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("选择材料", selection: $selectedMaterialId) {
                            Text("请选择").tag(nil as UUID?)
                            ForEach(availableMaterials) { material in
                                HStack {
                                    Circle()
                                        .fill(material.color)
                                        .frame(width: 12, height: 12)
                                    Text(material.fullName)
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
                
                Section(header: Text("打印任务信息")) {
                    HStack {
                        Text("设备名称")
                        Spacer()
                        Text(task.deviceName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("打印时间")
                        Spacer()
                        Text(task.formattedStartTime)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("用时")
                        Spacer()
                        Text(task.formattedPrintTime)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("添加到耗材统计")
            .navigationBarItems(
                leading: Button("取消") {
                    isPresented = false
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
                        isPresented = false
                    }
                }
                .disabled(selectedMaterialId == nil || modelName.isEmpty || weightUsed.isEmpty ||
                          (selectedMaterialId != nil && Double(weightUsed) ?? 0 <= 0))
            )
        }
    }
}
