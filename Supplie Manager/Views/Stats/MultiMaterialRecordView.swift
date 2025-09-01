import SwiftUI

struct MultiMaterialRecordView: View {
    @ObservedObject var store: MaterialStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var modelName = ""
    @State private var makerWorldLink = ""
    @State private var materialUsages: [MaterialUsageItem] = []
    @State private var selectedMaterialId: UUID?
    @State private var weightUsed = ""
    
    // 只获取有剩余的材料
    private var availableMaterials: [Material] {
        store.materials.filter { $0.remainingWeight > 0 }
    }
    
    // 计算总重量
    private var totalWeight: Double {
        materialUsages.reduce(0) { $0 + $1.weightUsed }
    }
    
    // 计算总成本
    private var totalCost: Double {
        var cost: Double = 0
        for usage in materialUsages {
            if let material = store.materials.first(where: { $0.id == usage.materialId }) {
                let unitPrice = material.price / material.initialWeight
                cost += unitPrice * usage.weightUsed
            }
        }
        return cost
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("模型信息")) {
                    TextField("模型名称", text: $modelName)
                    TextField("Makerworld链接", text: $makerWorldLink)
                }
                
                Section(header: Text("材料使用")) {
                    // 添加材料区域
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("添加材料")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        if availableMaterials.isEmpty {
                            Text("没有可用耗材，请先添加耗材")
                                .foregroundColor(.secondary)
                        } else {
                            Picker("选择材料", selection: $selectedMaterialId) {
                                Text("请选择").tag(nil as UUID?)
                                ForEach(availableMaterials.filter { material in
                                    !materialUsages.contains { $0.materialId == material.id }
                                }) { material in
                                    HStack {
                                        MaterialColorView(material: material, size: 12, strokeWidth: 0.5)
                                        Text(material.displayNameWithId)
                                    }.tag(material.id as UUID?)
                                }
                            }
                            
                            if let materialId = selectedMaterialId,
                               let material = availableMaterials.first(where: { $0.id == materialId }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("剩余: \(String(format: "%.2f", material.remainingWeight))g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("单价: ¥\(String(format: "%.2f", material.price / material.initialWeight))/g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    TextField("用量(g)", text: $weightUsed)
                                        .keyboardType(.decimalPad)
                                    
                                    Button("添加") {
                                        addMaterialUsage()
                                    }
                                    .disabled(weightUsed.isEmpty || Double(weightUsed) ?? 0 <= 0)
                                }
                                
                                if let weight = Double(weightUsed), weight > 0 {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("预计成本: ¥\(String(format: "%.2f", (material.price / material.initialWeight) * weight))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if weight > material.remainingWeight {
                                            Text("警告：用量超过剩余量！最大可用：\(String(format: "%.2f", material.remainingWeight))g")
                                                .foregroundColor(.red)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 已添加的材料列表
                    if !materialUsages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("已添加的材料")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("总计: \(String(format: "%.2f", totalWeight))g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            ForEach(materialUsages) { usage in
                                HStack {
                                    if let material = store.materials.first(where: { $0.id == usage.materialId }) {
                                        MaterialColorView(material: material, size: 16, strokeWidth: 0.5)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(usage.materialName)
                                            .font(.subheadline)
                                        Text("\(String(format: "%.2f", usage.weightUsed))g")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        removeMaterialUsage(usage)
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            
                            if totalCost > 0 {
                                HStack {
                                    Text("总成本:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("¥\(String(format: "%.2f", totalCost))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
            }
            .navigationTitle("多材料打印记录")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    saveMultiMaterialRecord()
                }
                .disabled(modelName.isEmpty || materialUsages.isEmpty)
            )
        }
    }
    
    private func addMaterialUsage() {
        guard let materialId = selectedMaterialId,
              let material = availableMaterials.first(where: { $0.id == materialId }),
              let weight = Double(weightUsed),
              weight > 0 else { return }
        
        // 限制用量不超过剩余量
        let actualWeight = min(weight, material.remainingWeight)
        
        let usage = MaterialUsageItem(
            materialId: materialId,
            materialName: material.fullName,
            weightUsed: actualWeight
        )
        
        materialUsages.append(usage)
        
        // 重置选择
        selectedMaterialId = nil
        weightUsed = ""
    }
    
    private func removeMaterialUsage(_ usage: MaterialUsageItem) {
        materialUsages.removeAll { $0.id == usage.id }
    }
    
    private func saveMultiMaterialRecord() {
        guard !modelName.isEmpty && !materialUsages.isEmpty else { return }
        
        let record = store.createMultiMaterialRecord(
            modelName: modelName,
            makerWorldLink: makerWorldLink,
            materialUsages: materialUsages
        )
        
        store.addPrintRecord(record)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    MultiMaterialRecordView(store: MaterialStore())
}