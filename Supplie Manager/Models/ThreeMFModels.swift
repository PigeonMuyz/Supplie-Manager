import Foundation
import SceneKit
import Compression
import UIKit

// MARK: - 3MF数据模型

/// 3MF模型元数据
struct ThreeMFMetadata {
    let title: String?
    let designer: String?
    let description: String?
    let partCount: Int
    let totalVertices: Int
    let totalTriangles: Int
    let fileSize: Int64
}

/// 材料信息
struct ThreeMFMaterial {
    let id: String
    let name: String?
    let displayColor: UIColor?
}

/// 3D模型部件信息
struct ThreeMFPart: Identifiable {
    let id: String
    let name: String
    let vertexCount: Int
    let triangleCount: Int
    let bounds: (min: SCNVector3, max: SCNVector3)?
    let materialId: String?
}

/// 顶点数据
struct Vertex {
    let x: Float
    let y: Float
    let z: Float
}

/// 三角形数据
struct Triangle {
    let v1: Int
    let v2: Int
    let v3: Int
    let materialId: String?
}

// MARK: - 完整的3MF解析器

class ThreeMFParser: NSObject, XMLParserDelegate {
    // 解析状态
    private var currentElement = ""
    private var currentAttributes: [String: String] = [:]
    private var elementStack: [String] = []
    
    // 解析结果
    private var parts: [ThreeMFPart] = []
    private var materials: [String: ThreeMFMaterial] = [:]
    private var metadata: [String: String] = [:]
    
    // 当前正在解析的对象
    private var currentObject: (id: String, name: String)?
    private var currentVertices: [Vertex] = []
    private var currentTriangles: [Triangle] = []
    private var isInMesh = false
    private var isInVertices = false
    private var isInTriangles = false
    private var isInResources = false
    private var isInBaseMaterials = false
    
    // 解析3MF文件
    func parse(fileURL: URL) -> (parts: [ThreeMFPart], materials: [String: ThreeMFMaterial], metadata: ThreeMFMetadata?) {
        print("开始解析3MF文件: \(fileURL.lastPathComponent)")
        
        // 重置状态
        parts = []
        materials = [:]
        metadata = [:]
        currentVertices = []
        currentTriangles = []
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            print("文件大小: \(fileData.count) bytes")
            
            // 从ZIP中提取3D模型文件
            if let modelData = extractModelFromZip(data: fileData) {
                print("成功提取模型数据，大小: \(modelData.count) bytes")
                
                // 解析XML
                let parser = XMLParser(data: modelData)
                parser.delegate = self
                parser.shouldProcessNamespaces = true
                parser.shouldReportNamespacePrefixes = true
                parser.shouldResolveExternalEntities = false
                
                if parser.parse() {
                    print("XML解析成功")
                    print("找到 \(parts.count) 个部件")
                    print("找到 \(materials.count) 种材料")
                } else if let error = parser.parserError {
                    print("XML解析错误: \(error)")
                }
            } else {
                print("无法从ZIP文件中提取模型数据")
            }
            
            // 创建元数据
            let meta = ThreeMFMetadata(
                title: metadata["Title"],
                designer: metadata["Designer"],
                description: metadata["Description"],
                partCount: parts.count,
                totalVertices: parts.reduce(0) { $0 + $1.vertexCount },
                totalTriangles: parts.reduce(0) { $0 + $1.triangleCount },
                fileSize: Int64(fileData.count)
            )
            
            return (parts, materials, meta)
            
        } catch {
            print("解析失败: \(error)")
            return ([], [:], nil)
        }
    }
    
    // 从ZIP中提取3D模型文件
    private func extractModelFromZip(data: Data) -> Data? {
        var offset = 0
        
        while offset < data.count - 30 {
            // 查找本地文件头签名
            let signature = data.subdata(in: offset..<min(offset + 4, data.count))
            if signature == Data([0x50, 0x4B, 0x03, 0x04]) {
                // 读取文件头
                guard offset + 30 <= data.count else { break }
                
                let compressionMethod = data[offset + 8] | (data[offset + 9] << 8)
                let compressedSize = Int(data[offset + 18]) | (Int(data[offset + 19]) << 8) | 
                                    (Int(data[offset + 20]) << 16) | (Int(data[offset + 21]) << 24)
                let uncompressedSize = Int(data[offset + 22]) | (Int(data[offset + 23]) << 8) | 
                                      (Int(data[offset + 24]) << 16) | (Int(data[offset + 25]) << 24)
                let fileNameLength = Int(data[offset + 26]) | (Int(data[offset + 27]) << 8)
                let extraFieldLength = Int(data[offset + 28]) | (Int(data[offset + 29]) << 8)
                
                let fileNameStart = offset + 30
                let fileNameEnd = fileNameStart + fileNameLength
                
                guard fileNameEnd <= data.count else { break }
                
                if let fileName = String(data: data.subdata(in: fileNameStart..<fileNameEnd), encoding: .utf8) {
                    print("找到文件: \(fileName)")
                    
                    // 查找3D模型文件
                    if fileName.hasSuffix(".model") || fileName.contains("3dmodel") {
                        let dataStart = fileNameEnd + extraFieldLength
                        let dataEnd = dataStart + (compressedSize > 0 ? compressedSize : uncompressedSize)
                        
                        guard dataEnd <= data.count else { break }
                        
                        let fileData = data.subdata(in: dataStart..<dataEnd)
                        
                        // 检查是否需要解压
                        if compressionMethod == 8 { // Deflate
                            return decompressData(fileData)
                        } else if compressionMethod == 0 { // 无压缩
                            return fileData
                        }
                    }
                }
                
                offset = fileNameEnd + extraFieldLength + compressedSize
            } else {
                offset += 1
            }
        }
        
        return nil
    }
    
    // 解压数据
    private func decompressData(_ data: Data) -> Data? {
        return data.withUnsafeBytes { bytes in
            let sourceBuffer = bytes.bindMemory(to: UInt8.self).baseAddress!
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count * 10)
            defer { destinationBuffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                destinationBuffer, data.count * 10,
                sourceBuffer, data.count,
                nil, COMPRESSION_ZLIB
            )
            
            guard decompressedSize > 0 else { return nil }
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict
        elementStack.append(elementName)
        
        // 打印调试信息
        if elementName == "object" || elementName == "mesh" || elementName == "resources" || elementName == "basematerials" || elementName == "base" {
            print("开始元素: \(elementName), 属性: \(attributeDict)")
        }
        
        switch elementName {
        case "metadata":
            // 元数据将在foundCharacters中处理
            break
            
        case "resources":
            isInResources = true
            
        case "basematerials":
            if isInResources {
                isInBaseMaterials = true
            }
            
        case "base":
            if isInBaseMaterials {
                // 解析材料
                if let id = attributeDict["id"] ?? attributeDict["ID"] {
                    var color: UIColor?
                    if let displayColor = attributeDict["displaycolor"] ?? attributeDict["displayColor"] {
                        color = parseColor(from: displayColor)
                    }
                    
                    let material = ThreeMFMaterial(
                        id: id,
                        name: attributeDict["name"] ?? attributeDict["Name"],
                        displayColor: color
                    )
                    materials[id] = material
                    let colorStr = attributeDict["displaycolor"] ?? attributeDict["displayColor"]
                    print("添加材料: \(id), 名称: \(material.name ?? "无"), 颜色: \(colorStr ?? "无")")
                }
            }
            
        case "object":
            let id = attributeDict["id"] ?? attributeDict["ID"] ?? UUID().uuidString
            let name = attributeDict["name"] ?? attributeDict["Name"] ?? "Object \(id)"
            currentObject = (id: id, name: name)
            currentVertices = []
            currentTriangles = []
            print("开始解析对象: \(name) (ID: \(id))")
            
        case "mesh":
            isInMesh = true
            
        case "vertices":
            if isInMesh {
                isInVertices = true
            }
            
        case "vertex":
            if isInVertices {
                if let xStr = attributeDict["x"], let x = Float(xStr),
                   let yStr = attributeDict["y"], let y = Float(yStr),
                   let zStr = attributeDict["z"], let z = Float(zStr) {
                    currentVertices.append(Vertex(x: x, y: y, z: z))
                }
            }
            
        case "triangles":
            if isInMesh {
                isInTriangles = true
            }
            
        case "triangle":
            if isInTriangles {
                if let v1Str = attributeDict["v1"], let v1 = Int(v1Str),
                   let v2Str = attributeDict["v2"], let v2 = Int(v2Str),
                   let v3Str = attributeDict["v3"], let v3 = Int(v3Str) {
                    let materialId = attributeDict["pid"] ?? attributeDict["PID"]
                    currentTriangles.append(Triangle(v1: v1, v2: v2, v3: v3, materialId: materialId))
                }
            }
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        elementStack.removeLast()
        
        switch elementName {
        case "resources":
            isInResources = false
            
        case "basematerials":
            isInBaseMaterials = false
            
        case "object":
            if let object = currentObject {
                // 计算边界
                var minBounds = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
                var maxBounds = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
                
                for vertex in currentVertices {
                    minBounds.x = min(minBounds.x, vertex.x)
                    minBounds.y = min(minBounds.y, vertex.y)
                    minBounds.z = min(minBounds.z, vertex.z)
                    maxBounds.x = max(maxBounds.x, vertex.x)
                    maxBounds.y = max(maxBounds.y, vertex.y)
                    maxBounds.z = max(maxBounds.z, vertex.z)
                }
                
                let bounds = currentVertices.isEmpty ? nil : (min: minBounds, max: maxBounds)
                
                let part = ThreeMFPart(
                    id: object.id,
                    name: object.name,
                    vertexCount: currentVertices.count,
                    triangleCount: currentTriangles.count,
                    bounds: bounds,
                    materialId: currentTriangles.first?.materialId
                )
                
                parts.append(part)
                print("完成对象: \(object.name), 顶点: \(currentVertices.count), 三角形: \(currentTriangles.count)")
                
                currentObject = nil
                currentVertices = []
                currentTriangles = []
            }
            
        case "mesh":
            isInMesh = false
            
        case "vertices":
            isInVertices = false
            print("顶点解析完成，共 \(currentVertices.count) 个顶点")
            
        case "triangles":
            isInTriangles = false
            print("三角形解析完成，共 \(currentTriangles.count) 个三角形")
            
        default:
            break
        }
        
        currentElement = ""
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty else { return }
        
        // 处理元数据
        if currentElement == "metadata" {
            if let name = currentAttributes["name"] {
                metadata[name] = trimmedString
                print("元数据: \(name) = \(trimmedString)")
            }
        }
    }
    
    private func parseColor(from hexString: String) -> UIColor? {
        var hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        
        // 处理不同格式的颜色值
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = String(hex.dropFirst(2))
        }
        
        guard hex.count == 6 || hex.count == 8 else { 
            print("无效的颜色格式: \(hexString)")
            return nil 
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        
        if hex.count == 6 {
            // RGB格式
            return UIColor(
                red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                alpha: 1.0
            )
        } else {
            // RGBA格式
            return UIColor(
                red: CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0,
                green: CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0,
                blue: CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0,
                alpha: CGFloat(rgbValue & 0x000000FF) / 255.0
            )
        }
    }
}

// MARK: - 优化的3MF解析器（主接口）

class OptimizedThreeMFParser: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var metadata: ThreeMFMetadata?
    @Published var parts: [ThreeMFPart] = []
    @Published var materials: [String: ThreeMFMaterial] = [:]
    
    private let parser = ThreeMFParser()
    
    /// 解析3MF文件
    func parseMetadata(from url: URL) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // 在后台线程解析
        let result = await Task.detached {
            return self.parser.parse(fileURL: url)
        }.value
        
        await MainActor.run {
            self.parts = result.parts
            self.materials = result.materials
            self.metadata = result.metadata
            self.isLoading = false
            
            if parts.isEmpty {
                self.errorMessage = "未能从文件中提取模型数据"
            }
        }
    }
    
    /// 生成边界框预览
    func generateBoundingBoxPreview(for part: ThreeMFPart) -> SCNNode {
        let node = SCNNode()
        
        if let bounds = part.bounds {
            let width = CGFloat(bounds.max.x - bounds.min.x)
            let height = CGFloat(bounds.max.y - bounds.min.y)
            let depth = CGFloat(bounds.max.z - bounds.min.z)
            
            // 创建边界框
            let box = SCNBox(width: width, height: height, length: depth, chamferRadius: 0)
            
            // 设置材质
            let material = SCNMaterial()
            if let materialId = part.materialId,
               let mat = materials[materialId],
               let color = mat.displayColor {
                material.diffuse.contents = color
            } else {
                material.diffuse.contents = UIColor.systemBlue
            }
            material.transparency = 0.8
            material.isDoubleSided = true
            box.materials = [material]
            
            let boxNode = SCNNode(geometry: box)
            boxNode.position = SCNVector3(
                (bounds.min.x + bounds.max.x) / 2,
                (bounds.min.y + bounds.max.y) / 2,
                (bounds.min.z + bounds.max.z) / 2
            )
            
            node.addChildNode(boxNode)
            
            // 添加线框
            let wireframe = SCNBox(width: width, height: height, length: depth, chamferRadius: 0)
            let wireframeMaterial = SCNMaterial()
            wireframeMaterial.diffuse.contents = UIColor.white
            wireframeMaterial.fillMode = .lines
            wireframe.materials = [wireframeMaterial]
            
            let wireframeNode = SCNNode(geometry: wireframe)
            wireframeNode.position = boxNode.position
            node.addChildNode(wireframeNode)
        } else {
            // 如果没有边界，创建一个默认的球体
            let sphere = SCNSphere(radius: 10)
            sphere.firstMaterial?.diffuse.contents = UIColor.systemGray
            node.geometry = sphere
        }
        
        return node
    }
    
    /// 生成简化预览（暂时返回边界框）
    func generatePreview(for partId: String, simplificationLevel: Float = 0.5) -> SCNNode? {
        guard let part = parts.first(where: { $0.id == partId }) else { return nil }
        return generateBoundingBoxPreview(for: part)
    }
}

// MARK: - 兼容性结构

struct ModelPart: Identifiable {
    let id: String
    let name: String
    let vertexCount: Int
    let triangleCount: Int
    let materialId: String?
    
    func createSCNGeometry() -> SCNGeometry {
        let sphere = SCNSphere(radius: 1.0)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemBlue
        return sphere
    }
}

struct MaterialInfo {
    let id: String
    let name: String?
    let displayColor: String?
    let type: String?
}

struct ModelMetadata {
    let title: String?
    let designer: String?
    let description: String?
    let copyright: String?
    let createdDate: Date?
}

struct ParsedThreeMFModel {
    let parts: [ModelPart]
    let originalMaterials: [String: MaterialInfo]
    let metadata: ModelMetadata?
}

// MARK: - 错误定义

enum ThreeMFError: LocalizedError {
    case invalidFormat
    case fileNotFound
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "无效的3MF文件格式"
        case .fileNotFound:
            return "文件未找到"
        case .parsingFailed(let reason):
            return "解析失败: \(reason)"
        }
    }
}