import SwiftUI

struct BambuPrinterStatusView: View {
    @ObservedObject var printerManager: BambuPrinterManager
    @EnvironmentObject var store: MaterialStore
    @State private var showPrintHistory = false
    
    // 添加定时器相关状态
    @State private var timer: Timer? = nil
    private let refreshInterval: TimeInterval = 20 // 20秒刷新一次API数据
    
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
                    .foregroundColor(Color.red)
                    .font(.caption)
            } else if printerManager.printers.isEmpty {
                Text("未找到打印机设备")
                    .foregroundColor(Color.secondary)
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
            }
        }
        .sheet(isPresented: $showPrintHistory) {
            PrintHistoryView(printerManager: printerManager)
                .environmentObject(store)
        }
        .onAppear {
            // 启动定时器进行自动刷新
            startAutoRefresh()
        }
        .onDisappear {
            // 停止定时器
            stopAutoRefresh()
        }
    }
    
    // 启动自动刷新
    private func startAutoRefresh() {
        // 确保先停止之前可能存在的定时器
        stopAutoRefresh()
        
        // 创建并启动新的定时器
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task {
                await printerManager.fetchPrinters()
            }
        }
        
        // 立即执行一次更新
        Task {
            await printerManager.fetchPrinters()
        }
    }
    
    // 停止自动刷新
    private func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
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
            
            // 打印机状态详情 - 实时数据版本
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("型号:")
                        Text(printer.modelDescription)
                            .foregroundColor(Color.secondary)
                    }
                    .font(.caption)
                    
                    // 从API获取状态
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
                    .foregroundColor(Color.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
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
            .foregroundColor(isOnline ? Color.green : Color.gray)
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
    @State private var selectedPrinterId: String? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                if !printerManager.printers.isEmpty {
                    // 打印机选择器 - 修改为使用ID而不是整个PrinterInfo对象
                    Picker("选择打印机", selection: $selectedPrinterId) {
                        Text("全部打印机").tag(nil as String?)
                        ForEach(printerManager.printers) { printer in
                            Text(printer.name).tag(printer.id as String?)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                List {
                    
                    Section(header: Text("打印历史")) {
                        if printerManager.recentTasks.isEmpty {
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView("正在加载打印记录...")
                                    Spacer()
                                }
                            } else {
                                Text("暂无打印记录")
                                    .foregroundColor(Color.secondary)
                            }
                        } else {
                            // 过滤选定打印机的任务
                            let filteredTasks = selectedPrinterId != nil
                                ? printerManager.recentTasks.filter { $0.deviceId == selectedPrinterId }
                                : printerManager.recentTasks
                            
                            if filteredTasks.isEmpty {
                                Text("所选打印机暂无打印记录")
                                    .foregroundColor(Color.secondary)
                            } else {
                                ForEach(Array(filteredTasks.prefix(loadedTasksCount))) { task in
                                    PrintTaskRow(task: task)
                                        .environmentObject(store)
                                        .onAppear {
                                            // 如果显示到列表最后几个项目，加载更多数据
                                            if task.id == filteredTasks.prefix(loadedTasksCount).last?.id &&
                                                loadedTasksCount < filteredTasks.count {
                                                loadMoreTasks()
                                            }
                                        }
                                }
                                
                                // 如果还有更多内容可以加载，显示加载按钮
                                if loadedTasksCount < filteredTasks.count {
                                    Button("加载更多...") {
                                        loadMoreTasks()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
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
            .foregroundColor(Color.secondary)
            
            HStack {
                if let firstMaterial = task.amsDetailMapping.first {
                    Text("材料: \(firstMaterial.filamentType)")
                }
                Spacer()
                Text("用量: \(String(format: "%.2f", task.weight))g")
            }
            .font(.caption)
            .foregroundColor(Color.secondary)
            
            HStack {
                Text("开始: \(task.formattedStartTime)")
                Spacer()
                Text("用时: \(task.formattedPrintTime)")
            }
            .font(.caption)
            .foregroundColor(Color.secondary)
            
            // 添加"添加到统计"按钮
            Button(action: {
                showAddToStatsSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("添加到耗材统计")
                }
                .font(.caption)
                .foregroundColor(Color.blue)
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
