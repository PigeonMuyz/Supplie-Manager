import SwiftUI

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
                            resetForm()
                        },
                        trailing: Button("保存") {
                            savePreset()
                            isShowingAddPresetSheet = false
                            resetForm()
                        }
                        .disabled(!isFormValid)
                    )
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        let validBrand = selectedBrand != "" && (selectedBrand != "自定义" || customBrand != "")
        let validMainCategory = selectedMainCategory != "" && (selectedMainCategory != "自定义" || customMainCategory != "")
        let validSubCategory = selectedSubCategory != "自定义" || customSubCategory != ""
        let validColorName = !colorName.isEmpty
        
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
            colorName: colorName,
            colorHex: colorHex,
            gradientColorHex: isGradient ? gradientColorHex : nil
        )
        
        store.addPreset(newPreset)
    }
    
    private func resetForm() {
        selectedBrand = ""
        selectedMainCategory = ""
        selectedSubCategory = "无"
        customBrand = ""
        customMainCategory = ""
        customSubCategory = ""
        colorName = ""
        colorHex = "#FFFFFF"
        isGradient = false
        gradientColorHex = "#FFFF00"
    }
}