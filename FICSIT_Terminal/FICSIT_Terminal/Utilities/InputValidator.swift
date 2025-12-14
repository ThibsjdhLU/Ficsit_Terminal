import Foundation

struct InputValidator {
    let db: FICSITDatabase
    
    func validateInputs(_ inputs: [ResourceInput]) throws {
        guard !inputs.isEmpty else {
            throw ProductionError.invalidInput(message: "Au moins une ressource est requise")
        }
        
        for input in inputs {
            guard db.rawResources.contains(input.resourceName) else {
                throw ProductionError.invalidResource(name: input.resourceName)
            }
            guard input.productionRate > 0 else {
                throw ProductionError.invalidRate(resource: input.resourceName)
            }
            guard input.productionRate <= 240 * 2.0 else { // Mk3 Pure max
                throw ProductionError.invalidRate(resource: input.resourceName)
            }
        }
    }
    
    func validateGoals(_ goals: [ProductionGoal]) throws {
        guard !goals.isEmpty else {
            throw ProductionError.invalidInput(message: "Au moins un objectif est requis")
        }
        
        for goal in goals {
            guard db.items.contains(where: { $0.name == goal.item.name }) else {
                throw ProductionError.invalidGoal(item: goal.item.name)
            }
            guard goal.ratio > 0 else {
                throw ProductionError.invalidInput(message: "Le ratio doit être > 0 pour \(Localization.translate(goal.item.name))")
            }
        }
    }
    
    func validateRecipes(_ activeRecipes: [String: [Recipe]]) throws {
        for (itemName, recipes) in activeRecipes {
            for recipe in recipes {
                guard recipe.products.keys.contains(itemName) else {
                    throw ProductionError.invalidRecipe(
                        recipe: recipe.name,
                        reason: "Ne produit pas \(Localization.translate(itemName))"
                    )
                }
            }
        }
    }
    
    func validateAll(inputs: [ResourceInput], goals: [ProductionGoal], activeRecipes: [String: [Recipe]]) throws {
        try validateInputs(inputs)
        try validateGoals(goals)
        try validateRecipes(activeRecipes)
    }
}

