import SwiftUI
import Combine

struct ProductionInputView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase

    // States
    @State private var selectedItem: ProductionItem?
    @State private var showSearchSheet = false
    @State private var inputRate: Double = 60.0
    @State private var useAlternate: Bool = false
    @State private var showSaveBlueprint = false
    @State private var blueprintName = ""
    @State private var blueprintDesc = ""

    // Calculated Previews
    @State private var previewResults: PreviewResult?

    struct PreviewResult {
        let materials: [String: Double]
        let machines: [String: Double]
        let power: Double
        let space: String
    }

    var body: some View {
        ZStack {
            FicsitBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("PRODUCTION PLANNER")
                            .font(.caption).fontDesign(.monospaced)
                            .foregroundColor(.ficsitOrange)
                        Text("NEW PRODUCTION LINE")
                            .font(.title2).bold().fontDesign(.monospaced)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.ficsitDark)

                ScrollView {
                    VStack(spacing: 20) {

                        // 1. SELECT ITEM CARD
                        VStack(alignment: .leading, spacing: 10) {
                            FicsitHeader(title: "Target Product", icon: "cube.fill")

                            Button(action: { showSearchSheet = true }) {
                                HStack(spacing: 15) {
                                    if let item = selectedItem {
                                        ItemIcon(item: item, size: 50)
                                        VStack(alignment: .leading) {
                                            Text(item.localizedName)
                                                .font(.title3).bold().foregroundColor(.white)
                                            Text(item.category)
                                                .font(.caption).foregroundColor(.gray)
                                        }
                                    } else {
                                        Image(systemName: "magnifyingglass")
                                            .font(.title).foregroundColor(.gray)
                                        Text("Select Item to Produce...")
                                            .font(.headline).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.ficsitGray)
                                }
                                .padding()
                                .ficsitCard()
                            }
                        }

                        if let item = selectedItem {

                            // 2. INPUT SECTION
                            VStack(alignment: .leading, spacing: 15) {
                                FicsitHeader(title: "Production Parameters", icon: "slider.horizontal.3")

                                VStack(alignment: .leading) {
                                    Text("Desired Output Rate")
                                        .font(.caption).foregroundColor(.gray)
                                    HStack {
                                        Slider(value: $inputRate, in: 1...600, step: 1)
                                            .accentColor(.ficsitOrange)
                                            .onChange(of: inputRate) { _ in calculatePreview() }

                                        TextField("60", value: $inputRate, format: .number)
                                            .keyboardType(.decimalPad)
                                            .font(.system(.body, design: .monospaced))
                                            .frame(width: 60)
                                            .padding(8)
                                            .background(Color.black.opacity(0.3))
                                            .cornerRadius(4)
                                            .foregroundColor(.white)
                                            .onChange(of: inputRate) { _ in calculatePreview() }

                                        Text("/ min").font(.caption).foregroundColor(.gray)
                                    }

                                    // Presets
                                    HStack {
                                        ForEach([10.0, 30.0, 60.0, 120.0], id: \.self) { val in
                                            Button("\(Int(val))") {
                                                inputRate = val
                                                calculatePreview()
                                            }
                                            .buttonStyle(FicsitButtonStyle(primary: false, color: .gray))
                                            .font(.caption)
                                        }
                                    }
                                }

                                Toggle(isOn: $useAlternate) {
                                    Text("Allow Alternate Recipes")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .ficsitOrange))
                                .onChange(of: useAlternate) { _ in calculatePreview() }
                            }
                            .padding()
                            .ficsitCard()

                            // 3. PREVIEW RESULTS
                            if let preview = previewResults {
                                VStack(alignment: .leading, spacing: 15) {
                                    FicsitHeader(title: "Projected Requirements", icon: "doc.text.magnifyingglass")

                                    // Materials
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Estimated Input Materials")
                                            .font(.caption).bold().foregroundColor(.white)

                                        ForEach(preview.materials.keys.sorted(), id: \.self) { mat in
                                            HStack {
                                                Text("• \(mat):")
                                                    .font(.caption).foregroundColor(.ficsitGray)
                                                Spacer()
                                                Text("\(String(format: "%.1f", preview.materials[mat]!))/min")
                                                    .font(.caption).bold().foregroundColor(.white)
                                            }
                                        }
                                    }

                                    Divider().background(Color.gray)

                                    HStack(spacing: 20) {
                                        VStack(alignment: .leading) {
                                            Text("Primary Machines").font(.caption).foregroundColor(.gray)
                                            if let firstMachine = preview.machines.keys.first {
                                                Text("~ \(Int(preview.machines[firstMachine]!))x \(firstMachine)")
                                                    .font(.subheadline).bold()
                                            } else {
                                                Text("N/A").font(.subheadline)
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("Est. Power").font(.caption).foregroundColor(.gray)
                                            HStack {
                                                Image(systemName: "bolt.fill").foregroundColor(.yellow)
                                                Text("\(Int(preview.power)) MW").bold()
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .ficsitCard(borderColor: .green.opacity(0.3))
                            }

                            // 4. ACTION BUTTONS
                            HStack(spacing: 15) {
                                Button(action: {
                                    viewModel.addGoal(item: item, ratio: inputRate)
                                    HapticManager.shared.success()
                                    // Close sheet logic should be handled by parent or Environment
                                }) {
                                    Label("Add to Project", systemImage: "plus.square.fill")
                                }
                                .buttonStyle(FicsitButtonStyle())

                                Button(action: {
                                    blueprintName = "Blueprint: \(item.localizedName)"
                                    blueprintDesc = "Producing \(Int(inputRate))/min"
                                    showSaveBlueprint = true
                                }) {
                                    Label("Blueprint", systemImage: "doc.text.fill")
                                }
                                .buttonStyle(FicsitButtonStyle(primary: false))
                            }
                            .padding(.bottom)
                        }
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                ItemSelectorView(title: "Select Product", items: db.items.filter { $0.category != "Raw" }, selection: $selectedItem)
            }
            .sheet(isPresented: $showSaveBlueprint) {
                NavigationView {
                    Form {
                        Section(header: Text("Blueprint Details")) {
                            TextField("Name", text: $blueprintName)
                            TextField("Description", text: $blueprintDesc)
                        }
                        Button("Save Blueprint") {
                            saveBlueprint()
                            showSaveBlueprint = false
                        }
                    }
                    .navigationTitle("Save Blueprint")
                    .navigationBarItems(trailing: Button("Cancel") { showSaveBlueprint = false })
                }
            }
        }
        .onChange(of: selectedItem) { _ in calculatePreview() }
    }

    // MARK: - LOGIC

    private func calculatePreview() {
        guard let item = selectedItem else { return }

        // Use a temporary engine to calculate
        // Ideally we would reuse the main engine, but we don't want to affect the current factory state.
        // For preview, we can just do a single-depth lookup or use a temporary ProductionEngine instance.
        // Given complexity, let's do a quick calculation of immediate ingredients using the best recipe.

        let recipes = db.getRecipesOptimized(producing: item.name)
        guard let recipe = recipes.first(where: { useAlternate ? true : !$0.isAlternate }) ?? recipes.first else {
            return
        }

        // Calculate based on recipe
        let productRate = recipe.products[item.name] ?? 1.0
        let scale = inputRate / productRate

        var materials: [String: Double] = [:]
        for (ing, amount) in recipe.ingredients {
            materials[ing] = amount * scale
        }

        var machines: [String: Double] = [:]
        machines[recipe.machine.name] = scale

        let power = recipe.machine.powerConsumption * scale

        previewResults = PreviewResult(
            materials: materials,
            machines: machines,
            power: power,
            space: "Calculating..." // Complex to estimate without full layout
        )
    }

    private func saveBlueprint() {
        guard let item = selectedItem else { return }
        // Create a temporary factory subset to represent this blueprint
        // This is a simplified "single step" blueprint for now, as calculating full chain without adding to world is complex.
        // In a real app, we'd run the full engine on a temp Factory.

        let goal = ProductionGoal(item: item, ratio: inputRate)
        // We need to construct a valid Factory object or similar structure
        // Since BlueprintService expects a Factory, we create a dummy one with just this goal

        let dummyFactory = Factory(
            name: blueprintName,
            date: Date(),
            inputs: [], // We don't know inputs yet without full calc
            goals: [goal],
            activeRecipes: [:],
            beltLevel: .mk3,
            fuelType: .coal,
            fuelAmount: "0"
        )

        BlueprintService.shared.saveBlueprint(from: dummyFactory, name: blueprintName, description: blueprintDesc)
    }
}
