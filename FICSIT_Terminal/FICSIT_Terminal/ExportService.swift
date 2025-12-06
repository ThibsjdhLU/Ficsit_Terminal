import Foundation

struct ExportService {
    static func exportToCSV(plan: [ConsolidatedStep]) -> String {
        var csv = "Machine,Item,Rate/min,Machines,Power MW\n"
        for step in plan {
            csv += "\(step.buildingName),\(step.item.name),\(String(format: "%.2f", step.totalRate)),\(String(format: "%.2f", step.machineCount)),\(String(format: "%.2f", step.powerUsage))\n"
        }
        return csv
    }
    
    static func exportToJSON(project: ProjectData) -> Data? {
        return try? JSONEncoder().encode(project)
    }
    
    static func exportProjectSummary(project: ProjectData, plan: [ConsolidatedStep], totalPower: Double, sinkResult: SinkResult?) -> String {
        var summary = "# \(project.name)\n\n"
        summary += "**Date:** \(DateFormatter.localizedString(from: project.date, dateStyle: .medium, timeStyle: .short))\n\n"
        
        summary += "## Ressources\n"
        for input in project.inputs {
            summary += "- \(input.resourceName): \(String(format: "%.1f", input.productionRate))/min (\(input.purity.rawValue), \(input.miner.rawValue))\n"
        }
        
        summary += "\n## Objectifs\n"
        for goal in project.goals {
            summary += "- \(goal.item.name): \(String(format: "%.1f", goal.ratio))/min\n"
        }
        
        summary += "\n## Plan de Production\n"
        summary += "**Consommation totale:** \(String(format: "%.1f", totalPower)) MW\n\n"
        
        let grouped = Dictionary(grouping: plan, by: { $0.buildingName })
        for (building, steps) in grouped.sorted(by: { $0.key < $1.key }) {
            summary += "### \(building)\n"
            for step in steps {
                summary += "- \(step.item.name): \(String(format: "%.2f", step.machineCount))x machines, \(String(format: "%.2f", step.totalRate))/min\n"
            }
            summary += "\n"
        }
        
        if let sink = sinkResult {
            summary += "## Awesome Sink\n"
            summary += "- Item: \(sink.bestItem.name)\n"
            summary += "- Taux: \(String(format: "%.1f", sink.producedAmount))/min\n"
            summary += "- Points: \(sink.totalPoints)/min\n"
        }
        
        return summary
    }
}

