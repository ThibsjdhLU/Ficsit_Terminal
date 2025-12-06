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
                // Créer un ID stable basé sur le nom et le type
                let stableID = UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", (input.resourceName + "_input").hashValue & 0xFFFFFFFFFFFF))") ?? UUID()
                let node = GraphNode(
                    id: stableID,
                    item: ProductionItem(name: input.resourceName, category: "Raw"),
                    label: "Resource Node",
                    subLabel: input.resourceName,
                    recipeName: "\(input.purity.rawValue.capitalized) \(input.miner.rawValue.uppercased())",
                    color: Color.gray,
                    type: .input,
                    position: CGPoint(x: 0, y: 0)
                )
                nodes.append(node)
                nodeMap[input.resourceName] = node.id
            }
        }
        
        // Machines & Outputs
        for step in plan {
            let depth = itemDepth[step.item.name] ?? 1
            let color = getColorForBuilding(step.buildingName)
            
            // Noeud Machine - ID stable basé sur le nom de l'item et le type
            let machineNodeID = UUID(uuidString: "00000000-0000-0000-0001-\(String(format: "%012x", (step.item.name + "_machine").hashValue & 0xFFFFFFFFFFFF))") ?? UUID()
            let machineNode = GraphNode(
                id: machineNodeID,
                item: step.item,
                label: "\(String(format: "%.1f", step.machineCount))x \(step.buildingName)",
                subLabel: step.item.name,
                recipeName: step.recipe?.name,
                color: color,
                type: .machine,
                position: CGPoint(x: CGFloat(depth), y: 0)
            )
            nodes.append(machineNode)
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
                
                // Output Node - ID stable basé sur le nom de l'item et le type
                let outputNodeID = UUID(uuidString: "00000000-0000-0000-0002-\(String(format: "%012x", (step.item.name + "_output").hashValue & 0xFFFFFFFFFFFF))") ?? UUID()
                let outputNode = GraphNode(
                    id: outputNodeID,
                    item: step.item,
                    label: isSink && !isGoal ? "SINK OVERFLOW" : "FINAL PRODUCT",
                    subLabel: step.item.name,
                    recipeName: nil, // Pas de recette pour une boite de sortie
                    color: isSink && !isGoal ? Color.purple : Color.ficsitOrange,
                    type: .output,
                    position: CGPoint(x: CGFloat(depth + 1), y: 0)
                )
                nodes.append(outputNode)
                
                // Lien Machine -> Output
                // IMPORTANT: Utiliser les IDs des noeuds qui sont DÉJÀ dans la liste nodes
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
        // IMPORTANT: Créer les liens APRÈS avoir tous les noeuds, mais AVANT de modifier les positions
        for step in plan {
            guard let recipe = step.recipe else { continue }
            
            // Trouver le noeud machine cible (celui qui produit l'item)
            guard let targetMachineNode = nodes.first(where: { 
                $0.item.name == step.item.name && $0.type == .machine 
            }) else {
                print("⚠️ No machine node found for \(step.item.name)")
                continue
            }
            
            for (ingName, ingRatePerMachine) in recipe.ingredients {
                // Trouver le noeud source (peut être input ou machine)
                // PRIORITÉ: Prendre le noeud machine s'il existe, sinon l'input
                let sourceNode = nodes.first(where: { 
                    $0.item.name == ingName && $0.type == .machine
                }) ?? nodes.first(where: { 
                    $0.item.name == ingName && $0.type == .input
                })
                
                if let sourceNode = sourceNode {
                    let link = GraphLink(
                        fromNodeID: sourceNode.id,
                        toNodeID: targetMachineNode.id,
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
        
        
        let columnWidth: CGFloat = GraphConfig.columnWidth
        let rowHeight: CGFloat = GraphConfig.rowHeight
        
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
        
        // FILTRER les liens pour ne garder que ceux dont les noeuds existent
        let validNodeIDs = Set(finalNodes.map { $0.id })
        let validLinks = links.filter { link in
            validNodeIDs.contains(link.fromNodeID) && validNodeIDs.contains(link.toNodeID)
        }
        
        if validLinks.count != links.count {
            print("⚠️ Filtered out \(links.count - validLinks.count) invalid links")
            print("   Valid node IDs: \(validNodeIDs)")
            print("   Invalid link IDs: \(Set(links.map { $0.fromNodeID }).union(Set(links.map { $0.toNodeID })).subtracting(validNodeIDs))")
        }
        
        return GraphLayout(nodes: finalNodes, links: validLinks, contentSize: CGSize(width: maxWidth, height: maxHeight))
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
        // Couleurs harmonieuses et saturées pour meilleure visibilité
        if n.contains("iron") { return Color(red: 0.35, green: 0.35, blue: 0.45) } // Gris acier
        if n.contains("copper") || n.contains("wire") || n.contains("cable") { return Color(red: 0.95, green: 0.65, blue: 0.25) } // Orange cuivre chaud
        if n.contains("caterium") || n.contains("quickwire") { return Color(red: 1.0, green: 0.85, blue: 0.1) } // Or
        if n.contains("coal") || n.contains("steel") { return Color(red: 0.15, green: 0.15, blue: 0.2) } // Noir charbon
        if n.contains("concrete") || n.contains("limestone") { return Color(red: 0.65, green: 0.65, blue: 0.7) } // Gris béton
        if n.contains("screw") { return Color(red: 0.25, green: 0.5, blue: 0.95) } // Bleu acier
        if n.contains("plastic") || n.contains("rubber") { return Color(red: 0.75, green: 0.35, blue: 0.95) } // Violet vif
        if n.contains("oil") || n.contains("fuel") { return Color(red: 0.25, green: 0.25, blue: 0.3) } // Gris pétrole
        if n.contains("water") { return Color(red: 0.25, green: 0.6, blue: 0.95) } // Bleu océan
        if n.contains("plate") { return Color(red: 0.5, green: 0.5, blue: 0.6) } // Gris métallique
        if n.contains("rod") { return Color(red: 0.45, green: 0.45, blue: 0.55) } // Gris tige
        return Color(red: 1.0, green: 0.65, blue: 0.35) // Orange FICSIT
    }
}
