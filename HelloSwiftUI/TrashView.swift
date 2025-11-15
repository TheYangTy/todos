import SwiftUI

struct TrashView: View {
    @Binding var todos: [TodoItem]
    let lists: [TodoList]
    
    private var trashIndices: [Int] {
        todos.indices
            .filter { todos[$0].deletedAt != nil }
            .sorted { lhs, rhs in
                let a = todos[lhs].deletedAt ?? .distantPast
                let b = todos[rhs].deletedAt ?? .distantPast
                return a > b
            }
    }
    
    var body: some View {
        List {
            if trashIndices.isEmpty {
                Text("回收站为空")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(trashIndices, id: \.self) { idx in
                    let item = todos[idx]
                    let listName = lists.first(where: { $0.id == item.listId })?.name ?? "未知清单"
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text("来自：\(listName)")
                            if let deletedAt = item.deletedAt {
                                Text("删除时间：\(format(date: deletedAt))")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            permanentlyDelete(index: idx)
                        } label: {
                            Label("彻底删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            restore(index: idx)
                        } label: {
                            Label("还原", systemImage: "arrow.uturn.left.circle")
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .navigationTitle("回收站")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !trashIndices.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空") {
                        clearAll()
                    }
                }
            }
        }
    }
    
    private func restore(index: Int) {
        todos[index].deletedAt = nil
    }
    
    private func permanentlyDelete(index: Int) {
        todos.remove(at: index)
    }
    
    private func clearAll() {
        todos.removeAll { $0.deletedAt != nil }
    }
    
    private func format(date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
