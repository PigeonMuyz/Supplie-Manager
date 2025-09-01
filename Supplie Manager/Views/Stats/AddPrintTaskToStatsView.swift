//
//  AddPrintTaskToStatsView.swift
//  Supplie Manager
//
//  Created by 黄天晨 on 2025/4/26.
//


import SwiftUI

// 将打印任务添加到统计的视图
struct AddPrintTaskToStatsView: View {
    let task: PrintTaskInfo
    @Binding var isPresented: Bool
    @EnvironmentObject var store: MaterialStore
    
    @State private var selectedMaterialId: UUID?
    @State private var weightUsed: String
    @State private var modelName: String
    @State private var makerWorldLink: String = ""
    @State private var isMultiMaterial = false // 是否为多材料模式
    @State private var materialUsages: [MaterialUsageItem] = [] // 多材料使用列表
    @State private var multiMaterialWeightUsed = "" // 多材料模式下的当前输入重量
    
    init(task: PrintTaskInfo, isPresented: Binding<Bool>) {
        self.task = task
        self._isPresented = isPresented
        // 初始化状态变量
        self._weightUsed = State(initialValue: String(format: "%.2f", task.weight))
        self._modelName = State(initialValue: task.title)
        // 初始化多材料相关状态
        self._multiMaterialWeightUsed = State(initialValue: "")
        self._materialUsages = State(initialValue: [])
        self._selectedMaterialId = State(initialValue: nil)
    }
    
    // 只获取有剩余的材料
    private var availableMaterials: [Material] {
        store.materials.filter { $0.remainingWeight > 0 }
    }
    
    // 获取未被选择的材料（多材料模式）
    private var availableMultiMaterials: [Material] {
        availableMaterials.filter { material in
            !materialUsages.contains { $0.materialId == material.id }
        }
    }
    
    // 计算多材料总重量
    private var totalMultiWeight: Double {
        materialUsages.reduce(0) { $0 + $1.weightUsed }
    }
    
    // 计算多材料总成本
    private var totalMultiCost: Double {
        var cost: Double = 0
        for usage in materialUsages {
            if let material = store.materials.first(where: { $0.id == usage.materialId }) {
                let unitPrice = material.price / material.initialWeight
                cost += unitPrice * usage.weightUsed
            }
        }
        return cost
    }
    
    // 判断保存按钮是否应该禁用
    private var isSaveDisabled: Bool {
        if modelName.isEmpty {
            return true
        }
        
        if !isMultiMaterial {
            return selectedMaterialId == nil || weightUsed.isEmpty || Double(weightUsed) ?? 0 <= 0
        } else {
            return materialUsages.isEmpty
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("打印模型信息")) {
                    TextField("模型名称", text: $modelName)
                    TextField("Makerworld链接", text: $makerWorldLink)
                }
                
                Section(header: Text("记录类型")) {
                    Toggle(isOn: $isMultiMaterial) {
                        HStack {
                            Image(systemName: isMultiMaterial ? "square.stack.3d.up" : "circle")
                                .foregroundColor(isMultiMaterial ? .blue : .primary)
                            Text(isMultiMaterial ? "多材料记录" : "单材料记录")
                        }
                    }
                    .onChange(of: isMultiMaterial) { newValue in
                        // 切换记录类型时的简单清理，不自动填充数据
                        if newValue {
                            // 切换到多材料模式时，清空单材料状态，让用户手动添加
                            selectedMaterialId = nil
                            // 保留重量信息，用户可以参考但不自动填充
                        } else {
                            // 切换到单材料时，清空多材料列表
                            materialUsages.removeAll()
                            multiMaterialWeightUsed = ""
                        }
                    }
                    
                    if isMultiMaterial {
                        Text("提示：多材料模式下可以分别记录不同材料的使用量")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !weightUsed.isEmpty {
                        Text("提示：检测到打印重量 \(weightUsed)g，可作为参考")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !isMultiMaterial {
                    Section(header: Text("耗材信息")) {
                        if availableMaterials.isEmpty {
                            Text("没有可用耗材，请先添加耗材")
                                .foregroundColor(Color.secondary)
                        } else {
                            Picker("选择材料", selection: $selectedMaterialId) {
                                Text("请选择").tag(nil as UUID?)
                                ForEach(availableMaterials) { material in
                                    HStack {
                                        MaterialColorView(material: material, size: 12, strokeWidth: 0.5)
                                        Text(material.displayNameWithId)
                                    }.tag(material.id as UUID?)
                                }
                            }
                            
                            if let materialId = selectedMaterialId,
                               let material = availableMaterials.first(where: { $0.id == materialId }) {
                                Text("剩余: \(String(format: "%.2f", material.remainingWeight))g")
                                    .font(.caption)
                                    .foregroundColor(Color.secondary)
                                
                                Text("单价: ¥\(String(format: "%.2f", material.price / material.initialWeight))/g")
                                    .font(.caption)
                                    .foregroundColor(Color.secondary)
                            }
                            
                            TextField("用量(g)", text: $weightUsed)
                                .keyboardType(.decimalPad)
                            
                            if let materialId = selectedMaterialId,
                               let material = availableMaterials.first(where: { $0.id == materialId }),
                               let weight = Double(weightUsed), weight > 0 {
                                Text("预计成本: ¥\(String(format: "%.2f", (material.price / material.initialWeight) * weight))")
                                    .font(.caption)
                                    .foregroundColor(Color.secondary)
                                
                                // 添加警告，如果用量超过剩余量
                                if weight > material.remainingWeight {
                                    Text("警告：用量超过剩余量！最大可用：\(String(format: "%.2f", material.remainingWeight))g")
                                        .foregroundColor(Color.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                } else {
                    // 材料选择
                    Section(header: Text("选择材料")) {
                        if availableMultiMaterials.isEmpty {
                            Text("没有更多可用耗材")
                                .foregroundColor(.secondary)
                        } else {
                            Picker("选择材料", selection: $selectedMaterialId) {
                                Text("请选择").tag(nil as UUID?)
                                ForEach(availableMultiMaterials) { material in
                                    HStack {
                                        MaterialColorView(material: material, size: 12, strokeWidth: 0.5)
                                        Text(material.displayNameWithId)
                                    }.tag(material.id as UUID?)
                                }
                            }
                            
                            if let materialId = selectedMaterialId,
                               let material = availableMultiMaterials.first(where: { $0.id == materialId }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("剩余: \(String(format: "%.2f", material.remainingWeight))g")
                                        Spacer()
                                        Text("单价: ¥\(String(format: "%.2f", material.price / material.initialWeight))/g")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    
                                    TextField("用量(g)", text: $multiMaterialWeightUsed)
                                        .keyboardType(.decimalPad)
                                    
                                    if let weight = Double(multiMaterialWeightUsed), weight > 0 {
                                        HStack {
                                            Text("预计成本: ¥\(String(format: "%.2f", (material.price / material.initialWeight) * weight))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            if weight > material.remainingWeight {
                                                Text("超出剩余量")
                                                    .foregroundColor(.red)
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 添加按钮（独立 Section）
                    if selectedMaterialId != nil && !multiMaterialWeightUsed.isEmpty {
                        Section {
                            Button(action: {
                                addMaterialUsage()
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("添加到材料列表")
                                }
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .disabled(multiMaterialWeightUsed.isEmpty || Double(multiMaterialWeightUsed) ?? 0 <= 0)
                        }
                    }
                    
                    // 已添加的材料列表
                    if !materialUsages.isEmpty {
                        Section(header: HStack {
                            Text("已添加的材料")
                            Spacer()
                            Text("总计: \(String(format: "%.2f", totalMultiWeight))g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }) {
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
                                            .font(.title2)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(.vertical, 2)
                            }
                            
                            if totalMultiCost > 0 {
                                HStack {
                                    Text("总成本:")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("¥\(String(format: "%.2f", totalMultiCost))")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                
                Section(header: Text("打印任务信息")) {
                    HStack {
                        Text("设备名称")
                        Spacer()
                        Text(task.deviceName)
                            .foregroundColor(Color.secondary)
                    }
                    
                    HStack {
                        Text("打印时间")
                        Spacer()
                        Text(task.formattedStartTime)
                            .foregroundColor(Color.secondary)
                    }
                    
                    HStack {
                        Text("用时")
                        Spacer()
                        Text(task.formattedPrintTime)
                            .foregroundColor(Color.secondary)
                    }
                }
            }
            .navigationTitle("添加到耗材统计")
            .navigationBarItems(
                leading: Button("取消") {
                    isPresented = false
                },
                trailing: Button("保存") {
                    if !isMultiMaterial {
                        // 单材料记录
                        if !modelName.isEmpty && selectedMaterialId != nil && !weightUsed.isEmpty,
                           let weight = Double(weightUsed),
                           let materialId = selectedMaterialId,
                           let material = availableMaterials.first(where: { $0.id == materialId }) {
                            // 限制用量不超过剩余量
                            let actualWeight = min(weight, material.remainingWeight)
                            
                            let newRecord = store.createSingleMaterialRecord(
                                modelName: modelName,
                                makerWorldLink: makerWorldLink,
                                materialId: materialId,
                                materialName: material.fullName,
                                weightUsed: actualWeight
                            )
                            store.addPrintRecord(newRecord)
                            isPresented = false
                        }
                    } else {
                        // 多材料记录
                        if !modelName.isEmpty && !materialUsages.isEmpty {
                            let newRecord = store.createMultiMaterialRecord(
                                modelName: modelName,
                                makerWorldLink: makerWorldLink,
                                materialUsages: materialUsages
                            )
                            store.addPrintRecord(newRecord)
                            isPresented = false
                        }
                    }
                }
                .disabled(isSaveDisabled)
            )
        }
    }
    
    // 添加材料到多材料列表
    private func addMaterialUsage() {
        guard let materialId = selectedMaterialId,
              let material = availableMultiMaterials.first(where: { $0.id == materialId }),
              let weight = Double(multiMaterialWeightUsed),
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
        multiMaterialWeightUsed = ""
    }
    
    // 从多材料列表中移除材料
    private func removeMaterialUsage(_ usage: MaterialUsageItem) {
        materialUsages.removeAll { $0.id == usage.id }
    }
}
