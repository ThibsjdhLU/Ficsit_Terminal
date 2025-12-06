import SwiftUI

struct RecipeLibraryView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @ObservedObject var db: FICSITDatabase
    @State private var selectedRecipeForInfo: Recipe?
    
    var itemsWithChoices: [String] {
        // Break into simpler steps to help the type-checker
        let producedKeyArrays: [[String]] = db.recipes.map { Array($0.products.keys) }
        let flattened: [String] = producedKeyArrays.flatMap { $0 }
        let unique = Set(flattened)
        let sorted = unique.sorted()
        let filtered = sorted.filter { itemName in
            let recipesForItem: [Recipe] = db.getRecipesOptimized(producing: itemName)
            return recipesForItem.count > 1
        }
        return filtered
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 1. LE FOND
                FicsitBackground()
                
                // 2. LA LISTE
                List {
                    Section(header: Text("M.A.M. HARD DRIVE LIBRARY").font(.system(.caption, design: .monospaced)).foregroundColor(.ficsitOrange)) {
                        ForEach(itemsWithChoices, id: \.self) { itemName in
                            DisclosureGroup(
                                content: {
                                    ForEach(db.getRecipesOptimized(producing: itemName)) { recipe in
                                        HStack {
                                            // BOUTON SELECTION
                                            Button(action: {
                                                viewModel.toggleRecipe(for: itemName, recipe: recipe)
                                                HapticManager.shared.click()
                                            }) {
                                                HStack {
                                                    Image(systemName: viewModel.isRecipeActive(item: itemName, recipe: recipe) ? "checkmark.square.fill" : "square")
                                                        .foregroundColor(viewModel.isRecipeActive(item: itemName, recipe: recipe) ? .ficsitOrange : .gray)
                                                        .font(.title3)
                                                    
                                                    VStack(alignment: .leading) {
                                                        Text(recipe.name)
                                                            .font(.system(.body, design: .monospaced))
                                                            .fontWeight(viewModel.isRecipeActive(item: itemName, recipe: recipe) ? .bold : .regular)
                                                            .foregroundColor(.white)
                                                        
                                                        HStack {
                                                            if recipe.isAlternate {
                                                                Text("ALT").font(.system(size: 8, weight: .bold)).padding(3).background(Color.blue).cornerRadius(3).foregroundColor(.white)
                                                            } else {
                                                                Text("STD").font(.system(size: 8, weight: .bold)).padding(3).background(Color.gray).cornerRadius(3).foregroundColor(.white)
                                                            }
                                                            Text(ingredientsString(recipe))
                                                                .font(.system(.caption, design: .monospaced))
                                                                .foregroundColor(.gray)
                                                        }
                                                    }
                                                    Spacer()
                                                }
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            // BOUTON INFO
                                            Button(action: { selectedRecipeForInfo = recipe }) {
                                                Image(systemName: "info.circle")
                                                    .foregroundColor(.ficsitOrange)
                                                    .padding(.leading, 8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .padding(.vertical, 4)
                                    }
                                },
                                label: {
                                    HStack {
                                        ItemIcon(item: ProductionItem(name: itemName, category: "Part", sinkValue: 0), size: 30)
                                        Text(itemName)
                                            .font(.system(.headline, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if let count = viewModel.activeRecipes[itemName]?.count, count > 0 {
                                            Text("\(count) active")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.ficsitOrange)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.ficsitOrange.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            )
                            .listRowBackground(Color.black.opacity(0.4)) // Fond des cellules sombre
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden) // REND LA LISTE TRANSPARENTE POUR VOIR LE FOND
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedRecipeForInfo) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
    
    func ingredientsString(_ recipe: Recipe) -> String {
        return recipe.ingredients.map { "\($0.key): \(Int($0.value))" }.joined(separator: ", ")
    }
}
