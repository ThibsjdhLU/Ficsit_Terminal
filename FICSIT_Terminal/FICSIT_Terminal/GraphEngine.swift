import SwiftUI

class GraphEngine {
    
    struct GraphLayout {
        var nodes: [GraphNode]
        var links: [GraphLink]
        var contentSize: CGSize
    }
    
    func generateLayout(from plan: [ConsolidatedStep], inputs: [ResourceInput], db: FICSITDatabase) -> GraphLayout {
        var nodes: [GraphNode] = []
        var links: [GraphLink] = []
        var nodeMap: [String: UUID] = [:]
        var itemDepth: [String: Int] = [:]
        
        // 1. CALCUL DE LA PROFONDEUR (RANG)
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
        
        // 2. CRÉATION DES NOEUDS
        
        // Inputs
        for input in inputs {
            if nodeMap[input.resourceName] == nil {
                let node = GraphNode(
                    item: ProductionItem(name: input.resourceName, category: "Raw", sinkValue: 0),
                    label: "Resource Node",
                    subLabel: input.resourceName,
                    recipeName: "\(input.purity.rawValue.capitalized) \(input.miner.rawValue.uppercased())",
                    color: Color.gray
                )
                var tempNode = node
                tempNode.position = CGPoint(x: 0, y: 0)
                nodes.append(tempNode)
                nodeMap[input.resourceName] = node.id
            }
        }
        
        // Machines
        for step in plan {
            let depth = itemDepth[step.item.name] ?? 1
            let color = getColorForBuilding(step.buildingName)
            
            let node = GraphNode(
                item: step.item,
                label: "\(String(format: "%.1f", step.machineCount))x \(step.buildingName)",
                subLabel: step.item.name,
                recipeName: step.recipe?.name,
                color: color
            )
            
            var tempNode = node
            tempNode.position = CGPoint(x: CGFloat(depth), y: 0)
            nodes.append(tempNode)
            nodeMap[step.item.name] = node.id
        }
        
        // 3. CRÉATION DES LIENS
        for step in plan {
            guard let recipe = step.recipe else { continue }
            guard let targetID = nodeMap[step.item.name] else { continue }
            
            for (ingName, ingRatePerMachine) in recipe.ingredients {
                if let sourceID = nodeMap[ingName] {
                    let totalLinkRate = ingRatePerMachine * step.machineCount
                    let link = GraphLink(
                        fromNodeID: sourceID,
                        toNodeID: targetID,
                        rate: totalLinkRate,
                        itemName: ingName,
                        color: getColorForResource(ingName)
                    )
                    links.append(link)
                }
            }
        }
        
        // 4. POSITIONNEMENT FINAL OPTIMISÉ
        let maxDepth = (nodes.map { Int($0.position.x) }.max() ?? 0)
        var finalNodes = nodes
        
        // Espacements augmentés pour réduire le chevauchement
        let columnWidth: CGFloat = 350
        let rowHeight: CGFloat = 200
        
        for d in 0...maxDepth {
            let colIndices = finalNodes.indices.filter { Int(finalNodes[$0].position.x) == d }
            
            // TRI : On groupe par nom d'item pour éviter les croisements !
            let sortedIndices = colIndices.sorted {
                finalNodes[$0].item.name < finalNodes[$1].item.name
            }
            
            // Centrage vertical
            let totalHeight = CGFloat(sortedIndices.count) * rowHeight
            let startY = max(100, (1000 - totalHeight) / 2)
            
            for (i, nodeIndex) in sortedIndices.enumerated() {
                let xPx = CGFloat(d) * columnWidth + 100
                let yPx = startY + CGFloat(i) * rowHeight
                finalNodes[nodeIndex].position = CGPoint(x: xPx, y: yPx)
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
