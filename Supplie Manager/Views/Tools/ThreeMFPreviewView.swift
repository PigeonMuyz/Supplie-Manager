import SwiftUI
import SceneKit
import UniformTypeIdentifiers
import UIKit

struct ThreeMFPreviewView: View {
    @StateObject private var parser = OptimizedThreeMFParser()
    @StateObject private var materialStore = MaterialStore()  // 添加材料商店
    @State private var showingFilePicker = false
    @State private var selectedPartIndex = 0
    @State private var fileURL: URL?
    @State private var showAllParts = false  // 新增：显示所有部件的开关
    @State private var selectedParts: Set<Int> = []  // 新增：选中的部件集合
    @State private var partMaterials: [Int: Material] = [:]  // 部件对应的材料预设
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if parser.metadata != nil {
                        // 显示模式切换
                        HStack {
                            Button(action: {
                                showAllParts.toggle()
                                if showAllParts {
                                    // 显示所有部件时，选中所有
                                    selectedParts = Set(0..<parser.parts.count)
                                } else {
                                    // 单个显示时，清空选择
                                    selectedParts = [selectedPartIndex]
                                }
                            }) {
                                HStack {
                                    Image(systemName: showAllParts ? "square.grid.3x3.fill" : "square")
                                    Text(showAllParts ? "显示所有部件" : "单个部件")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(showAllParts ? Color.blue : Color(.systemGray5))
                                .foregroundColor(showAllParts ? .white : .primary)
                                .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            if showAllParts && parser.parts.count > 1 {
                                Text("已选择 \(selectedParts.count)/\(parser.parts.count) 个部件")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 3D预览区域
                        ModelSceneView(
                            parser: parser,
                            selectedPartIndex: $selectedPartIndex,
                            showAllParts: $showAllParts,
                            selectedParts: $selectedParts,
                            partMaterials: $partMaterials
                        )
                        .frame(height: 400)  // 增加高度
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                        
                        // 模型信息
                        ModelInfoView(
                            parser: parser,
                            selectedPartIndex: $selectedPartIndex,
                            showAllParts: $showAllParts,
                            selectedParts: $selectedParts,
                            materialStore: materialStore,
                            partMaterials: $partMaterials
                        )
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
                // 重置状态
                selectedPartIndex = 0
                selectedParts = [0]  // 默认选中第一个部件
                showAllParts = false  // 默认单个显示
                partMaterials.removeAll()  // 清空材料映射
                
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

// MARK: - 3D场景视图

struct ModelSceneView: UIViewRepresentable {
    let parser: OptimizedThreeMFParser
    @Binding var selectedPartIndex: Int
    @Binding var showAllParts: Bool
    @Binding var selectedParts: Set<Int>
    @Binding var partMaterials: [Int: Material]
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true  // 使用自动默认光照
        sceneView.backgroundColor = UIColor.systemGray6
        sceneView.antialiasingMode = .multisampling2X
        
        // 设置相机控制的缩放限制
        let cameraController = sceneView.defaultCameraController
        cameraController.minimumVerticalAngle = -90
        cameraController.maximumVerticalAngle = 90
        cameraController.inertiaEnabled = true
        cameraController.interactionMode = .orbitTurntable
        
        // 创建场景
        let scene = SCNScene()
        sceneView.scene = scene
        
        // 设置相机
        setupCamera(scene: scene)
        
        // 不再手动设置光照，使用自动光照
        
        // 显示统计信息（调试用，可以关闭）
        sceneView.showsStatistics = false
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 当选中的部件改变时，更新场景
        if let scene = uiView.scene {
            updateScene(scene: scene)
        }
    }
    
    private func setupCamera(scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.automaticallyAdjustsZRange = true
        cameraNode.position = SCNVector3(x: 0, y: 50, z: 100)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func updateScene(scene: SCNScene) {
        // 清除现有几何节点
        scene.rootNode.childNodes
            .filter { $0.name == "model_part" || ($0.light == nil && $0.camera == nil && $0.name != "floor_grid") }
            .forEach { $0.removeFromParentNode() }
        
        // 创建一个容器节点来组合所有部件
        let containerNode = SCNNode()
        containerNode.name = "model_container"
        
        var allBounds: (min: SCNVector3, max: SCNVector3)?
        
        if showAllParts {
            // 显示所有选中的部件，并排排列而非堆叠
            var xOffset: Float = 0
            let spacing: Float = 20  // 部件之间的间距
            
            for (_, index) in selectedParts.sorted().enumerated() {
                guard index < parser.parts.count else { continue }
                
                let part = parser.parts[index]
                print("添加部件: \(part.name)")
                
                if let partNode = parser.generatePreview(for: part.id, simplificationLevel: 1.0) {
                    partNode.name = "model_part_\(index)"
                    
                    // 计算部件尺寸用于排列
                    var partWidth: Float = 50  // 默认宽度
                    if let bounds = part.bounds {
                        partWidth = bounds.max.x - bounds.min.x
                        
                        // 将部件移动到正确的位置（横向排列）
                        let centerX = (bounds.min.x + bounds.max.x) / 2
                        partNode.position = SCNVector3(xOffset - centerX, 0, 0)
                        
                        // 更新下一个部件的偏移
                        xOffset += partWidth + spacing
                        
                        // 更新总边界
                        let translatedBounds = (
                            min: SCNVector3(
                                bounds.min.x + partNode.position.x,
                                bounds.min.y,
                                bounds.min.z
                            ),
                            max: SCNVector3(
                                bounds.max.x + partNode.position.x,
                                bounds.max.y,
                                bounds.max.z
                            )
                        )
                        
                        if var totalBounds = allBounds {
                            totalBounds.min.x = min(totalBounds.min.x, translatedBounds.min.x)
                            totalBounds.min.y = min(totalBounds.min.y, translatedBounds.min.y)
                            totalBounds.min.z = min(totalBounds.min.z, translatedBounds.min.z)
                            totalBounds.max.x = max(totalBounds.max.x, translatedBounds.max.x)
                            totalBounds.max.y = max(totalBounds.max.y, translatedBounds.max.y)
                            totalBounds.max.z = max(totalBounds.max.z, translatedBounds.max.z)
                            allBounds = totalBounds
                        } else {
                            allBounds = translatedBounds
                        }
                    }
                    
                    // 应用材料
                    if let userMaterial = partMaterials[index] {
                        applyMaterialPreset(userMaterial, to: partNode)
                    } else if let materialId = part.materialId,
                           let material = parser.materials[materialId],
                           let color = material.displayColor {
                        // 使用3MF文件中的材料颜色
                        partNode.geometry?.firstMaterial?.diffuse.contents = color
                    }
                    
                    containerNode.addChildNode(partNode)
                }
            }
        } else {
            // 单个部件显示
            guard selectedPartIndex < parser.parts.count else {
                print("无效的部件索引: \(selectedPartIndex)")
                return
            }
            
            let selectedPart = parser.parts[selectedPartIndex]
            print("显示部件: \(selectedPart.name)")
            
            if let partNode = parser.generatePreview(for: selectedPart.id, simplificationLevel: 1.0) {
                partNode.name = "model_part"
                
                // 优先使用用户选择的材料预设
                if let userMaterial = partMaterials[selectedPartIndex] {
                    applyMaterialPreset(userMaterial, to: partNode)
                } else if let materialId = selectedPart.materialId,
                       let material = parser.materials[materialId],
                       let color = material.displayColor {
                    // 使用3MF文件中的材料颜色
                    partNode.geometry?.firstMaterial?.diffuse.contents = color
                }
                
                containerNode.addChildNode(partNode)
                allBounds = selectedPart.bounds
            } else {
                // 如果失败，创建一个默认球体
                let sphere = SCNSphere(radius: 10)
                sphere.firstMaterial?.diffuse.contents = UIColor.systemBlue
                let node = SCNNode(geometry: sphere)
                node.name = "model_part"
                containerNode.addChildNode(node)
            }
        }
        
        // 自动调整相机以适应模型
        if let bounds = allBounds {
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
            
            print("模型总尺寸: \(size)")
            
            // 设置相机位置
            if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
                let distance = max(size * 2.5, 50)  // 确保最小距离
                cameraNode.position = SCNVector3(
                    center.x + size * 0.5,
                    center.y + size * 0.5,
                    center.z + distance
                )
                cameraNode.look(at: center)
                
                // 设置相机的远近裁剪平面，允许更大的缩放范围
                cameraNode.camera?.zNear = 0.1
                cameraNode.camera?.zFar = Double(distance * 100)
                
                // 设置正交投影的缩放范围（如果需要）
                if let camera = cameraNode.camera {
                    camera.automaticallyAdjustsZRange = true
                    camera.usesOrthographicProjection = false  // 使用透视投影
                    camera.fieldOfView = 60  // 设置视野角度
                }
            }
        }
        
        scene.rootNode.addChildNode(containerNode)
        
        // 不再添加地板
    }
    
    // 移除手动光照设置，使用SceneKit的自动默认光照
    
    // 移除地板功能
    /*
    private func addFloorGrid(to scene: SCNScene) {
        // 功能已移除
    }
    */
    
    // 应用材料预设到节点
    private func applyMaterialPreset(_ materialPreset: Material, to node: SCNNode) {
        print("应用材料预设: \(materialPreset.name) (\(materialPreset.brand))")
        
        // 递归应用材料到所有包含几何体的节点
        applyMaterialRecursively(materialPreset, to: node)
    }
    
    private func applyMaterialRecursively(_ materialPreset: Material, to node: SCNNode) {
        // 如果当前节点有几何体，应用材料
        if let geometry = node.geometry {
            applyMaterialToGeometry(materialPreset, geometry: geometry)
        }
        
        // 递归应用到所有子节点
        for childNode in node.childNodes {
            applyMaterialRecursively(materialPreset, to: childNode)
        }
    }
    
    private func applyMaterialToGeometry(_ materialPreset: Material, geometry: SCNGeometry) {
        let material = SCNMaterial()
        
        if materialPreset.isGradient {
            // 创建渐变纹理
            if let gradientImage = createGradientTexture(for: materialPreset) {
                material.diffuse.contents = gradientImage
            } else {
                material.diffuse.contents = UIColor(hex: materialPreset.colorHex) ?? UIColor.gray
            }
        } else {
            // 单色材料
            material.diffuse.contents = UIColor(hex: materialPreset.colorHex) ?? UIColor.gray
        }
        
        // 设置材料属性以模拟不同类型的塑料
        let categoryUpper = materialPreset.mainCategory.uppercased()
        let subCategoryUpper = materialPreset.subCategory.uppercased()
        
        // 检查是否是金属或特殊材质
        if categoryUpper.contains("METAL") || subCategoryUpper.contains("METAL") || 
           materialPreset.name.localizedCaseInsensitiveContains("金属") ||
           materialPreset.name.localizedCaseInsensitiveContains("metal") {
            // 金属材质
            material.metalness.contents = 0.9
            material.roughness.contents = 0.2
            material.specular.contents = UIColor(white: 1.0, alpha: 1.0)
        } else if categoryUpper.contains("SILK") || subCategoryUpper.contains("SILK") ||
                  materialPreset.name.localizedCaseInsensitiveContains("丝绸") ||
                  materialPreset.name.localizedCaseInsensitiveContains("silk") {
            // 丝绸质感
            material.metalness.contents = 0.4
            material.roughness.contents = 0.15
            material.specular.contents = UIColor(white: 0.9, alpha: 1.0)
        } else if subCategoryUpper.contains("MATTE") || materialPreset.name.localizedCaseInsensitiveContains("哑光") {
            // 哑光材质
            material.metalness.contents = 0.0
            material.roughness.contents = 0.9
            material.specular.contents = UIColor(white: 0.1, alpha: 1.0)
        } else {
            // 标准塑料材质
            switch categoryUpper {
            case "PLA":
                material.metalness.contents = 0.0
                material.roughness.contents = 0.6
                material.specular.contents = UIColor(white: 0.3, alpha: 1.0)
            case "PETG":
                material.metalness.contents = 0.05
                material.roughness.contents = 0.4
                material.specular.contents = UIColor(white: 0.5, alpha: 1.0)
                if materialPreset.name.localizedCaseInsensitiveContains("透明") ||
                   materialPreset.name.localizedCaseInsensitiveContains("clear") {
                    material.transparency = 0.9
                }
            case "ABS":
                material.metalness.contents = 0.02
                material.roughness.contents = 0.5
                material.specular.contents = UIColor(white: 0.4, alpha: 1.0)
            case "TPU":
                material.metalness.contents = 0.0
                material.roughness.contents = 0.7
                material.specular.contents = UIColor(white: 0.2, alpha: 1.0)
            default:
                material.metalness.contents = 0.0
                material.roughness.contents = 0.5
                material.specular.contents = UIColor(white: 0.3, alpha: 1.0)
            }
        }
        
        material.locksAmbientWithDiffuse = true
        geometry.materials = [material]
    }
    
    // 创建渐变纹理
    private func createGradientTexture(for material: Material) -> UIImage? {
        let size = CGSize(width: 512, height: 512)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        var colors: [CGColor] = []
        
        // 处理多色渐变
        if let gradientColors = material.gradientColors, !gradientColors.isEmpty {
            // 第一个颜色
            if let firstColor = UIColor(hex: material.colorHex)?.cgColor {
                colors.append(firstColor)
            }
            // 其他渐变颜色
            for hexColor in gradientColors {
                if let color = UIColor(hex: hexColor)?.cgColor {
                    colors.append(color)
                }
            }
        } else if let gradientHex = material.gradientColorHex {
            // 双色渐变
            if let color1 = UIColor(hex: material.colorHex)?.cgColor,
               let color2 = UIColor(hex: gradientHex)?.cgColor {
                colors = [color1, color2]
            }
        }
        
        guard !colors.isEmpty else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let locations: [CGFloat] = Array(0..<colors.count).map { CGFloat($0) / CGFloat(max(colors.count - 1, 1)) }
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
            return nil
        }
        
        // 创建对角线渐变
        let startPoint = CGPoint(x: 0, y: 0)
        let endPoint = CGPoint(x: size.width, y: size.height)
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}

// MARK: - 模型信息视图

struct ModelInfoView: View {
    let parser: OptimizedThreeMFParser
    @Binding var selectedPartIndex: Int
    @Binding var showAllParts: Bool
    @Binding var selectedParts: Set<Int>
    let materialStore: MaterialStore
    @Binding var partMaterials: [Int: Material]
    @State private var showingMaterialPickerForPart: IdentifiableInt? = nil
    
    private func showMaterialPickerForPart(index: Int) {
        showingMaterialPickerForPart = IdentifiableInt(value: index)
    }
    
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
                        if showAllParts {
                            Text("已选择 \(selectedParts.count) 个")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(selectedPartIndex + 1) / \(parser.parts.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if showAllParts && parser.parts.count > 1 {
                    // 多选模式下的部件列表（带独立材质选择）
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(0..<parser.parts.count, id: \.self) { index in
                                let part = parser.parts[index]
                                HStack {
                                    // 显示/隐藏切换
                                    Button(action: {
                                        if selectedParts.contains(index) {
                                            selectedParts.remove(index)
                                        } else {
                                            selectedParts.insert(index)
                                        }
                                    }) {
                                        Image(systemName: selectedParts.contains(index) ? "eye.fill" : "eye.slash")
                                            .foregroundColor(selectedParts.contains(index) ? .blue : .gray)
                                            .frame(width: 30)
                                    }
                                    
                                    // 部件名称和颜色
                                    HStack(spacing: 8) {
                                        if let userMaterial = partMaterials[index] {
                                            // 用户选择的材质
                                            if userMaterial.isGradient {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color(hex: userMaterial.colorHex) ?? .gray,
                                                                   Color(hex: userMaterial.gradientColorHex ?? "#FFFFFF") ?? .white],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 24, height: 24)
                                            } else {
                                                Circle()
                                                    .fill(Color(hex: userMaterial.colorHex) ?? .gray)
                                                    .frame(width: 24, height: 24)
                                            }
                                        } else if let materialId = part.materialId,
                                                let material = parser.materials[materialId],
                                                let color = material.displayColor {
                                            Circle()
                                                .fill(Color(color))
                                                .frame(width: 24, height: 24)
                                        } else {
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 24, height: 24)
                                        }
                                        
                                        Text(part.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        // 材质选择按钮
                                        Button(action: {
                                            // 这里可以打开单个部件的材质选择器
                                            showMaterialPickerForPart(index: index)
                                        }) {
                                            Text(partMaterials[index]?.name ?? "选择材质")
                                                .font(.caption2)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color(.systemGray5))
                                                .cornerRadius(4)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedParts.contains(index) ? Color(.systemGray6) : Color.clear)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .padding(.vertical, 4)
                } else if parser.parts.count > 1 {
                    // 单选模式下的选择器
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
                    .onChange(of: selectedPartIndex) { oldValue, newValue in
                        // 单选模式下同步更新selectedParts
                        selectedParts = [newValue]
                    }
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
            
            // 材料预设选择器
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("应用材料预设")
                        .font(.headline)
                    Spacer()
                    Button("清除所有") {
                        partMaterials.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                if !showAllParts {
                    // 单部件模式：为当前部件选择材料
                    if let currentMaterial = partMaterials[selectedPartIndex] {
                        HStack {
                            MaterialPresetView(material: currentMaterial)
                            Spacer()
                            Button("更改") {
                                // 这里可以打开材料选择器
                            }
                            .font(.caption)
                            Button("移除") {
                                partMaterials.removeValue(forKey: selectedPartIndex)
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    } else {
                        MaterialPickerRow(
                            selectedPartIndex: selectedPartIndex,
                            partMaterials: $partMaterials,
                            materialStore: materialStore
                        )
                    }
                } else {
                    // 多部件模式：批量应用
                    MaterialPickerRow(
                        selectedPartIndex: -1,  // 表示批量应用
                        partMaterials: $partMaterials,
                        materialStore: materialStore,
                        selectedParts: selectedParts
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .sheet(item: $showingMaterialPickerForPart) { identifiableInt in
                MaterialPickerSheet(
                    selectedPartIndex: identifiableInt.value,
                    partMaterials: $partMaterials,
                    materialStore: materialStore,
                    selectedParts: Set([identifiableInt.value])
                )
            }
            
            // 原有的材料列表（如果有多个）
            if !parser.materials.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("3MF文件材料")
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

// MARK: - 材料选择器组件

struct MaterialPickerRow: View {
    let selectedPartIndex: Int
    @Binding var partMaterials: [Int: Material]
    let materialStore: MaterialStore
    var selectedParts: Set<Int> = []
    @State private var showingMaterialPicker = false
    
    var body: some View {
        Button(action: {
            showingMaterialPicker = true
        }) {
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(.blue)
                Text(selectedPartIndex == -1 ? "为选中部件应用材料" : "选择材料预设")
                    .font(.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(12)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingMaterialPicker) {
            MaterialPickerSheet(
                selectedPartIndex: selectedPartIndex,
                partMaterials: $partMaterials,
                materialStore: materialStore,
                selectedParts: selectedParts
            )
        }
    }
}

struct MaterialPickerSheet: View {
    let selectedPartIndex: Int?
    @Binding var partMaterials: [Int: Material]
    let materialStore: MaterialStore
    let selectedParts: Set<Int>
    @Environment(\.dismiss) var dismiss
    @State private var selectedMaterial: Material?
    @State private var searchText = ""
    
    var filteredMaterials: [Material] {
        if searchText.isEmpty {
            return materialStore.materials
        } else {
            return materialStore.materials.filter { material in
                material.name.localizedCaseInsensitiveContains(searchText) ||
                material.brand.localizedCaseInsensitiveContains(searchText) ||
                material.mainCategory.localizedCaseInsensitiveContains(searchText) ||
                material.subCategory.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索材料...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                .padding(.top)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if filteredMaterials.isEmpty {
                            Text("没有找到匹配的材料")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredMaterials) { material in
                                Button(action: {
                                    selectedMaterial = material
                                }) {
                                    MaterialPresetView(material: material)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    selectedMaterial?.id == material.id ? Color.blue : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("选择材料预设")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        if let material = selectedMaterial {
                            if let partIndex = selectedPartIndex {
                                if partIndex == -1 {
                                    // 批量应用到所有选中的部件
                                    for index in selectedParts {
                                        partMaterials[index] = material
                                    }
                                } else {
                                    // 单个应用
                                    partMaterials[partIndex] = material
                                }
                            }
                        }
                        dismiss()
                    }
                    .disabled(selectedMaterial == nil)
                }
            }
        }
        .onAppear {
            materialStore.loadData()
        }
    }
}

struct MaterialPresetView: View {
    let material: Material
    
    var body: some View {
        HStack(spacing: 12) {
            // 颜色预览
            if material.isGradient {
                // 渐变色预览
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: material.gradientColors?.compactMap { Color(hex: $0) } ?? [
                                Color(hex: material.colorHex) ?? .gray,
                                Color(hex: material.gradientColorHex ?? "#FFFFFF") ?? .white
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            } else {
                // 单色预览
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: material.colorHex) ?? .gray)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            }
            
            // 材料信息
            VStack(alignment: .leading, spacing: 4) {
                Text(material.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(material.brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(material.mainCategory) \(material.subCategory)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// 颜色工具扩展
extension UIColor {
    convenience init?(hex: String) {
        let r, g, b: CGFloat
        var hexColor = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexColor.hasPrefix("#") {
            hexColor.remove(at: hexColor.startIndex)
        }
        
        if hexColor.count == 6 {
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0
            
            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                b = CGFloat(hexNumber & 0x0000ff) / 255
                
                self.init(red: r, green: g, blue: b, alpha: 1.0)
                return
            }
        }
        
        return nil
    }
}

// 辅助结构体用于使Int可识别
struct IdentifiableInt: Identifiable {
    let id = UUID()
    let value: Int
}

struct ThreeMFPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ThreeMFPreviewView()
    }
}