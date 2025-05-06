import Foundation
import CocoaMQTT
import SwiftUI

// Bambu Cloud MQTT客户端管理器，负责与Bambu云服务建立MQTT连接
class BambuMQTTClient: ObservableObject {
    // MQTT客户端
    private var mqttClient: CocoaMQTT?
    
    // 连接超时定时器
    private var connectionTimer: Timer?
    private let connectionTimeoutInterval: TimeInterval = 15.0 // 15秒超时
    
    // 重连相关变量
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 3
    private let reconnectInterval: TimeInterval = 5.0
    
    // 打印机信息
    private var serialNumber: String
    private var cloudToken: String
    private var username: String = "bblp"
    
    // MQTT服务器信息 - 使用中国区域服务器
    private let mqttServer = "mqtt.bambulab.cn"
    private let mqttPort: UInt16 = 8883
    
    // 连接状态
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var lastMessage: String?
    @Published var connectionState: String = "未连接"
    
    // 最新的打印机数据
    @Published var printerData: [String: Any] = [:]
    
    // 初始化方法
    init(serialNumber: String, cloudToken: String) {
        self.serialNumber = serialNumber
        self.cloudToken = cloudToken
    }
    
    // 建立MQTT连接
    func connect() {
        // 如果已经有连接或正在连接，先断开
        if mqttClient != nil {
            disconnect()
        }
        
        // 更新UI状态
        DispatchQueue.main.async {
            self.connectionState = "正在连接"
            self.lastError = "正在连接到Bambu Cloud MQTT服务器..."
        }
        
        // 使用随机客户端ID避免连接冲突
        let clientID = "SupplieManager-\(UUID().uuidString)"
        
        // 配置MQTT客户端 - 连接到Bambu Cloud MQTT服务器
        let mqtt = CocoaMQTT(clientID: clientID, host: mqttServer, port: mqttPort)
        mqtt.username = username
        mqtt.password = cloudToken // 使用云令牌作为密码
        mqtt.enableSSL = true
        mqtt.allowUntrustCACertificate = true
        mqtt.keepAlive = 60
        
        // 设置代理
        mqtt.delegate = self
        
        // 保存客户端引用
        self.mqttClient = mqtt
        
        // 设置连接超时
        connectionTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeoutInterval, repeats: false) { [weak self] _ in
            guard let self = self, !self.isConnected else { return }
            
            DispatchQueue.main.async {
                self.connectionState = "连接超时"
                self.lastError = "连接超时，请检查网络连接和账号信息"
                print("MQTT连接超时")
                
                // 尝试重连
                self.scheduleReconnect()
            }
        }
        
        // 尝试连接
        let connectResult = mqtt.connect()
        print("MQTT连接开始: \(connectResult)")
    }
    
    // 计划重新连接
    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            
            DispatchQueue.main.async {
                self.lastError = "连接失败，将在\(Int(self.reconnectInterval))秒后进行第\(self.reconnectAttempts)次重试..."
                self.connectionState = "准备重连"
            }
            
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                print("尝试重新连接 #\(self.reconnectAttempts)")
                self.connect()
            }
        } else {
            DispatchQueue.main.async {
                self.lastError = "多次连接尝试失败，请检查网络连接和账号信息，或稍后再试"
                self.connectionState = "连接失败"
            }
            reconnectAttempts = 0
        }
    }
    
    // 重置重连计数
    private func resetReconnectAttempts() {
        reconnectAttempts = 0
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    // 断开MQTT连接
    func disconnect() {
        // 取消所有计时器
        connectionTimer?.invalidate()
        connectionTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        // 断开连接
        mqttClient?.disconnect()
        mqttClient = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionState = "已断开"
        }
    }
    
    // 发送pushall命令，请求打印机发送完整状态
    func requestPushAll() {
        let commandTopic = "device/\(serialNumber)/request"
        let payload = "{\"pushing\":{\"command\":\"pushall\"}}"
        
        mqttClient?.publish(commandTopic, withString: payload, qos: .qos1)
    }
    
    // 发送命令给打印机（通用方法）
    func sendCommand(_ command: [String: Any]) {
        let commandTopic = "device/\(serialNumber)/request"
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: command),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mqttClient?.publish(commandTopic, withString: jsonString, qos: .qos1)
        } else {
            lastError = "无法序列化命令"
        }
    }
    
    // 处理接收到的JSON消息
    private func processMessage(_ message: String) {
        if let data = message.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // 更新UI线程中的数据
            DispatchQueue.main.async {
                // 合并新数据到当前数据中
                for (key, value) in json {
                    if let nestedDict = value as? [String: Any] {
                        var currentDict = self.printerData[key] as? [String: Any] ?? [:]
                        for (nestedKey, nestedValue) in nestedDict {
                            currentDict[nestedKey] = nestedValue
                        }
                        self.printerData[key] = currentDict
                    } else {
                        self.printerData[key] = value
                    }
                }
                
                // 触发数据更新通知
                self.objectWillChange.send()
            }
        }
    }
    
    // 检查服务器可达性
    func checkServerReachability(completion: @escaping (Bool) -> Void) {
        let hostURL = URL(string: "https://\(mqttServer)")!
        let task = URLSession.shared.dataTask(with: hostURL) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(true)
            } else {
                print("MQTT服务器不可达: \(error?.localizedDescription ?? "未知错误")")
                completion(false)
            }
        }
        task.resume()
    }
}

// MARK: - MQTT代理方法
extension BambuMQTTClient: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        // 取消连接超时定时器
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        print("MQTT连接确认: \(ack)")
        
        if ack == .accept {
            DispatchQueue.main.async {
                self.isConnected = true
                self.lastError = nil
                self.lastMessage = "成功连接到Bambu Cloud MQTT服务器"
                self.connectionState = "已连接"
            }
            
            // 重置重连尝试
            resetReconnectAttempts()
            
            // 订阅打印机状态主题 - 这是Cloud MQTT的正确主题格式
            mqtt.subscribe("device/\(serialNumber)/report")
            
            // 连接后立即请求完整状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.requestPushAll()
            }
        } else {
            DispatchQueue.main.async {
                self.isConnected = false
                self.lastError = "连接被拒绝: \(ack)"
                self.connectionState = "连接被拒绝"
            }
            
            // 如果连接被拒绝，尝试重连
            scheduleReconnect()
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        // 消息发布成功
        print("MQTT消息发布成功: ID \(id)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        // 收到发布确认
        print("MQTT发布确认: ID \(id)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        // 收到消息
        if let string = message.string {
            DispatchQueue.main.async {
                self.lastMessage = "收到消息: \(string.prefix(100))..."
            }
            processMessage(string)
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        // 订阅主题成功
        if !failed.isEmpty {
            DispatchQueue.main.async {
                self.lastError = "订阅失败的主题: \(failed.joined(separator: ", "))"
                print("MQTT订阅失败: \(failed)")
            }
        } else {
            DispatchQueue.main.async {
                self.lastMessage = "成功订阅打印机状态主题"
                print("MQTT订阅成功")
            }
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        // 取消订阅主题
        print("MQTT取消订阅: \(topics)")
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        // 发送ping
        print("MQTT发送ping")
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        // 收到pong
        print("MQTT收到pong")
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            
            if let error = err {
                self.lastError = "断开连接: \(error.localizedDescription)"
                self.connectionState = "连接错误"
                print("MQTT断开连接错误: \(error)")
                
                // 获取更详细的错误信息
                if let nsError = error as NSError? {
                    print("MQTT错误域: \(nsError.domain), 代码: \(nsError.code)")
                    print("MQTT错误用户信息: \(nsError.userInfo)")
                }
                
                // 只有在非主动断开的情况下才尝试重连
                if self.mqttClient != nil {
                    self.scheduleReconnect()
                }
            } else {
                self.lastError = "与Bambu Cloud MQTT服务器的连接已断开"
                self.connectionState = "已断开"
                print("MQTT正常断开连接")
            }
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        // 连接状态变化
        DispatchQueue.main.async {
            self.lastMessage = "MQTT连接状态: \(state)"
            print("MQTT状态变化: \(state)")
        }
    }
}

// MARK: - 打印机数据访问方法
extension BambuMQTTClient {
    // 获取打印状态
    func getPrintStatus() -> PrinterStatus {
        let status = printerData["print"] as? [String: Any]
        let printStatus = status?["print_status"] as? String ?? ""
        return PrinterStatus.fromString(printStatus)
    }
    
    // 获取打印进度
    func getPrintProgress() -> Double {
        let status = printerData["print"] as? [String: Any]
        let progressStr = status?["mc_percent"] as? String ?? "0"
        let progress = Double(progressStr) ?? 0.0
        return progress / 100.0 // 确保返回的是0-1范围的值
    }
    
    // 获取热床温度
    func getBedTemperature() -> Double {
        let status = printerData["print"] as? [String: Any]
        let tempStr = status?["bed_temper"] as? String ?? "0"
        return Double(tempStr) ?? 0.0
    }
    
    // 获取热床目标温度
    func getBedTargetTemperature() -> Double {
        let status = printerData["print"] as? [String: Any]
        let tempStr = status?["bed_target_temper"] as? String ?? "0"
        return Double(tempStr) ?? 0.0
    }
    
    // 获取喷嘴温度
    func getNozzleTemperature() -> Double {
        let status = printerData["print"] as? [String: Any]
        let tempStr = status?["nozzle_temper"] as? String ?? "0"
        return Double(tempStr) ?? 0.0
    }
    
    // 获取喷嘴目标温度
    func getNozzleTargetTemperature() -> Double {
        let status = printerData["print"] as? [String: Any]
        let tempStr = status?["nozzle_target_temper"] as? String ?? "0"
        return Double(tempStr) ?? 0.0
    }
    
    // 获取当前层数
    func getCurrentLayer() -> Int {
        let status = printerData["print"] as? [String: Any]
        let layerStr = status?["layer_num"] as? String ?? "0"
        return Int(layerStr) ?? 0
    }
    
    // 获取总层数
    func getTotalLayers() -> Int {
        let status = printerData["print"] as? [String: Any]
        let layerStr = status?["total_layer_num"] as? String ?? "0"
        return Int(layerStr) ?? 0
    }
    
    // 获取剩余时间（秒）
    func getRemainingTime() -> Int {
        let status = printerData["print"] as? [String: Any]
        let timeStr = status?["mc_remaining_time"] as? String ?? "0"
        return Int(timeStr) ?? 0
    }
    
    // 获取当前打印文件名
    func getFileName() -> String {
        let status = printerData["print"] as? [String: Any]
        return status?["subtask_name"] as? String ?? status?["gcode_file"] as? String ?? ""
    }
    
    // 获取打印速度
    func getPrintSpeed() -> Int {
        let status = printerData["print"] as? [String: Any]
        let speedStr = status?["spd_lvl"] as? String ?? "1"
        return Int(speedStr) ?? 1
    }
    
    // 获取风扇速度
    func getFanSpeed() -> Int {
        let status = printerData["print"] as? [String: Any]
        let fanStr = status?["fan_gear"] as? String ?? "0"
        return Int(fanStr) ?? 0
    }
    
    // 判断是否为活动打印任务
    func isActivePrinting() -> Bool {
        return getPrintStatus().category == .active
    }
}
