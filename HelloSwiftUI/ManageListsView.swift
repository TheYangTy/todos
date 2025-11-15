import SwiftUI

struct ManageListsView: View {
    @Binding var lists: [TodoList]
    let onDeleteList: (UUID) -> Void
    
    @State private var newListName: String = ""
    
    var body: some View {
        Form {
            Section("新增清单") {
                HStack {
                    TextField("清单名称", text: $newListName)
                    Button("添加") {
                        addList()
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
            Section("现有清单") {
                if lists.isEmpty {
                    Text("暂无清单")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(lists) { list in
                        HStack {
                            TextField("名称", text: binding(for: list).name)
                            Spacer()
                        }
                    }
                    .onDelete(perform: deleteLists)
                }
            }
        }
        .navigationTitle("管理清单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
    }
    
    private func binding(for list: TodoList) -> Binding<TodoList> {
        guard let index = lists.firstIndex(where: { $0.id == list.id }) else {
            fatalError("List not found")
        }
        return $lists[index]
    }
    
    private func addList() {
        let trimmed = newListName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let list = TodoList(name: trimmed)
        lists.append(list)
        newListName = ""
    }
    
    private func deleteLists(at offsets: IndexSet) {
        let toDelete = offsets.map { lists[$0].id }
        lists.remove(atOffsets: offsets)
        toDelete.forEach { onDeleteList($0) }
    }
}
