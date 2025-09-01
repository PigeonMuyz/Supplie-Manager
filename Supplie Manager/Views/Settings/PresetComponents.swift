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
            case "fluor", "translucent":
                TranslucentTextureView()
            default:
                EmptyView()
            }
        }
    }
}

struct SilkTextureView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let spacing: CGFloat = 8
                
                // 创建对角线条纹
                for i in stride(from: -height, through: width + height, by: spacing) {
                    path.move(to: CGPoint(x: i, y: 0))
                    path.addLine(to: CGPoint(x: i + height, y: height))
                }
            }
            .stroke(Color.white.opacity(0.15), lineWidth: 1)
            
            // 添加更细的交叉纹理
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let spacing: CGFloat = 16
                
                for i in stride(from: -height, through: width + height, by: spacing) {
                    path.move(to: CGPoint(x: i, y: height))
                    path.addLine(to: CGPoint(x: i + height, y: 0))
                }
            }
            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

struct MatteTextureView: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                
                // 创建随机点阵营造哑光效果
                for _ in 0..<Int(width * height / 40) {
                    let x = Double.random(in: 0...width)
                    let y = Double.random(in: 0...height)
                    let opacity = Double.random(in: 0.05...0.15)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

struct MetalTextureView: View {
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.3), location: 0.0),
                    .init(color: Color.clear, location: 0.1),
                    .init(color: Color.white.opacity(0.1), location: 0.2),
                    .init(color: Color.clear, location: 0.3),
                    .init(color: Color.white.opacity(0.2), location: 0.4),
                    .init(color: Color.clear, location: 0.6),
                    .init(color: Color.white.opacity(0.1), location: 0.8),
                    .init(color: Color.clear, location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct WoodTextureView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // 创建木纹效果
                for i in stride(from: 0, through: height, by: 15) {
                    let y = CGFloat(i)
                    path.move(to: CGPoint(x: 0, y: y))
                    
                    // 创建波浪形木纹
                    for x in stride(from: 0, through: width, by: 10) {
                        let waveY = y + sin(x / 20) * 2
                        path.addLine(to: CGPoint(x: x, y: waveY))
                    }
                }
            }
            .stroke(Color.brown.opacity(0.2), lineWidth: 1)
        }
    }
}

struct TranslucentTextureView: View {
    var body: some View {
        RadialGradient(
            stops: [
                .init(color: Color.white.opacity(0.4), location: 0.0),
                .init(color: Color.white.opacity(0.1), location: 0.4),
                .init(color: Color.clear, location: 0.7),
                .init(color: Color.white.opacity(0.2), location: 1.0)
            ],
            center: .center,
            startRadius: 20,
            endRadius: 140
        )
    }
}

struct GradientTextureView: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.3), location: animateGradient ? 0.0 : 0.3),
                .init(color: Color.clear, location: animateGradient ? 0.3 : 0.5),
                .init(color: Color.white.opacity(0.2), location: animateGradient ? 0.7 : 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

struct SparkleTextureView: View {
    @State private var sparkleOpacity: [Double] = []
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                
                if sparkleOpacity.isEmpty {
                    sparkleOpacity = (0..<50).map { _ in Double.random(in: 0.1...0.8) }
                }
                
                // 创建闪烁点
                for (_, opacity) in sparkleOpacity.enumerated() {
                    let x = Double.random(in: 0...width)
                    let y = Double.random(in: 0...height)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                    sparkleOpacity = sparkleOpacity.map { _ in Double.random(in: 0.1...0.8) }
                }
            }
        }
    }
}