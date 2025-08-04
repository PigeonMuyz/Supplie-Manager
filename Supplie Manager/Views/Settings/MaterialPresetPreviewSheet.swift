import SwiftUI

struct MaterialPresetPreviewSheet: View {
    let preset: MaterialPreset
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 大型颜色预览
                    ZStack {
                        // 背景圆形
                        Circle()
                            .fill(
                                preset.isGradient 
                                    ? LinearGradient(
                                        colors: preset.allGradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [preset.color],
                                        startPoint: .center,
                                        endPoint: .center
                                    )
                            )
                            .frame(width: 280, height: 280)
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        
                        // 材料纹理叠加
                        MaterialTextureOverlay(subCategory: preset.subCategory)
                            .frame(width: 280, height: 280)
                            .clipShape(Circle())
                        
                        // 光泽效果
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    center: .init(x: 0.3, y: 0.3),
                                    startRadius: 10,
                                    endRadius: 140
                                )
                            )
                            .frame(width: 280, height: 280)
                    }
                    .padding(.top, 40)
                    
                    // 标题信息
                    VStack(spacing: 8) {
                        Text(preset.colorName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text(preset.brand)
                            Text("•")
                            Text(preset.mainCategory)
                            Text("•")
                            Text(preset.subCategory)
                        }
                        .font(.title2)
                        .foregroundColor(.secondary)
                    }
                    
                    // 详细信息
                    VStack(alignment: .leading, spacing: 16) {
                        Group {
                            HStack {
                                Text("品牌")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(preset.brand)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("材料类型")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(preset.mainCategory)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("子分类")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(preset.subCategory)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("颜色名称")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(preset.colorName)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("颜色代码")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(preset.colorHex.uppercased())
                                    .font(.monospaced(.body)())
                                    .foregroundColor(.secondary)
                            }
                            
                            if preset.isGradient {
                                if let gradientHex = preset.gradientColorHex {
                                    HStack {
                                        Text("渐变色代码")
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(gradientHex.uppercased())
                                            .font(.monospaced(.body)())
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let gradientColors = preset.gradientColors, !gradientColors.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("多色渐变")
                                            .fontWeight(.medium)
                                        
                                        ForEach(Array(gradientColors.enumerated()), id: \.offset) { index, colorHex in
                                            HStack {
                                                Circle()
                                                    .fill(Color(hex: colorHex) ?? .gray)
                                                    .frame(width: 20, height: 20)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(.quaternary, lineWidth: 1)
                                                    )
                                                
                                                Text("颜色 \(index + 2)")
                                                    .font(.caption)
                                                
                                                Spacer()
                                                
                                                Text(colorHex.uppercased())
                                                    .font(.monospaced(.caption)())
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("预设详情")
            .navigationBarItems(
                trailing: Button("完成") {
                    isPresented = false
                }
            )
        }
    }
}