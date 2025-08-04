import SwiftUI

// 本地化日期
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

struct MyMaterialsView: View {
    @ObservedObject var store: MaterialStore
    @State private var isShowingAddMaterialSheet = false
    @State private var showEmptyMaterials = false // 控制已用完耗材的折叠状态
    
    var body: some View {
        NavigationView {
            List {
                // 先显示有剩余的耗材
                if !store.materials.filter({ $0.remainingWeight > 0 }).isEmpty {
                    Section(header: Text("可用耗材")) {
                        ForEach(store.materials.filter { $0.remainingWeight > 0 }
                                 .sorted(by: {
                                     // 首先按照是否有使用量排序（初始重量-剩余重量>0表示有使用）
                                     let hasUsage1 = $0.initialWeight - $0.remainingWeight > 0
                                     let hasUsage2 = $1.initialWeight - $1.remainingWeight > 0
                                     if hasUsage1 != hasUsage2 {
                                         return hasUsage1 && !hasUsage2
                                     }
                                     // 其次按购入时间降序排序（较新的排在前面）
                                     return $0.purchaseDate > $1.purchaseDate
                                 })) { material in
                            MaterialRow(material: material)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.deleteMaterial(id: material.id)
                                    } label: {
                                        Label("", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        // 手动标记耗材已经用尽
                                        store.markMaterialAsEmpty(id: material.id)
                                    } label: {
                                        Label("", systemImage: "checkmark.circle")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
                
                // 已用完的耗材(折叠式)
                if !store.materials.filter({ $0.remainingWeight <= 0 }).isEmpty {
                    Section {
                        DisclosureGroup(
                            isExpanded: $showEmptyMaterials,
                            content: {
                                ForEach(store.materials.filter { $0.remainingWeight <= 0 }) { material in
                                    MaterialRow(material: material)
                                        .foregroundColor(.secondary)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                store.deleteMaterial(id: material.id)
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                        }
                                }
                            },
                            label: {
                                HStack {
                                    Text("已用完")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(store.materials.filter { $0.remainingWeight <= 0 }.count)项")
                                        .foregroundColor(.secondary)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("我的耗材")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            isShowingAddMaterialSheet = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingAddMaterialSheet) {
                AddMaterialView(store: store, isPresented: $isShowingAddMaterialSheet)
            }
        }
    }
}

// 耗材行视图组件
struct MaterialRow: View {
    let material: Material
    
    var body: some View {
        HStack {
            MaterialColorView(material: material, size: 20, strokeWidth: 1)
            
            VStack(alignment: .leading) {
                Text(material.displayNameWithId)
                    .font(.headline)
                
                Text("购入日期: \(dateFormatter.string(from: material.purchaseDate))")
                    .font(.caption)
                
                Text("价格: ¥\(String(format: "%.2f", material.price))")
                    .font(.caption)
                
                if material.remainingWeight > 0 {
                    Text("剩余: \(String(format: "%.2f", material.remainingWeight))g / \(material.formattedWeight)")
                        .font(.caption)
                } else {
                    Text("状态: 已用完")
                        .font(.caption)
                }
                
                // 耗材使用进度条
                ProgressView(value: 1 - (material.remainingWeight / material.initialWeight))
            }
            .padding(.vertical, 4)
        }
    }
}