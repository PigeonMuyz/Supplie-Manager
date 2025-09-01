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
            ScrollView {  // 添加ScrollView以支持滑动
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
                        .frame(height: 350)  // 稍微增加高度
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                        
                        // 模型信息
                        ModelInfoView(parser: parser, selectedPartIndex: $selectedPartIndex)
                            .padding(.horizontal)
                        
                    } else {
                        // 空状态 - 等待文件选择
                        EmptyStateView(showingFilePicker: $showingFilePicker)
                            .frame(minHeight: 400)
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
                    .padding(.bottom, 20)
                }
                .padding(.top, 10)
            }
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
            .alert("提示", isPresented: .constant(parser.errorMessage != nil)) {
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
                
                // 打印调试信息
                print("解析完成:")
                print("- 部件数: \(parser.parts.count)")
                print("- 材料数: \(parser.materials.count)")
                if let meta = parser.metadata {
                    print("- 文件大小: \(meta.fileSize)")
                    print("- 总顶点数: \(meta.totalVertices)")
                    print("- 总三角形数: \(meta.totalTriangles)")
                }
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
        
        // 显示统计信息（调试用）
        sceneView.showsStatistics = true
        
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
        cameraNode.position = SCNVector3(x: 0, y: 50, z: 100)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func updateScene(scene: SCNScene) {
        // 清除现有几何节点
        scene.rootNode.childNodes
            .filter { $0.name == "model_part" || $0.light == nil && $0.camera == nil }
            .forEach { $0.removeFromParentNode() }
        
        // 确保有部件可显示
        guard selectedPartIndex < parser.parts.count else { 
            print("无效的部件索引: \(selectedPartIndex)")
            return 
        }
        
        let selectedPart = parser.parts[selectedPartIndex]
        print("显示部件: \(selectedPart.name)")
        
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
            
            print("模型尺寸: \(size)")
            
            // 设置相机位置
            if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
                let distance = max(size * 2.5, 50)  // 确保最小距离
                cameraNode.position = SCNVector3(
                    center.x + size * 0.5,
                    center.y + size * 0.5,
                    center.z + distance
                )
                cameraNode.look(at: center)
                
                // 设置相机的远近裁剪平面
                cameraNode.camera?.zNear = 1
                cameraNode.camera?.zFar = Double(distance * 10)
            }
        }
        
        scene.rootNode.addChildNode(node)
        
        // 添加光照
        setupLighting(scene: scene)
        
        // 添加地板网格（辅助参考）
        addFloorGrid(to: scene)
    }
    
    private func setupLighting(scene: SCNScene) {
        // 移除旧的光照
        scene.rootNode.childNodes
            .filter { $0.light != nil && $0.name != "camera_light" }
            .forEach { $0.removeFromParentNode() }
        
        // 添加环境光
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 800
        ambientLight.color = UIColor(white: 0.9, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // 添加主方向光
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 1000
        directionalLight.castsShadow = true
        directionalLight.shadowMode = .deferred
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        lightNode.position = SCNVector3(50, 100, 50)
        lightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(lightNode)
        
        // 添加补光
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 500
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.position = SCNVector3(-50, 50, -50)
        fillNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillNode)
    }
    
    private func addFloorGrid(to scene: SCNScene) {
        // 移除旧的地板
        scene.rootNode.childNodes
            .filter { $0.name == "floor_grid" }
            .forEach { $0.removeFromParentNode() }
        
        // 创建地板网格
        let floor = SCNFloor()
        floor.reflectivity = 0.1
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.95, alpha: 1.0)
        material.locksAmbientWithDiffuse = true
        floor.materials = [material]
        
        let floorNode = SCNNode(geometry: floor)
        floorNode.name = "floor_grid"
        floorNode.position = SCNVector3(0, -20, 0)
        scene.rootNode.addChildNode(floorNode)
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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("文件信息")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let title = metadata.title {
                            Label(title, systemImage: "doc.text")
                                .font(.caption)
                        }
                        
                        if let designer = metadata.designer {
                            Label("设计师: \(designer)", systemImage: "person")
                                .font(.caption)
                        }
                        
                        if let description = metadata.description {
                            Label(description, systemImage: "text.alignleft")
                                .font(.caption)
                                .lineLimit(2)
                        }
                        
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.blue)
                            Text("文件大小: \(formatFileSize(metadata.fileSize))")
                                .font(.caption)
                            
                            Spacer()
                            
                            Image(systemName: "cube.fill")
                                .foregroundColor(.orange)
                            Text("部件: \(metadata.partCount)")
                                .font(.caption)
                        }
                        
                        HStack {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .foregroundColor(.green)
                            Text("顶点: \(formatNumber(metadata.totalVertices))")
                                .font(.caption)
                            
                            Spacer()
                            
                            Image(systemName: "triangle.fill")
                                .foregroundColor(.purple)
                            Text("三角形: \(formatNumber(metadata.totalTriangles))")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // 零件选择器和信息
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("零件信息")
                        .font(.headline)
                    Spacer()
                    if parser.parts.count > 1 {
                        Text("\(selectedPartIndex + 1) / \(parser.parts.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
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
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "cube")
                                .foregroundColor(.blue)
                            Text(currentPart.name)
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Label("\(formatNumber(currentPart.vertexCount))", systemImage: "point.3.filled.connected.trianglepath.dotted")
                                    .font(.caption)
                                Text("顶点")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Label("\(formatNumber(currentPart.triangleCount))", systemImage: "triangle")
                                    .font(.caption)
                                Text("三角形")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let bounds = currentPart.bounds {
                            Divider()
                            HStack {
                                Image(systemName: "ruler")
                                    .foregroundColor(.orange)
                                Text("尺寸: \(formatBounds(bounds))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let materialId = currentPart.materialId,
                           let material = parser.materials[materialId] {
                            Divider()
                            HStack {
                                if let color = material.displayColor {
                                    Circle()
                                        .fill(Color(color))
                                        .frame(width: 16, height: 16)
                                        .overlay(Circle().stroke(Color.gray, lineWidth: 0.5))
                                }
                                Text("材料: \(material.name ?? materialId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // 材料列表（如果有多个）
            if !parser.materials.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("材料列表")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(parser.materials.values), id: \.id) { material in
                                VStack {
                                    if let color = material.displayColor {
                                        Circle()
                                            .fill(Color(color))
                                            .frame(width: 30, height: 30)
                                            .overlay(Circle().stroke(Color.gray, lineWidth: 0.5))
                                    } else {
                                        Circle()
                                            .fill(Color.gray)
                                            .frame(width: 30, height: 30)
                                    }
                                    Text(material.name ?? material.id)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .frame(width: 60)
                                }
                                .padding(4)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_CN")
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