import SwiftUI

struct BambuPrinterStatusView: View {
    @ObservedObject var printerManager: BambuPrinterManager
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
                        Text(printer.statusDescription)
                            .foregroundColor(statusColor(for: printer.print_status))
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
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("刷新") {
                        Task {
                            isLoading = true
                            await printerManager.fetchRecentTasks()
                            isLoading = false
                        }
                    }
                    .disabled(isLoading)
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
        }
        .padding(.vertical, 4)
    }
}
