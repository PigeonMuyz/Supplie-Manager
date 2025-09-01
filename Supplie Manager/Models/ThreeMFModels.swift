import Foundation
import SceneKit
import Compression
import UIKit

// MARK: - 3MF 数据模型

/// ZIP文件中的文件索引信息
struct FileIndex {
    let fileName: String
    let offset: Int
    let compressedSize: Int
    let uncompressedSize: Int
    let compressionMethod: UInt16
}

/// 部件描述信息（超轻量级）
struct PartInfo: Identifiable {
    let id: String
    let name: String
    let vertexCount: Int
    let triangleCount: Int
    let materialId: String?
    let fileIndex: FileIndex // 存储文件在ZIP中的位置，而非内容
    let directXMLData: Data? // 对于简单模型，直接存储XML数据
    
    // 主构造函数（用于流式解析）
    init(id: String, name: String, vertexCount: Int, triangleCount: Int, materialId: String?, fileIndex: FileIndex) {
        self.id = id
        self.name = name
        self.vertexCount = vertexCount
        self.triangleCount = triangleCount
        self.materialId = materialId
        self.fileIndex = fileIndex
        self.directXMLData = nil
    }
    
    // 简单模型构造函数（用于传统解析）
    init(id: String, name: String, vertexCount: Int, triangleCount: Int, materialId: String?, directXMLData: Data) {
        self.id = id
        self.name = name
        self.vertexCount = vertexCount
        self.triangleCount = triangleCount
        self.materialId = materialId
        self.directXMLData = directXMLData
        // 创建一个空的fileIndex
        self.fileIndex = FileIndex(
            fileName: "direct.model",
            offset: 0,
            compressedSize: directXMLData.count,
            uncompressedSize: directXMLData.count,
            compressionMethod: 0
        )
    }
}

/// ZIP数据提供者协议
protocol ZipDataProvider: AnyObject {
    func getZipData() -> Data?
}

/// ZIP数据管理器
class ThreeMFDataManager: ZipDataProvider, ObservableObject {
    private var _zipData: Data?
    
    init(zipData: Data) {
        self._zipData = zipData
    }
    
    func getZipData() -> Data? {
        return _zipData
    }
    
    deinit {
        print("ThreeMFDataManager 被释放")
        _zipData = nil
    }
}

/// 解析后的3MF模型数据（轻量级）
struct ParsedThreeMFModel {
    let partInfos: [PartInfo] // 改为存储部件信息而不是完整部件
    let originalMaterials: [String: MaterialInfo]
    let metadata: ModelMetadata?
    let dataManager: ThreeMFDataManager? // 数据管理器，对于简单模型可能为nil
    
    // 懒加载创建特定部件的方法（流式解析）
    func createModelPart(for partInfo: PartInfo) -> ModelPart? {
        print("按需解析部件: \(partInfo.name)")
        
        // 对于简单模型，直接使用存储的数据
        if let dataManager = dataManager {
            // 通过数据管理器获取ZIP数据
            guard let zipData = dataManager.getZipData() else {
                print("无法获取ZIP数据")
                return nil
            }
            
            // 从ZIP文件中提取特定文件的数据
            guard let xmlData = ThreeMFParser.extractSpecificFile(
                from: zipData,
                fileIndex: partInfo.fileIndex
            ) else {
                print("无法提取文件数据: \(partInfo.fileIndex.fileName)")
                return nil
            }
            
            guard let xmlString = String(data: xmlData, encoding: .utf8) else {
                print("无法解析XML编码")
                return nil
            }
            
            // 解析几何数据
            let vertices = ThreeMFParser.parseVerticesFromXML(xmlString)
            let triangles = ThreeMFParser.parseTrianglesFromXML(xmlString)
            
            return ModelPart(
                id: partInfo.id,
                name: partInfo.name,
                vertices: vertices,
                triangles: triangles,
                materialId: partInfo.materialId
            )
        } else {
            // 简单模型：从直接存储的数据解析
            if let directData = partInfo.directXMLData {
                guard let xmlString = String(data: directData, encoding: .utf8) else {
                    print("无法解析XML编码")
                    return nil
                }
                
                let vertices = ThreeMFParser.parseVerticesFromXML(xmlString)
                let triangles = ThreeMFParser.parseTrianglesFromXML(xmlString)
                
                return ModelPart(
                    id: partInfo.id,
                    name: partInfo.name,
                    vertices: vertices,
                    triangles: triangles,
                    materialId: partInfo.materialId
                )
            } else {
                print("无法获取部件数据")
                return nil
            }
        }
    }
    
    // 兼容性：提供parts属性（已废弃，但保持向后兼容）
    var parts: [ModelPart] {
        return partInfos.compactMap { createModelPart(for: $0) }
    }
}

/// 模型零件（懒加载模式）
struct ModelPart: Identifiable {
    let id: String
    let name: String
    let vertices: [SCNVector3]
    let triangles: [Triangle]
    let materialId: String?
    
    // 移除自动创建的SCNGeometry，改为按需创建
    
    /// 按需创建SceneKit几何体
    func createSCNGeometry() -> SCNGeometry {
        print("为部件 \(name) 创建几何体：\(vertices.count) 顶点，\(triangles.count) 三角形")
        
        let vertexSource = SCNGeometrySource(vertices: vertices)
        
        // 转换三角形索引为Int32数组
        var indices: [Int32] = []
        for triangle in triangles {
            indices.append(contentsOf: [Int32(triangle.v1), Int32(triangle.v2), Int32(triangle.v3)])
        }
        
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: indexData, primitiveType: .triangles, primitiveCount: triangles.count, bytesPerIndex: MemoryLayout<Int32>.size)
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        
        // 设置默认材质
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemBlue
        material.lightingModel = .physicallyBased
        geometry.materials = [material]
        
        return geometry
    }
}

/// 三角形面
struct Triangle {
    let v1: Int
    let v2: Int  
    let v3: Int
}

/// 材料信息
struct MaterialInfo {
    let id: String
    let name: String?
    let displayColor: String?  // 十六进制颜色值
    let type: String?
}

/// 模型元数据
struct ModelMetadata {
    let title: String?
    let designer: String?
    let description: String?
    let copyright: String?
    let createdDate: Date?
}

// MARK: - 3MF 解析器

class ThreeMFParser: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 流式解析的临时存储
    private var streamingModel: ParsedThreeMFModel?
    // 全局解析模型存储
    private var parsedModel: ParsedThreeMFModel?
    
    /// 解析3MF文件
    func parseThreeMFFile(at url: URL) async -> ParsedThreeMFModel? {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let model = try await parse3MFFile(url: url)
            await MainActor.run {
                isLoading = false
            }
            return model
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "解析失败: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    private func parse3MFFile(url: URL) async throws -> ParsedThreeMFModel {
        print("开始解析3MF文件: \(url.lastPathComponent)")
        
        // 读取3MF文件数据
        let fileData = try Data(contentsOf: url)
        print("文件大小: \(fileData.count) 字节")
        
        // 尝试解析3MF文件
        if let xmlData = extractXMLFromZip(data: fileData) {
            print("成功提取XML数据，大小: \(xmlData.count) 字节")
            return try parseXMLModel(data: xmlData)
        } else {
            print("无法提取XML数据，使用测试模型")
            throw ThreeMFError.invalidFileFormat("无法从3MF文件中提取XML数据")
        }
    }
    
    private func extractXMLFromZip(data: Data) -> Data? {
        print("开始解析ZIP文件结构...")
        
        // 检查ZIP文件签名
        guard data.count >= 4 else {
            print("文件太小，不是有效的ZIP文件")
            return nil
        }
        
        let signature = data[0..<4]
        let zipSignature = Data([0x50, 0x4B, 0x03, 0x04]) // PK\003\004
        
        print("ZIP签名: \(signature.map { String(format: "%02X", $0) }.joined())")
        
        if signature != zipSignature {
            print("不是标准ZIP文件签名，尝试查找ZIP结构...")
            return findXMLInNonStandardZip(data: data)
        }
        
        // 解析ZIP文件条目，返回合并的模型数据
        return parseComplexZipStructure(data: data)
    }
    
    private func parseZipEntries(data: Data) -> Data? {
        var offset = 0
        
        while offset < data.count - 30 { // 最小ZIP条目头大小是30字节
            // 检查本地文件头签名 PK\003\004
            let headerSignature = data[offset..<offset+4]
            let localHeaderSig = Data([0x50, 0x4B, 0x03, 0x04])
            
            if headerSignature != localHeaderSig {
                offset += 1
                continue
            }
            
            print("找到ZIP条目在偏移: \(offset)")
            
            // 读取文件名长度
            guard offset + 30 <= data.count else { break }
            
            // 确保不会越界
            guard offset + 29 < data.count else {
                print("ZIP条目头不完整")
                offset += 30
                continue
            }
            
            let fileNameLength = UInt16(data[offset + 26]) | (UInt16(data[offset + 27]) << 8)
            let extraFieldLength = UInt16(data[offset + 28]) | (UInt16(data[offset + 29]) << 8)
            
            // 读取压缩大小和未压缩大小（小端序）
            let compressedSize = UInt32(data[offset + 18]) | (UInt32(data[offset + 19]) << 8) | (UInt32(data[offset + 20]) << 16) | (UInt32(data[offset + 21]) << 24)
            let uncompressedSize = UInt32(data[offset + 22]) | (UInt32(data[offset + 23]) << 8) | (UInt32(data[offset + 24]) << 16) | (UInt32(data[offset + 25]) << 24)
            
            print("文件名长度: \(fileNameLength), 压缩大小: \(compressedSize), 未压缩大小: \(uncompressedSize)")
            
            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + Int(fileNameLength)
            
            guard fileNameEnd <= data.count else {
                print("文件名超出范围")
                offset += 30
                continue
            }
            
            let fileNameData = data[fileNameStart..<fileNameEnd]
            guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                print("无法解析文件名")
                offset = fileNameEnd + Int(extraFieldLength) + Int(compressedSize)
                continue
            }
            
            print("找到文件: \(fileName)")
            
            // 检查是否是3D模型文件
            if fileName.hasSuffix("3dmodel.model") || fileName.hasSuffix(".model") {
                let dataStart = fileNameEnd + Int(extraFieldLength)
                
                // 处理ZIP64或错误的大小值
                var actualSize = Int(compressedSize)
                if compressedSize == 0xFFFFFFFF {
                    // ZIP64格式或错误值，尝试使用未压缩大小
                    actualSize = Int(uncompressedSize)
                    print("检测到ZIP64或特殊格式，使用未压缩大小: \(actualSize)")
                }
                
                // 如果大小仍然异常，尝试推断大小
                if actualSize > data.count || actualSize == 0 {
                    actualSize = data.count - dataStart
                    print("大小异常，使用推断大小: \(actualSize)")
                }
                
                let dataEnd = dataStart + actualSize
                
                guard dataEnd <= data.count && dataStart < data.count else {
                    print("数据范围无效: start=\(dataStart), end=\(dataEnd), fileSize=\(data.count)")
                    offset += 30
                    continue
                }
                
                let fileData = data[dataStart..<dataEnd]
                print("提取文件数据，大小: \(fileData.count) 字节")
                
                // 检查数据是否像XML
                if let dataString = String(data: fileData.prefix(100), encoding: .utf8),
                   dataString.contains("<?xml") {
                    print("数据看起来像XML，直接返回")
                    return fileData
                } else {
                    print("数据前100字节: \(fileData.prefix(100).map { String(format: "%02X", $0) }.joined(separator: " "))")
                    // 检查是否需要解压缩（compression method在偏移8-9）
                    let compressionMethod = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
                    print("压缩方法: \(compressionMethod)")
                    
                    if compressionMethod == 0 {
                        // 无压缩，直接返回数据
                        return fileData
                    } else if compressionMethod == 8 {
                        // Deflate压缩，需要解压缩
                        print("文件使用Deflate压缩，开始解压缩...")
                        if let decompressedData = decompressData(fileData) {
                            print("解压缩成功，大小: \(decompressedData.count) 字节")
                            return decompressedData
                        } else {
                            print("解压缩失败")
                            return nil
                        }
                    } else {
                        print("不支持的压缩方法: \(compressionMethod)")
                        return nil
                    }
                }
            }
            
            // 跳到下一个条目，使用更安全的计算
            let nextOffset = fileNameEnd + Int(extraFieldLength) + max(0, min(Int(compressedSize), data.count - fileNameEnd - Int(extraFieldLength)))
            offset = nextOffset
        }
        
        print("未找到3D模型文件")
        return nil
    }
    
    private func parseComplexZipStructure(data: Data) -> Data? {
        // 根据文件大小决定使用哪种解析策略
        let fileSizeThreshold = 10 * 1024 * 1024 // 10MB
        
        if data.count > fileSizeThreshold {
            print("大文件检测，使用流式解析")
            // 大文件：使用流式解析
            let fileIndexes = buildFileIndexes(from: data)
            if let model = buildLightweightModel(from: fileIndexes, zipData: data) {
                // 将ParsedThreeMFModel存储到全局变量中，以便后续使用
                parsedModel = model
                
                // 返回空的XML数据，触发使用parseMultiplePartsFromXML
                return "<?xml version='1.0' encoding='UTF-8'?><model></model>".data(using: .utf8)
            }
            return nil
        } else {
            print("小文件检测，使用传统解析")
            // 小文件：使用传统解析
            return parseZipEntries(data: data)
        }
    }
    
    private func buildFileIndexes(from data: Data) -> [FileIndex] {
        var fileIndexes: [FileIndex] = []
        var offset = 0
        
        print("开始构建文件索引...")
        
        while offset < data.count - 30 {
            // 检查本地文件头签名
            let headerSignature = data[offset..<offset+4]
            let localHeaderSig = Data([0x50, 0x4B, 0x03, 0x04])
            
            if headerSignature != localHeaderSig {
                offset += 1
                continue
            }
            
            // 读取文件头信息
            guard offset + 30 <= data.count else { break }
            
            let fileNameLength = UInt16(data[offset + 26]) | (UInt16(data[offset + 27]) << 8)
            let extraFieldLength = UInt16(data[offset + 28]) | (UInt16(data[offset + 29]) << 8)
            let compressedSize = UInt32(data[offset + 18]) | (UInt32(data[offset + 19]) << 8) | (UInt32(data[offset + 20]) << 16) | (UInt32(data[offset + 21]) << 24)
            let uncompressedSize = UInt32(data[offset + 22]) | (UInt32(data[offset + 23]) << 8) | (UInt32(data[offset + 24]) << 16) | (UInt32(data[offset + 25]) << 24)
            let compressionMethod = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
            
            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + Int(fileNameLength)
            
            guard fileNameEnd <= data.count else {
                offset += 30
                continue
            }
            
            let fileNameData = data[fileNameStart..<fileNameEnd]
            guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                offset = fileNameEnd + Int(extraFieldLength) + Int(compressedSize)
                continue
            }
            
            // 只为模型文件创建索引
            if fileName.hasSuffix(".model") {
                var actualCompressedSize = Int(compressedSize)
                var actualUncompressedSize = Int(uncompressedSize)
                
                // 处理ZIP64格式
                if compressedSize == 0xFFFFFFFF {
                    actualCompressedSize = data.count - (fileNameEnd + Int(extraFieldLength))
                    actualUncompressedSize = Int(uncompressedSize)
                }
                
                let fileIndex = FileIndex(
                    fileName: fileName,
                    offset: fileNameEnd + Int(extraFieldLength),
                    compressedSize: actualCompressedSize,
                    uncompressedSize: actualUncompressedSize,
                    compressionMethod: compressionMethod
                )
                
                fileIndexes.append(fileIndex)
                print("索引文件: \(fileName), 压缩大小: \(actualCompressedSize)")
            }
            
            // 跳到下一个条目
            offset = fileNameEnd + Int(extraFieldLength) + max(0, min(Int(compressedSize), data.count - fileNameEnd - Int(extraFieldLength)))
        }
        
        print("完成索引构建，找到 \(fileIndexes.count) 个模型文件")
        return fileIndexes
    }
    
    private func buildLightweightModel(from fileIndexes: [FileIndex], zipData: Data) -> ParsedThreeMFModel? {
        var partInfos: [PartInfo] = []
        
        print("开始构建轻量级模型描述...")
        
        // 创建数据管理器
        let dataManager = ThreeMFDataManager(zipData: zipData)
        
        for fileIndex in fileIndexes {
            // 只读取很小的数据样本来计算顶点和三角形数量
            if let sampleData = extractSampleData(from: zipData, fileIndex: fileIndex) {
                let sampleString = String(data: sampleData, encoding: .utf8) ?? ""
                
                // 快速估算几何数据数量（不完全解析）
                let vertexCount = estimateVertexCount(from: sampleString)
                let triangleCount = estimateTriangleCount(from: sampleString)
                
                if vertexCount > 0 && triangleCount > 0 {
                    let objectName = fileIndex.fileName.components(separatedBy: "/").last?
                        .replacingOccurrences(of: ".model", with: "") ?? "unknown"
                    
                    let partInfo = PartInfo(
                        id: objectName,
                        name: objectName.replacingOccurrences(of: "_", with: " ").capitalized,
                        vertexCount: vertexCount,
                        triangleCount: triangleCount,
                        materialId: nil,
                        fileIndex: fileIndex
                    )
                    
                    partInfos.append(partInfo)
                    print("部件索引: \(partInfo.name) - 预估 \(vertexCount) 顶点, \(triangleCount) 三角形")
                }
            }
        }
        
        // 构建材料信息
        let materials = ["default": MaterialInfo(
            id: "default",
            name: "3MF材料",
            displayColor: "#4A9EFF",
            type: "Unknown"
        )]
        
        // 构建元数据
        let metadata = ModelMetadata(
            title: "3MF模型",
            designer: nil,
            description: "从3MF文件解析的模型，包含\(partInfos.count)个部件",
            copyright: nil,
            createdDate: Date()
        )
        
        return ParsedThreeMFModel(
            partInfos: partInfos,
            originalMaterials: materials,
            metadata: metadata,
            dataManager: dataManager
        )
    }
    
    private func extractSampleData(from zipData: Data, fileIndex: FileIndex) -> Data? {
        // 只提取文件的前面一小部分来估算数量
        let sampleSize = min(50000, fileIndex.compressedSize) // 最多50KB样本
        let dataStart = fileIndex.offset
        let dataEnd = dataStart + sampleSize
        
        guard dataEnd <= zipData.count && dataStart < zipData.count else {
            return nil
        }
        
        let sampleCompressedData = zipData[dataStart..<dataEnd]
        
        // 如果是压缩的，尝试解压样本
        if fileIndex.compressionMethod == 8 {
            return ThreeMFParser.decompressDataStatic(sampleCompressedData)
        } else {
            return sampleCompressedData
        }
    }
    
    private func estimateVertexCount(from sampleXML: String) -> Int {
        // 通过计算样本中的vertex标签数量来估算总数
        let vertexMatches = sampleXML.components(separatedBy: "<vertex").count - 1
        
        // 如果样本不完整，根据文件大小估算倍数
        if sampleXML.count < 50000 {
            return vertexMatches
        } else {
            // 假设样本只包含文件的一小部分，估算总数
            let estimatedMultiplier = max(1, sampleXML.count / 10000)
            return vertexMatches * estimatedMultiplier
        }
    }
    
    private func estimateTriangleCount(from sampleXML: String) -> Int {
        // 通过计算样本中的triangle标签数量来估算总数
        let triangleMatches = sampleXML.components(separatedBy: "<triangle").count - 1
        
        // 如果样本不完整，根据文件大小估算倍数
        if sampleXML.count < 50000 {
            return triangleMatches
        } else {
            // 假设样本只包含文件的一小部分，估算总数
            let estimatedMultiplier = max(1, sampleXML.count / 10000)
            return triangleMatches * estimatedMultiplier
        }
    }
    
    private func extractAllRelevantFiles(data: Data, extractedFiles: inout [String: Data]) {
        var offset = 0
        
        while offset < data.count - 30 {
            // 检查本地文件头签名
            let headerSignature = data[offset..<offset+4]
            let localHeaderSig = Data([0x50, 0x4B, 0x03, 0x04])
            
            if headerSignature != localHeaderSig {
                offset += 1
                continue
            }
            
            print("找到ZIP条目在偏移: \(offset)")
            
            // 读取文件头信息
            guard offset + 30 <= data.count else { break }
            
            let fileNameLength = UInt16(data[offset + 26]) | (UInt16(data[offset + 27]) << 8)
            let extraFieldLength = UInt16(data[offset + 28]) | (UInt16(data[offset + 29]) << 8)
            let compressedSize = UInt32(data[offset + 18]) | (UInt32(data[offset + 19]) << 8) | (UInt32(data[offset + 20]) << 16) | (UInt32(data[offset + 21]) << 24)
            let uncompressedSize = UInt32(data[offset + 22]) | (UInt32(data[offset + 23]) << 8) | (UInt32(data[offset + 24]) << 16) | (UInt32(data[offset + 25]) << 24)
            let compressionMethod = UInt16(data[offset + 8]) | (UInt16(data[offset + 9]) << 8)
            
            print("文件名长度: \(fileNameLength), 压缩大小: \(compressedSize), 未压缩大小: \(uncompressedSize)")
            
            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + Int(fileNameLength)
            
            guard fileNameEnd <= data.count else {
                offset += 30
                continue
            }
            
            let fileNameData = data[fileNameStart..<fileNameEnd]
            guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                offset = fileNameEnd + Int(extraFieldLength) + Int(compressedSize)
                continue
            }
            
            print("找到文件: \(fileName)")
            
            // 检查是否是我们需要的文件
            if fileName.hasSuffix(".model") || fileName.hasSuffix(".xml") {
                let dataStart = fileNameEnd + Int(extraFieldLength)
                
                var actualSize = Int(compressedSize)
                if compressedSize == 0xFFFFFFFF {
                    actualSize = Int(uncompressedSize)
                }
                
                if actualSize > data.count || actualSize == 0 {
                    actualSize = data.count - dataStart
                }
                
                let dataEnd = dataStart + actualSize
                guard dataEnd <= data.count && dataStart < data.count else {
                    offset += 30
                    continue
                }
                
                let fileData = data[dataStart..<dataEnd]
                
                // 解压缩数据
                var finalData: Data
                if compressionMethod == 8 {
                    print("解压缩文件: \(fileName)")
                    if let decompressedData = decompressData(fileData) {
                        finalData = decompressedData
                    } else {
                        print("解压缩失败，使用原始数据")
                        finalData = fileData
                    }
                } else {
                    finalData = fileData
                }
                
                extractedFiles[fileName] = finalData
                print("提取文件成功: \(fileName), 大小: \(finalData.count)")
            }
            
            // 跳到下一个条目
            offset = fileNameEnd + Int(extraFieldLength) + max(0, min(Int(compressedSize), data.count - fileNameEnd - Int(extraFieldLength)))
        }
    }
    
    private func buildMultiPartModel(from extractedFiles: [String: Data]) -> Data? {
        var mainModelFile: Data?
        var objectFiles: [String: Data] = [:]
        
        // 分类文件
        for (fileName, fileData) in extractedFiles {
            if fileName.hasSuffix("3dmodel.model") {
                mainModelFile = fileData
                print("找到主模型文件: \(fileName)")
            } else if fileName.contains("Objects/") && fileName.hasSuffix(".model") {
                objectFiles[fileName] = fileData
                print("找到对象文件: \(fileName)")
            }
        }
        
        // 构建包含所有部件的XML
        var combinedXML = """
        <?xml version='1.0' encoding='UTF-8'?>
        <model xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" unit="millimeter">
        <resources>
        """
        
        var partIndex = 0
        
        // 处理主模型文件
        if let mainModel = mainModelFile {
            let mainModelString = String(data: mainModel, encoding: .utf8) ?? ""
            let vertices = ThreeMFParser.parseVerticesFromXML(mainModelString)
            let triangles = ThreeMFParser.parseTrianglesFromXML(mainModelString)
            
            if !vertices.isEmpty && !triangles.isEmpty {
                print("主模型包含几何数据: \(vertices.count) 顶点, \(triangles.count) 三角形")
                combinedXML += buildMeshXML(vertices: vertices, triangles: triangles, id: "part_\(partIndex)")
                partIndex += 1
            }
        }
        
        // 处理对象文件
        for (fileName, objectData) in objectFiles {
            guard let objectString = String(data: objectData, encoding: .utf8) else {
                continue
            }
            
            let vertices = ThreeMFParser.parseVerticesFromXML(objectString)
            let triangles = ThreeMFParser.parseTrianglesFromXML(objectString)
            
            if !vertices.isEmpty && !triangles.isEmpty {
                print("对象文件包含几何数据: \(fileName) - \(vertices.count) 顶点, \(triangles.count) 三角形")
                let objectName = fileName.components(separatedBy: "/").last?.replacingOccurrences(of: ".model", with: "") ?? "part_\(partIndex)"
                combinedXML += buildMeshXML(vertices: vertices, triangles: triangles, id: objectName)
                partIndex += 1
            }
        }
        
        combinedXML += """
        </resources>
        <build>
        """
        
        // 添加构建项引用所有部件
        for i in 0..<partIndex {
            let partName = i == 0 && mainModelFile != nil ? "part_0" : objectFiles.keys.sorted()[safe: i - (mainModelFile != nil ? 1 : 0)]?.components(separatedBy: "/").last?.replacingOccurrences(of: ".model", with: "") ?? "part_\(i)"
            combinedXML += "<item objectid=\"\(partName)\"/>\n"
        }
        
        combinedXML += """
        </build>
        </model>
        """
        
        print("构建的合并XML包含 \(partIndex) 个部件")
        return combinedXML.data(using: .utf8)
    }
    
    private func buildMeshXML(vertices: [SCNVector3], triangles: [Triangle], id: String) -> String {
        var meshXML = "<object id=\"\(id)\" type=\"model\">\n<mesh>\n<vertices>\n"
        
        for vertex in vertices {
            meshXML += "<vertex x=\"\(vertex.x)\" y=\"\(vertex.y)\" z=\"\(vertex.z)\"/>\n"
        }
        
        meshXML += "</vertices>\n<triangles>\n"
        
        for triangle in triangles {
            meshXML += "<triangle v1=\"\(triangle.v1)\" v2=\"\(triangle.v2)\" v3=\"\(triangle.v3)\"/>\n"
        }
        
        meshXML += "</triangles>\n</mesh>\n</object>\n"
        
        return meshXML
    }
    
    private func parseMultiplePartsFromXML(_ xml: String) -> [PartInfo] {
        // 这个方法现在被废弃，因为我们使用流式解析
        // 如果调用到这里，说明是简单的XML数据，直接处理
        print("解析简单XML数据（非流式）")
        
        let vertices = ThreeMFParser.parseVerticesFromXML(xml)
        let triangles = ThreeMFParser.parseTrianglesFromXML(xml)
        
        if !vertices.isEmpty && !triangles.isEmpty {
            // 创建一个临时的FileIndex来兼容新结构
            let tempFileIndex = FileIndex(
                fileName: "direct.model",
                offset: 0,
                compressedSize: xml.data(using: .utf8)?.count ?? 0,
                uncompressedSize: xml.data(using: .utf8)?.count ?? 0,
                compressionMethod: 0
            )
            
            let tempData = xml.data(using: .utf8) ?? Data()
            
            let partInfo = PartInfo(
                id: "main-model",
                name: "主模型",
                vertexCount: vertices.count,
                triangleCount: triangles.count,
                materialId: nil,
                directXMLData: tempData
            )
            
            return [partInfo]
        }
        
        return []
    }
    
    private func mergeModelWithObjects(mainModel: Data, objectFiles: [String: Data]) -> Data? {
        guard let mainModelString = String(data: mainModel, encoding: .utf8) else {
            return nil
        }
        
        print("开始合并主模型和对象文件...")
        
        // 查找主模型中的对象引用
        var mergedModel = mainModelString
        
        // 为每个对象文件添加几何数据
        for (fileName, objectData) in objectFiles {
            guard let objectString = String(data: objectData, encoding: .utf8) else {
                continue
            }
            
            print("合并对象文件: \(fileName)")
            
            // 提取对象文件中的vertices和triangles
            let vertices = ThreeMFParser.parseVerticesFromXML(objectString)
            let triangles = ThreeMFParser.parseTrianglesFromXML(objectString)
            
            if !vertices.isEmpty && !triangles.isEmpty {
                print("从对象文件 \(fileName) 提取到 \(vertices.count) 个顶点, \(triangles.count) 个三角形")
                
                // 将几何数据插入到主模型中
                if let insertionPoint = mergedModel.range(of: "</resources>") {
                    var geometryXML = "\n<mesh>\n<vertices>\n"
                    
                    for vertex in vertices {
                        geometryXML += "<vertex x=\"\(vertex.x)\" y=\"\(vertex.y)\" z=\"\(vertex.z)\"/>\n"
                    }
                    
                    geometryXML += "</vertices>\n<triangles>\n"
                    
                    for triangle in triangles {
                        geometryXML += "<triangle v1=\"\(triangle.v1)\" v2=\"\(triangle.v2)\" v3=\"\(triangle.v3)\"/>\n"
                    }
                    
                    geometryXML += "</triangles>\n</mesh>\n"
                    
                    mergedModel.insert(contentsOf: geometryXML, at: insertionPoint.lowerBound)
                    break // 使用第一个有效的对象文件
                }
            }
        }
        
        return mergedModel.data(using: .utf8)
    }
    
    private func decompressData(_ compressedData: Data) -> Data? {
        return compressedData.withUnsafeBytes { bytes in
            let _ = UnsafeBufferPointer<UInt8>(start: bytes.bindMemory(to: UInt8.self).baseAddress, count: compressedData.count)
            
            // 使用Foundation的解压缩API
            do {
                let decompressedData = try (compressedData as NSData).decompressed(using: .zlib)
                return decompressedData as Data
            } catch {
                print("zlib解压缩失败: \(error)")
                
                // 尝试使用lzfse解压缩
                do {
                    let decompressedData = try (compressedData as NSData).decompressed(using: .lzfse)
                    return decompressedData as Data
                } catch {
                    print("lzfse解压缩也失败: \(error)")
                    return nil
                }
            }
        }
    }
    
    private func findXMLInNonStandardZip(data: Data) -> Data? {
        print("在非标准ZIP中查找XML...")
        
        // 直接查找XML声明
        let xmlDeclaration = "<?xml".data(using: .utf8)!
        
        guard let xmlStart = data.range(of: xmlDeclaration) else {
            print("未找到XML声明")
            return nil
        }
        
        print("找到XML声明在位置: \(xmlStart.lowerBound)")
        
        // 查找可能的结束标签
        let possibleEndTags = ["</model>", "</3mf>"]
        
        for endTag in possibleEndTags {
            if let endTagData = endTag.data(using: .utf8),
               let endRange = data.range(of: endTagData, in: xmlStart.lowerBound..<data.count) {
                let xmlData = data[xmlStart.lowerBound...endRange.upperBound-1]
                print("找到XML数据，结束标签: \(endTag), 大小: \(xmlData.count)")
                return xmlData
            }
        }
        
        print("未找到合适的XML结束标签")
        return nil
    }
    
    
    private func parseXMLModel(data: Data) throws -> ParsedThreeMFModel {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw ThreeMFError.invalidXML("无法解析XML编码")
        }
        
        print("XML内容预览: \(String(xmlString.prefix(200)))")
        
        // 尝试解析多部件模型信息（轻量级）
        let partInfos = parseMultiplePartsFromXML(xmlString)
        
        if partInfos.isEmpty {
            print("未找到任何有效的模型部件，使用测试模型")
            throw ThreeMFError.invalidXML("未找到有效的几何数据")
        }
        
        let materials = ["default": MaterialInfo(
            id: "default",
            name: "3MF材料",
            displayColor: "#4A9EFF",
            type: "Unknown"
        )]
        
        let metadata = ModelMetadata(
            title: "3MF模型",
            designer: nil,
            description: "从3MF文件解析的模型，包含\(partInfos.count)个部件",
            copyright: nil,
            createdDate: Date()
        )
        
        return ParsedThreeMFModel(
            partInfos: partInfos,
            originalMaterials: materials,
            metadata: metadata,
            dataManager: nil
        )
    }
    
    /// 从ZIP文件中提取特定文件
    static func extractSpecificFile(from zipData: Data, fileIndex: FileIndex) -> Data? {
        let dataStart = fileIndex.offset
        let dataEnd = dataStart + fileIndex.compressedSize
        
        guard dataEnd <= zipData.count && dataStart < zipData.count else {
            print("文件数据超出ZIP范围")
            return nil
        }
        
        let fileData = zipData[dataStart..<dataEnd]
        
        // 根据压缩方法处理数据
        if fileIndex.compressionMethod == 8 {
            // Deflate压缩，需要解压缩
            if let decompressedData = decompressDataStatic(fileData) {
                return decompressedData
            } else {
                print("解压缩失败")
                return nil
            }
        } else {
            // 无压缩
            return fileData
        }
    }
    
    /// 静态解压缩方法
    static func decompressDataStatic(_ compressedData: Data) -> Data? {
        return compressedData.withUnsafeBytes { bytes in
            let _ = UnsafeBufferPointer<UInt8>(start: bytes.bindMemory(to: UInt8.self).baseAddress, count: compressedData.count)
            
            // 使用Foundation的解压缩API
            do {
                let decompressedData = try (compressedData as NSData).decompressed(using: .zlib)
                return decompressedData as Data
            } catch {
                print("zlib解压缩失败: \(error)")
                
                // 尝试使用lzfse解压缩
                do {
                    let decompressedData = try (compressedData as NSData).decompressed(using: .lzfse)
                    return decompressedData as Data
                } catch {
                    print("lzfse解压缩也失败: \(error)")
                    return nil
                }
            }
        }
    }
    
    static func parseVerticesFromXML(_ xml: String) -> [SCNVector3] {
        var vertices: [SCNVector3] = []
        
        // 3MF vertex格式: <vertex x="..." y="..." z="..."/>
        let pattern = #"<vertex\s+x=['""]([^'""]*)['"']\s+y=['""]([^'""]*)['"']\s+z=['""]([^'""]*)['"'][^>]*/?>"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml))
            
            for match in matches {
                if match.numberOfRanges >= 4,
                   let xRange = Range(match.range(at: 1), in: xml),
                   let yRange = Range(match.range(at: 2), in: xml),
                   let zRange = Range(match.range(at: 3), in: xml) {
                    
                    let xStr = String(xml[xRange])
                    let yStr = String(xml[yRange])
                    let zStr = String(xml[zRange])
                    
                    if let x = Float(xStr), let y = Float(yStr), let z = Float(zStr) {
                        vertices.append(SCNVector3(x, y, z))
                    }
                }
            }
        } catch {
            print("顶点解析正则表达式错误: \(error)")
        }
        
        return vertices
    }
    
    static func parseTrianglesFromXML(_ xml: String) -> [Triangle] {
        var triangles: [Triangle] = []
        
        // 3MF triangle格式: <triangle v1="..." v2="..." v3="..."/>
        let pattern = #"<triangle\s+v1=['""]([^'""]*)['"']\s+v2=['""]([^'""]*)['"']\s+v3=['""]([^'""]*)['"'][^>]*/?>"#
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml))
            
            for match in matches {
                if match.numberOfRanges >= 4,
                   let v1Range = Range(match.range(at: 1), in: xml),
                   let v2Range = Range(match.range(at: 2), in: xml),
                   let v3Range = Range(match.range(at: 3), in: xml) {
                    
                    let v1Str = String(xml[v1Range])
                    let v2Str = String(xml[v2Range])
                    let v3Str = String(xml[v3Range])
                    
                    if let v1 = Int(v1Str), let v2 = Int(v2Str), let v3 = Int(v3Str) {
                        triangles.append(Triangle(v1: v1, v2: v2, v3: v3))
                    }
                }
            }
        } catch {
            print("三角形解析正则表达式错误: \(error)")
        }
        
        return triangles
    }
    
    /// 创建测试用的立方体模型
    private func createTestCube() -> ParsedThreeMFModel {
        // 立方体的8个顶点
        let vertices: [SCNVector3] = [
            SCNVector3(-1, -1, -1), // 0
            SCNVector3(1, -1, -1),  // 1
            SCNVector3(1, 1, -1),   // 2
            SCNVector3(-1, 1, -1),  // 3
            SCNVector3(-1, -1, 1),  // 4
            SCNVector3(1, -1, 1),   // 5
            SCNVector3(1, 1, 1),    // 6
            SCNVector3(-1, 1, 1)    // 7
        ]
        
        // 立方体的12个三角形面（每个面2个三角形）
        let triangles: [Triangle] = [
            // 前面
            Triangle(v1: 0, v2: 1, v3: 2),
            Triangle(v1: 0, v2: 2, v3: 3),
            // 后面
            Triangle(v1: 4, v2: 6, v3: 5),
            Triangle(v1: 4, v2: 7, v3: 6),
            // 左面
            Triangle(v1: 0, v2: 3, v3: 7),
            Triangle(v1: 0, v2: 7, v3: 4),
            // 右面
            Triangle(v1: 1, v2: 5, v3: 6),
            Triangle(v1: 1, v2: 6, v3: 2),
            // 顶面
            Triangle(v1: 3, v2: 2, v3: 6),
            Triangle(v1: 3, v2: 6, v3: 7),
            // 底面
            Triangle(v1: 0, v2: 4, v3: 5),
            Triangle(v1: 0, v2: 5, v3: 1)
        ]
        
        // 创建测试XML数据
        let testXML = """
        <mesh>
        <vertices>
        <vertex x="-1" y="-1" z="-1"/>
        <vertex x="1" y="-1" z="-1"/>
        <vertex x="1" y="1" z="-1"/>
        <vertex x="-1" y="1" z="-1"/>
        <vertex x="-1" y="-1" z="1"/>
        <vertex x="1" y="-1" z="1"/>
        <vertex x="1" y="1" z="1"/>
        <vertex x="-1" y="1" z="1"/>
        </vertices>
        <triangles>
        <triangle v1="0" v2="1" v3="2"/>
        <triangle v1="0" v2="2" v3="3"/>
        <triangle v1="4" v2="6" v3="5"/>
        <triangle v1="4" v2="7" v3="6"/>
        <triangle v1="0" v2="3" v3="7"/>
        <triangle v1="0" v2="7" v3="4"/>
        <triangle v1="1" v2="5" v3="6"/>
        <triangle v1="1" v2="6" v3="2"/>
        <triangle v1="3" v2="2" v3="6"/>
        <triangle v1="3" v2="6" v3="7"/>
        <triangle v1="0" v2="4" v3="5"/>
        <triangle v1="0" v2="5" v3="1"/>
        </triangles>
        </mesh>
        """
        
        let testFileIndex = FileIndex(
            fileName: "test-cube.model",
            offset: 0,
            compressedSize: testXML.data(using: .utf8)?.count ?? 0,
            uncompressedSize: testXML.data(using: .utf8)?.count ?? 0,
            compressionMethod: 0
        )
        
        let testPartInfo = PartInfo(
            id: "test-cube",
            name: "测试立方体",
            vertexCount: vertices.count,
            triangleCount: triangles.count,
            materialId: "default",
            directXMLData: testXML.data(using: .utf8) ?? Data()
        )
        
        let materials = [
            "default": MaterialInfo(
                id: "default",
                name: "默认材料",
                displayColor: "#4A9EFF",
                type: "PLA"
            )
        ]
        
        let metadata = ModelMetadata(
            title: "测试模型",
            designer: "System",
            description: "用于测试的立方体模型",
            copyright: nil,
            createdDate: Date()
        )
        
        return ParsedThreeMFModel(
            partInfos: [testPartInfo],
            originalMaterials: materials,
            metadata: metadata,
            dataManager: nil
        )
    }
}

// MARK: - Array Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - 3MF 解析错误
enum ThreeMFError: LocalizedError {
    case invalidFileFormat(String)
    case invalidXML(String)
    case unsupportedVersion(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFileFormat(let message):
            return "无效的3MF文件格式: \(message)"
        case .invalidXML(let message):
            return "XML解析错误: \(message)"
        case .unsupportedVersion(let version):
            return "不支持的3MF版本: \(version)"
        }
    }
}