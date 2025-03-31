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
            MaterialPreset(
                brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Basic", colorName: "浅杏色",
                colorHex: "#FFE5C8"),
            MaterialPreset(
                brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Lite", colorName: "白色",
                colorHex: "#FFFFFF"),
            MaterialPreset(
                brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Lite", colorName: "灰色",
                colorHex: "#999D9D"),
            MaterialPreset(
                brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Lite", colorName: "天蓝色",
                colorHex: "#4DAFDA"),
            MaterialPreset(
                brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Lite", colorName: "黄色",
                colorHex: "#EFE255"),
            MaterialPreset(
                brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Lite", colorName: "红色",
                colorHex: "#C6001A"),
            MaterialPreset(
                brand: "Bambu Lab", mainCategory: "PLA", subCategory: "Lite", colorName: "黑色",
                colorHex: "#000000"),
        ]
    }

}
