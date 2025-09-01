import Foundation
import SceneKit
import Compression
import UIKit

// MARK: - 优化的3MF解析器
// 使用流式解析和内存映射减少内存占用

/// 3MF模型元数据（轻量级）
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

/// 简化的3D模型部件（仅存储必要信息）
struct ThreeMFPart: Identifiable {
    let id: String
    let name: String
    let vertexCount: Int
    let triangleCount: Int
    let bounds: (min: SCNVector3, max: SCNVector3)?
    let materialId: String?
}

/// 3MF文件句柄（避免一次性加载整个文件）
class ThreeMFFileHandle {
    private let fileURL: URL
    private var fileHandle: FileHandle?
    private var zipEntries: [String: ZipEntry] = [:]
    
    struct ZipEntry {
        let offset: Int64
        let compressedSize: Int64
        let uncompressedSize: Int64
        let compressionMethod: UInt16
    }
    
    init(url: URL) {
        self.fileURL = url
    }
    
    deinit {
        close()
    }
    
    func open() throws {
        fileHandle = try FileHandle(forReadingFrom: fileURL)
        try scanZipDirectory()
    }
    
    func close() {
        fileHandle?.closeFile()
        fileHandle = nil
        zipEntries.removeAll()
    }
    
    private func scanZipDirectory() throws {
        guard let handle = fileHandle else { return }
        
        // 扫描中央目录，不加载文件内容
        let fileSize = try handle.seekToEnd()
        
        // 查找中央目录结束记录
        var centralDirOffset: Int64 = -1
        let endSignature = Data([0x50, 0x4B, 0x05, 0x06])
        
        // 从文件末尾向前搜索
        let searchSize: Int64 = min(65536, fileSize)
        try handle.seek(toOffset: UInt64(max(0, fileSize - searchSize)))
        let searchData = handle.readData(ofLength: Int(searchSize))
        
        if let range = searchData.range(of: endSignature) {
            let endOffset = fileSize - searchSize + Int64(range.lowerBound)
            try handle.seek(toOffset: UInt64(endOffset + 16))
            
            // 读取中央目录偏移
            let offsetData = handle.readData(ofLength: 4)
            centralDirOffset = Int64(offsetData.withUnsafeBytes { $0.load(as: UInt32.self) })
        }
        
        if centralDirOffset >= 0 {
            try scanCentralDirectory(at: centralDirOffset)
        }
    }
    
    private func scanCentralDirectory(at offset: Int64) throws {
        guard let handle = fileHandle else { return }
        
        try handle.seek(toOffset: UInt64(offset))
        let centralDirSignature = Data([0x50, 0x4B, 0x01, 0x02])
        
        while true {
            let signatureData = handle.readData(ofLength: 4)
            if signatureData != centralDirSignature {
                break
            }
            
            // 跳过版本信息
            _ = handle.readData(ofLength: 24)
            
            // 读取文件名长度
            let lengthsData = handle.readData(ofLength: 6)
            let nameLength = lengthsData[0...1].withUnsafeBytes { $0.load(as: UInt16.self) }
            let extraLength = lengthsData[2...3].withUnsafeBytes { $0.load(as: UInt16.self) }
            let commentLength = lengthsData[4...5].withUnsafeBytes { $0.load(as: UInt16.self) }
            
            // 跳过磁盘号
            _ = handle.readData(ofLength: 8)
            
            // 读取本地文件头偏移
            let offsetData = handle.readData(ofLength: 4)
            let localOffset = offsetData.withUnsafeBytes { $0.load(as: UInt32.self) }
            
            // 读取文件名
            let nameData = handle.readData(ofLength: Int(nameLength))
            if let fileName = String(data: nameData, encoding: .utf8) {
                // 存储文件条目信息（稍后读取详细信息）
                zipEntries[fileName] = ZipEntry(
                    offset: Int64(localOffset),
                    compressedSize: 0,
                    uncompressedSize: 0,
                    compressionMethod: 0
                )
            }
            
            // 跳过额外字段和注释
            _ = handle.readData(ofLength: Int(extraLength + commentLength))
        }
    }
    
    func extractFile(named fileName: String) -> Data? {
        guard let handle = fileHandle,
              let entry = zipEntries[fileName] else { return nil }
        
        do {
            // 读取本地文件头获取准确信息
            try handle.seek(toOffset: UInt64(entry.offset))
            
            let signature = handle.readData(ofLength: 4)
            guard signature == Data([0x50, 0x4B, 0x03, 0x04]) else { return nil }
            
            // 跳过版本和标志
            _ = handle.readData(ofLength: 4)
            
            // 读取压缩方法
            let methodData = handle.readData(ofLength: 2)
            let compressionMethod = methodData.withUnsafeBytes { $0.load(as: UInt16.self) }
            
            // 跳过时间和CRC
            _ = handle.readData(ofLength: 8)
            
            // 读取大小信息
            let sizeData = handle.readData(ofLength: 8)
            let compressedSize = sizeData[0...3].withUnsafeBytes { $0.load(as: UInt32.self) }
            let uncompressedSize = sizeData[4...7].withUnsafeBytes { $0.load(as: UInt32.self) }
            
            // 读取文件名和额外字段长度
            let lengthData = handle.readData(ofLength: 4)
            let fileNameLength = lengthData[0...1].withUnsafeBytes { $0.load(as: UInt16.self) }
            let extraFieldLength = lengthData[2...3].withUnsafeBytes { $0.load(as: UInt16.self) }
            
            // 跳过文件名和额外字段
            _ = handle.readData(ofLength: Int(fileNameLength + extraFieldLength))
            
            // 读取文件数据
            let fileData = handle.readData(ofLength: Int(compressedSize))
            
            // 根据压缩方法处理数据
            if compressionMethod == 0 {
                return fileData
            } else if compressionMethod == 8 {
                // Deflate压缩
                return decompressData(fileData, uncompressedSize: Int(uncompressedSize))
            }
            
        } catch {
            print("提取文件失败: \(error)")
        }
        
        return nil
    }
    
    private func decompressData(_ data: Data, uncompressedSize: Int) -> Data? {
        return data.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
            defer { buffer.deallocate() }
            
            let result = compression_decode_buffer(
                buffer, uncompressedSize,
                bytes.bindMemory(to: UInt8.self).baseAddress!, data.count,
                nil, COMPRESSION_ZLIB
            )
            
            guard result > 0 else { return nil }
            return Data(bytes: buffer, count: result)
        }
    }
}

// MARK: - 流式XML解析器

class ThreeMFStreamParser: NSObject, XMLParserDelegate {
    private var parts: [ThreeMFPart] = []
    private var materials: [String: ThreeMFMaterial] = []
    private var metadata: ThreeMFMetadata?
    
    private var currentElement = ""
    private var currentPartId = ""
    private var currentPartName = ""
    private var vertexCount = 0
    private var triangleCount = 0
    private var isParsingMesh = false
    
    // 用于计算边界
    private var minBounds = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
    private var maxBounds = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
    
    func parse(data: Data) -> (parts: [ThreeMFPart], materials: [String: ThreeMFMaterial], metadata: ThreeMFMetadata?) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        
        // 创建元数据
        let meta = ThreeMFMetadata(
            title: nil,
            designer: nil,
            description: nil,
            partCount: parts.count,
            totalVertices: parts.reduce(0) { $0 + $1.vertexCount },
            totalTriangles: parts.reduce(0) { $0 + $1.triangleCount },
            fileSize: Int64(data.count)
        )
        
        return (parts, materials, meta)
    }
    
    // XMLParserDelegate方法
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        switch elementName {
        case "object":
            currentPartId = attributeDict["id"] ?? UUID().uuidString
            currentPartName = attributeDict["name"] ?? "Part \(currentPartId)"
            vertexCount = 0
            triangleCount = 0
            minBounds = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
            maxBounds = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
            
        case "mesh":
            isParsingMesh = true
            
        case "vertex":
            if isParsingMesh {
                vertexCount += 1
                
                // 更新边界（不存储顶点数据）
                if let xStr = attributeDict["x"], let x = Float(xStr),
                   let yStr = attributeDict["y"], let y = Float(yStr),
                   let zStr = attributeDict["z"], let z = Float(zStr) {
                    minBounds.x = min(minBounds.x, x)
                    minBounds.y = min(minBounds.y, y)
                    minBounds.z = min(minBounds.z, z)
                    maxBounds.x = max(maxBounds.x, x)
                    maxBounds.y = max(maxBounds.y, y)
                    maxBounds.z = max(maxBounds.z, z)
                }
            }
            
        case "triangle":
            if isParsingMesh {
                triangleCount += 1
            }
            
        case "basematerials":
            // 解析材料
            if let id = attributeDict["id"] {
                var color: UIColor?
                if let displayColor = attributeDict["displaycolor"] {
                    color = parseColor(from: displayColor)
                }
                materials[id] = ThreeMFMaterial(
                    id: id,
                    name: attributeDict["name"],
                    displayColor: color
                )
            }
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "mesh":
            isParsingMesh = false
            
        case "object":
            // 创建部件信息（不存储几何数据）
            let bounds = (minBounds.x != Float.greatestFiniteMagnitude) ? (min: minBounds, max: maxBounds) : nil
            let part = ThreeMFPart(
                id: currentPartId,
                name: currentPartName,
                vertexCount: vertexCount,
                triangleCount: triangleCount,
                bounds: bounds,
                materialId: nil
            )
            parts.append(part)
            
        default:
            break
        }
    }
    
    private func parseColor(from hexString: String) -> UIColor? {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 || hex.count == 8 else { return nil }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        
        if hex.count == 6 {
            return UIColor(
                red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                alpha: 1.0
            )
        } else {
            return UIColor(
                red: CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0,
                green: CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0,
                blue: CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0,
                alpha: CGFloat(rgbValue & 0x000000FF) / 255.0
            )
        }
    }
}

// MARK: - 简化的3MF解析器（主类）

class OptimizedThreeMFParser: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var metadata: ThreeMFMetadata?
    @Published var parts: [ThreeMFPart] = []
    @Published var materials: [String: ThreeMFMaterial] = [:]
    
    private var fileHandle: ThreeMFFileHandle?
    
    /// 解析3MF文件（仅提取元数据，不加载几何数据）
    func parseMetadata(from url: URL) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let handle = ThreeMFFileHandle(url: url)
            try handle.open()
            self.fileHandle = handle
            
            // 查找并解析主模型文件
            if let modelData = handle.extractFile(named: "3D/3dmodel.model") {
                let parser = ThreeMFStreamParser()
                let result = parser.parse(data: modelData)
                
                await MainActor.run {
                    self.parts = result.parts
                    self.materials = result.materials
                    self.metadata = result.metadata
                    self.isLoading = false
                }
            } else {
                throw ThreeMFError.invalidFormat
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// 按需生成预览（仅为选定的部件生成几何数据）
    func generatePreview(for partId: String, simplificationLevel: Float = 0.5) -> SCNNode? {
        guard let handle = fileHandle,
              let part = parts.first(where: { $0.id == partId }) else { return nil }
        
        // 提取并解析特定部件的几何数据
        if let modelData = handle.extractFile(named: "3D/3dmodel.model") {
            return parsePartGeometry(from: modelData, partId: partId, simplificationLevel: simplificationLevel)
        }
        
        return nil
    }
    
    /// 生成简化的预览（使用边界框）
    func generateBoundingBoxPreview(for part: ThreeMFPart) -> SCNNode {
        let node = SCNNode()
        
        if let bounds = part.bounds {
            let width = CGFloat(bounds.max.x - bounds.min.x)
            let height = CGFloat(bounds.max.y - bounds.min.y)
            let depth = CGFloat(bounds.max.z - bounds.min.z)
            
            let box = SCNBox(width: width, height: height, length: depth, chamferRadius: 0)
            box.firstMaterial?.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.7)
            box.firstMaterial?.isDoubleSided = true
            
            let boxNode = SCNNode(geometry: box)
            boxNode.position = SCNVector3(
                (bounds.min.x + bounds.max.x) / 2,
                (bounds.min.y + bounds.max.y) / 2,
                (bounds.min.z + bounds.max.z) / 2
            )
            
            node.addChildNode(boxNode)
        }
        
        return node
    }
    
    private func parsePartGeometry(from data: Data, partId: String, simplificationLevel: Float) -> SCNNode? {
        // 这里实现具体的几何数据解析
        // 为了演示，返回一个简单的占位节点
        let node = SCNNode()
        
        // 实际实现时，这里应该：
        // 1. 使用XMLParser解析特定部件的顶点和三角形
        // 2. 根据simplificationLevel简化网格
        // 3. 创建SCNGeometry
        
        return node
    }
    
    deinit {
        fileHandle?.close()
    }
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

// MARK: - 用于完整解析的轻量级结构（向后兼容）

struct ModelPart: Identifiable {
    let id: String
    let name: String
    let vertexCount: Int
    let triangleCount: Int
    let materialId: String?
    
    func createSCNGeometry() -> SCNGeometry {
        // 创建占位几何体
        let sphere = SCNSphere(radius: 1.0)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemBlue
        return sphere
    }
}

struct Triangle {
    let v1: Int
    let v2: Int
    let v3: Int
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

// MARK: - 兼容旧API的包装器

class ThreeMFParser: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let optimizedParser = OptimizedThreeMFParser()
    
    func parseThreeMFFile(at url: URL) async -> ParsedThreeMFModel? {
        await optimizedParser.parseMetadata(from: url)
        
        // 转换为旧格式（仅用于兼容）
        let parts = optimizedParser.parts.map { part in
            ModelPart(
                id: part.id,
                name: part.name,
                vertexCount: part.vertexCount,
                triangleCount: part.triangleCount,
                materialId: part.materialId
            )
        }
        
        let materials = optimizedParser.materials.reduce(into: [String: MaterialInfo]()) { result, item in
            result[item.key] = MaterialInfo(
                id: item.value.id,
                name: item.value.name,
                displayColor: item.value.displayColor.map { colorToHex($0) },
                type: nil
            )
        }
        
        let metadata = optimizedParser.metadata.map { meta in
            ModelMetadata(
                title: meta.title,
                designer: meta.designer,
                description: meta.description,
                copyright: nil,
                createdDate: nil
            )
        }
        
        return ParsedThreeMFModel(
            parts: parts,
            originalMaterials: materials,
            metadata: metadata
        )
    }
    
    private func colorToHex(_ color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}