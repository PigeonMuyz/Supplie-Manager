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
    
    init(task: PrintTaskInfo, isPresented: Binding<Bool>) {
        self.task = task
        self._isPresented = isPresented
        // 初始化状态变量
        self._weightUsed = State(initialValue: String(format: "%.2f", task.weight))
        self._modelName = State(initialValue: task.title)
    }
    
    // 只获取有剩余的材料
    private var availableMaterials: [Material] {
        store.materials.filter { $0.remainingWeight > 0 }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("打印模型信息")) {
                    TextField("模型名称", text: $modelName)
                    TextField("Makerworld链接", text: $makerWorldLink)
                }
                
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
                    if !modelName.isEmpty && selectedMaterialId != nil && !weightUsed.isEmpty,
                       let weight = Double(weightUsed),
                       let materialId = selectedMaterialId,
                       let material = availableMaterials.first(where: { $0.id == materialId }) {
                        // 限制用量不超过剩余量
                        let actualWeight = min(weight, material.remainingWeight)
                        
                        let newRecord = PrintRecord(
                            modelName: modelName,
                            makerWorldLink: makerWorldLink,
                            materialId: materialId,
                            materialName: material.fullName,
                            weightUsed: actualWeight,
                            date: Date()
                        )
                        store.addPrintRecord(newRecord)
                        isPresented = false
                    }
                }
                .disabled(selectedMaterialId == nil || modelName.isEmpty || weightUsed.isEmpty ||
                          (selectedMaterialId != nil && Double(weightUsed) ?? 0 <= 0))
            )
        }
    }
}
