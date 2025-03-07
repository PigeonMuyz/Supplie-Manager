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
    private let defaultBrands = ["Bambu Lab", "eSUN", "Polymaker", "Prusa", "Creality", "Sunlu", "Overture"]
    private let defaultMainCategories = ["PLA", "PETG", "ABS", "TPU", "ASA", "PC", "Nylon", "PVA"]
    private let defaultSubCategories = ["无", "Matte", "Basic", "Silk", "Fluor", "Metal", "Wood", "CF"]
    
    // 自定义选项
    @Published var customBrands: [String] = []
    @Published var customMainCategories: [String] = []
    @Published var customSubCategories: [String] = []
    
    // 计算属性：品牌列表
    var brands: [String] {
        var result = defaultBrands + customBrands
        result.append("自定义")
        return result
    }
    
    // 计算属性：主分类列表
    var mainCategories: [String] {
        var result = defaultMainCategories + customMainCategories
        result.append("自定义")
        return result
    }
    
    // 计算属性：子分类列表 - 从预设中动态获取所有唯一的子分类
    var subCategories: [String] {
        // 从预设中获取所有子分类并去重
        var uniqueSubCategories = Set<String>(["无"])
        
        // 添加默认子分类
        for category in defaultSubCategories {
            uniqueSubCategories.insert(category)
        }
        
        // 从预设中添加所有存在的子分类
        for preset in materialPresets {
            if !preset.subCategory.isEmpty && preset.subCategory != "无" {
                uniqueSubCategories.insert(preset.subCategory)
            }
        }
        
        // 添加自定义子分类
        for category in customSubCategories {
            uniqueSubCategories.insert(category)
        }
        
        // 转换为排序的数组并添加"自定义"选项
        var result = Array(uniqueSubCategories).sorted()
        if !result.contains("自定义") {
            result.append("自定义")
        }
        
        return result
    }
    // 修改 MaterialStore 内的预设数据
    private let bambuPresets: [MaterialPreset] = [
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "白色", colorHex: "#FFFFFF"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "杏色", colorHex: "#F7E6DE"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "金色", colorHex: "#E4BD68"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "银色", colorHex: "#A6A9AA"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "灰色", colorHex: "#8E9089"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "青铜色", colorHex: "#847D48"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "棕色", colorHex: "#9D432C"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "红色", colorHex: "#C12E1F"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "品红色", colorHex: "#EC008C"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "粉色", colorHex: "#F55A74"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "橙色", colorHex: "#FF6A13"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "黄色", colorHex: "#F4EE2A"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "拓竹绿", colorHex: "#00AE42"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "墨绿色", colorHex: "#164B35"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "青色", colorHex: "#0086D6"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "深蓝色", colorHex: "#0A2989"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "蓝紫色", colorHex: "#5E43B7"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "灰蓝色", colorHex: "#5B6579"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "黑色", colorHex: "#FFFFFF"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "浅灰色", colorHex: "#D1D3D5"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "暖黄色", colorHex: "#FEC600"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "苹果绿色", colorHex: "#BECF00"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "南瓜橙色", colorHex: "#FF9016"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "桃红色", colorHex: "#F5547C"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "松石绿色", colorHex: "#00B1B7"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "钴蓝色", colorHex: "#0056B8"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "深灰色", colorHex: "#545454"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "可可棕色", colorHex: "#6F5034"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "胭脂红色", colorHex: "#9D2235"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "绀紫色", colorHex: "#482960"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "象牙白", colorHex: "#FFFFFF"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "骨白色", colorHex: "#CBC6B8"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "拿铁褐", colorHex: "#D3B7A7"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "岩石灰", colorHex: "#9B9EA0"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "枪灰色", colorHex: "#757575"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "丁香紫", colorHex: "#AE96D4"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "樱花粉", colorHex: "#E8AFCF"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "柠檬黄", colorHex: "#F7D959"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "沙漠黄", colorHex: "#E8DBB7"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "橘橙色", colorHex: "#F99963"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "猩红色", colorHex: "#DE4343"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "暗夜红", colorHex: "#BB3D43"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "莓果紫", colorHex: "#950051"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "砖红色", colorHex: "#B15533"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "深棕色", colorHex: "#4D3324"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "暗夜棕", colorHex: "#7D6556"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "沙棕色", colorHex: "#AE835B"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "暗夜绿", colorHex: "#68724D"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "草绿色", colorHex: "#61C680"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "果绿色", colorHex: "#C2E189"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "冰蓝色", colorHex: "#A3D8E1"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "天蓝色", colorHex: "#56B7E6"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "海蓝色", colorHex: "#0078BF"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "暗夜蓝", colorHex: "#042F56"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Matte", colorName: "炭黑色", colorHex: "#000000"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PETG", subCategory: "Translucent", colorName: "粉色", colorHex: "#F9C1BD"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PETG", subCategory: "Translucent", colorName: "紫色", colorHex: "#D6ABFF"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PETG", subCategory: "Translucent", colorName: "浅绿色", colorHex: "#77EDD7"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PETG", subCategory: "Translucent", colorName: "浅蓝色", colorHex: "#61B0FF"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PETG", subCategory: "Translucent", colorName: "橘色", colorHex: "#FF911A"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PETG", subCategory: "Translucent", colorName: "灰色", colorHex: "#8E8E8E"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PETG", subCategory: "Translucent", colorName: "茶色", colorHex: "#C9A381"),
        MaterialPreset(brand: "Bambu Lab", mainCategory: "PETG", subCategory: "Translucent", colorName: "橄榄绿", colorHex: "#748C45"),
    ]
    
    // eSun常见预设
    private let esunPresets: [MaterialPreset] = [
        MaterialPreset(brand: "eSUN", mainCategory: "PLA", subCategory: "Plus", colorName: "标准白", colorHex: "#FFFFFF"),
        MaterialPreset(brand: "eSUN", mainCategory: "PETG", subCategory: "Basic", colorName: "标准黑", colorHex: "#000000"),
        MaterialPreset(brand: "eSUN", mainCategory: "ABS", subCategory: "Plus", colorName: "标准红", colorHex: "#FF0000"),
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
        loadAllDefaultPresets()
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
        if let savedCustomBrands = UserDefaults.standard.stringArray(forKey: "customBrands") {
            customBrands = savedCustomBrands
        }
        
        if let savedCustomMainCategories = UserDefaults.standard.stringArray(forKey: "customMainCategories") {
            customMainCategories = savedCustomMainCategories
        }
        
        if let savedCustomSubCategories = UserDefaults.standard.stringArray(forKey: "customSubCategories") {
            customSubCategories = savedCustomSubCategories
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
        UserDefaults.standard.set(customBrands, forKey: "customBrands")
        UserDefaults.standard.set(customMainCategories, forKey: "customMainCategories")
        UserDefaults.standard.set(customSubCategories, forKey: "customSubCategories")
    }
    
    func addCustomBrand(_ brand: String) {
        if !brand.isEmpty && !customBrands.contains(brand) {
            customBrands.append(brand)
            saveData()
        }
    }
    
    func addCustomMainCategory(_ category: String) {
        if !category.isEmpty && !customMainCategories.contains(category) {
            customMainCategories.append(category)
            saveData()
        }
    }
    
    func addCustomSubCategory(_ category: String) {
        if !category.isEmpty && !customSubCategories.contains(category) {
            customSubCategories.append(category)
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
        // 处理每条要删除的记录
        for index in indexSet {
            let recordToDelete = printRecords[index]
            
            // 更新对应材料的剩余重量
            if let materialIndex = materials.firstIndex(where: { $0.id == recordToDelete.materialId }) {
                materials[materialIndex].remainingWeight += recordToDelete.weightUsed
                
                // 确保剩余重量不超过初始重量
                if materials[materialIndex].remainingWeight > materials[materialIndex].initialWeight {
                    materials[materialIndex].remainingWeight = materials[materialIndex].initialWeight
                }
            }
        }
        
        // 删除选中的记录
        printRecords.remove(atOffsets: indexSet)
        saveData()
    }
    
    func deletePrintRecord(id: UUID) {
        // 找到要删除的记录
        if let recordToDelete = printRecords.first(where: { $0.id == id }) {
            // 更新对应材料的剩余重量（将已使用的重量加回去）
            if let materialIndex = materials.firstIndex(where: { $0.id == recordToDelete.materialId }) {
                materials[materialIndex].remainingWeight += recordToDelete.weightUsed
                
                // 确保剩余重量不超过初始重量
                if materials[materialIndex].remainingWeight > materials[materialIndex].initialWeight {
                    materials[materialIndex].remainingWeight = materials[materialIndex].initialWeight
                }
            }
            
            // 删除记录
            printRecords.removeAll(where: { $0.id == id })
            saveData()
        }
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
        if let index = customBrands.firstIndex(of: brand) {
            customBrands.remove(at: index)
            saveData()
        }
    }
    
    func removeCustomMainCategory(_ category: String) {
        if let index = customMainCategories.firstIndex(of: category) {
            customMainCategories.remove(at: index)
            saveData()
        }
    }
    
    func removeCustomSubCategory(_ category: String) {
        if let index = customSubCategories.firstIndex(of: category) {
            customSubCategories.remove(at: index)
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
    
    func markMaterialAsEmpty(id: UUID) {
        if let index = materials.firstIndex(where: { $0.id == id }) {
            // 将剩余量设为 0
            materials[index].remainingWeight = 0
            saveData()
        }
    }
}
