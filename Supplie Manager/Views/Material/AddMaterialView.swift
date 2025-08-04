import SwiftUI

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