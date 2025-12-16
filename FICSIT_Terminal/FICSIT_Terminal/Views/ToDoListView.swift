import SwiftUI

struct ToDoListView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @State private var showingAddItem = false
    @State private var newItemTitle = ""
    @State private var newItemCategory = ""
    @State private var newItemPriority = 0

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
                        .accessibilityLabel("Add Task")
                    }

                    // SEARCH BAR
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search tasks...", text: $searchText)
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
                                                if let idx = viewModel.toDoList.firstIndex(where: {$0.id == item.id}) {
                                                    viewModel.toDoList.remove(at: idx)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
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
    }

    // MARK: - Subviews

    private var addItemSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Description", text: $newItemTitle)
                    TextField("Category (e.g. Tier 1, Logistics)", text: $newItemCategory)
                }
                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $newItemPriority) {
                        Text("Normal").tag(0)
                        Text("High").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("New Task")
            .navigationBarItems(
                leading: Button("Cancel") { showingAddItem = false },
                trailing: Button("Add") {
                    let cat = newItemCategory.isEmpty ? nil : newItemCategory
                    viewModel.addToDoItem(title: newItemTitle, category: cat, priority: newItemPriority)
                    showingAddItem = false
                }
                .disabled(newItemTitle.isEmpty)
            )
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

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .gray : .white)
                    .fontDesign(.monospaced)

                if item.priority == 1 && !item.isCompleted {
                    Text("HIGH PRIORITY")
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
