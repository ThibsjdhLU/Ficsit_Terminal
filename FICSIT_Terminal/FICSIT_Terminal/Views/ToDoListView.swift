import SwiftUI

struct ToDoListView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @State private var showingAddItem = false
    @State private var newItemTitle = ""
    @State private var newItemCategory = ""
    @State private var newItemPriority = 0

    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()

                VStack(spacing: 0) {
                    // HEADER
                    HStack {
                        VStack(alignment: .leading) {
                            Text(Localization.translate("TO-DO LIST"))
                                .font(.largeTitle)
                                .fontWeight(.heavy)
                                .fontDesign(.monospaced)
                                .foregroundColor(.white)

                            if !viewModel.currentProjectName.isEmpty {
                                Text(viewModel.currentProjectName)
                                    .font(.caption)
                                    .fontDesign(.monospaced)
                                    .foregroundColor(.ficsitOrange)
                            }
                        }
                        Spacer()
                        Button(action: {
                            newItemTitle = ""
                            newItemCategory = ""
                            newItemPriority = 0
                            showingAddItem = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.ficsitDark)
                                .padding(10)
                                .background(Color.ficsitOrange)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(Localization.translate("Add new task"))
                    }
                    .padding()
                    .background(Color.ficsitDark.opacity(0.8))

                    if viewModel.toDoList.isEmpty {
                        emptyStateView
                    } else {
                        List {
                            ForEach(groupedItems.keys.sorted(), id: \.self) { category in
                                Section(header: Text(category)
                                    .fontDesign(.monospaced)
                                    .foregroundColor(.ficsitOrange)
                                ) {
                                    ForEach(groupedItems[category] ?? []) { item in
                                        ToDoItemRow(item: item) {
                                            viewModel.toggleToDoItem(item)
                                        }
                                    }
                                    .onDelete { offsets in
                                        deleteItems(at: offsets, in: category)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddItem) {
                addItemSheet
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.ficsitGray)
                .accessibilityHidden(true)
            Text(Localization.translate("No tasks pending."))
                .font(.headline)
                .fontDesign(.monospaced)
                .foregroundColor(.ficsitGray)
            Text(Localization.translate("Add construction tasks to track your progress."))
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
    }

    private var addItemSheet: some View {
        ZStack {
            Color.ficsitDark.ignoresSafeArea()

            VStack(spacing: 20) {
                Text(Localization.translate("Add New Task"))
                    .font(.headline)
                    .fontDesign(.monospaced)
                    .foregroundColor(.white)
                    .padding(.top)

                TextField(Localization.translate("Task Description"), text: $newItemTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .preferredColorScheme(.dark)

                TextField(Localization.translate("Category (Optional)"), text: $newItemCategory)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Picker("Priority", selection: $newItemPriority) {
                    Text(Localization.translate("Normal")).tag(0)
                    Text(Localization.translate("High")).tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .onAppear {
                    UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.ficsitOrange)
                    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
                    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
                }

                HStack(spacing: 20) {
                    Button(Localization.translate("Cancel")) {
                        showingAddItem = false
                    }
                    .foregroundColor(.red)

                    Button(Localization.translate("Add")) {
                        // Store nil if empty, so "General" is localized at display time
                        let cat = newItemCategory.isEmpty ? nil : newItemCategory
                        viewModel.addToDoItem(title: newItemTitle, category: cat, priority: newItemPriority)
                        showingAddItem = false
                    }
                    .disabled(newItemTitle.isEmpty)
                    .foregroundColor(newItemTitle.isEmpty ? .gray : .ficsitOrange)
                }
                .padding()

                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private var groupedItems: [String: [ToDoItem]] {
        Dictionary(grouping: viewModel.toDoList) { $0.category ?? Localization.translate("General") }
    }

    private func deleteItems(at offsets: IndexSet, in category: String) {
        // Find items to delete
        let itemsToDelete = offsets.map { (groupedItems[category] ?? [])[$0] }

        // Find their indices in the main list
        let indicesToDelete = itemsToDelete.compactMap { item in
            viewModel.toDoList.firstIndex(where: { $0.id == item.id })
        }

        // Remove them (sorting descending to avoid index shift issues)
        for index in indicesToDelete.sorted(by: >) {
            viewModel.toDoList.remove(at: index)
        }
    }
}

struct ToDoItemRow: View {
    let item: ToDoItem
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(item.isCompleted ? .green : .ficsitGray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(item.isCompleted ? Localization.translate("Mark as incomplete") : Localization.translate("Mark as completed"))

            VStack(alignment: .leading) {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundColor(item.isCompleted ? .gray : .white)
                    .fontDesign(.monospaced)

                if item.priority == 1 {
                    Text(Localization.translate("HIGH PRIORITY"))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.ficsitOrange)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }
}
