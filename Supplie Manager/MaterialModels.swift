import SwiftUI

// 材料数据模型
struct Material: Identifiable, Codable {
    var id = UUID()
    // 品牌，例：Bambu Lab
    var brand: String
    // 主分类，例：PLA
    var mainCategory: String
    // 子分类，例：Basic
    var subCategory: String
    // 颜色名称，例：樱花粉
    var name: String
    var purchaseDate: Date
    var price: Double
    var initialWeight: Double  // 以克为单位
    var remainingWeight: Double  // 以克为单位
    var colorHex: String
    var gradientColorHex: String? // 渐变色的第二个颜色，如果为nil则不是渐变色
    var gradientColors: [String]? // 多色渐变支持，包含所有渐变颜色
    var shortCode: String?
    
    // 带标识的显示名称（用于区分）例：PLA Basic 樱花粉(Bambu Lab-咕咕1号)
    var displayNameWithId: String {
        if let code = shortCode, !code.isEmpty {
            return "\(mainCategory) \(subCategory) \(name)(\(brand)-\(code))"
        } else {
            return "\(mainCategory) \(subCategory) \(name)(\(brand)-\(id.uuidString.prefix(4)))"
        }
    }
    
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
    
    // 判断是否为渐变色
    var isGradient: Bool {
        return gradientColorHex != nil || (gradientColors != nil && !gradientColors!.isEmpty)
    }
    
    // 判断是否为多色渐变（超过2色）
    var isMultiColorGradient: Bool {
        return gradientColors != nil && gradientColors!.count > 0
    }
    
    // 获取所有渐变颜色（包括主色）
    var allGradientColors: [Color] {
        var colors = [color]
        
        if let multiColors = gradientColors {
            colors.append(contentsOf: multiColors.compactMap { Color(hex: $0) })
        } else if let gradientHex = gradientColorHex {
            colors.append(Color(hex: gradientHex) ?? .gray)
        }
        
        return colors
    }
    
    // 获取渐变色的第二个颜色（向后兼容）
    var gradientColor: Color? {
        if let multiColors = gradientColors, !multiColors.isEmpty {
            return Color(hex: multiColors[0])
        } else if let gradientHex = gradientColorHex {
            return Color(hex: gradientHex)
        }
        return nil
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
    var gradientColorHex: String? // 渐变色的第二个颜色，如果为nil则不是渐变色
    var gradientColors: [String]? // 多色渐变支持，包含所有渐变颜色
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    // 判断是否为渐变色
    var isGradient: Bool {
        return gradientColorHex != nil || (gradientColors != nil && !gradientColors!.isEmpty)
    }
    
    // 判断是否为多色渐变（超过2色）
    var isMultiColorGradient: Bool {
        return gradientColors != nil && gradientColors!.count > 0
    }
    
    // 获取所有渐变颜色（包括主色）
    var allGradientColors: [Color] {
        var colors = [color]
        
        if let multiColors = gradientColors {
            colors.append(contentsOf: multiColors.compactMap { Color(hex: $0) })
        } else if let gradientHex = gradientColorHex {
            colors.append(Color(hex: gradientHex) ?? .gray)
        }
        
        return colors
    }
    
    // 获取渐变色的第二个颜色（向后兼容）
    var gradientColor: Color? {
        if let multiColors = gradientColors, !multiColors.isEmpty {
            return Color(hex: multiColors[0])
        } else if let gradientHex = gradientColorHex {
            return Color(hex: gradientHex)
        }
        return nil
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
    private let defaultSubCategories = ["无", "Matte", "Basic", "Silk", "Fluor", "Metal", "Wood", "CF", "Gradient"]
    
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
    
    init() {
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
            // 添加自定义预设（从JSON加载的预设已经在loadAllDefaultPresets中加载）
            materialPresets.append(contentsOf: decodedPresets)
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
        
        // 只保存用户自定义添加的预设，JSON中的默认预设不需要保存
        let customPresets = materialPresets.filter { preset in
            // 这里需要根据实际情况判断哪些是自定义预设
            // 暂时保存所有预设，因为无法准确区分JSON预设和自定义预设
            true
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
    
    func getTotalConsumedWeight() -> Double {
        // 计算所有材料的已消耗重量 (初始重量 - 剩余重量)
        return materials.reduce(0) { $0 + ($1.initialWeight - $1.remainingWeight) }
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
        // 注意：删除预设时需要谨慎，确保不删除JSON中加载的默认预设
        // 目前暂时允许删除所有预设，可根据需要进一步限制
        materialPresets.remove(atOffsets: indexSet)
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
    
    func getTotalConsumedCost() -> Double {
        var totalCost: Double = 0
        
        for material in materials {
            // 计算已消耗部分的成本
            let consumedWeight = material.initialWeight - material.remainingWeight
            let unitPrice = material.price / material.initialWeight
            totalCost += unitPrice * consumedWeight
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

// MARK: - 颜色显示组件
import SwiftUI

// 通用的材料颜色显示组件，支持单色和渐变色
struct MaterialColorView: View {
    let material: Material
    let size: CGFloat
    let strokeWidth: CGFloat
    
    init(material: Material, size: CGFloat = 20, strokeWidth: CGFloat = 1) {
        self.material = material
        self.size = size
        self.strokeWidth = strokeWidth
    }
    
    var body: some View {
        Circle()
            .fill(
                material.isGradient 
                    ? LinearGradient(
                        colors: material.allGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(colors: [material.color], startPoint: .center, endPoint: .center)
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(.quaternary, lineWidth: strokeWidth)
            )
    }
}

// 通用的材料预设颜色显示组件，支持单色和渐变色
struct MaterialPresetColorView: View {
    let preset: MaterialPreset
    let size: CGFloat
    let strokeWidth: CGFloat
    
    init(preset: MaterialPreset, size: CGFloat = 20, strokeWidth: CGFloat = 1) {
        self.preset = preset
        self.size = size
        self.strokeWidth = strokeWidth
    }
    
    var body: some View {
        Circle()
            .fill(
                preset.isGradient 
                    ? LinearGradient(
                        colors: preset.allGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(colors: [preset.color], startPoint: .center, endPoint: .center)
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(.quaternary, lineWidth: strokeWidth)
            )
    }
}
