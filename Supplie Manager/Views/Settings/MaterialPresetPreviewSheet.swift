import SwiftUI

struct MaterialPresetPreviewSheet: View {
    let preset: MaterialPreset
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
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
                    .font(.headline)
                    .foregroundColor(.secondary)
                }
                
                // 颜色预览区域
                VStack(spacing: 20) {
                    // 大尺寸颜色预览
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            preset.isGradient
                                ? LinearGradient(
                                    colors: preset.allGradientColors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [preset.color],
                                    startPoint: .center,
                                    endPoint: .center
                                )
                        )
                        .frame(width: 280, height: 280)
                        .overlay(
                            // 添加纹理效果
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.clear)
                                .overlay(
                                    MaterialTextureOverlay(subCategory: preset.subCategory)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    // 颜色信息
                    VStack(spacing: 12) {
                        if preset.isGradient {
                            VStack(spacing: 8) {
                                Text("渐变色")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 16) {
                                    ForEach(Array(preset.allGradientColors.enumerated()), id: \.offset) { index, color in
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 30, height: 30)
                                                .overlay(
                                                    Circle()
                                                        .stroke(.quaternary, lineWidth: 1)
                                                )
                                            
                                            Text("#\(index + 1)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 8) {
                                Text("单色")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(preset.colorHex.uppercased())
                                    .font(.monospaced(.body)())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("颜色预览")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("完成") {
                    isPresented = false
                }
            )
        }
    }
}