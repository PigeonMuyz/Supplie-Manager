import SwiftUI

// 扩展 MaterialStore 以添加预设数据
extension MaterialStore {
    // 加载所有品牌的预设
    func loadAllDefaultPresets() {
        materialPresets.append(contentsOf: bambuLabPresets)
    }
    
    // Bambu Lab 预设
    var bambuLabPresets: [MaterialPreset] {
        return [
            MaterialPreset(brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "浅杏色", colorHex: "#FFE5C8"),
        ]
    }
    

}
