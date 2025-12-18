import SwiftUI

struct ToDoListView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @State private var showingAddItem = false
    @State private var newItemTitle = ""
    @State private var newItemCategory = ""
    @State private var newItemPriority = 0

    @State private var itemToDelete: ToDoItem?
    @State private var showDeleteAlert = false

    // Filter State
    @State private var filter: ToDoFilter = .all
    @State private var searchText = ""

    enum ToDoFilter: String, CaseIterable {
        case all = "All"
        case active = "In Progress"
        case completed = "Complete"
    }

    var body: some View {
        ZStack {
            FicsitBackground()

            VStack(spacing: 0) {
                // HEADER & FILTER
                VStack(spacing: 15) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(Localization.translate("TASK LOG"))
                                .font(.caption).fontDesign(.monospaced)
                                .foregroundColor(.ficsitOrange)
                            Text(Localization.translate("CONSTRUCTION TASKS"))
                                .font(.title2).bold().fontDesign(.monospaced)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Button(action: {
                            newItemTitle = ""
                            newItemCategory = ""
                            newItemPriority = 0
                            showingAddItem = true
                        }) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(10)
                                .background(Color.ficsitOrange)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(Localization.translate("Add New Task"))
                    }

                    // SEARCH BAR
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField(Localization.translate("Search tasks..."), text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))

                    // FILTER TABS
                    HStack {
                        ForEach(ToDoFilter.allCases, id: \.self) { f in
                            Button(action: { filter = f }) {
                                Text(Localization.translate(f.rawValue))
                                    .font(.caption).bold()
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(filter == f ? Color.ficsitOrange : Color.clear)
                                    .foregroundColor(filter == f ? .black : .gray)
                                    .cornerRadius(15)
                                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(filter == f ? Color.clear : Color.gray, lineWidth: 1))
                            }
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color.ficsitDark)

                // LIST
                if filteredItems.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "checklist")
                            .font(.system(size: 60))
                            .foregroundColor(.ficsitGray.opacity(0.3))
                        Text(Localization.translate("No tasks found"))
                            .font(.headline).foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(groupedItems.keys.sorted(), id: \.self) { category in
                                Section(header:
                                    HStack {
                                        Text(category.uppercased())
                                            .font(.caption).bold().fontDesign(.monospaced)
                                            .foregroundColor(.ficsitOrange)
                                            .padding(.vertical, 5)
                                            .padding(.horizontal, 10)
                                            .background(Color.ficsitOrange.opacity(0.1))
                                            .cornerRadius(4)
                                        Spacer()
                                    }
                                    .padding(.top, 10)
                                    .padding(.horizontal)
                                ) {
                                    ForEach(groupedItems[category] ?? []) { item in
                                        ToDoItemRow(item: item) {
                                            viewModel.toggleToDoItem(item)
                                            HapticManager.shared.click()
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                itemToDelete = item
                                                showDeleteAlert = true
                                            } label: {
                                                Label(Localization.translate("Delete"), systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            addItemSheet
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text(Localization.translate("Delete Task?")),
                message: Text(Localization.translate("Are you sure you want to delete this task? This action cannot be undone.")),
                primaryButton: .destructive(Text(Localization.translate("Delete"))) {
                    if let item = itemToDelete, let idx = viewModel.toDoList.firstIndex(where: {$0.id == item.id}) {
                        viewModel.toDoList.remove(at: idx)
                    }
                    itemToDelete = nil
                },
                secondaryButton: .cancel {
                    itemToDelete = nil
                }
            )
        }
    }

    // MARK: - Subviews

    private var addItemSheet: some View {
        NavigationView {
            Form {
                Section(header: Text(Localization.translate("Task Details"))) {
                    TextField(Localization.translate("Task Description"), text: $newItemTitle)
                    TextField(Localization.translate("Category (Optional)"), text: $newItemCategory)
                }
                Section(header: Text(Localization.translate("Priority"))) {
                    Picker(Localization.translate("Priority"), selection: $newItemPriority) {
                        Text(Localization.translate("Normal")).tag(0)
                        Text(Localization.translate("High")).tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle(Localization.translate("New Task"))
            .navigationBarItems(
                leading: Button(Localization.translate("Cancel")) { showingAddItem = false },
                trailing: Button(Localization.translate("Add")) {
                    let cat = newItemCategory.isEmpty ? nil : newItemCategory
                    viewModel.addToDoItem(title: newItemTitle, category: cat, priority: newItemPriority)
                    showingAddItem = false
                }
                .disabled(newItemTitle.isEmpty)
            )
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                        .foregroundColor(.ficsitOrange)
                }
            }
        }
    }

    // MARK: - Filtering Logic

    private var filteredItems: [ToDoItem] {
        viewModel.toDoList.filter { item in
            let matchesSearch = searchText.isEmpty || item.title.localizedCaseInsensitiveContains(searchText) || (item.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .active: matchesFilter = !item.isCompleted
            case .completed: matchesFilter = item.isCompleted
            }
            return matchesSearch && matchesFilter
        }
    }

    private var groupedItems: [String: [ToDoItem]] {
        Dictionary(grouping: filteredItems) { $0.category ?? Localization.translate("General") }
    }
}

struct ToDoItemRow: View {
    let item: ToDoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 15) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundColor(item.isCompleted ? .green : .ficsitGray)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(item.isCompleted ? Localization.translate("Mark as incomplete") : Localization.translate("Mark as completed"))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .gray : .white)
                    .fontDesign(.monospaced)

                if item.priority == 1 && !item.isCompleted {
                    Text(Localization.translate("HIGH PRIORITY"))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.ficsitOrange)
                        .padding(2)
                        .background(Color.ficsitOrange.opacity(0.1))
                        .cornerRadius(2)
                }
            }

            Spacer()
        }
        .padding()
        .ficsitCard(borderColor: item.isCompleted ? .green.opacity(0.2) : .white.opacity(0.1))
        .padding(.horizontal)
    }
}
