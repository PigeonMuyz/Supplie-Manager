import Foundation
import SwiftUI

// 打印机基本信息模型
struct PrinterInfo: Identifiable, Hashable {
    // 基本信息，由API返回
    struct BasicInfo: Codable, Hashable {
        var dev_id: String
        var name: String
        var online: Bool
        var print_status: String
        var dev_model_name: String
        var dev_product_name: String
        var dev_access_code: String
        var nozzle_diameter: Double
        var dev_structure: String
    }
    
    // 基本信息
    var basicInfo: BasicInfo
    
    // MQTT客户端 - 使用UUID作为标识避免Hashable需要考虑它
    var mqttClient: BambuMQTTClient?
    
    // ID属性转发
    var id: String { basicInfo.dev_id }
    
    // 属性访问器，转发到basicInfo
    var dev_id: String { basicInfo.dev_id }
    var name: String { basicInfo.name }
    var online: Bool { basicInfo.online }
    var print_status: String { basicInfo.print_status }
    var dev_model_name: String { basicInfo.dev_model_name }
    var dev_product_name: String { basicInfo.dev_product_name }
    var dev_access_code: String { basicInfo.dev_access_code }
    var nozzle_diameter: Double { basicInfo.nozzle_diameter }
    var dev_structure: String { basicInfo.dev_structure }
    
    // 简化的打印状态描述
    var statusDescription: String {
        return detailedStatus.description
    }
    
    // 打印机型号显示
    var modelDescription: String {
        return "\(dev_product_name) (\(dev_model_name))"
    }
    
    // 实现Hashable协议
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PrinterInfo, rhs: PrinterInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

// 移除这些属性，因为它们在PrinterStatusModel.swift中已经定义
/*
// 打印机信息模型的扩展，用于集成打印机状态
extension PrinterInfo {
    // 获取详细状态
    var detailedStatus: PrinterStatus {
        return PrinterStatus.fromString(print_status)
    }
    
    // 获取状态分类
    var statusCategory: StatusCategory {
        return detailedStatus.category
    }
    
    // 获取状态颜色
    var statusColor: Color {
        return statusCategory.color
    }
    
    // 获取状态图标
    var statusIcon: String {
        return statusCategory.iconName
    }
}
*/

// 打印任务信息模型
struct PrintTaskInfo: Codable, Identifiable {
    var id: Int
    var title: String
    var cover: String
    var status: Int
    var startTime: String
    var endTime: String?
    var weight: Double
    var length: Double
    var costTime: Int
    var deviceId: String
    var deviceName: String
    var deviceModel: String
    var amsDetailMapping: [AMSDetail]
    
    // 格式化打印时间
    var formattedPrintTime: String {
        let hours = costTime / 3600
        let minutes = (costTime % 3600) / 60
        
        if hours > 0 {
            return String(format: "%d小时%d分钟", hours, minutes)
        } else {
            return String(format: "%d分钟", minutes)
        }
    }
    
    // 格式化开始时间
    var formattedStartTime: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        if let date = dateFormatter.date(from: startTime) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return outputFormatter.string(from: date)
        }
        return startTime
    }
    
    // 获取使用的材料类型
    var materialType: String {
        if let firstMaterial = amsDetailMapping.first {
            return firstMaterial.filamentType
        }
        return "未知"
    }
}

// AMS详情模型
struct AMSDetail: Codable {
    var ams: Int
    var sourceColor: String
    var filamentType: String
    var weight: Double
    var amsId: Int
    var slotId: Int
}

// 打印机设备列表响应
struct PrinterListResponse: Codable {
    var message: String
    var code: String?
    var error: String?
    var devices: [PrinterInfo.BasicInfo]
}

// 打印任务历史列表响应
struct PrintTasksResponse: Codable {
    var total: Int
    var hits: [PrintTaskInfo]
}

// 用户项目响应
struct ProjectsResponse: Codable {
    var message: String
    var code: String?
    var error: String?
    var projects: [ProjectInfo]
}

// 项目信息模型
struct ProjectInfo: Codable {
    var project_id: String
    var user_id: String
    var model_id: String
    var status: String
    var name: String
    var content: String
    var create_time: String
    var update_time: String
}

// 打印机服务管理
class BambuPrinterManager: ObservableObject {
    @Published var printers: [PrinterInfo] = []
    @Published var recentTasks: [PrintTaskInfo] = []
    @Published var projects: [ProjectInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalPrintCount: Int = 0
    
    // 添加MQTT相关状态
    @Published var mqttStatusMessages: [String] = []
    
    private let authManager: BambuAuthManager
    
    init(authManager: BambuAuthManager) {
        self.authManager = authManager
    }
    
    func fetchPrinters() async {
            guard authManager.isLoggedIn, let token = authManager.getAccessToken() else {
                DispatchQueue.main.async {
                    self.errorMessage = "未登录，无法获取打印机信息"
                    self.printers = []
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isLoading = true
                self.errorMessage = nil
            }
            
            guard let url = URL(string: "https://api.bambulab.cn/v1/iot-service/api/user/bind") else {
                DispatchQueue.main.async {
                    self.errorMessage = "无效的URL"
                    self.isLoading = false
                }
                return
            }
            
            do {
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "GET"
                urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        self.errorMessage = "无效的响应"
                        self.isLoading = false
                    }
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        let printerResponse = try JSONDecoder().decode(PrinterListResponse.self, from: data)
                        
                        if printerResponse.error != nil {
                            DispatchQueue.main.async {
                                self.errorMessage = "获取打印机失败: \(printerResponse.error ?? "未知错误")"
                                self.isLoading = false
                            }
                            return
                        }
                        
                        DispatchQueue.main.async {
                            // 断开现有的MQTT连接
                            for printer in self.printers {
                                printer.mqttClient?.disconnect()
                            }
                            
                            // 将BasicInfo转换为完整的PrinterInfo并创建MQTT客户端
                            self.printers = printerResponse.devices.map { basicInfo in
                                var printerInfo = PrinterInfo(basicInfo: basicInfo)
                                
                                // 创建MQTT客户端 - 使用Cloud MQTT
                                if let token = self.authManager.getAccessToken() {
                                    let mqttClient = BambuMQTTClient(
                                        serialNumber: basicInfo.dev_id,
                                        cloudToken: token
                                    )
                                    printerInfo.mqttClient = mqttClient
                                    //mqttClient.connect()
                                }
                                
                                return printerInfo
                            }
                            
                            self.isLoading = false
                            
                            // 如果获取到了打印机，可以继续获取最近任务
                            if !self.printers.isEmpty {
                                Task {
                                    await self.fetchRecentTasks()
                                }
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.errorMessage = "解析响应失败: \(error.localizedDescription)"
                            self.isLoading = false
                        }
                    }
                } else {
                    // 处理错误响应
                    let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
                    DispatchQueue.main.async {
                        self.errorMessage = "请求失败: \(httpResponse.statusCode), \(responseString)"
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "请求失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    
    // 获取最近的打印任务
    func fetchRecentTasks() async {
        guard authManager.isLoggedIn, let token = authManager.getAccessToken() else {
            return
        }
        
        guard let url = URL(string: "https://api.bambulab.cn/v1/user-service/my/tasks?limit=50") else {
            return
        }
        
        do {
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }
            
            do {
                let tasksResponse = try JSONDecoder().decode(PrintTasksResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.recentTasks = tasksResponse.hits
                    self.totalPrintCount = tasksResponse.total
                }
            } catch {
                print("解析任务失败: \(error.localizedDescription)")
            }
        } catch {
            print("获取任务失败: \(error.localizedDescription)")
        }
    }
    
    // 获取用户项目
    func fetchProjects() async {
        guard authManager.isLoggedIn, let token = authManager.getAccessToken() else {
            return
        }
        
        guard let url = URL(string: "https://api.bambulab.cn/v1/iot-service/api/user/project") else {
            return
        }
        
        do {
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }
            
            do {
                let projectsResponse = try JSONDecoder().decode(ProjectsResponse.self, from: data)
                
                if projectsResponse.error != nil {
                    return
                }
                
                DispatchQueue.main.async {
                    self.projects = projectsResponse.projects
                }
            } catch {
                print("解析项目失败: \(error.localizedDescription)")
            }
        } catch {
            print("获取项目失败: \(error.localizedDescription)")
        }
    }
    
    // 断开所有MQTT连接
    func disconnectAllMQTT() {
        for printer in printers {
            printer.mqttClient?.disconnect()
        }
    }
    
    // 获取指定打印机的MQTT客户端
    func getMQTTClient(for printerId: String) -> BambuMQTTClient? {
        if let printer = printers.first(where: { $0.id == printerId }) {
            return printer.mqttClient
        }
        return nil
    }
}
