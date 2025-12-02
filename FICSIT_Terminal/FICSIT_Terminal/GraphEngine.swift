import SwiftUI

class GraphEngine {
    
    struct GraphLayout {
        var nodes: [GraphNode]
        var links: [GraphLink]
        var contentSize: CGSize
    }
    
    // MODIFICATION ICI : Ajout de 'goals' et 'sinkResult' dans les paramètres
    func generateLayout(from plan: [ConsolidatedStep], inputs: [ResourceInput], goals: [ProductionGoal], sinkResult: SinkResult?, db: FICSITDatabase) -> GraphLayout {
        var nodes: [GraphNode] = []
        var links: [GraphLink] = []
        var nodeMap: [String: UUID] = [:]
        var itemDepth: [String: Int] = [:]
        
        // Liste des noms d'items qui sont des objectifs explicites
        let goalItemNames = Set(goals.map { $0.item.name })
        let sinkItemName = sinkResult?.bestItem.name
        
        // 1. DETECTION DES PRODUITS FINIS
        // Un item est final s'il n'est consommé par personne... OU si c'est un GOAL !
        var consumedItems: Set<String> = []
        for step in plan {
            if let recipe = step.recipe {
                for (ing, _) in recipe.ingredients {
                    consumedItems.insert(ing)
                }
            }
        }
        
        // 2. PROFONDEUR
        for input in inputs { itemDepth[input.resourceName] = 0 }
        for _ in 0..<10 {
            for step in plan {
                var maxIngDepth = -1
                if let recipe = step.recipe {
                    for (ingName, _) in recipe.ingredients {
                        let d = itemDepth[ingName] ?? 0
                        if d > maxIngDepth { maxIngDepth = d }
                    }
                }
                let currentDepth = (maxIngDepth == -1) ? 0 : (maxIngDepth + 1)
                if currentDepth > (itemDepth[step.item.name] ?? -1) {
                    itemDepth[step.item.name] = currentDepth
                }
            }
        }
        
        // 3. NOEUDS
        
        // Inputs
        for input in inputs {
            if nodeMap[input.resourceName] == nil {
                let node = GraphNode(item: ProductionItem(name: input.resourceName, category: "Raw"), label: "Resource Node", subLabel: input.resourceName, recipeName: "\(input.purity.rawValue.capitalized) \(input.miner.rawValue.uppercased())", color: Color.gray, type: .input)
                var temp = node; temp.position = CGPoint(x: 0, y: 0)
                nodes.append(temp)
                nodeMap[input.resourceName] = node.id
            }
        }
        
        // Machines & Outputs
        for step in plan {
            let depth = itemDepth[step.item.name] ?? 1
            let color = getColorForBuilding(step.buildingName)
            
            // Noeud Machine
            let machineNode = GraphNode(
                item: step.item,
                label: "\(String(format: "%.1f", step.machineCount))x \(step.buildingName)",
                subLabel: step.item.name,
                recipeName: step.recipe?.name,
                color: color,
                type: .machine
            )
            var tempMachine = machineNode
            tempMachine.position = CGPoint(x: CGFloat(depth), y: 0)
            nodes.append(tempMachine)
            nodeMap[step.item.name] = machineNode.id
            
            // LOGIQUE CORRIGÉE POUR L'OUTPUT
            // On affiche un output SI :
            // 1. C'est un Goal utilisateur (PRIORITÉ)
            // 2. OU C'est l'item du Sink
            // 3. OU Ce n'est pas consommé ailleurs (fallback)
            let isGoal = goalItemNames.contains(step.item.name)
            let isSink = (step.item.name == sinkItemName)
            let isNotConsumed = !consumedItems.contains(step.item.name)
            
            if isGoal || isSink || isNotConsumed {
                
                // Calculer combien part vers la sortie
                // Si c'est un goal, on prend le ratio demandé * multiplicateur (approximatif ici, ou on affiche tout)
                // Pour simplifier graphiquement : On affiche le total produit par la machine comme dispo en sortie
                // (Même si une partie part vers une autre machine, c'est visuellement acceptable de voir une sortie "Tiges" ET un lien vers "Assembler")
                
                let outputNode = GraphNode(
                    item: step.item,
                    label: isSink && !isGoal ? "SINK OVERFLOW" : "FINAL PRODUCT",
                    subLabel: step.item.name,
                    recipeName: nil, // Pas de recette pour une boite de sortie
                    color: isSink && !isGoal ? Color.purple : Color.ficsitOrange,
                    type: .output
                )
                
                var tempOutput = outputNode
                tempOutput.position = CGPoint(x: CGFloat(depth + 1), y: 0)
                nodes.append(tempOutput)
                
                // Lien Machine -> Output
                let link = GraphLink(
                    fromNodeID: machineNode.id,
                    toNodeID: outputNode.id,
                    rate: step.totalRate, // On affiche le débit total sortant
                    itemName: step.item.name,
                    color: getColorForResource(step.item.name)
                )
                links.append(link)
            }
        }
        
        // 4. LIENS ENTRE MACHINES
        for step in plan {
            guard let recipe = step.recipe, let targetID = nodeMap[step.item.name] else { continue }
            for (ingName, ingRatePerMachine) in recipe.ingredients {
                if let sourceID = nodeMap[ingName] {
                    let link = GraphLink(
                        fromNodeID: sourceID,
                        toNodeID: targetID,
                        rate: ingRatePerMachine * step.machineCount,
                        itemName: ingName,
                        color: getColorForResource(ingName)
                    )
                    links.append(link)
                }
            }
        }
        
        // 5. POSITIONS (Tri)
        let maxDepth = (nodes.map { Int($0.position.x) }.max() ?? 0)
        var finalNodes = nodes
        
        let columnWidth: CGFloat = 350; let rowHeight: CGFloat = 200
        
        for d in 0...maxDepth {
            let colIndices = finalNodes.indices.filter { Int(finalNodes[$0].position.x) == d }
            let sortedIndices = colIndices.sorted {
                let n1 = finalNodes[$0]; let n2 = finalNodes[$1]
                if n1.type == n2.type { return n1.item.name < n2.item.name }
                // Ordre : Input > Machine > Output
                let typeScore: (GraphNodeType) -> Int = { t in switch t { case .input: return 0; case .machine: return 1; case .output: return 2 } }
                return typeScore(n1.type) < typeScore(n2.type)
            }
            
            let totalH = CGFloat(sortedIndices.count) * rowHeight
            let startY = max(100, (1000 - totalH) / 2)
            
            for (i, idx) in sortedIndices.enumerated() {
                let xPx = CGFloat(d) * columnWidth + 100
                let yPx = startY + CGFloat(i) * rowHeight
                finalNodes[idx].position = CGPoint(x: xPx, y: yPx)
            }
        }
        
        let maxWidth = CGFloat((maxDepth + 1) * Int(columnWidth) + 200)
        let maxItemsInCol = (0...maxDepth).map { d in nodes.filter { Int($0.position.x) == d }.count }.max() ?? 0
        let maxHeight = CGFloat(maxItemsInCol * Int(rowHeight) + 400)
        
        return GraphLayout(nodes: finalNodes, links: links, contentSize: CGSize(width: maxWidth, height: maxHeight))
    }
    
    func getColorForBuilding(_ name: String) -> Color {
        let n = name.lowercased()
        if n.contains("smelter") || n.contains("foundry") { return Color.red.opacity(0.8) }
        if n.contains("constructor") { return Color.orange.opacity(0.8) }
        if n.contains("assembler") { return Color.blue.opacity(0.8) }
        if n.contains("manufacturer") { return Color.purple.opacity(0.8) }
        if n.contains("refinery") || n.contains("blender") { return Color.green.opacity(0.8) }
        return Color.gray
    }
    
    func getColorForResource(_ name: String) -> Color {
        let n = name.lowercased()
        if n.contains("iron") { return Color.gray }
        if n.contains("copper") || n.contains("wire") || n.contains("cable") { return Color(red: 0.8, green: 0.5, blue: 0.2) }
        if n.contains("caterium") || n.contains("quickwire") { return Color.yellow }
        if n.contains("coal") || n.contains("steel") { return Color.black }
        if n.contains("concrete") || n.contains("limestone") { return Color.gray.opacity(0.5) }
        if n.contains("screw") { return Color.blue.opacity(0.6) }
        if n.contains("plastic") || n.contains("rubber") { return Color.purple }
        return Color.ficsitOrange
    }
}
