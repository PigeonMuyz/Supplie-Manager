import SwiftUI

// 本地化日期
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

struct ContentView: View {
    @StateObject private var store = MaterialStore()
    @StateObject private var authManager = BambuAuthManager()
    @StateObject private var printerManager: BambuPrinterManager
    
    init() {
        let auth = BambuAuthManager()
        self._authManager = StateObject(wrappedValue: auth)
        self._printerManager = StateObject(wrappedValue: BambuPrinterManager(authManager: auth))
    }
    
    var body: some View {
        TabView {
            StatisticsView(store: store, authManager: authManager, printerManager: printerManager)
                .tabItem {
                    Label("数据统计", systemImage: "chart.bar.fill")
                }
            
            MyMaterialsView(store: store)
                .tabItem {
                    Label("我的耗材", systemImage: "cylinder.fill")
                }
            
            RecordUsageView(store: store)
                .tabItem {
                    Label("打印记录", systemImage: "pencil")
                }
            
            PresetManagementView(store: store)
                .tabItem {
                    Label("耗材预设", systemImage: "list.bullet")
                }
        }
        .onAppear {
            // 如果已登录，自动获取打印机状态
            if authManager.isLoggedIn {
                Task {
                    await printerManager.fetchPrinters()
                }
            }
        }
    }
}

// MARK: 统计视图
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

// MARK: 我的耗材
struct MyMaterialsView: View {
    @ObservedObject var store: MaterialStore
    @State private var isShowingAddMaterialSheet = false
    @State private var showEmptyMaterials = false // 控制已用完耗材的折叠状态
    
    var body: some View {
        NavigationView {
            List {
                // 先显示有剩余的耗材
                if !store.materials.filter({ $0.remainingWeight > 0 }).isEmpty {
                    Section(header: Text("可用耗材")) {
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
                            MaterialRow(material: material)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.deleteMaterial(id: material.id)
                                    } label: {
                                        Label("", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        // 手动标记耗材已经用尽
                                        store.markMaterialAsEmpty(id: material.id)
                                    } label: {
                                        Label("", systemImage: "checkmark.circle")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
                
                // 已用完的耗材(折叠式)
                if !store.materials.filter({ $0.remainingWeight <= 0 }).isEmpty {
                    Section {
                        DisclosureGroup(
                            isExpanded: $showEmptyMaterials,
                            content: {
                                ForEach(store.materials.filter { $0.remainingWeight <= 0 }) { material in
                                    MaterialRow(material: material)
                                        .foregroundColor(.secondary)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                store.deleteMaterial(id: material.id)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                            },
                            label: {
                                HStack {
                                    Text("已用完")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(store.materials.filter { $0.remainingWeight <= 0 }.count)项")
                                        .foregroundColor(.secondary)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("我的耗材")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            isShowingAddMaterialSheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingAddMaterialSheet) {
                AddMaterialView(store: store, isPresented: $isShowingAddMaterialSheet)
            }
        }
    }
}

// 抽取出耗材行视图组件
struct MaterialRow: View {
    let material: Material
    
    var body: some View {
        HStack {
            MaterialColorView(material: material, size: 20, strokeWidth: 1)
            
            VStack(alignment: .leading) {
                Text(material.displayNameWithId)
                    .font(.headline)
                
                Text("购入日期: \(dateFormatter.string(from: material.purchaseDate))")
                    .font(.caption)
                
                Text("价格: ¥\(String(format: "%.2f", material.price))")
                    .font(.caption)
                
                if material.remainingWeight > 0 {
                    Text("剩余: \(String(format: "%.2f", material.remainingWeight))g / \(material.formattedWeight)")
                        .font(.caption)
                } else {
                    Text("状态: 已用完")
                        .font(.caption)
                }
                
                // 耗材使用进度条
                ProgressView(value: 1 - (material.remainingWeight / material.initialWeight))
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: Sheet - 添加耗材
struct AddMaterialView: View {
    @ObservedObject var store: MaterialStore
    @Binding var isPresented: Bool
    
    @State private var selectedBrand = ""
    @State private var selectedMainCategory = ""
    @State private var selectedSubCategory = "无"
    @State private var customBrand = ""
    @State private var customMainCategory = ""
    @State private var customSubCategory = ""
    @State private var colorName = ""
    @State private var colorHex = "#FFFFFF"
    @State private var isGradient = false
    @State private var gradientColorHex = "#FFFF00"
    @State private var purchaseDate = Date()
    @State private var price = ""
    @State private var weight = ""
    @State private var shortCode: String = ""
    
    // 计算属性：获取所选品牌/主分类/子分类的预设
    private var filteredPresets: [MaterialPreset] {
        store.materialPresets.filter { preset in
            preset.brand == selectedBrand &&
            preset.mainCategory == selectedMainCategory &&
            preset.subCategory == selectedSubCategory
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("从预设选择")) {
                    // 品牌选择
                    Picker("品牌", selection: $selectedBrand) {
                        Text("请选择").tag("")
                        ForEach(store.brands, id: \.self) { brand in
                            Text(brand).tag(brand)
                        }
                    }
                    
                    if selectedBrand == "自定义" {
                        TextField("输入品牌名称", text: $customBrand)
                    }
                    
                    // 主分类选择
                    Picker("主分类", selection: $selectedMainCategory) {
                        Text("请选择").tag("")
                        ForEach(store.mainCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    if selectedMainCategory == "自定义" {
                        TextField("输入主分类名", text: $customMainCategory)
                    }
                    
                    // 子分类选择
                    Picker("子分类", selection: $selectedSubCategory) {
                        ForEach(store.subCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    
                    if selectedSubCategory == "自定义" {
                        TextField("输入子分类名", text: $customSubCategory)
                    }
                    
                    // 如果有匹配的预设，显示颜色预设选择器
                    if !filteredPresets.isEmpty {
                        Picker("预设颜色", selection: Binding(
                            get: { colorName },
                            set: { selectedColorName in
                                if let preset = filteredPresets.first(where: { $0.colorName == selectedColorName }) {
                                    colorName = preset.colorName
                                    colorHex = preset.colorHex
                                }
                            }
                        )) {
                            Text("自定义").tag("")
                            ForEach(filteredPresets) { preset in
                                HStack {
                                    MaterialPresetColorView(preset: preset, size: 12, strokeWidth: 0.5)
                                    Text(preset.colorName)
                                }.tag(preset.colorName)
                            }
                        }
                    }
                }
                
                Section(header: Text("材料详情")) {
                    // 颜色名称
                    TextField("颜色名称", text: $colorName)
                    
                    // 渐变色开关
                    Toggle("渐变色", isOn: $isGradient)
                    
                    // 颜色选择
                    ColorPicker(isGradient ? "起始颜色" : "颜色", selection: Binding(
                        get: { Color(hex: colorHex) ?? .white },
                        set: { newColor in
                            // 将Color转换为hex值
                            if let components = newColor.cgColor?.components,
                               components.count >= 3 {
                                let r = Float(components[0])
                                let g = Float(components[1])
                                let b = Float(components[2])
                                colorHex = String(format: "#%02lX%02lX%02lX",
                                                  lroundf(r * 255),
                                                  lroundf(g * 255),
                                                  lroundf(b * 255))
                            }
                        }
                    ))
                    
                    // 如果选择了渐变色，显示第二个颜色选择器
                    if isGradient {
                        ColorPicker("结束颜色", selection: Binding(
                            get: { Color(hex: gradientColorHex) ?? .yellow },
                            set: { newColor in
                                // 将Color转换为hex值
                                if let components = newColor.cgColor?.components,
                                   components.count >= 3 {
                                    let r = Float(components[0])
                                    let g = Float(components[1])
                                    let b = Float(components[2])
                                    gradientColorHex = String(format: "#%02lX%02lX%02lX",
                                                              lroundf(r * 255),
                                                              lroundf(g * 255),
                                                              lroundf(b * 255))
                                }
                            }
                        ))
                    }
                    
                    // 购入日期
                    DatePicker(
                        "购入日期",
                        selection: $purchaseDate,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "zh_CN")) // 设置为中文日期格式
                    
                    // 价格
                    TextField("价格 (¥)", text: $price)
                        .keyboardType(.decimalPad)
                    
                    // 重量
                    TextField("重量 (g)", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("标识码（可选）", text: $shortCode)
                }
            }
            .navigationTitle("添加耗材")
            .navigationBarItems(
                leading: Button("取消") {
                    isPresented = false
                },
                trailing: Button("保存") {
                    saveMaterial()
                    isPresented = false
                }
                .disabled(!isFormValid)
            )
        }
    }
    
    private var isFormValid: Bool {
        let validBrand = selectedBrand != "" && (selectedBrand != "自定义" || customBrand != "")
        let validMainCategory = selectedMainCategory != "" && (selectedMainCategory != "自定义" || customMainCategory != "")
        let validSubCategory = selectedSubCategory != "自定义" || customSubCategory != ""
        let validDetails = !colorName.isEmpty && !price.isEmpty && !weight.isEmpty
        
        return validBrand && validMainCategory && validSubCategory && validDetails
    }
    
    private func saveMaterial() {
        // 处理自定义选项
        let finalBrand: String
        if selectedBrand == "自定义" && !customBrand.isEmpty {
            finalBrand = customBrand
            store.addCustomBrand(customBrand)
        } else {
            finalBrand = selectedBrand
        }
        
        let finalMainCategory: String
        if selectedMainCategory == "自定义" && !customMainCategory.isEmpty {
            finalMainCategory = customMainCategory
            store.addCustomMainCategory(customMainCategory)
        } else {
            finalMainCategory = selectedMainCategory
        }
        
        let finalSubCategory: String
        if selectedSubCategory == "自定义" && !customSubCategory.isEmpty {
            finalSubCategory = customSubCategory
            store.addCustomSubCategory(customSubCategory)
        } else {
            finalSubCategory = selectedSubCategory
        }
        
        // 创建并保存新材料
        if let priceValue = Double(price), let weightValue = Double(weight) {
            let newMaterial = Material(
                brand: finalBrand,
                mainCategory: finalMainCategory,
                subCategory: finalSubCategory,
                name: colorName,
                purchaseDate: purchaseDate,
                price: priceValue,
                initialWeight: weightValue,
                remainingWeight: weightValue,
                colorHex: colorHex,
                gradientColorHex: isGradient ? gradientColorHex : nil,
                gradientColors: nil, // 手动添加时暂不支持多色渐变，保持向后兼容
                shortCode: shortCode.isEmpty ? nil : shortCode
            )
            
            store.addMaterial(newMaterial)
        }
    }
}

// MARK: 记录用量
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

// MARK: 预设管理
struct PresetManagementView: View {
    @ObservedObject var store: MaterialStore
    @State private var isShowingAddPresetSheet = false
    @State private var searchText = ""
    
    // 预览相关状态
    @State private var showingPreview = false
    @State private var previewPreset: MaterialPreset?
    
    // 新预设表单状态
    @State private var selectedBrand = ""
    @State private var selectedMainCategory = ""
    @State private var selectedSubCategory = "无"
    @State private var customBrand = ""
    @State private var customMainCategory = ""
    @State private var customSubCategory = ""
    @State private var colorName = "" // 新增的颜色名称字段
    @State private var colorHex = "#FFFFFF"
    @State private var isGradient = false
    @State private var gradientColorHex = "#FFFF00"
    
    // 搜索过滤的预设
    private var filteredPresets: [MaterialPreset] {
        if searchText.isEmpty {
            return store.materialPresets
        } else {
            return store.materialPresets.filter { preset in
                preset.brand.localizedCaseInsensitiveContains(searchText) ||
                preset.mainCategory.localizedCaseInsensitiveContains(searchText) ||
                preset.subCategory.localizedCaseInsensitiveContains(searchText) ||
                preset.colorName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // 首先按品牌分组（使用过滤后的预设）
                ForEach(Array(Dictionary(grouping: filteredPresets, by: { $0.brand }).sorted(by: { $0.key < $1.key })), id: \.key) { brand, brandPresets in
                    Section(header: Text(brand)) {
                        BrandPresetSection(
                            brandPresets: brandPresets,
                            store: store,
                            previewPreset: $previewPreset,
                            showingPreview: $showingPreview
                        )
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索品牌、分类或颜色...")
            .navigationTitle("耗材预设")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddPresetSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingPreview) {
                if let preset = previewPreset {
                    MaterialPresetPreviewSheet(preset: preset, isPresented: $showingPreview)
                        .onDisappear {
                            previewPreset = nil
                        }
                }
            }
            .sheet(isPresented: $isShowingAddPresetSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("添加耗材预设")) {
                            // 品牌选择
                            Picker("品牌", selection: $selectedBrand) {
                                Text("请选择").tag("")
                                ForEach(store.brands, id: \.self) { brand in
                                    Text(brand).tag(brand)
                                }
                            }
                            
                            if selectedBrand == "自定义" {
                                TextField("输入品牌名", text: $customBrand)
                            }
                            
                            // 主分类选择
                            Picker("主分类", selection: $selectedMainCategory) {
                                Text("请选择").tag("")
                                ForEach(store.mainCategories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            
                            if selectedMainCategory == "自定义" {
                                TextField("输入主分类名", text: $customMainCategory)
                            }
                            
                            // 子分类选择
                            Picker("子分类", selection: $selectedSubCategory) {
                                ForEach(store.subCategories, id: \.self) { category in
                                    Text(category).tag(category)
                                }
                            }
                            
                            if selectedSubCategory == "自定义" {
                                TextField("输入子分类名", text: $customSubCategory)
                            }
                            
                            // 颜色名称
                            TextField("颜色名称", text: $colorName)
                            
                            // 渐变色开关
                            Toggle("渐变色", isOn: $isGradient)
                            
                            // 颜色选择
                            ColorPicker(isGradient ? "起始颜色" : "颜色", selection: Binding(
                                get: { Color(hex: colorHex) ?? .white },
                                set: { newColor in
                                    // 将Color转换为hex值
                                    if let components = newColor.cgColor?.components,
                                       components.count >= 3 {
                                        let r = Float(components[0])
                                        let g = Float(components[1])
                                        let b = Float(components[2])
                                        colorHex = String(format: "#%02lX%02lX%02lX",
                                                          lroundf(r * 255),
                                                          lroundf(g * 255),
                                                          lroundf(b * 255))
                                    }
                                }
                            ))
                            
                            // 如果选择了渐变色，显示第二个颜色选择器
                            if isGradient {
                                ColorPicker("结束颜色", selection: Binding(
                                    get: { Color(hex: gradientColorHex) ?? .yellow },
                                    set: { newColor in
                                        // 将Color转换为hex值
                                        if let components = newColor.cgColor?.components,
                                           components.count >= 3 {
                                            let r = Float(components[0])
                                            let g = Float(components[1])
                                            let b = Float(components[2])
                                            gradientColorHex = String(format: "#%02lX%02lX%02lX",
                                                                      lroundf(r * 255),
                                                                      lroundf(g * 255),
                                                                      lroundf(b * 255))
                                        }
                                    }
                                ))
                            }
                        }
                    }
                    .navigationTitle("添加预设")
                    .navigationBarItems(
                        leading: Button("取消") {
                            isShowingAddPresetSheet = false
                            resetPresetForm()
                        },
                        trailing: Button("保存") {
                            savePreset()
                            isShowingAddPresetSheet = false
                        }
                        .disabled(!isPresetFormValid)
                    )
                }
            }
        }
    }
    
    private var isPresetFormValid: Bool {
        let validBrand = selectedBrand != "" && (selectedBrand != "自定义" || customBrand != "")
        let validMainCategory = selectedMainCategory != "" && (selectedMainCategory != "自定义" || customMainCategory != "")
        let validSubCategory = selectedSubCategory != "自定义" || customSubCategory != ""
        let validColorName = !colorName.isEmpty // 颜色名称不能为空
        
        return validBrand && validMainCategory && validSubCategory && validColorName
    }
    
    private func savePreset() {
        // 处理自定义选项
        let finalBrand: String
        if selectedBrand == "自定义" && !customBrand.isEmpty {
            finalBrand = customBrand
            store.addCustomBrand(customBrand)
        } else {
            finalBrand = selectedBrand
        }
        
        let finalMainCategory: String
        if selectedMainCategory == "自定义" && !customMainCategory.isEmpty {
            finalMainCategory = customMainCategory
            store.addCustomMainCategory(customMainCategory)
        } else {
            finalMainCategory = selectedMainCategory
        }
        
        let finalSubCategory: String
        if selectedSubCategory == "自定义" && !customSubCategory.isEmpty {
            finalSubCategory = customSubCategory
            store.addCustomSubCategory(customSubCategory)
        } else {
            finalSubCategory = selectedSubCategory
        }
        
        // 创建并保存新预设
        let newPreset = MaterialPreset(
            brand: finalBrand,
            mainCategory: finalMainCategory,
            subCategory: finalSubCategory,
            colorName: colorName, // 新增的颜色名称
            colorHex: colorHex,
            gradientColorHex: isGradient ? gradientColorHex : nil
        )
        
        store.addPreset(newPreset)
    }
    
    private func resetPresetForm() {
        selectedBrand = ""
        selectedMainCategory = ""
        selectedSubCategory = "无"
        customBrand = ""
        customMainCategory = ""
        customSubCategory = ""
        colorName = "" // 重置颜色名称
        colorHex = "#FFFFFF"
        isGradient = false
        gradientColorHex = "#FFFF00"
    }
}

// MARK: 品牌预设区域组件
struct BrandPresetSection: View {
    let brandPresets: [MaterialPreset]
    let store: MaterialStore
    @Binding var previewPreset: MaterialPreset?
    @Binding var showingPreview: Bool
    
    var body: some View {
        // 在每个品牌下按材料类型（主分类）分组
        ForEach(Array(Dictionary(grouping: brandPresets, by: { $0.mainCategory }).sorted(by: { $0.key < $1.key })), id: \.key) { mainCategory, categoryPresets in
            DisclosureGroup(mainCategory) {
                MainCategorySection(
                    categoryPresets: categoryPresets,
                    store: store,
                    previewPreset: $previewPreset,
                    showingPreview: $showingPreview
                )
            }
        }
    }
}

// MARK: 主分类区域组件
struct MainCategorySection: View {
    let categoryPresets: [MaterialPreset]
    let store: MaterialStore
    @Binding var previewPreset: MaterialPreset?
    @Binding var showingPreview: Bool
    
    var body: some View {
        // 在每个材料类型下按细分类型分组
        ForEach(Array(Dictionary(grouping: categoryPresets, by: { $0.subCategory }).sorted(by: { $0.key < $1.key })), id: \.key) { subCategory, subCategoryPresets in
            DisclosureGroup(subCategory) {
                SubCategorySection(
                    subCategoryPresets: subCategoryPresets,
                    store: store,
                    previewPreset: $previewPreset,
                    showingPreview: $showingPreview
                )
            }
        }
    }
}

// MARK: 子分类区域组件
struct SubCategorySection: View {
    let subCategoryPresets: [MaterialPreset]
    let store: MaterialStore
    @Binding var previewPreset: MaterialPreset?
    @Binding var showingPreview: Bool
    
    var body: some View {
        // 显示该细分类型下的所有颜色预设
        ForEach(subCategoryPresets) { preset in
            PresetRowView(
                preset: preset,
                store: store,
                previewPreset: $previewPreset,
                showingPreview: $showingPreview
            )
        }
    }
}

// MARK: 预设行组件
struct PresetRowView: View {
    let preset: MaterialPreset
    let store: MaterialStore
    @Binding var previewPreset: MaterialPreset?
    @Binding var showingPreview: Bool
    
    var body: some View {
        HStack {
            MaterialPresetColorView(preset: preset, size: 20, strokeWidth: 1)
            
            Text(preset.colorName)
                .font(.body)
        }
        .padding(.leading, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            previewPreset = preset
        }
        .onChange(of: previewPreset) {
            if previewPreset != nil {
                showingPreview = true
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let index = store.materialPresets.firstIndex(where: { $0.id == preset.id }) {
                    store.deletePreset(at: IndexSet([index]))
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: 材料纹理效果组件
struct MaterialTextureOverlay: View {
    let subCategory: String
    
    var body: some View {
        ZStack {
            switch subCategory.lowercased() {
            case "silk", "silk+":
                // 丝绸纹理 - 对角线条纹
                SilkTextureView()
            case "matte":
                // 哑光纹理 - 细密颗粒
                MatteTextureView()
            case "metal":
                // 金属纹理 - 反光条纹
                MetalTextureView()
            case "wood":
                // 木质纹理 - 木纹
                WoodTextureView()
            case "translucent":
                // 半透明纹理 - 光泽效果
                TranslucentTextureView()
            case "gradient":
                // 渐变纹理 - 流动效果
                GradientTextureView()
            case "sparkle":
                // 闪粉纹理 - 闪烁点
                SparkleTextureView()
            default:
                // 默认无纹理
                EmptyView()
            }
        }
    }
}

// MARK: 丝绸纹理
struct SilkTextureView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let spacing: CGFloat = 8
                
                // 创建对角线条纹
                for i in stride(from: -height, through: width + height, by: spacing) {
                    path.move(to: CGPoint(x: i, y: 0))
                    path.addLine(to: CGPoint(x: i + height, y: height))
                }
            }
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
            
            // 添加更细的交叉纹理
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let spacing: CGFloat = 16
                
                for i in stride(from: -height, through: width + height, by: spacing) {
                    path.move(to: CGPoint(x: i, y: height))
                    path.addLine(to: CGPoint(x: i + height, y: 0))
                }
            }
            .stroke(Color.white.opacity(0.075), lineWidth: 0.5)
        }
    }
}

// MARK: 哑光纹理
struct MatteTextureView: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                
                // 创建随机点阵营造哑光效果
                for _ in 0..<Int(width * height / 40) {
                    let x = Double.random(in: 0...width)
                    let y = Double.random(in: 0...height)
                    let opacity = Double.random(in: 0.05...0.15)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

// MARK: 金属纹理
struct MetalTextureView: View {
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.3), location: 0.0),
                    .init(color: Color.clear, location: 0.1),
                    .init(color: Color.white.opacity(0.1), location: 0.2),
                    .init(color: Color.clear, location: 0.3),
                    .init(color: Color.white.opacity(0.2), location: 0.4),
                    .init(color: Color.clear, location: 0.6),
                    .init(color: Color.white.opacity(0.1), location: 0.8),
                    .init(color: Color.clear, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: 木质纹理
struct WoodTextureView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // 创建木纹效果
                for i in stride(from: 0, through: height, by: 15) {
                    let y = CGFloat(i)
                    path.move(to: CGPoint(x: 0, y: y))
                    
                    // 创建波浪形木纹
                    for x in stride(from: 0, through: width, by: 10) {
                        let waveY = y + sin(x / 20) * 2
                        path.addLine(to: CGPoint(x: x, y: waveY))
                    }
                }
            }
            .stroke(Color.brown.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: 半透明纹理
struct TranslucentTextureView: View {
    var body: some View {
        RadialGradient(
            stops: [
                .init(color: Color.white.opacity(0.4), location: 0.0),
                .init(color: Color.white.opacity(0.1), location: 0.4),
                .init(color: Color.clear, location: 0.7),
                .init(color: Color.white.opacity(0.2), location: 1.0)
            ],
            center: .center,
            startRadius: 20,
            endRadius: 140
        )
    }
}

// MARK: 渐变纹理
struct GradientTextureView: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.3), location: animateGradient ? 0.0 : 0.3),
                .init(color: Color.clear, location: animateGradient ? 0.3 : 0.5),
                .init(color: Color.white.opacity(0.2), location: animateGradient ? 0.7 : 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: 闪粉纹理
struct SparkleTextureView: View {
    @State private var sparkleOpacity: [Double] = []
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                
                if sparkleOpacity.isEmpty {
                    sparkleOpacity = (0..<50).map { _ in Double.random(in: 0.1...0.8) }
                }
                
                // 创建闪烁点
                for (index, opacity) in sparkleOpacity.enumerated() {
                    let x = Double.random(in: 0...width)
                    let y = Double.random(in: 0...height)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                    sparkleOpacity = sparkleOpacity.map { _ in Double.random(in: 0.1...0.8) }
                }
            }
        }
    }
}


// MARK: 材料预设预览
struct MaterialPresetPreviewSheet: View {
    let preset: MaterialPreset
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 标题信息
                VStack(spacing: 8) {
                    Text(preset.colorName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(preset.brand)
                        Text("•")
                        Text(preset.mainCategory)
                        Text("•")
                        Text(preset.subCategory)
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                }
                
                // 颜色预览区域
                VStack(spacing: 20) {
                    // 大尺寸颜色预览
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            preset.isGradient
                                ? LinearGradient(
                                    colors: preset.allGradientColors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [preset.color],
                                    startPoint: .center,
                                    endPoint: .center
                                )
                        )
                        .frame(width: 280, height: 280)
                        .overlay(
                            // 添加纹理效果
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.clear)
                                .overlay(
                                    MaterialTextureOverlay(subCategory: preset.subCategory)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // 颜色信息
                    VStack(spacing: 12) {
                        if preset.isGradient {
                            VStack(spacing: 8) {
                                Text("渐变色")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 16) {
                                    ForEach(Array(preset.allGradientColors.enumerated()), id: \.offset) { index, color in
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 30, height: 30)
                                                .overlay(
                                                    Circle()
                                                        .stroke(.quaternary, lineWidth: 1)
                                                )
                                            
                                            Text("#\(index + 1)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 8) {
                                Text("单色")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(preset.colorHex.uppercased())
                                    .font(.monospaced(.body)())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("颜色预览")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("完成") {
                    isPresented = false
                }
            )
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
