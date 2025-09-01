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
    
    // 对象引用（有些3MF文件使用引用）
    private var objectReferences: [String: String] = [:]
    private var meshData: [String: (vertices: [Vertex], triangles: [Triangle])] = [:]
    
    // 解析3MF文件
    func parse(fileURL: URL) -> (parts: [ThreeMFPart], materials: [String: ThreeMFMaterial], metadata: ThreeMFMetadata?) {
        print("开始解析3MF文件: \(fileURL.lastPathComponent)")
        
        // 重置状态
        parts = []
        materials = [:]
        metadata = [:]
        currentVertices = []
        currentTriangles = []
        objectReferences = [:]
        meshData = [:]
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            print("文件大小: \(fileData.count) bytes")
            
            // 提取所有模型文件
            let modelFiles = extractAllModelFiles(from: fileData)
            print("找到 \(modelFiles.count) 个模型文件")
            
            // 解析每个模型文件
            for (fileName, modelData) in modelFiles {
                print("解析文件: \(fileName), 大小: \(modelData.count) bytes")
                
                // 清空当前状态
                currentVertices = []
                currentTriangles = []
                currentObject = nil
                
                // 解析XML
                let parser = XMLParser(data: modelData)
                parser.delegate = self
                parser.shouldProcessNamespaces = true
                parser.shouldReportNamespacePrefixes = true
                parser.shouldResolveExternalEntities = false
                
                if parser.parse() {
                    print("文件 \(fileName) 解析成功")
                } else if let error = parser.parserError {
                    print("文件 \(fileName) 解析错误: \(error)")
                }
            }
            
            // 如果没有找到部件，尝试从mesh数据创建
            if parts.isEmpty && !meshData.isEmpty {
                print("从mesh数据创建部件...")
                for (id, data) in meshData {
                    let part = createPartFromMeshData(id: id, vertices: data.vertices, triangles: data.triangles)
                    parts.append(part)
                }
            }
            
            print("最终: 找到 \(parts.count) 个部件, \(materials.count) 种材料")
            
            // 创建元数据
            let meta = ThreeMFMetadata(
                title: metadata["Title"],
                designer: metadata["Designer"],
                description: cleanDescription(metadata["Description"]),
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
    
    // 清理HTML描述
    private func cleanDescription(_ desc: String?) -> String? {
        guard let desc = desc else { return nil }
        // 移除HTML标签
        let cleaned = desc.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
        
        // 使用正则表达式移除HTML标签
        let pattern = "<[^>]+>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: cleaned.count)
        let result = regex?.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        
        return result?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 提取所有模型文件
    private func extractAllModelFiles(from data: Data) -> [(String, Data)] {
        var modelFiles: [(String, Data)] = []
        var offset = 0
        
        while offset < data.count - 30 {
            // 查找本地文件头签名
            let signature = data.subdata(in: offset..<min(offset + 4, data.count))
            if signature == Data([0x50, 0x4B, 0x03, 0x04]) {
                // 读取文件头
                guard offset + 30 <= data.count else { break }
                
                // 读取压缩方法和大小
                let compressionMethod = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
                
                // 读取大小字段
                var compressedSize = UInt32(data[offset + 18]) | 
                                     (UInt32(data[offset + 19]) << 8) |
                                     (UInt32(data[offset + 20]) << 16) | 
                                     (UInt32(data[offset + 21]) << 24)
                var uncompressedSize = UInt32(data[offset + 22]) | 
                                       (UInt32(data[offset + 23]) << 8) |
                                       (UInt32(data[offset + 24]) << 16) | 
                                       (UInt32(data[offset + 25]) << 24)
                
                let fileNameLength = Int(data[offset + 26]) | (Int(data[offset + 27]) << 8)
                let extraFieldLength = Int(data[offset + 28]) | (Int(data[offset + 29]) << 8)
                
                let fileNameStart = offset + 30
                let fileNameEnd = fileNameStart + fileNameLength
                
                guard fileNameEnd <= data.count else { break }
                
                if let fileName = String(data: data.subdata(in: fileNameStart..<fileNameEnd), encoding: .utf8) {
                    print("找到文件: \(fileName)")
                    
                    // 检查是否需要读取ZIP64扩展字段
                    if compressedSize == 0xFFFFFFFF || uncompressedSize == 0xFFFFFFFF {
                        // 可能使用ZIP64格式，尝试从扩展字段读取
                        if extraFieldLength >= 20 {
                            let extraStart = fileNameEnd
                            // 简化处理：如果大小字段是0xFFFFFFFF，尝试从后面读取实际大小
                            // 这里我们跳过ZIP64的复杂解析，直接尝试读取合理大小的数据
                            compressedSize = 0
                            uncompressedSize = 0
                        }
                    }
                    
                    // 查找模型文件
                    if fileName.hasSuffix(".model") || fileName.contains("3dmodel") {
                        let dataStart = fileNameEnd + extraFieldLength
                        
                        // 如果压缩大小为0，尝试查找下一个文件头来确定大小
                        if compressedSize == 0 {
                            var searchOffset = dataStart + 1
                            while searchOffset < data.count - 4 {
                                let nextSig = data.subdata(in: searchOffset..<searchOffset + 4)
                                if nextSig == Data([0x50, 0x4B, 0x03, 0x04]) || 
                                   nextSig == Data([0x50, 0x4B, 0x01, 0x02]) {
                                    compressedSize = UInt32(searchOffset - dataStart)
                                    break
                                }
                                searchOffset += 1
                            }
                            // 如果没找到下一个文件头，使用剩余数据大小
                            if compressedSize == 0 {
                                compressedSize = UInt32(min(data.count - dataStart, 10000000))
                            }
                        }
                        
                        let dataEnd = dataStart + Int(compressedSize)
                        guard dataEnd <= data.count else { 
                            offset += 1
                            continue 
                        }
                        
                        let fileData = data.subdata(in: dataStart..<dataEnd)
                        
                        // 尝试解压或直接使用
                        if compressionMethod == 8 { // Deflate
                            if let decompressed = decompressData(fileData) {
                                modelFiles.append((fileName, decompressed))
                                print("解压文件 \(fileName): \(decompressed.count) bytes")
                            }
                        } else if compressionMethod == 0 { // 无压缩
                            modelFiles.append((fileName, fileData))
                            print("提取文件 \(fileName): \(fileData.count) bytes")
                        }
                    }
                }
                
                // 移动到下一个可能的位置
                if compressedSize > 0 {
                    offset = fileNameEnd + extraFieldLength + Int(compressedSize)
                } else {
                    offset += 1
                }
            } else {
                offset += 1
            }
        }
        
        return modelFiles
    }
    
    // 解压数据
    private func decompressData(_ data: Data) -> Data? {
        // 尝试多种解压方式
        
        // 方式1：标准ZLIB
        if let result = tryDecompress(data, algorithm: COMPRESSION_ZLIB) {
            return result
        }
        
        // 方式2：DEFLATE（无ZLIB头）
        if let result = tryDecompress(data, algorithm: COMPRESSION_ZLIB, skipBytes: 0) {
            return result
        }
        
        // 方式3：尝试跳过可能的头部
        for skip in [2, 4, 6] {
            if data.count > skip {
                let trimmed = data.subdata(in: skip..<data.count)
                if let result = tryDecompress(trimmed, algorithm: COMPRESSION_ZLIB) {
                    return result
                }
            }
        }
        
        return nil
    }
    
    private func tryDecompress(_ data: Data, algorithm: compression_algorithm, skipBytes: Int = 0) -> Data? {
        let sourceData = skipBytes > 0 && data.count > skipBytes ? 
                        data.subdata(in: skipBytes..<data.count) : data
        
        return sourceData.withUnsafeBytes { bytes in
            let sourceBuffer = bytes.bindMemory(to: UInt8.self).baseAddress!
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: sourceData.count * 20)
            defer { destinationBuffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                destinationBuffer, sourceData.count * 20,
                sourceBuffer, sourceData.count,
                nil, algorithm
            )
            
            guard decompressedSize > 0 else { return nil }
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
    }
    
    // 从mesh数据创建部件
    private func createPartFromMeshData(id: String, vertices: [Vertex], triangles: [Triangle]) -> ThreeMFPart {
        var minBounds = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxBounds = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        
        for vertex in vertices {
            minBounds.x = min(minBounds.x, vertex.x)
            minBounds.y = min(minBounds.y, vertex.y)
            minBounds.z = min(minBounds.z, vertex.z)
            maxBounds.x = max(maxBounds.x, vertex.x)
            maxBounds.y = max(maxBounds.y, vertex.y)
            maxBounds.z = max(maxBounds.z, vertex.z)
        }
        
        let bounds = vertices.isEmpty ? nil : (min: minBounds, max: maxBounds)
        
        return ThreeMFPart(
            id: id,
            name: "Object \(id)",
            vertexCount: vertices.count,
            triangleCount: triangles.count,
            bounds: bounds,
            materialId: triangles.first?.materialId
        )
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict
        elementStack.append(elementName)
        
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
                    print("添加材料: \(id)")
                }
            }
            
        case "object":
            let id = attributeDict["id"] ?? attributeDict["ID"] ?? UUID().uuidString
            let name = attributeDict["name"] ?? attributeDict["Name"] ?? "Object \(id)"
            currentObject = (id: id, name: name)
            currentVertices = []
            currentTriangles = []
            
        case "mesh":
            isInMesh = true
            currentVertices = []
            currentTriangles = []
            
        case "vertices":
            if isInMesh {
                isInVertices = true
            }
            
        case "vertex":
            if isInVertices || isInMesh {
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
            if isInTriangles || isInMesh {
                if let v1Str = attributeDict["v1"], let v1 = Int(v1Str),
                   let v2Str = attributeDict["v2"], let v2 = Int(v2Str),
                   let v3Str = attributeDict["v3"], let v3 = Int(v3Str) {
                    let materialId = attributeDict["pid"] ?? attributeDict["PID"] ?? attributeDict["p1"]
                    currentTriangles.append(Triangle(v1: v1, v2: v2, v3: v3, materialId: materialId))
                }
            }
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
        
        switch elementName {
        case "resources":
            isInResources = false
            
        case "basematerials":
            isInBaseMaterials = false
            
        case "object":
            if let object = currentObject {
                // 保存mesh数据
                if !currentVertices.isEmpty || !currentTriangles.isEmpty {
                    meshData[object.id] = (vertices: currentVertices, triangles: currentTriangles)
                }
                
                // 创建部件
                let part = createPartFromMeshData(
                    id: object.id, 
                    vertices: currentVertices, 
                    triangles: currentTriangles
                )
                
                // 更新名称
                var updatedPart = part
                updatedPart = ThreeMFPart(
                    id: part.id,
                    name: object.name,
                    vertexCount: part.vertexCount,
                    triangleCount: part.triangleCount,
                    bounds: part.bounds,
                    materialId: part.materialId
                )
                
                if updatedPart.vertexCount > 0 || updatedPart.triangleCount > 0 {
                    parts.append(updatedPart)
                    print("添加部件: \(object.name), 顶点: \(updatedPart.vertexCount), 三角形: \(updatedPart.triangleCount)")
                }
                
                currentObject = nil
            }
            
        case "mesh":
            isInMesh = false
            // 如果没有当前对象，保存mesh数据供后续使用
            if currentObject == nil && (!currentVertices.isEmpty || !currentTriangles.isEmpty) {
                let meshId = "mesh_\(meshData.count)"
                meshData[meshId] = (vertices: currentVertices, triangles: currentTriangles)
                print("保存独立mesh: 顶点 \(currentVertices.count), 三角形 \(currentTriangles.count)")
            }
            
        case "vertices":
            isInVertices = false
            
        case "triangles":
            isInTriangles = false
            
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
                // 合并多行描述
                if name == "Description" {
                    let existing = metadata[name] ?? ""
                    metadata[name] = existing + trimmedString
                } else {
                    metadata[name] = trimmedString
                }
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
                self.errorMessage = "未能从文件中提取模型数据，请确认文件格式正确"
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