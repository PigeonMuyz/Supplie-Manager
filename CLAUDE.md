# Supplie Manager - Claude Project Documentation

## 项目概述
Supplie Manager 是一个用 SwiftUI 开发的 iOS 应用，用于管理 3D 打印耗材（材料）。该应用提供材料库存管理、使用量统计、预设管理以及与 Bambu Lab 打印机的集成功能。

## 技术栈
- **平台**: iOS
- **UI框架**: SwiftUI
- **语言**: Swift
- **最低支持版本**: iOS 16.2
- **依赖管理**: Swift Package Manager

## 项目结构
```
Supplie Manager/
├── Models/                      # 数据模型
│   ├── BambuAuthModel.swift     # Bambu Lab 认证模型
│   ├── BambuPrinterModel.swift  # 打印机状态模型
│   ├── MaterialModels.swift     # 材料数据模型
│   ├── MaterialModelsPresets.swift # 材料预设模型
│   ├── PrinterStatusModel.swift # 打印机状态管理
│   └── ThreeMFModels.swift      # 3MF 文件模型
├── Views/                       # 视图组件
│   ├── Material/               # 材料相关视图
│   │   ├── AddMaterialView.swift
│   │   ├── ContentView.swift    # 主界面（TabView）
│   │   └── MyMaterialsView.swift
│   ├── Printer/                # 打印机相关视图
│   │   ├── BambuLoginView.swift
│   │   └── BambuPrinterStatusView.swift
│   ├── Settings/               # 设置相关视图
│   │   ├── MaterialPresetPreviewSheet.swift
│   │   ├── PresetComponents.swift
│   │   └── PresetManagementView.swift
│   ├── Stats/                  # 统计相关视图
│   │   ├── AddPrintTaskToStatsView.swift
│   │   ├── RecordUsageView.swift
│   │   └── StatisticsView.swift
│   └── Tools/                  # 工具相关视图
│       ├── ThreeMFPreviewView.swift
│       └── ToolsView.swift
├── Services/                   # 服务层（待开发）
├── Resources/                  # 资源文件
│   └── MaterialPresets.json    # 材料预设配置
└── Assets.xcassets/           # 图片资源
```

## 外部依赖
项目配置了以下依赖但当前代码中未实际使用，建议在不需要时移除：

1. **CocoaMQTT** (v2.1.9) - 未使用
   - 配置用途: 与 Bambu Lab 打印机的 MQTT 通信
   - 仓库: https://github.com/emqx/CocoaMQTT.git

2. **MqttCocoaAsyncSocket** (v1.0.8) - 未使用
   - 配置用途: MQTT 连接的底层 Socket 支持
   - 仓库: https://github.com/leeway1208/MqttCocoaAsyncSocket

3. **Starscream** (v4.0.8) - 未使用
   - 配置用途: WebSocket 连接支持
   - 仓库: https://github.com/daltoniam/Starscream.git

**注意**: 当前项目仅使用标准的 URLSession 进行 HTTP API 调用，上述依赖未被实际使用。

## 核心功能模块

### 1. 材料管理 (Material)
- **数据模型**: `Material` 结构体包含品牌、分类、颜色、重量、价格等信息
- **存储**: 本地 JSON 存储，通过 `MaterialStore` 管理
- **功能**: 添加、编辑、删除材料，跟踪使用量和剩余量

### 2. 统计模块 (Stats)
- **功能**: 记录打印任务和材料使用量
- **数据可视化**: 提供使用统计图表和报告

### 3. 预设管理 (Settings)
- **材料预设**: 预定义的常用材料配置
- **配置文件**: `MaterialPresets.json` 存储预设数据

### 4. Bambu Lab 集成 (Printer)
- **认证**: 支持 Bambu Lab 账户登录
- **MQTT 通信**: 实时获取打印机状态
- **打印任务**: 监控打印进度和材料消耗

### 5. 工具模块 (Tools)
- **3MF 预览**: 支持 3MF 文件的预览和分析
- **其他工具**: 扩展功能集合

## 开发指南

### 构建要求
- Xcode 16.2+
- Swift 5.9+
- macOS 14.0+ (开发环境)
- iOS 16.2+ (目标平台)

### 网络权限配置
项目在 `Supplie-Manager-Info.plist` 中配置了以下网络权限：
- 允许本地网络访问（用于打印机通信）
- Bambu Lab MQTT 服务器例外配置
- 后台处理权限（用于数据同步）

### 主要架构模式
- **MVVM**: 使用 `@StateObject` 和 `@ObservableObject` 进行状态管理
- **组合式架构**: 每个功能模块独立开发，通过主界面组合
- **数据持久化**: JSON 文件本地存储

### 开发建议
1. **代码风格**: 遵循 Swift 官方编码规范
2. **UI 设计**: 使用 SwiftUI 原生组件，保持 Apple 设计语言一致性
3. **数据管理**: 通过 Store 模式集中管理状态
4. **网络请求**: 异步处理，使用 async/await 模式
5. **错误处理**: 实现完善的错误捕获和用户反馈机制

### 常用命令
```bash
# 构建项目
xcodebuild -project "Supplie Manager.xcodeproj" -scheme "Supplie Manager" build

# 运行测试
xcodebuild test -project "Supplie Manager.xcodeproj" -scheme "Supplie Manager"

# 清理构建
xcodebuild clean -project "Supplie Manager.xcodeproj" -scheme "Supplie Manager"
```

## 当前开发状态
- ✅ 基础材料管理功能
- ✅ 主界面和导航结构
- ✅ Bambu Lab 打印机集成
- ✅ 材料预设系统
- ✅ 3MF 文件预览功能
- 🔄 统计和数据可视化优化中
- 📋 Services 层架构待完善

## 注意事项
1. 该应用需要网络权限以连接 Bambu Lab 打印机
2. 材料数据存储在本地，建议实现数据备份功能
3. MQTT 连接需要稳定的网络环境
4. 3MF 文件处理可能占用较多内存，需要优化大文件处理

## 联系信息
- 开发者: PigeonMuyz
- 项目路径: `/Users/huangtianchen/XCodeProject/Supplie Manager`