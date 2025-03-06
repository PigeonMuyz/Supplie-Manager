import SwiftUI

// 材料数据模型
struct Material: Identifiable, Codable {
    var id = UUID()
    var brand: String
    var mainCategory: String
    var subCategory: String
    var name: String
    var purchaseDate: Date
    var price: Double
    var initialWeight: Double  // 以克为单位
    var remainingWeight: Double  // 以克为单位
    var colorHex: String
    
    var formattedWeight: String {
        if initialWeight >= 1000 {
            return "1kg"
        } else {
            return "\(Int(initialWeight))g"
        }
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    // a完整显示名称
    var fullName: String {
        var parts = [brand]
        
        if !mainCategory.isEmpty {
            parts.append(mainCategory)
        }
        
        if !subCategory.isEmpty && subCategory != "无" {
            parts.append(subCategory)
        }
        
        if !name.isEmpty {
            parts.append(name)
        }
        
        return parts.joined(separator: " ")
    }
}

// 材料预设模型
struct MaterialPreset: Identifiable, Codable {
    var id = UUID()
    var brand: String
    var mainCategory: String
    var subCategory: String
    var colorName: String // 新增的颜色名称字段
    var colorHex: String
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    // 完整显示名称
    var fullName: String {
        var parts = [brand]
        
        if !mainCategory.isEmpty {
            parts.append(mainCategory)
        }
        
        if !subCategory.isEmpty && subCategory != "无" {
            parts.append(subCategory)
        }
        
        if !colorName.isEmpty {
            parts.append(colorName)
        }
        
        return parts.joined(separator: " ")
    }
}

// 打印记录模型
struct PrintRecord: Identifiable, Codable {
    var id = UUID()
    var modelName: String
    var makerWorldLink: String
    var materialId: UUID  // 直接关联到材料ID
    var materialName: String  // 材料完整名称
    var weightUsed: Double  // 使用的克数
    var date: Date
}

// 颜色扩展，支持十六进制代码
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

// 数据存储管理
class MaterialStore: ObservableObject {
    @Published var materials: [Material] = []
    @Published var printRecords: [PrintRecord] = []
    @Published var materialPresets: [MaterialPreset] = []
    
    // 预设选项
    @Published var brands: [String] = ["Bambu Lab", "eSUN", "Polymaker", "Prusa", "Creality", "Sunlu", "Overture", "自定义"]
    @Published var mainCategories: [String] = ["PLA", "PLA+", "PETG", "ABS", "TPU", "ASA", "PC", "Nylon", "PVA", "自定义"]
    @Published var subCategories: [String] = ["无", "Matte", "Basic", "Silk", "Fluor", "Metal", "Wood", "CF", "自定义"]

    // 修改 MaterialStore 内的预设数据
    private let bambuPresets: [MaterialPreset] = [
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "哑光白", colorHex: "#FFFFFF"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "象牙白", colorHex: "#FFF8DC"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "哑光黑", colorHex: "#000000"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "象牙黑", colorHex: "#1A1A1A"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Silk", colorName: "丝绸蓝", colorHex: "#4169E1"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "CF", colorName: "碳纤维黑", colorHex: "#1A1A1A"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PETG", subCategory: "Matte", colorName: "哑光橙", colorHex: "#FF4500"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "ABS", subCategory: "Matte", colorName: "哑光绿", colorHex: "#3CB371"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "TPU", subCategory: "Basic", colorName: "标准黄", colorHex: "#FFD700"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PVA", subCategory: "Basic", colorName: "标准白", colorHex: "#F5F5F5"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PA-CF", subCategory: "Carbon Fiber", colorName: "碳纤维深灰", colorHex: "#2F4F4F")
    ]

    // eSun常见预设
    private let esunPresets: [MaterialPreset] = [
        MaterialPreset(brand: "eSUN", mainCategory: "PLA+", subCategory: "Basic", colorName: "标准白", colorHex: "#FFFFFF"),
        MaterialPreset(brand: "eSUN", mainCategory: "PETG", subCategory: "Basic", colorName: "标准黑", colorHex: "#000000"),
        MaterialPreset(brand: "eSUN", mainCategory: "ABS+", subCategory: "Basic", colorName: "标准红", colorHex: "#FF0000"),
        MaterialPreset(brand: "eSUN", mainCategory: "TPU", subCategory: "Basic", colorName: "标准蓝", colorHex: "#0000FF")
    ]

    // Polymaker常见预设
    private let polymakerPresets: [MaterialPreset] = [
        MaterialPreset(brand: "Polymaker", mainCategory: "PolyLite PLA", subCategory: "Basic", colorName: "标准白", colorHex: "#FFFFFF"),
        MaterialPreset(brand: "Polymaker", mainCategory: "PolyMax PLA", subCategory: "Basic", colorName: "标准黑", colorHex: "#000000"),
        MaterialPreset(brand: "Polymaker", mainCategory: "PolyTerra PLA", subCategory: "Matte", colorName: "木质棕", colorHex: "#8B4513")
    ]
    
    init() {
        // 添加预设
        materialPresets.append(contentsOf: bambuPresets)
        materialPresets.append(contentsOf: esunPresets)
        materialPresets.append(contentsOf: polymakerPresets)
        
        loadData()
    }
    
    func loadData() {
        // 从UserDefaults加载数据
        if let materialsData = UserDefaults.standard.data(forKey: "materials"),
           let decodedMaterials = try? JSONDecoder().decode([Material].self, from: materialsData) {
            materials = decodedMaterials
        }
        
        if let recordsData = UserDefaults.standard.data(forKey: "printRecords"),
           let decodedRecords = try? JSONDecoder().decode([PrintRecord].self, from: recordsData) {
            printRecords = decodedRecords
        }
        
        if let presetsData = UserDefaults.standard.data(forKey: "materialPresets"),
           let decodedPresets = try? JSONDecoder().decode([MaterialPreset].self, from: presetsData) {
            // 合并自定义预设与内置预设
            let customPresets = decodedPresets.filter { preset in
                !bambuPresets.contains(where: { $0.brand == preset.brand && $0.mainCategory == preset.mainCategory && $0.subCategory == preset.subCategory }) &&
                !esunPresets.contains(where: { $0.brand == preset.brand && $0.mainCategory == preset.mainCategory && $0.subCategory == preset.subCategory }) &&
                !polymakerPresets.contains(where: { $0.brand == preset.brand && $0.mainCategory == preset.mainCategory && $0.subCategory == preset.subCategory })
            }
            materialPresets.append(contentsOf: customPresets)
        }
        
        // 加载自定义的品牌、分类等
        if let customBrands = UserDefaults.standard.stringArray(forKey: "customBrands") {
            for brand in customBrands {
                if !brands.contains(brand) {
                    brands.append(brand)
                }
            }
        }
        
        if let customMainCategories = UserDefaults.standard.stringArray(forKey: "customMainCategories") {
            for category in customMainCategories {
                if !mainCategories.contains(category) {
                    mainCategories.append(category)
                }
            }
        }
        
        if let customSubCategories = UserDefaults.standard.stringArray(forKey: "customSubCategories") {
            for category in customSubCategories {
                if !subCategories.contains(category) {
                    subCategories.append(category)
                }
            }
        }
    }
    
    func saveData() {
        // 保存到UserDefaults
        if let encodedMaterials = try? JSONEncoder().encode(materials) {
            UserDefaults.standard.set(encodedMaterials, forKey: "materials")
        }
        
        if let encodedRecords = try? JSONEncoder().encode(printRecords) {
            UserDefaults.standard.set(encodedRecords, forKey: "printRecords")
        }
        
        // 只保存自定义的预设，内置预设不需要保存
        let customPresets = materialPresets.filter { preset in
            !bambuPresets.contains(where: { $0.brand == preset.brand && $0.mainCategory == preset.mainCategory && $0.subCategory == preset.subCategory }) &&
            !esunPresets.contains(where: { $0.brand == preset.brand && $0.mainCategory == preset.mainCategory && $0.subCategory == preset.subCategory }) &&
            !polymakerPresets.contains(where: { $0.brand == preset.brand && $0.mainCategory == preset.mainCategory && $0.subCategory == preset.subCategory })
        }
        
        if let encodedPresets = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(encodedPresets, forKey: "materialPresets")
        }
        
        // 保存自定义的品牌和分类
        let customBrands = brands.filter { $0 != "自定义" && !["Bambu Lab", "eSUN", "Polymaker", "Prusa", "Creality", "Sunlu", "Overture"].contains($0) }
        UserDefaults.standard.set(customBrands, forKey: "customBrands")
        
        let customMainCategories = mainCategories.filter { $0 != "自定义" && !["PLA", "PLA+", "PETG", "ABS", "TPU", "ASA", "PC", "Nylon", "PVA"].contains($0) }
        UserDefaults.standard.set(customMainCategories, forKey: "customMainCategories")
        
        let customSubCategories = subCategories.filter { $0 != "自定义" && $0 != "无" && !["哑光", "亮面", "丝绸", "荧光", "金属质感", "木质感", "碳纤维"].contains($0) }
        UserDefaults.standard.set(customSubCategories, forKey: "customSubCategories")
    }
    
    func addCustomBrand(_ brand: String) {
        if !brand.isEmpty && !brands.contains(brand) {
            brands.insert(brand, at: brands.count - 1)
            saveData()
        }
    }
    
    func addCustomMainCategory(_ category: String) {
        if !category.isEmpty && !mainCategories.contains(category) {
            mainCategories.insert(category, at: mainCategories.count - 1)
            saveData()
        }
    }
    
    func addCustomSubCategory(_ category: String) {
        if !category.isEmpty && !subCategories.contains(category) {
            subCategories.insert(category, at: subCategories.count - 1)
            saveData()
        }
    }
    
    func addMaterial(_ material: Material) {
        materials.append(material)
        saveData()
    }
    
    func addPreset(_ preset: MaterialPreset) {
        materialPresets.append(preset)
        saveData()
    }
    
    func addPrintRecord(_ record: PrintRecord) {
        // 添加打印记录
        printRecords.append(record)
        
        // 更新对应材料的剩余重量
        if let index = materials.firstIndex(where: { $0.id == record.materialId }) {
            materials[index].remainingWeight -= record.weightUsed
            // 防止剩余克数变为负数
            if materials[index].remainingWeight < 0 {
                materials[index].remainingWeight = 0
            }
        }
        
        saveData()
    }
    
    func getTotalUsedWeight() -> Double {
        return printRecords.reduce(0) { $0 + $1.weightUsed }
    }
    
    func deleteMaterial(at indexSet: IndexSet) {
        materials.remove(atOffsets: indexSet)
        saveData()
    }

    func deleteMaterial(id: UUID) {
        materials.removeAll(where: { $0.id == id })
        saveData()
    }

    func deletePrintRecord(at indexSet: IndexSet) {
        printRecords.remove(atOffsets: indexSet)
        saveData()
    }

    func deletePrintRecord(id: UUID) {
        printRecords.removeAll(where: { $0.id == id })
        saveData()
    }

    func deletePreset(at indexSet: IndexSet) {
        // 过滤出自定义预设
        let customPresets = materialPresets.filter { preset in
            !bambuPresets.contains(where: { $0.brand == preset.brand && $0.mainCategory == preset.mainCategory && $0.subCategory == preset.subCategory }) &&
            !esunPresets.contains(where: { $0.brand == preset.brand && $0.mainCategory == preset.mainCategory && $0.subCategory == preset.subCategory }) &&
            !polymakerPresets.contains(where: { $0.brand == preset.brand && $0.mainCategory == preset.mainCategory && $0.subCategory == preset.subCategory })
        }
        
        // 只删除自定义预设
        let customIndicesToDelete = indexSet.map { idx -> Int? in
            let preset = materialPresets[idx]
            return customPresets.firstIndex(where: { $0.id == preset.id })
        }.compactMap { $0 }
        
        for index in customIndicesToDelete.sorted(by: >) {
            if let presetIndex = materialPresets.firstIndex(where: { $0.id == customPresets[index].id }) {
                materialPresets.remove(at: presetIndex)
            }
        }
        
        saveData()
    }
    func removeCustomBrand(_ brand: String) {
        if let index = brands.firstIndex(of: brand) {
            brands.remove(at: index)
            saveData()
        }
    }

    func removeCustomMainCategory(_ category: String) {
        if let index = mainCategories.firstIndex(of: category) {
            mainCategories.remove(at: index)
            saveData()
        }
    }

    func removeCustomSubCategory(_ category: String) {
        if let index = subCategories.firstIndex(of: category) {
            subCategories.remove(at: index)
            saveData()
        }
    }
    func getTotalUsedCost() -> Double {
        var totalCost: Double = 0
        
        for record in printRecords {
            totalCost += getCostForRecord(record)
        }
        
        return totalCost
    }

    func getCostForRecord(_ record: PrintRecord) -> Double {
        // 找到对应的材料
        if let material = materials.first(where: { $0.id == record.materialId }) {
            // 计算单价 = 总价 / 总重量
            let unitPrice = material.price / material.initialWeight
            // 计算成本 = 单价 * 使用量
            return unitPrice * record.weightUsed
        } else {
            // 如果找不到对应材料（可能已被删除），尝试在所有打印记录中寻找相同材料ID的记录
            if let similarRecord = printRecords.first(where: {
                $0.materialId == record.materialId && $0.id != record.id
            }), let material = materials.first(where: { $0.id == similarRecord.materialId }) {
                let unitPrice = material.price / material.initialWeight
                return unitPrice * record.weightUsed
            }
            
            // 如果还是找不到，尝试用平均单价估算
            let materialsWithPrices = materials.filter { $0.initialWeight > 0 }
            if !materialsWithPrices.isEmpty {
                let averageUnitPrice = materialsWithPrices.map { $0.price / $0.initialWeight }.reduce(0, +) / Double(materialsWithPrices.count)
                return averageUnitPrice * record.weightUsed
            }
            
            // 实在找不到任何参考价格，返回0
            return 0
        }
    }
}
