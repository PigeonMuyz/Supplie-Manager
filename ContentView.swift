import SwiftUI

// 主界面
struct ContentView: View {
    @StateObject private var materialStore = MaterialStore()
    @State private var showingAddMaterial = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MaterialListView(materialStore: materialStore)
                .tabItem {
                    Label("耗材", systemImage: "cube.box")
                }
                .tag(0)
            
            SummaryView(materialStore: materialStore)
                .tabItem {
                    Label("统计", systemImage: "chart.pie")
                }
                .tag(1)
            
            SettingsView(materialStore: materialStore)
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

// 材料列表视图
struct MaterialListView: View {
    @ObservedObject var materialStore: MaterialStore
    @State private var showingAddMaterial = false
    
    var body: some View {
        NavigationView {
            List {
                if materialStore.materials.isEmpty {
                    Text("暂无耗材记录，点击添加耗材以开始")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(materialStore.materials) { material in
                        NavigationLink(destination: MaterialDetailView(material: material, materialStore: materialStore)) {
                            MaterialRowView(material: material)
                        }
                    }
                    .onDelete(perform: materialStore.deleteMaterial)
                }
            }
            .navigationTitle("Bambu Manager")
            .navigationBarItems(
                trailing: Button(action: {
                    showingAddMaterial = true
                }) {
                    Label("添加", systemImage: "plus")
                }
            )
            .sheet(isPresented: $showingAddMaterial) {
                AddMaterialView(materialStore: materialStore)
            }
        }
    }
}

// 材料行视图
struct MaterialRowView: View {
    let material: Material
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(material.color.color)
                    .overlay(
                        Circle()
                            .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1)
                    )
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading) {
                    Text("\(material.brand.name) \(material.type.name)")
                        .font(.headline)
                    Text("\(material.color.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "%.2f g", material.remainingWeight))
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: material.usagePercentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: 
                                                            colorScheme == .dark ? .white : .black
                                                          ))
            
            Text("购买日期: \(formatDate(material.purchaseDate))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// 添加材料视图
struct AddMaterialView: View {
    @ObservedObject var materialStore: MaterialStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedBrandIndex = 0
    @State private var selectedTypeIndex = 0
    @State private var selectedColorIndex = 0
    @State private var purchaseDate = Date()
    @State private var initialWeight = 1000.0 // 默认1kg
    @State private var showingAddBrand = false
    @State private var showingAddType = false
    @State private var showingAddColor = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("材料信息")) {
                    HStack {
                        Text("品牌")
                        Spacer()
                        Picker("", selection: $selectedBrandIndex) {
                            ForEach(0..<materialStore.brands.count, id: \.self) { index in
                                Text(materialStore.brands[index].name).tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                        
                        Button(action: {
                            showingAddBrand = true
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                    
                    HStack {
                        Text("材料类型")
                        Spacer()
                        Picker("", selection: $selectedTypeIndex) {
                            ForEach(0..<materialStore.materialTypes.count, id: \.self) { index in
                                Text(materialStore.materialTypes[index].name).tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                        
                        Button(action: {
                            showingAddType = true
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                    
                    HStack {
                        Text("颜色")
                        Spacer()
                        
                        Circle()
                            .fill(materialStore.materialColors[selectedColorIndex].color)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary, lineWidth: 1)
                            )
                            .frame(width: 20, height: 20)
                        
                        Picker("", selection: $selectedColorIndex) {
                            ForEach(0..<materialStore.materialColors.count, id: \.self) { index in
                                Text(materialStore.materialColors[index].name).tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                        
                        Button(action: {
                            showingAddColor = true
                        }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                    
                    DatePicker("购买日期", selection: $purchaseDate, displayedComponents: .date)
                    
                    HStack {
                        Text("初始重量(g)")
                        Spacer()
                        TextField("默认1000g", value: $initialWeight, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section {
                    Button("保存") {
                        let selectedBrand = materialStore.brands[selectedBrandIndex]
                        let selectedType = materialStore.materialTypes[selectedTypeIndex]
                        let selectedColor = materialStore.materialColors[selectedColorIndex]
                        
                        let newMaterial = Material(
                            brand: selectedBrand,
                            type: selectedType,
                            color: selectedColor,
                            purchaseDate: purchaseDate,
                            initialWeight: initialWeight,
                            remainingWeight: initialWeight
                        )
                        
                        materialStore.addMaterial(material: newMaterial)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("添加新耗材")
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingAddBrand) {
                AddBrandView(materialStore: materialStore)
            }
            .sheet(isPresented: $showingAddType) {
                AddMaterialTypeView(materialStore: materialStore)
            }
            .sheet(isPresented: $showingAddColor) {
                AddColorView(materialStore: materialStore)
            }
        }
    }
}

// 添加品牌视图
struct AddBrandView: View {
    @ObservedObject var materialStore: MaterialStore
    @Environment(\.presentationMode) var presentationMode
    @State private var brandName = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("品牌名称", text: $brandName)
                
                Button("添加品牌") {
                    if !brandName.isEmpty {
                        materialStore.addBrand(Brand(name: brandName))
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(brandName.isEmpty)
            }
            .navigationTitle("添加新品牌")
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 添加材料类型视图
struct AddMaterialTypeView: View {
    @ObservedObject var materialStore: MaterialStore
    @Environment(\.presentationMode) var presentationMode
    @State private var typeName = ""
    @State private var selectedBrandIndex: Int?
    
    var body: some View {
        NavigationView {
            Form {
                TextField("材料类型名称", text: $typeName)
                
                Picker("关联品牌(可选)", selection: $selectedBrandIndex) {
                    Text("通用").tag(nil as Int?)
                    ForEach(0..<materialStore.brands.count, id: \.self) { index in
                        Text(materialStore.brands[index].name).tag(index as Int?)
                    }
                }
                
                Button("添加类型") {
                    if !typeName.isEmpty {
                        let brandID = selectedBrandIndex != nil ? materialStore.brands[selectedBrandIndex!].id : nil
                        materialStore.addMaterialType(MaterialType(name: typeName, brandID: brandID))
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(typeName.isEmpty)
            }
            .navigationTitle("添加新材料类型")
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 添加颜色视图
struct AddColorView: View {
    @ObservedObject var materialStore: MaterialStore
    @Environment(\.presentationMode) var presentationMode
    @State private var colorName = ""
    @State private var colorHex = "#000000"
    @State private var selectedColor = Color.black
    
    var body: some View {
        NavigationView {
            Form {
                TextField("颜色名称", text: $colorName)
                
                ColorPicker("选择颜色", selection: $selectedColor)
                
                Button("添加颜色") {
                    if !colorName.isEmpty {
                        // 将Color转换为Hex
                        let uiColor = UIColor(selectedColor)
                        var red: CGFloat = 0
                        var green: CGFloat = 0
                        var blue: CGFloat = 0
                        var alpha: CGFloat = 0
                        
                        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                        
                        let hex = String(
                            format: "#%02lX%02lX%02lX",
                            lroundf(Float(red * 255)),
                            lroundf(Float(green * 255)),
                            lroundf(Float(blue * 255))
                        )
                        
                        materialStore.addColor(MaterialColor(name: colorName, colorValue: hex, isPreset: false))
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(colorName.isEmpty)
            }
            .navigationTitle("添加新颜色")
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 材料详情页面
struct MaterialDetailView: View {
    let material: Material
    @ObservedObject var materialStore: MaterialStore
    @State private var showingAddUsage = false
    
    var body: some View {
        VStack {
            // 材料信息卡片
            MaterialInfoCard(material: material)
            
            // 使用记录列表
            List {
                Section(header: Text("使用记录")) {
                    if material.usageRecords.isEmpty {
                        Text("暂无使用记录")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(material.usageRecords.sorted(by: { $0.date > $1.date })) { record in
                            UsageRecordRow(record: record)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(material.brand.name) \(material.type.name)")
        .navigationBarItems(trailing: Button(action: {
            showingAddUsage = true
        }) {
            Label("记录用量", systemImage: "square.and.pencil")
        })
        .sheet(isPresented: $showingAddUsage) {
            AddUsageView(materialID: material.id, materialStore: materialStore)
        }
    }
}

// 材料信息卡片
struct MaterialInfoCard: View {
    let material: Material
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(material.color.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1)
                    )
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading) {
                    Text("\(material.brand.name) \(material.type.name)")
                        .font(.headline)
                    Text("\(material.color.name) · 购买日期: \(formatDate(material.purchaseDate))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                // 重量指标
                VStack {
                    Text("初始重量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f g", material.initialWeight))
                        .font(.headline)
                }
                
                Spacer()
                
                VStack {
                    Text("已使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f g", material.usedWeight))
                        .font(.headline)
                }
                
                Spacer()
                
                VStack {
                    Text("剩余重量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f g", material.remainingWeight))
                        .font(.headline)
                }
            }
            .padding(.vertical, 5)
            
            // 使用进度条
            VStack(alignment: .leading) {
                HStack {
                    Text("使用进度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f%%", material.usagePercentage))
                        .font(.caption)
                }
                
                ProgressView(value: material.usagePercentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: 
                                                                colorScheme == .dark ? .white : .black
                                                              ))
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.5) : Color.gray.opacity(0.3), radius: 3)
        .padding(.horizontal)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// 使用记录行
struct UsageRecordRow: View {
    let record: UsageRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(record.modelName)
                    .font(.headline)
                Text(formatDate(record.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.2f g", record.usedWeight))
                .font(.headline)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// 添加使用记录视图
struct AddUsageView: View {
    let materialID: UUID
    @ObservedObject var materialStore: MaterialStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var modelName = ""
    @State private var usedWeight = 10.0 // 默认值
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // 获取当前材料
    var currentMaterial: Material? {
        materialStore.materials.first(where: { $0.id == materialID })
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("使用详情")) {
                    TextField("模型名称", text: $modelName)
                    
                    HStack {
                        Text("使用重量(g)")
                        Spacer()
                        TextField("重量", value: $usedWeight, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if let material = currentMaterial {
                        HStack {
                            Text("剩余重量")
                            Spacer()
                            Text(String(format: "%.2f g", material.remainingWeight))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button("保存") {
                        if let material = currentMaterial {
                            if material.remainingWeight < usedWeight {
                                alertMessage = "材料不足！当前材料剩余 \(String(format: "%.2f", material.remainingWeight))g，无法使用 \(String(format: "%.2f", usedWeight))g。"
                                showingAlert = true
                            } else {
                                let success = materialStore.recordUsage(for: materialID, modelName: modelName, usedWeight: usedWeight)
                                if success {
                                    presentationMode.wrappedValue.dismiss()
                                } else {
                                    alertMessage = "记录使用失败，请重试。"
                                    showingAlert = true
                                }
                            }
                        }
                    }
                    .disabled(modelName.isEmpty || usedWeight <= 0)
                }
            }
            .navigationTitle("记录耗材使用")
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
}
