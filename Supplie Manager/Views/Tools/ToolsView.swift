import SwiftUI

struct ToolsView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 3D模型工具分组
                    ToolSectionView(title: "3D模型工具", icon: "cube") {
                        ToolCardView(
                            title: "预览3MF",
                            description: "查看和分析3MF文件中的3D模型",
                            icon: "cube.transparent",
                            color: .blue
                        ) {
                            ThreeMFPreviewView()
                        }
                    }
                    
                    // 未来的工具分组预留位置
                    ToolSectionView(title: "材料工具", icon: "paintbrush") {
                        // 预留位置：材料计算器、成本分析等
                        PlaceholderToolCard(
                            title: "材料计算器",
                            description: "即将推出",
                            icon: "calculator"
                        )
                        
                        PlaceholderToolCard(
                            title: "成本分析",
                            description: "即将推出", 
                            icon: "chart.line.uptrend.xyaxis"
                        )
                    }
                    
                    ToolSectionView(title: "打印工具", icon: "printer") {
                        PlaceholderToolCard(
                            title: "切片设置优化",
                            description: "即将推出",
                            icon: "slider.horizontal.3"
                        )
                        
                        PlaceholderToolCard(
                            title: "支撑生成器",
                            description: "即将推出",
                            icon: "building.columns"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("工具")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 工具分组视图
struct ToolSectionView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                content
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 工具卡片视图
struct ToolCardView<Destination: View>: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    @ViewBuilder let destination: () -> Destination
    
    var body: some View {
        NavigationLink(destination: destination()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .frame(height: 120)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 占位符工具卡片
struct PlaceholderToolCard: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.gray)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(description)
                    .font(.caption) 
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .disabled(true)
    }
}

struct ToolsView_Previews: PreviewProvider {
    static var previews: some View {
        ToolsView()
    }
}