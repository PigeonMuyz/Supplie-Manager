import SwiftUI

// 统计页面
struct SummaryView: View {
    @ObservedObject var materialStore: MaterialStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 总计卡片
                    SummaryCard(materialStore: materialStore)
                        .padding(.horizontal)
                    
                    // 按品牌分组
                    GroupBox(label: Label("按品牌统计", systemImage: "tag")) {
                        ForEach(Array(materialStore.materialsByBrand.keys), id: \.id) { brand in
                            if let materials = materialStore.materialsByBrand[brand] {
                                BrandSummaryRow(brand: brand, materials: materials)
                                if brand.id != Array(materialStore.materialsByBrand.keys).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 按颜色分组
                    GroupBox(label: Label("按颜色统计", systemImage: "paintpalette")) {
                        ForEach(Array(materialStore.materialsByColor.keys), id: \.id) { color in
                            if let materials = materialStore.materialsByColor[color] {
                                ColorSummaryRow(color: color, materials: materials)
                                if color.id != Array(materialStore.materialsByColor.keys).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("材料统计")
        }
    }
}

// 总计卡片
struct SummaryCard: View {
    @ObservedObject var materialStore: MaterialStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 15) {
            Text("总体使用情况")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(materialStore.totalMaterials)")
                        .font(.system(size: 24, weight: .bold))
                    Text("总耗材数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(String(format: "%.2f g", materialStore.totalRemainingWeight))
                        .font(.system(size: 24, weight: .bold))
                    Text("剩余重量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(String(format: "%.2f g", materialStore.totalUsedWeight))
                        .font(.system(size: 24, weight: .bold))
                    Text("已使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 5)
            
            // 使用进度条
            if materialStore.totalInitialWeight > 0 {
                let percentage = materialStore.totalUsedWeight / materialStore.totalInitialWeight * 100
                VStack(alignment: .leading) {
                    HStack {
                        Text("总体使用率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", percentage))
                            .font(.caption)
                    }
                    
                    ProgressView(value: percentage, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: 
                                                                    colorScheme == .dark ? .white : .black
                                                                  ))
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.5) : Color.gray.opacity(0.3), radius: 3)
    }
}

// 品牌汇总行
struct BrandSummaryRow: View {
    let brand: Brand
    let materials: [Material]
    
    var totalInitialWeight: Double {
        materials.reduce(0) { $0 + $1.initialWeight }
    }
    
    var totalRemainingWeight: Double {
        materials.reduce(0) { $0 + $1.remainingWeight }
    }
    
    var totalUsedWeight: Double {
        materials.reduce(0) { $0 + $1.usedWeight }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(brand.name)
                    .font(.headline)
                
                Spacer()
                
                Text("\(materials.count) 种")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("剩余重量: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f g", totalRemainingWeight))
                    .font(.subheadline)
                
                Spacer()
                
                Text("已使用: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f g", totalUsedWeight))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }
}

// 颜色汇总行
struct ColorSummaryRow: View {
    let color: MaterialColor
    let materials: [Material]
    @Environment(\.colorScheme) var colorScheme
    
    var totalInitialWeight: Double {
        materials.reduce(0) { $0 + $1.initialWeight }
    }
    
    var totalRemainingWeight: Double {
        materials.reduce(0) { $0 + $1.remainingWeight }
    }
    
    var totalUsedWeight: Double {
        materials.reduce(0) { $0 + $1.usedWeight }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color.color)
                    .overlay(
                        Circle()
                            .strokeBorder(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1)
                    )
                    .frame(width: 20, height: 20)
                
                Text(color.name)
                    .font(.headline)
                
                Spacer()
                
                Text("\(materials.count) 种")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("剩余重量: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f g", totalRemainingWeight))
                    .font(.subheadline)
                
                Spacer()
                
                Text("已使用: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f g", totalUsedWeight))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }
}
