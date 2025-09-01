import SwiftUI
import SceneKit
import UniformTypeIdentifiers
import UIKit

struct ThreeMFPreviewView: View {
    @StateObject private var parser = OptimizedThreeMFParser()
    @State private var showingFilePicker = false
    @State private var selectedPartIndex = 0
    @State private var previewMode: PreviewMode = .boundingBox
    @State private var fileURL: URL?
    
    enum PreviewMode: String, CaseIterable {
        case boundingBox = "边界框"
        case simplified = "简化模型"
        
        var icon: String {
            switch self {
            case .boundingBox: return "cube"
            case .simplified: return "cube.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if parser.metadata != nil {
                    // 预览模式选择器
                    Picker("预览模式", selection: $previewMode) {
                        ForEach(PreviewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // 3D预览区域
                    ModelSceneView(
                        parser: parser,
                        selectedPartIndex: $selectedPartIndex,
                        previewMode: previewMode
                    )
                    .frame(height: 300)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    
                    // 模型信息
                    ModelInfoView(parser: parser, selectedPartIndex: $selectedPartIndex)
                    
                    Spacer()
                } else {
                    // 空状态 - 等待文件选择
                    EmptyStateView(showingFilePicker: $showingFilePicker)
                }
                
                // 底部按钮
                Button(action: {
                    showingFilePicker = true
                }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text(parser.metadata == nil ? "选择3MF文件" : "更换文件")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("3MF预览器")
            .navigationBarTitleDisplayMode(.large)
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "3mf") ?? UTType.data],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleFileSelection(result: result)
                }
            }
            .overlay {
                if parser.isLoading {
                    LoadingOverlay()
                }
            }
            .alert("解析错误", isPresented: .constant(parser.errorMessage != nil)) {
                Button("确定") {
                    parser.errorMessage = nil
                }
            } message: {
                Text(parser.errorMessage ?? "")
            }
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // 获取文件访问权限
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // 保存URL供后续使用
            fileURL = url
            
            // 解析3MF文件元数据
            await parser.parseMetadata(from: url)
            
            await MainActor.run {
                selectedPartIndex = 0
            }
            
        case .failure(let error):
            await MainActor.run {
                parser.errorMessage = "文件选择失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 优化的场景视图

struct ModelSceneView: UIViewRepresentable {
    let parser: OptimizedThreeMFParser
    @Binding var selectedPartIndex: Int
    let previewMode: ThreeMFPreviewView.PreviewMode
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.systemGray6
        sceneView.antialiasingMode = .multisampling2X
        
        // 创建场景
        let scene = SCNScene()
        sceneView.scene = scene
        
        // 设置相机
        setupCamera(scene: scene)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 当选中的部件或预览模式改变时，更新场景
        if let scene = uiView.scene {
            updateScene(scene: scene)
        }
    }
    
    private func setupCamera(scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 10, z: 30)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func updateScene(scene: SCNScene) {
        // 清除现有几何节点
        scene.rootNode.childNodes
            .filter { $0.name == "model_part" }
            .forEach { $0.removeFromParentNode() }
        
        // 确保有部件可显示
        guard selectedPartIndex < parser.parts.count else { return }
        
        let selectedPart = parser.parts[selectedPartIndex]
        
        // 根据预览模式创建节点
        let node: SCNNode
        switch previewMode {
        case .boundingBox:
            // 使用边界框预览（内存高效）
            node = parser.generateBoundingBoxPreview(for: selectedPart)
        case .simplified:
            // 尝试生成简化预览
            if let detailedNode = parser.generatePreview(for: selectedPart.id, simplificationLevel: 0.3) {
                node = detailedNode
            } else {
                // 如果失败，回退到边界框
                node = parser.generateBoundingBoxPreview(for: selectedPart)
            }
        }
        
        node.name = "model_part"
        
        // 自动调整相机以适应模型
        if let bounds = selectedPart.bounds {
            let center = SCNVector3(
                (bounds.min.x + bounds.max.x) / 2,
                (bounds.min.y + bounds.max.y) / 2,
                (bounds.min.z + bounds.max.z) / 2
            )
            
            let size = max(
                bounds.max.x - bounds.min.x,
                bounds.max.y - bounds.min.y,
                bounds.max.z - bounds.min.z
            )
            
            // 设置相机位置
            if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
                cameraNode.position = SCNVector3(
                    center.x,
                    center.y + size,
                    center.z + size * 2
                )
                cameraNode.look(at: center)
            }
        }
        
        scene.rootNode.addChildNode(node)
        
        // 添加光照
        setupLighting(scene: scene)
    }
    
    private func setupLighting(scene: SCNScene) {
        // 移除旧的光照
        scene.rootNode.childNodes
            .filter { $0.light != nil }
            .forEach { $0.removeFromParentNode() }
        
        // 添加环境光
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 500
        ambientLight.color = UIColor.white
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // 添加方向光
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 1000
        directionalLight.castsShadow = true
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        lightNode.position = SCNVector3(10, 10, 10)
        lightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(lightNode)
    }
}

// MARK: - 优化的信息视图

struct ModelInfoView: View {
    let parser: OptimizedThreeMFParser
    @Binding var selectedPartIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 文件信息
            if let metadata = parser.metadata {
                VStack(alignment: .leading, spacing: 4) {
                    Text("文件信息")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.blue)
                        Text("文件大小: \(formatFileSize(metadata.fileSize))")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundColor(.orange)
                        Text("部件数: \(metadata.partCount)")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "triangle.fill")
                            .foregroundColor(.green)
                        Text("总三角形: \(formatNumber(metadata.totalTriangles))")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // 零件选择器和信息
            VStack(alignment: .leading, spacing: 8) {
                Text("零件信息")
                    .font(.headline)
                
                if parser.parts.count > 1 {
                    Picker("选择零件", selection: $selectedPartIndex) {
                        ForEach(0..<parser.parts.count, id: \.self) { index in
                            Text(parser.parts[index].name)
                                .tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                
                // 当前零件详情
                if selectedPartIndex < parser.parts.count {
                    let currentPart = parser.parts[selectedPartIndex]
                    VStack(alignment: .leading, spacing: 4) {
                        Label(currentPart.name, systemImage: "cube")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text("顶点: \(formatNumber(currentPart.vertexCount))")
                            Spacer()
                            Text("三角形: \(formatNumber(currentPart.triangleCount))")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        if let bounds = currentPart.bounds {
                            Text("尺寸: \(formatBounds(bounds))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if let materialId = currentPart.materialId,
                           let material = parser.materials[materialId] {
                            HStack {
                                if let color = material.displayColor {
                                    Circle()
                                        .fill(Color(color))
                                        .frame(width: 12, height: 12)
                                }
                                Text("材料: \(material.name ?? materialId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
    
    private func formatBounds(_ bounds: (min: SCNVector3, max: SCNVector3)) -> String {
        let width = bounds.max.x - bounds.min.x
        let height = bounds.max.y - bounds.min.y
        let depth = bounds.max.z - bounds.min.z
        return String(format: "%.1f × %.1f × %.1f", width, height, depth)
    }
}

struct EmptyStateView: View {
    @Binding var showingFilePicker: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("暂无3MF文件")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("选择一个3MF文件来预览3D模型")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showingFilePicker = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("选择文件")
                }
                .font(.headline)
                .foregroundColor(.blue)
            }
        }
        .padding(40)
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("正在解析3MF文件...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
    }
}

struct ThreeMFPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ThreeMFPreviewView()
    }
}