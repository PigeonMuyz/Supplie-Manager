//
//  Models.swift
//  Supplie Manager
//
//  Created by 黄天晨 on 2025/3/6.
//


import Foundation
import SwiftUI

// 品牌模型
struct Brand: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    
    static var defaultBrands: [Brand] {
        [
            Brand(name: "Bambu"),
            Brand(name: "Creality"),
            Brand(name: "Prusament"),
            Brand(name: "eSun"),
            Brand(name: "Polymaker"),
            Brand(name: "Sunlu")
        ]
    }
}

// 材料类型模型
struct MaterialType: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var brandID: UUID?  // 可选关联到特定品牌
    
    static var defaultTypes: [MaterialType] {
        [
            MaterialType(name: "PLA"),
            MaterialType(name: "PLA Matte"),
            MaterialType(name: "PETG"),
            MaterialType(name: "ABS"),
            MaterialType(name: "TPU"),
            MaterialType(name: "PA"),
            MaterialType(name: "PA-CF"),
            MaterialType(name: "PEEK"),
            MaterialType(name: "ASA")
        ]
    }
}

// 预设颜色
struct MaterialColor: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorValue: String  // 保存为HEX值字符串
    var isPreset: Bool = true
    
    var color: Color {
        Color(hex: colorValue) ?? .gray
    }
    
    static var defaultColors: [MaterialColor] {
        [
            MaterialColor(name: "白色", colorValue: "#FFFFFF"),
            MaterialColor(name: "黑色", colorValue: "#000000"),
            MaterialColor(name: "红色", colorValue: "#FF0000"),
            MaterialColor(name: "蓝色", colorValue: "#0000FF"),
            MaterialColor(name: "绿色", colorValue: "#00FF00"),
            MaterialColor(name: "黄色", colorValue: "#FFFF00"),
            MaterialColor(name: "橙色", colorValue: "#FFA500"),
            MaterialColor(name: "紫色", colorValue: "#800080"),
            MaterialColor(name: "灰色", colorValue: "#808080"),
            MaterialColor(name: "透明", colorValue: "#FFFFFF", isPreset: false)
        ]
    }
}

// 材料模型
struct Material: Identifiable, Codable {
    var id = UUID()
    var brand: Brand
    var type: MaterialType
    var color: MaterialColor
    var purchaseDate: Date
    var initialWeight: Double = 1000.0 // 默认1kg(1000g)
    var remainingWeight: Double
    var usageRecords: [UsageRecord] = []
    
    // 计算已使用的重量
    var usedWeight: Double {
        initialWeight - remainingWeight
    }
    
    // 计算使用百分比
    var usagePercentage: Double {
        (usedWeight / initialWeight) * 100
    }
}

// 使用记录
struct UsageRecord: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var modelName: String
    var usedWeight: Double
}

// 存储管理
class MaterialStore: ObservableObject {
    @Published var materials: [Material] = [] {
        didSet {
            save()
        }
    }
    
    @Published var brands: [Brand] = [] {
        didSet {
            savePresets()
        }
    }
    
    @Published var materialTypes: [MaterialType] = [] {
        didSet {
            savePresets()
        }
    }
    
    @Published var materialColors: [MaterialColor] = [] {
        didSet {
            savePresets()
        }
    }
    
    // 总计数据
    var totalMaterials: Int {
        materials.count
    }
    
    var totalInitialWeight: Double {
        materials.reduce(0) { $0 + $1.initialWeight }
    }
    
    var totalRemainingWeight: Double {
        materials.reduce(0) { $0 + $1.remainingWeight }
    }
    
    var totalUsedWeight: Double {
        materials.reduce(0) { $0 + $1.usedWeight }
    }
    
    // 按品牌分组的材料
    var materialsByBrand: [Brand: [Material]] {
        Dictionary(grouping: materials) { $0.brand }
    }
    
    // 按颜色分组的材料
    var materialsByColor: [MaterialColor: [Material]] {
        Dictionary(grouping: materials) { $0.color }
    }
    
    init() {
        loadPresets()
        loadMaterials()
    }
    
    // 加载预设
    private func loadPresets() {
        // 加载品牌
        if let data = UserDefaults.standard.data(forKey: "SavedBrands") {
            if let decoded = try? JSONDecoder().decode([Brand].self, from: data) {
                brands = decoded
            } else {
                brands = Brand.defaultBrands
            }
        } else {
            brands = Brand.defaultBrands
        }
        
        // 加载材料类型
        if let data = UserDefaults.standard.data(forKey: "SavedMaterialTypes") {
            if let decoded = try? JSONDecoder().decode([MaterialType].self, from: data) {
                materialTypes = decoded
            } else {
                materialTypes = MaterialType.defaultTypes
            }
        } else {
            materialTypes = MaterialType.defaultTypes
        }
        
        // 加载颜色
        if let data = UserDefaults.standard.data(forKey: "SavedMaterialColors") {
            if let decoded = try? JSONDecoder().decode([MaterialColor].self, from: data) {
                materialColors = decoded
            } else {
                materialColors = MaterialColor.defaultColors
            }
        } else {
            materialColors = MaterialColor.defaultColors
        }
    }
    
    // 保存预设
    private func savePresets() {
        if let encoded = try? JSONEncoder().encode(brands) {
            UserDefaults.standard.set(encoded, forKey: "SavedBrands")
        }
        
        if let encoded = try? JSONEncoder().encode(materialTypes) {
            UserDefaults.standard.set(encoded, forKey: "SavedMaterialTypes")
        }
        
        if let encoded = try? JSONEncoder().encode(materialColors) {
            UserDefaults.standard.set(encoded, forKey: "SavedMaterialColors")
        }
    }
    
    // 加载材料数据
    private func loadMaterials() {
        if let data = UserDefaults.standard.data(forKey: "SavedMaterials") {
            if let decoded = try? JSONDecoder().decode([Material].self, from: data) {
                materials = decoded
                return
            }
        }
        
        // 如果没有数据，创建空列表
        materials = []
    }
    
    // 保存材料数据
    private func save() {
        if let encoded = try? JSONEncoder().encode(materials) {
            UserDefaults.standard.set(encoded, forKey: "SavedMaterials")
        }
    }
    
    // 添加新材料
    func addMaterial(material: Material) {
        materials.append(material)
    }
    
    // 更新材料
    func updateMaterial(_ material: Material) {
        if let index = materials.firstIndex(where: { $0.id == material.id }) {
            materials[index] = material
        }
    }
    
    // 记录材料使用
    func recordUsage(for materialID: UUID, modelName: String, usedWeight: Double) -> Bool {
        if let index = materials.firstIndex(where: { $0.id == materialID }) {
            // 检查是否有足够的材料
            if materials[index].remainingWeight < usedWeight {
                return false
            }
            
            let record = UsageRecord(date: Date(), modelName: modelName, usedWeight: usedWeight)
            materials[index].usageRecords.append(record)
            materials[index].remainingWeight -= usedWeight
            
            // 确保剩余重量不会小于0
            if materials[index].remainingWeight < 0 {
                materials[index].remainingWeight = 0
            }
            
            return true
        }
        return false
    }
    
    // 删除材料
    func deleteMaterial(at offsets: IndexSet) {
        materials.remove(atOffsets: offsets)
    }
    
    // 添加品牌
    func addBrand(_ brand: Brand) {
        brands.append(brand)
    }
    
    // 添加材料类型
    func addMaterialType(_ type: MaterialType) {
        materialTypes.append(type)
    }
    
    // 添加颜色
    func addColor(_ color: MaterialColor) {
        materialColors.append(color)
    }
    
    // 获取特定品牌的材料类型
    func getMaterialTypes(for brandID: UUID?) -> [MaterialType] {
        if let brandID = brandID {
            return materialTypes.filter { $0.brandID == brandID || $0.brandID == nil }
        } else {
            return materialTypes
        }
    }
}

// 扩展Color以支持HEX值
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            .sRGB,
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0,
            opacity: 1.0
        )
    }
}
