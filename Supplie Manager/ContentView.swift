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
                }
                
                Section(header: Text("现有耗材")) {
                    ForEach(store.materials) { material in
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
                                
                                Text("日期: \(record.date.formatted(date: .abbreviated, time: .shortened))")
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
    
    var body: some View {
        NavigationView {
            List {
                ForEach(store.materials) { material in
                    HStack {
                        Circle()
                            .fill(material.color)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading) {
                            Text(material.fullName)
                                .font(.headline)
                            
                            Text("购入日期: \(material.purchaseDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("价格: ¥\(String(format: "%.2f", material.price))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("剩余: \(String(format: "%.2f", material.remainingWeight))g / \(material.formattedWeight)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // 耗材使用进度条
                            ProgressView(value: 1 - (material.remainingWeight / material.initialWeight))
                        }
                    }
                    .padding(.vertical, 4)
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
                }
                
                Section(header: Text("材料详情")) {
                    // 颜色名称
                    TextField("颜色名称", text: $colorName)
                    
                    // 颜色选择
                    ColorPicker("颜色", selection: Binding(
                        get: { Color(hex: colorHex) ?? .white },
                        set: { _ in }
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
        let validDetails = !price.isEmpty && !weight.isEmpty
        
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
                            
                            Text("日期: \(record.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                            if store.materials.isEmpty {
                                Text("请先添加耗材")
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("选择材料", selection: $selectedMaterialId) {
                                    Text("请选择").tag(nil as UUID?)
                                    ForEach(store.materials) { material in
                                        HStack {
                                            Circle()
                                                .fill(material.color)
                                                .frame(width: 12, height: 12)
                                            Text(material.fullName)
                                        }.tag(material.id as UUID?)
                                    }
                                }
                                
                                if let materialId = selectedMaterialId,
                                   let material = store.materials.first(where: { $0.id == materialId }) {
                                    Text("剩余: \(String(format: "%.2f", material.remainingWeight))g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                TextField("用量(g)", text: $weightUsed)
                                    .keyboardType(.decimalPad)
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
                               let material = store.materials.first(where: { $0.id == materialId }) {
                                let newRecord = PrintRecord(
                                    modelName: modelName,
                                    makerWorldLink: makerWorldLink,
                                    materialId: materialId,
                                    materialName: material.fullName,
                                    weightUsed: weight,
                                    date: Date()
                                )
                                store.addPrintRecord(newRecord)
                                isShowingAddSheet = false
                                resetForm()
                            }
                        }
                        .disabled(selectedMaterialId == nil || modelName.isEmpty || weightUsed.isEmpty)
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
    @State private var colorHex = "#FFFFFF"
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("耗材预设")) {
                    ForEach(store.materialPresets) { preset in
                        HStack {
                            Circle()
                                .fill(preset.color)
                                .frame(width: 20, height: 20)
                            
                            Text(preset.fullName)
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
                            
                            // 颜色选择
                            ColorPicker("颜色", selection: Binding(
                                get: { Color(hex: colorHex) ?? .white },
                                set: { _ in }
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
        
        return validBrand && validMainCategory && validSubCategory
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
        colorHex = "#FFFFFF"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
