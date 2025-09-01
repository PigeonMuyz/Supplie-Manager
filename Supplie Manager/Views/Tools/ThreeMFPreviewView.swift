import SwiftUI
import SceneKit
import UniformTypeIdentifiers
import UIKit

struct ThreeMFPreviewView: View {
    @StateObject private var parser = ThreeMFParser()
    @State private var selectedModel: ParsedThreeMFModel?
    @State private var showingFilePicker = false
    @State private var selectedPartIndex = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let model = selectedModel {
                    // 3D预览区域
                    ModelSceneView(model: model, selectedPartIndex: $selectedPartIndex)
                        .frame(height: 300)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    
                    // 模型信息
                    ModelInfoView(model: model, selectedPartIndex: $selectedPartIndex)
                    
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
                        Text(selectedModel == nil ? "选择3MF文件" : "更换文件")
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
            .navigationTitle("预览3MF")
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
            
            // 解析3MF文件
            if let model = await parser.parseThreeMFFile(at: url) {
                await MainActor.run {
                    selectedModel = model
                    selectedPartIndex = 0
                }
            }
            
        case .failure(let error):
            await MainActor.run {
                parser.errorMessage = "文件选择失败: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - 子视图组件

struct ModelSceneView: UIViewRepresentable {
    let model: ParsedThreeMFModel
    @Binding var selectedPartIndex: Int
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.systemGray6
        
        // 创建场景
        let scene = SCNScene()
        sceneView.scene = scene
        
        // 添加模型到场景
        setupScene(scene: scene, model: model)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 当选中的部件改变时，重新设置场景
        if let scene = uiView.scene {
            setupScene(scene: scene, model: model)
        }
    }
    
    private func setupScene(scene: SCNScene, model: ParsedThreeMFModel) {
        // 清除现有节点
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        
        // 只为当前选中的部件创建几何体
        if selectedPartIndex < model.partInfos.count {
            let selectedPartInfo = model.partInfos[selectedPartIndex]
            print("设置场景：显示部件 \(selectedPartInfo.name)")
            
            // 懒加载创建ModelPart和几何体
            if let selectedPart = model.createModelPart(for: selectedPartInfo) {
                let geometry = selectedPart.createSCNGeometry()
                let node = SCNNode(geometry: geometry)
                node.name = "selected_part"
                
                scene.rootNode.addChildNode(node)
            } else {
                print("无法创建部件: \(selectedPartInfo.name)")
            }
        }
        
        // 添加环境光
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 300
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // 添加方向光
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.intensity = 1000
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        lightNode.position = SCNVector3(5, 5, 5)
        lightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(lightNode)
    }
    
    private func updatePartHighlight(sceneView: SCNView) {
        // 由于现在只显示一个部件，这个函数暂时不需要做任何事情
        // 如果需要的话，可以在这里添加特殊的材质效果
    }
}

struct ModelInfoView: View {
    let model: ParsedThreeMFModel
    @Binding var selectedPartIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 模型信息
            if let metadata = model.metadata {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = metadata.title {
                        Text(title)
                            .font(.headline)
                    }
                    
                    if let designer = metadata.designer {
                        Text("设计师: \(designer)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let description = metadata.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
            }
            
            // 零件信息
            VStack(alignment: .leading, spacing: 8) {
                Text("零件信息")
                    .font(.headline)
                
                if model.partInfos.count > 1 {
                    // 零件选择器
                    VStack(alignment: .leading, spacing: 4) {
                        Text("共 \(model.partInfos.count) 个部件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("选择零件", selection: $selectedPartIndex) {
                            ForEach(0..<model.partInfos.count, id: \.self) { index in
                                Text("\(model.partInfos[index].name)")
                                    .tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                } else {
                    Text("单个部件模型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 当前零件详情（使用轻量级的PartInfo）
                let currentPartInfo = model.partInfos[selectedPartIndex]
                VStack(alignment: .leading, spacing: 4) {
                    Text("名称: \(currentPartInfo.name)")
                        .font(.body)
                    
                    Text("顶点数: \(currentPartInfo.vertexCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("三角形数: \(currentPartInfo.triangleCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let materialId = currentPartInfo.materialId,
                       let material = model.originalMaterials[materialId] {
                        Text("材料: \(material.name ?? materialId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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