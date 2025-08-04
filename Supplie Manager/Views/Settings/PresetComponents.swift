import SwiftUI

// MARK: - Preset Management Support Components

struct BrandPresetSection: View {
    let brandPresets: [MaterialPreset]
    let store: MaterialStore
    @Binding var previewPreset: MaterialPreset?
    @Binding var showingPreview: Bool
    
    var body: some View {
        // 在每个品牌下按材料类型（主分类）分组
        ForEach(Array(Dictionary(grouping: brandPresets, by: { $0.mainCategory }).sorted(by: { $0.key < $1.key })), id: \.key) { mainCategory, categoryPresets in
            DisclosureGroup(mainCategory) {
                MainCategorySection(
                    categoryPresets: categoryPresets,
                    store: store,
                    previewPreset: $previewPreset,
                    showingPreview: $showingPreview
                )
            }
        }
    }
}

struct MainCategorySection: View {
    let categoryPresets: [MaterialPreset]
    let store: MaterialStore
    @Binding var previewPreset: MaterialPreset?
    @Binding var showingPreview: Bool
    
    var body: some View {
        // 在每个材料类型下按细分类型分组
        ForEach(Array(Dictionary(grouping: categoryPresets, by: { $0.subCategory }).sorted(by: { $0.key < $1.key })), id: \.key) { subCategory, subCategoryPresets in
            DisclosureGroup(subCategory) {
                SubCategorySection(
                    subCategoryPresets: subCategoryPresets,
                    store: store,
                    previewPreset: $previewPreset,
                    showingPreview: $showingPreview
                )
            }
        }
    }
}

struct SubCategorySection: View {
    let subCategoryPresets: [MaterialPreset]
    let store: MaterialStore
    @Binding var previewPreset: MaterialPreset?
    @Binding var showingPreview: Bool
    
    var body: some View {
        // 显示该细分类型下的所有颜色预设
        ForEach(subCategoryPresets) { preset in
            PresetRowView(
                preset: preset,
                store: store,
                previewPreset: $previewPreset,
                showingPreview: $showingPreview
            )
        }
    }
}

struct PresetRowView: View {
    let preset: MaterialPreset
    let store: MaterialStore
    @Binding var previewPreset: MaterialPreset?
    @Binding var showingPreview: Bool
    
    var body: some View {
        HStack {
            MaterialPresetColorView(preset: preset, size: 20, strokeWidth: 1)
            
            Text(preset.colorName)
                .font(.body)
        }
        .padding(.leading, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            previewPreset = preset
        }
        .onChange(of: previewPreset) {
            if previewPreset != nil {
                showingPreview = true
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let index = store.materialPresets.firstIndex(where: { $0.id == preset.id }) {
                    store.deletePreset(at: IndexSet([index]))
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Material Texture Overlays

struct MaterialTextureOverlay: View {
    let subCategory: String
    
    var body: some View {
        Group {
            switch subCategory.lowercased() {
            case "silk":
                SilkTextureView()
            case "matte":
                MatteTextureView()
            case "metal":
                MetalTextureView()
            case "wood":
                WoodTextureView()
            case "gradient":
                GradientTextureView()
            case "fluor":
                TranslucentTextureView()
            default:
                EmptyView()
            }
        }
    }
}

struct SilkTextureView: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // 绘制丝绸光泽效果
            for i in stride(from: 0, to: width, by: 3) {
                let x = i + sin(i / 5) * 2
                let opacity = 0.05 + sin(i / 10) * 0.03
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + height, y: height))
                    },
                    with: .color(Color.white.opacity(opacity)),
                    lineWidth: 1
                )
            }
            
            // 添加高光条纹
            for i in stride(from: 0, to: height, by: 8) {
                context.fill(
                    Path(ellipseIn: CGRect(x: 0, y: i, width: width, height: 1)),
                    with: .color(.white.opacity(0.075))
                )
            }
        }
    }
}

struct MatteTextureView: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // 绘制磨砂纹理
            for _ in 0..<Int(width * height / 4) {
                let x = Double.random(in: 0...width)
                let y = Double.random(in: 0...height)
                let opacity = Double.random(in: 0.02...0.08)
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 0.5, height: 0.5)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
    }
}

struct MetalTextureView: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // 绘制金属反光效果
            for i in stride(from: 0, to: width, by: 2) {
                let x = i
                let opacity = 0.03 + sin(i / 8) * 0.05
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    },
                    with: .color(Color.white.opacity(opacity)),
                    lineWidth: 0.5
                )
            }
        }
    }
}

struct WoodTextureView: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // 绘制木纹效果
            for i in stride(from: 0, to: height, by: 4) {
                let y = i + sin(i / 6) * 1.5
                let opacity = 0.04 + sin(i / 12) * 0.02
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addCurve(
                            to: CGPoint(x: width, y: y + sin(width / 15) * 2),
                            control1: CGPoint(x: width * 0.3, y: y - 1),
                            control2: CGPoint(x: width * 0.7, y: y + 1)
                        )
                    },
                    with: .color(Color.brown.opacity(opacity)),
                    lineWidth: 1
                )
            }
        }
    }
}

struct TranslucentTextureView: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // 绘制荧光/半透明效果
            context.fill(
                Path(ellipseIn: CGRect(x: 0, y: 0, width: width, height: height)),
                with: .color(.white.opacity(0.15))
            )
        }
    }
}

struct GradientTextureView: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // 绘制闪粉效果
            for _ in 0..<Int(width * height / 8) {
                let x = Double.random(in: 0...width)
                let y = Double.random(in: 0...height)
                let opacity = Double.random(in: 0.1...0.3)
                let sparkleSize = Double.random(in: 0.5...2)
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: sparkleSize, height: sparkleSize)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
    }
}

struct SparkleTextureView: View {
    @State private var animationOffset: Double = 0
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // 绘制动态闪粉效果
            for i in 0..<Int(width * height / 10) {
                let baseX = Double(i % Int(width))
                let baseY = Double(i / Int(width))
                let x = baseX + sin(animationOffset + baseX / 10) * 2
                let y = baseY + cos(animationOffset + baseY / 10) * 2
                let opacity = 0.1 + sin(animationOffset + Double(i) / 5) * 0.2
                let sparkleSize = 1 + sin(animationOffset + Double(i) / 3) * 0.5
                
                if x >= 0 && x <= width && y >= 0 && y <= height {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: sparkleSize, height: sparkleSize)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                animationOffset = .pi * 2
            }
        }
    }
}