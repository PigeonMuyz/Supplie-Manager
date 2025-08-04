import SwiftUI
import Foundation

// JSON数据结构
struct MaterialPresetData: Codable {
    let bambuLab: [MaterialPresetJSON]?
    let esun: [MaterialPresetJSON]?
    let polymaker: [MaterialPresetJSON]?
}

struct MaterialPresetJSON: Codable {
    let brand: String
    let mainCategory: String
    let subCategory: String
    let colorName: String
    let colorHex: String
    let gradientColorHex: String? // 向后兼容二色渐变
    let gradientColors: [String]? // 多色渐变支持
}

// 扩展 MaterialStore 以添加预设数据
extension MaterialStore {
    // 加载所有品牌的预设
    func loadAllDefaultPresets() {
        loadPresetsFromJSON()
    }
    
    // 从JSON文件加载预设
    private func loadPresetsFromJSON() {
        guard let url = Bundle.main.url(forResource: "MaterialPresets", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("无法找到或读取MaterialPresets.json文件")
            // 如果JSON文件不存在，使用硬编码的备用预设
            loadFallbackPresets()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let presetData = try decoder.decode(MaterialPresetData.self, from: data)
            
            // 转换并添加所有预设
            var allPresets: [MaterialPreset] = []
            
            if let bambuPresets = presetData.bambuLab {
                allPresets.append(contentsOf: bambuPresets.map { convertToMaterialPreset($0) })
            }
            
            if let esunPresets = presetData.esun {
                allPresets.append(contentsOf: esunPresets.map { convertToMaterialPreset($0) })
            }
            
            if let polymakerPresets = presetData.polymaker {
                allPresets.append(contentsOf: polymakerPresets.map { convertToMaterialPreset($0) })
            }
            
            materialPresets.append(contentsOf: allPresets)
            print("成功从JSON加载了 \(allPresets.count) 个预设")
            
        } catch {
            print("解析JSON文件失败: \(error)")
            loadFallbackPresets()
        }
    }
    
    // 将JSON预设转换为MaterialPreset
    private func convertToMaterialPreset(_ jsonPreset: MaterialPresetJSON) -> MaterialPreset {
        return MaterialPreset(
            brand: jsonPreset.brand,
            mainCategory: jsonPreset.mainCategory,
            subCategory: jsonPreset.subCategory,
            colorName: jsonPreset.colorName,
            colorHex: jsonPreset.colorHex,
            gradientColorHex: jsonPreset.gradientColorHex,
            gradientColors: jsonPreset.gradientColors
        )
    }
    
    // 备用预设（如果JSON加载失败）
    private func loadFallbackPresets() {
        let fallbackPresets = [
            MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "白色", colorHex: "#FFFFFF"),
            MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "黑色", colorHex: "#000000"),
            MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Gradient", colorName: "日落渐变", colorHex: "#FF6B35", gradientColorHex: "#F7931E")
        ]
        materialPresets.append(contentsOf: fallbackPresets)
        print("使用备用预设，加载了 \(fallbackPresets.count) 个预设")
    }

}
