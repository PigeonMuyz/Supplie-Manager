import SwiftUI

struct ContentView: View {
    @StateObject private var store = MaterialStore()
    
    var body: some View {
        TabView {
            StatisticsView(store: store)
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }
            
            MyMaterialsView(store: store)
                .tabItem {
                    Label("我的耗材", systemImage: "cylinder.fill")
                }
            
            RecordUsageView(store: store)
                .tabItem {
                    Label("记录", systemImage: "pencil")
                }
            
            PresetManagementView(store: store)
                .tabItem {
                    Label("预设", systemImage: "list.bullet")
                }
        }
    }
}

// MARK: 统计视图
struct StatisticsView: View {
    @ObservedObject var store: MaterialStore
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("总用量统计")) {
                    HStack {
                        Text("累计使用耗材")
                        Spacer()
                        Text("\(String(format: "%.2f", store.getTotalUsedWeight()))g")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("累计耗材价格")
                        Spacer()
                        Text("¥\(String(format: "%.2f", store.getTotalUsedCost()))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("平均耗材成本")
                        Spacer()
                        Text("¥\(String(format: "%.2f", store.getTotalUsedWeight() > 0 ? store.getTotalUsedCost() / store.getTotalUsedWeight() : 0))/g")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("现有耗材")) {
                    // 只显示有剩余的耗材
                    ForEach(store.materials.filter { $0.remainingWeight > 0 }) { material in
                        HStack {
                            Circle()
                                .fill(material.color)
                                .frame(width: 20, height: 20)
                            
                            VStack(alignment: .leading) {
                                Text(material.fullName)
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
            .navigationTitle("耗材统计")
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
                        ForEach(store.materials.filter { $0.remainingWeight > 0 }) { material in
                            MaterialRow(material: material)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.deleteMaterial(id: material.id)
                                    } label: {
//                                        Label("删除", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        // 手动标记耗材已经用尽
                                        store.markMaterialAsEmpty(id: material.id)
                                    } label: {
//                                        Label("标记为用完", systemImage: "checkmark.circle")
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
                    Button(action: {
                        isShowingAddMaterialSheet = true
                    }) {
                        Image(systemName: "plus")
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
            Circle()
                .fill(material.color)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading) {
                Text(material.fullName)
                    .font(.headline)
                
                Text("购入日期: \(material.purchaseDate.formatted(date: .abbreviated, time: .omitted))")
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
    @State private var purchaseDate = Date()
    @State private var price = ""
    @State private var weight = ""
    
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
                                    Circle()
                                        .fill(preset.color)
                                        .frame(width: 12, height: 12)
                                    Text(preset.colorName)
                                }.tag(preset.colorName)
                            }
                        }
                    }
                }
                
                Section(header: Text("材料详情")) {
                    // 颜色名称
                    TextField("颜色名称", text: $colorName)
                    
                    // 颜色选择
                    ColorPicker("颜色", selection: Binding(
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
                    
                    // 购入日期
                    DatePicker("购入日期", selection: $purchaseDate, displayedComponents: .date)
                    
                    // 价格
                    TextField("价格 (¥)", text: $price)
                        .keyboardType(.decimalPad)
                    
                    // 重量
                    TextField("重量 (g)", text: $weight)
                        .keyboardType(.decimalPad)
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
                colorHex: colorHex
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
    
    // 只获取有剩余的材料
    private var availableMaterials: [Material] {
        store.materials.filter { $0.remainingWeight > 0 }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(store.printRecords.sorted(by: { $0.date > $1.date })) { record in
                        VStack(alignment: .leading) {
                            Text(record.modelName)
                                .font(.headline)
                            
                            if !record.makerWorldLink.isEmpty {
                                Link("Makerworld链接", destination: URL(string: record.makerWorldLink) ?? URL(string: "https://makerworld.com")!)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Text("使用材料: \(record.materialName)")
                                Spacer()
                                Text("\(String(format: "%.2f", record.weightUsed))g")
                            }
                            .foregroundColor(.secondary)
                            
                            HStack {
                                Text("成本: ¥\(String(format: "%.2f", store.getCostForRecord(record)))")
                                Spacer()
                                Text("日期: \(record.date.formatted(date: .abbreviated, time: .shortened))")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deletePrintRecord(id: record.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("用量记录")
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
        }
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
    
    // 新预设表单状态
    @State private var selectedBrand = ""
    @State private var selectedMainCategory = ""
    @State private var selectedSubCategory = "无"
    @State private var customBrand = ""
    @State private var customMainCategory = ""
    @State private var customSubCategory = ""
    @State private var colorName = "" // 新增的颜色名称字段
    @State private var colorHex = "#FFFFFF"
    @State private var isShowingCategoryManagement = false
    
    var body: some View {
        NavigationView {
            List {
                // 首先按品牌分组
                ForEach(Array(Dictionary(grouping: store.materialPresets, by: { $0.brand }).sorted(by: { $0.key < $1.key })), id: \.key) { brand, brandPresets in
                    Section(header: Text(brand)) {
                        // 在每个品牌下按材料类型（主分类）分组
                        ForEach(Array(Dictionary(grouping: brandPresets, by: { $0.mainCategory }).sorted(by: { $0.key < $1.key })), id: \.key) { mainCategory, categoryPresets in
                            DisclosureGroup(mainCategory) {
                                // 在每个材料类型下按细分类型分组
                                ForEach(Array(Dictionary(grouping: categoryPresets, by: { $0.subCategory }).sorted(by: { $0.key < $1.key })), id: \.key) { subCategory, subCategoryPresets in
                                    DisclosureGroup(subCategory) {
                                        // 显示该细分类型下的所有颜色预设
                                        ForEach(subCategoryPresets) { preset in
                                            HStack {
                                                Circle()
                                                    .fill(preset.color)
                                                    .frame(width: 20, height: 20)
                                                
                                                Text(preset.colorName)
                                                    .font(.body)
                                            }
                                            .padding(.leading, 10)
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
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("耗材预设")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddPresetSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowingCategoryManagement = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $isShowingCategoryManagement) {
                CategoryManagementView(store: store)
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
                            
                            // 颜色选择
                            ColorPicker("颜色", selection: Binding(
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
            colorHex: colorHex
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
    }
}

// MARK: 分类管理视图
struct CategoryManagementView: View {
    @ObservedObject var store: MaterialStore
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("品牌管理")) {
                    ForEach(store.brands.filter { $0 != "自定义" && !["Bambu Lab", "eSUN", "Polymaker", "Prusa", "Creality", "Sunlu", "Overture"].contains($0) }, id: \.self) { brand in
                        Text(brand)
                    }
                    .onDelete { indexSet in
                        // 获取要删除的自定义品牌
                        let customBrands = store.brands.filter { $0 != "自定义" && !["Bambu Lab", "eSUN", "Polymaker", "Prusa", "Creality", "Sunlu", "Overture"].contains($0) }
                        // 从自定义品牌中找到要删除的项
                        for index in indexSet {
                            store.removeCustomBrand(customBrands[index])
                        }
                    }
                }
                
                Section(header: Text("主分类管理")) {
                    ForEach(store.mainCategories.filter { $0 != "自定义" && !["PLA", "PLA+", "PETG", "ABS", "TPU", "ASA", "PC", "Nylon", "PVA"].contains($0) }, id: \.self) { category in
                        Text(category)
                    }
                    .onDelete { indexSet in
                        let customCategories = store.mainCategories.filter { $0 != "自定义" && !["PLA", "PLA+", "PETG", "ABS", "TPU", "ASA", "PC", "Nylon", "PVA"].contains($0) }
                        for index in indexSet {
                            store.removeCustomMainCategory(customCategories[index])
                        }
                    }
                }
                
                Section(header: Text("子分类管理")) {
                    ForEach(store.subCategories.filter { $0 != "自定义" && $0 != "无" && !["哑光", "亮面", "丝绸", "荧光", "金属质感", "木质感", "碳纤维"].contains($0) }, id: \.self) { category in
                        Text(category)
                    }
                    .onDelete { indexSet in
                        let customCategories = store.subCategories.filter { $0 != "自定义" && $0 != "无" && !["哑光", "亮面", "丝绸", "荧光", "金属质感", "木质感", "碳纤维"].contains($0) }
                        for index in indexSet {
                            store.removeCustomSubCategory(customCategories[index])
                        }
                    }
                }
            }
            .navigationTitle("分类管理")
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
