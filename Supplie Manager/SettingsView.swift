//
//  SettingsView.swift
//  Supplie Manager
//
//  Created by 黄天晨 on 2025/3/6.
//


import SwiftUI

// 设置页面
struct SettingsView: View {
    @ObservedObject var materialStore: MaterialStore
    @State private var showingBrandManagement = false
    @State private var showingTypeManagement = false
    @State private var showingColorManagement = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("预设管理")) {
                    NavigationLink(destination: BrandManagementView(materialStore: materialStore)) {
                        Label("品牌管理", systemImage: "tag")
                    }
                    
                    NavigationLink(destination: MaterialTypeManagementView(materialStore: materialStore)) {
                        Label("材料类型管理", systemImage: "shippingbox")
                    }
                    
                    NavigationLink(destination: ColorManagementView(materialStore: materialStore)) {
                        Label("颜色管理", systemImage: "paintpalette")
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("Your Name")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

// 品牌管理视图
struct BrandManagementView: View {
    @ObservedObject var materialStore: MaterialStore
    @State private var showingAddBrand = false
    @State private var newBrandName = ""
    
    var body: some View {
        List {
            Section(header: Text("已有品牌")) {
                ForEach(materialStore.brands) { brand in
                    Text(brand.name)
                }
                // 注意：这里不添加删除功能，因为可能有材料已经关联到品牌
            }
            
            Section(header: Text("添加新品牌")) {
                HStack {
                    TextField("品牌名称", text: $newBrandName)
                    Button(action: {
                        if !newBrandName.isEmpty {
                            materialStore.addBrand(Brand(name: newBrandName))
                            newBrandName = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newBrandName.isEmpty)
                }
            }
        }
        .navigationTitle("品牌管理")
    }
}

// 材料类型管理视图
struct MaterialTypeManagementView: View {
    @ObservedObject var materialStore: MaterialStore
    @State private var newTypeName = ""
    @State private var selectedBrandIndex: Int?
    
    var body: some View {
        List {
            Section(header: Text("已有材料类型")) {
                ForEach(materialStore.materialTypes) { type in
                    HStack {
                        Text(type.name)
                        Spacer()
                        if let brandID = type.brandID, let brand = materialStore.brands.first(where: { $0.id == brandID }) {
                            Text(brand.name)
                                .foregroundColor(.secondary)
                        } else {
                            Text("通用")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                // 注意：这里不添加删除功能，因为可能有材料已经关联到类型
            }
            
            Section(header: Text("添加新材料类型")) {
                TextField("类型名称", text: $newTypeName)
                
                Picker("关联品牌(可选)", selection: $selectedBrandIndex) {
                    Text("通用").tag(nil as Int?)
                    ForEach(0..<materialStore.brands.count, id: \.self) { index in
                        Text(materialStore.brands[index].name).tag(index as Int?)
                    }
                }
                
                Button("添加类型") {
                    if !newTypeName.isEmpty {
                        let brandID = selectedBrandIndex != nil ? materialStore.brands[selectedBrandIndex!].id : nil
                        materialStore.addMaterialType(MaterialType(name: newTypeName, brandID: brandID))
                        newTypeName = ""
                        selectedBrandIndex = nil
                    }
                }
                .disabled(newTypeName.isEmpty)
            }
        }
        .navigationTitle("材料类型管理")
    }
}

// 颜色管理视图
struct ColorManagementView: View {
    @ObservedObject var materialStore: MaterialStore
    @State private var newColorName = ""
    @State private var selectedColor = Color.black
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List {
            Section(header: Text("预设颜色")) {
                ForEach(materialStore.materialColors.filter { $0.isPreset }) { color in
                    HStack {
                        Circle()
                            .fill(color.color)
                            .overlay(
                                Circle()
                                    .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1)
                            )
                            .frame(width: 20, height: 20)
                        Text(color.name)
                    }
                }
            }
            
            Section(header: Text("自定义颜色")) {
                ForEach(materialStore.materialColors.filter { !$0.isPreset }) { color in
                    HStack {
                        Circle()
                            .fill(color.color)
                            .overlay(
                                Circle()
                                    .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1)
                            )
                            .frame(width: 20, height: 20)
                        Text(color.name)
                    }
                }
                // 注意：这里不添加删除功能，因为可能有材料已经关联到颜色
            }
            
            Section(header: Text("添加新颜色")) {
                TextField("颜色名称", text: $newColorName)
                
                ColorPicker("选择颜色", selection: $selectedColor)
                
                Button("添加颜色") {
                    if !newColorName.isEmpty {
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
                        
                        materialStore.addColor(MaterialColor(name: newColorName, colorValue: hex, isPreset: false))
                        newColorName = ""
                    }
                }
                .disabled(newColorName.isEmpty)
            }
        }
        .navigationTitle("颜色管理")
    }
}
