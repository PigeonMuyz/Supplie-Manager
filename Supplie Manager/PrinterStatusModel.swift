import SwiftUI

// 打印机状态枚举，基于Bambu Lab API的状态码
enum PrinterStatus: Int, Codable {
    // 基础状态
    case unknown = -100       // 未知状态（默认值）
    case idle = -1            // P1返回255表示空闲，X1返回-1表示空闲
    case idleAlternate = 255  // P1返回255表示空闲
    case printing = 0
    
    // 预处理和校准阶段
    case autoBedLeveling = 1
    case heatbedPreheating = 2
    case sweepingXYMechMode = 3
    case changingFilament = 4
    case m400Pause = 5
    case heatingHotend = 7
    case calibratingExtrusion = 8
    case scanningBedSurface = 9
    case inspectingFirstLayer = 10
    case identifyingBuildPlateType = 11
    case calibratingMicroLidar = 12 // 在HACS插件中这个值重复了
    case homingToolhead = 13
    case cleaningNozzleTip = 14
    case checkingExtruderTemperature = 15
    case calibratingExtrusionFlow = 19
    case filamentUnloading = 22
    case filamentLoading = 24
    case calibratingMotorNoise = 25
    case coolingChamber = 29
    case motorNoiseShowoff = 31
    
    // 暂停状态
    case pausedFilamentRunout = 6
    case pausedUser = 16
    case pausedFrontCoverFalling = 17
    case pausedNozzleTemperatureMalfunction = 20
    case pausedHeatBedTemperatureMalfunction = 21
    case pausedSkippedStep = 23
    case pausedAmsLost = 26
    case pausedLowFanSpeedHeatBreak = 27
    case pausedChamberTemperatureControlError = 28
    case pausedUserGcode = 30
    case pausedNozzleFilamentCoveredDetected = 32
    case pausedCutterError = 33
    case pausedFirstLayerError = 34
    case pausedNozzleClog = 35
    
    // 状态文本描述
    var description: String {
        switch self {
        // 基础状态
        case .unknown: return "未知状态"
        case .idle, .idleAlternate: return "空闲"
        case .printing: return "打印中"
            
        // 预处理和校准阶段
        case .autoBedLeveling: return "自动调平中"
        case .heatbedPreheating: return "热床预热中"
        case .sweepingXYMechMode: return "扫描XY机构"
        case .changingFilament: return "更换耗材中"
        case .m400Pause: return "M400暂停"
        case .heatingHotend: return "加热喷嘴中"
        case .calibratingExtrusion: return "校准挤出量"
        case .scanningBedSurface: return "扫描打印床表面"
        case .inspectingFirstLayer: return "检查首层"
        case .identifyingBuildPlateType: return "识别打印板类型"
        case .calibratingMicroLidar: return "校准微型激光雷达"
        case .homingToolhead: return "工具头归位中"
        case .cleaningNozzleTip: return "清洁喷嘴尖端"
        case .checkingExtruderTemperature: return "检查挤出机温度"
        case .calibratingExtrusionFlow: return "校准挤出流量"
        case .filamentUnloading: return "卸载耗材中"
        case .filamentLoading: return "加载耗材中"
        case .calibratingMotorNoise: return "校准电机噪音"
        case .coolingChamber: return "冷却打印腔体"
        case .motorNoiseShowoff: return "电机噪音展示"
            
        // 暂停状态
        case .pausedFilamentRunout: return "暂停：耗材用尽"
        case .pausedUser: return "用户暂停"
        case .pausedFrontCoverFalling: return "暂停：前盖掉落"
        case .pausedNozzleTemperatureMalfunction: return "暂停：喷嘴温度异常"
        case .pausedHeatBedTemperatureMalfunction: return "暂停：热床温度异常"
        case .pausedSkippedStep: return "暂停：电机步进丢失"
        case .pausedAmsLost: return "暂停：AMS连接丢失"
        case .pausedLowFanSpeedHeatBreak: return "暂停：热断风扇速度低"
        case .pausedChamberTemperatureControlError: return "暂停：腔体温度控制错误"
        case .pausedUserGcode: return "暂停：用户G代码"
        case .pausedNozzleFilamentCoveredDetected: return "暂停：检测到喷嘴覆盖耗材"
        case .pausedCutterError: return "暂停：切刀错误"
        case .pausedFirstLayerError: return "暂停：首层错误"
        case .pausedNozzleClog: return "暂停：喷嘴堵塞"
        }
    }
    
    // 状态类别，用于UI展示
    var category: StatusCategory {
        switch self {
        case .unknown:
            return .unknown
        case .idle, .idleAlternate:
            return .ready
        case .printing:
            return .active
        case .autoBedLeveling, .heatbedPreheating, .sweepingXYMechMode, .changingFilament,
             .heatingHotend, .calibratingExtrusion, .scanningBedSurface, .inspectingFirstLayer,
             .identifyingBuildPlateType, .calibratingMicroLidar, .homingToolhead, .cleaningNozzleTip,
             .checkingExtruderTemperature, .calibratingExtrusionFlow, .filamentUnloading,
             .filamentLoading, .calibratingMotorNoise, .coolingChamber, .motorNoiseShowoff:
            return .preparing
        case .m400Pause, .pausedUser, .pausedUserGcode:
            return .paused
        default:
            return .error
        }
    }
    
    // 从API字符串值创建状态
    static func fromString(_ statusStr: String) -> PrinterStatus {
        switch statusStr.uppercased() {
        case "IDLE": return .idle
        case "RUNNING": return .printing
        case "PAUSE": return .pausedUser
        case "SUCCESS": return .idle // 打印成功后通常返回空闲状态
        case "FAILED": return .unknown // 失败状态需要进一步诊断
        default: return .unknown
        }
    }
    
    // 从原始整数创建，用于直接解析API响应
    static func fromRawValue(_ rawValue: Int) -> PrinterStatus {
        return PrinterStatus(rawValue: rawValue) ?? .unknown
    }
    
    // 向前兼容，与你现有代码的映射
    var legacyStatus: String {
        switch self {
        case .idle, .idleAlternate: return "IDLE"
        case .printing: return "RUNNING"
        case .pausedUser, .pausedFilamentRunout, .pausedFrontCoverFalling,
             .pausedNozzleTemperatureMalfunction, .pausedHeatBedTemperatureMalfunction,
             .pausedSkippedStep, .pausedAmsLost, .pausedLowFanSpeedHeatBreak,
             .pausedChamberTemperatureControlError, .pausedUserGcode,
             .pausedNozzleFilamentCoveredDetected, .pausedCutterError,
             .pausedFirstLayerError, .pausedNozzleClog:
            return "PAUSE"
        default: return "UNKNOWN"
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
        if let statusCode = Int(print_status) {
            return PrinterStatus.fromRawValue(statusCode)
        } else {
            return PrinterStatus.fromString(print_status)
        }
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
