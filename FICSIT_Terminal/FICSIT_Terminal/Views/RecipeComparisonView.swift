import SwiftUI

struct RecipeComparisonView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase

    @State private var selectedItemName: String = "Iron Ingot"
    @State private var showingSearch = false

    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text(Localization.translate("RECIPE ANALYSIS"))
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundColor(.ficsitOrange)
                                .tracking(2)

                            Button(action: { showingSearch = true }) {
                                HStack {
                                    Text(Localization.translate(selectedItemName))
                                        .font(.largeTitle)
                                        .fontWeight(.heavy)
                                        .fontDesign(.monospaced)
                                        .foregroundColor(.white)
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.ficsitOrange)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.ficsitDark.opacity(0.8))

                    // Content
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            let recipes = db.getRecipesOptimized(producing: selectedItemName)

                            if recipes.isEmpty {
                                Text(Localization.translate("No recipes found."))
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(recipes) { recipe in
                                    RecipeComparisonCard(recipe: recipe, targetItem: selectedItemName)
                                }
                            }
                        }
                        .padding()
                    }

                    Spacer()
                }
            }
            .sheet(isPresented: $showingSearch) {
                ItemSelectorView(
                    title: Localization.translate("Select Item to Analyze"),
                    items: db.items.filter { !db.rawResources.contains($0.name) },
                    selection: Binding(
                        get: { db.getItemOptimized(named: selectedItemName) },
                        set: { selectedItemName = $0?.name ?? selectedItemName }
                    )
                )
            }
            .navigationBarHidden(true)
        }
    }
}

struct RecipeComparisonCard: View {
    let recipe: Recipe
    let targetItem: String

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack {
                Text(recipe.localizedName)
                    .font(.headline)
                    .fontDesign(.monospaced)
                    .foregroundColor(recipe.isAlternate ? .ficsitOrange : .white)

                Spacer()

                if recipe.isAlternate {
                    Text("ALT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(4)
                        .background(Color.ficsitOrange)
                        .foregroundColor(.black)
                        .cornerRadius(4)
                }
            }

            Divider().background(Color.gray)

            // Output Rate
            HStack {
                VStack(alignment: .leading) {
                    Text(Localization.translate("Output"))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(String(format: "%.1f", recipe.products[targetItem] ?? 0))/min")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(Localization.translate("Machine"))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(recipe.machine.localizedName)
                        .font(.callout)
                        .foregroundColor(.white)
                }
            }

            // Inputs
            VStack(alignment: .leading, spacing: 5) {
                Text(Localization.translate("Ingredients"))
                    .font(.caption)
                    .foregroundColor(.gray)

                ForEach(recipe.ingredients.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text(Localization.translate(key))
                        Spacer()
                        Text("\(String(format: "%.1f", value))/min")
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                }
            }

            // Efficiency / Stats
            VStack(alignment: .leading, spacing: 5) {
                Text(Localization.translate("Stats"))
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Image(systemName: "bolt.fill")
                    Text("\(Int(recipe.machine.powerConsumption)) MW")
                }
                .foregroundColor(.yellow)
                .font(.caption)
            }

            Spacer()
        }
        .padding()
        .frame(width: 280, height: 350)
        .background(Color.ficsitDark)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(recipe.isAlternate ? Color.ficsitOrange : Color.gray, lineWidth: 2)
        )
    }
}
