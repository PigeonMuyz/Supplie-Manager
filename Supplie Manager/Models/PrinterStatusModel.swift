import SwiftUI

// 打印机状态枚举，基于Bambu Lab API的状态码
enum PrinterStatus: Codable {
    // 基础状态
    case unknown
    case idle
    case printing
    case paused
    case failed
    case finished
    
    // 预处理和校准阶段 - 数字状态用于MQTT消息
    case numericStatus(Int)
    
    // 从API字符串值创建状态
    static func fromString(_ statusStr: String) -> PrinterStatus {
        switch statusStr.uppercased() {
        case "IDLE": return .idle
        case "RUNNING": return .printing
        case "PAUSE": return .paused
        case "SUCCESS", "FINISH": return .finished
        case "FAILED", "FAIL": return .failed
        default:
            // 尝试解析为数字
            if let statusCode = Int(statusStr) {
                return .numericStatus(statusCode)
            }
            return .unknown
        }
    }
    
    // 状态文本描述
    var description: String {
        switch self {
        case .unknown: return "未知状态"
        case .idle: return "空闲"
        case .printing: return "打印中"
        case .paused: return "已暂停"
        case .failed: return "打印失败"
        case .finished: return "打印完成"
        case .numericStatus(let code):
            // 处理数字状态码
            switch code {
            case -1, 255: return "空闲"
            case 0: return "打印中"
            case 1: return "自动调平中"
            case 2: return "热床预热中"
            case 3: return "扫描XY机构"
            case 4: return "更换耗材中"
            case 5: return "M400暂停"
            case 6: return "暂停：耗材用尽"
            case 7: return "加热喷嘴中"
            case 8: return "校准挤出量"
            case 9: return "扫描打印床表面"
            case 10: return "检查首层"
            case 11: return "识别打印板类型"
            case 12: return "校准微型激光雷达"
            case 13: return "工具头归位中"
            case 14: return "清洁喷嘴尖端"
            case 15: return "检查挤出机温度"
            case 16: return "用户暂停"
            case 17: return "暂停：前盖掉落"
            case 19: return "校准挤出流量"
            case 20: return "暂停：喷嘴温度异常"
            case 21: return "暂停：热床温度异常"
            case 22: return "卸载耗材中"
            case 23: return "暂停：电机步进丢失"
            case 24: return "加载耗材中"
            case 25: return "校准电机噪音"
            case 26: return "暂停：AMS连接丢失"
            case 27: return "暂停：热断风扇速度低"
            case 28: return "暂停：腔体温度控制错误"
            case 29: return "冷却打印腔体"
            case 30: return "暂停：用户G代码"
            case 31: return "电机噪音展示"
            case 32: return "暂停：检测到喷嘴覆盖耗材"
            case 33: return "暂停：切刀错误"
            case 34: return "暂停：首层错误"
            case 35: return "暂停：喷嘴堵塞"
            default: return "状态代码: \(code)"
            }
        }
    }
    
    // 状态类别，用于UI展示
    var category: StatusCategory {
        switch self {
        case .unknown:
            return .unknown
        case .idle:
            return .ready
        case .printing:
            return .active
        case .paused:
            return .paused
        case .failed:
            return .error
        case .finished:
            return .ready
        case .numericStatus(let code):
            switch code {
            case -1, 255: // 空闲
                return .ready
            case 0: // 打印中
                return .active
            case 5, 6, 16, 17, 20, 21, 23, 26, 27, 28, 30, 32, 33, 34, 35: // 各种暂停状态
                return .paused
            case 1, 2, 3, 4, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19, 22, 24, 25, 29, 31: // 准备和校准
                return .preparing
            default:
                return .unknown
            }
        }
    }
}

// 状态分类枚举，用于UI展示
enum StatusCategory {
    case unknown   // 未知状态
    case ready     // 空闲/就绪
    case preparing // 准备中
    case active    // 活动打印中
    case paused    // 用户暂停
    case error     // 错误状态
    
    // 状态类别对应的颜色
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .ready: return .green
        case .preparing: return .blue
        case .active: return .indigo
        case .paused: return .orange
        case .error: return .red
        }
    }
    
    // 状态图标
    var iconName: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .ready: return "checkmark.circle"
        case .preparing: return "gear"
        case .active: return "printer"
        case .paused: return "pause.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// 打印机信息模型的扩展，用于集成新的状态枚举
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
