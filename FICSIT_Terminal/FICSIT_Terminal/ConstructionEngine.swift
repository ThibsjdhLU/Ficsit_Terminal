import Foundation
import SwiftUI

// MARK: - CONSTRUCTION MODELS

enum ConstructionType: String, Codable {
    case machine
    case splitter
    case merger
    case belt
    case pipe
    case pipeJunction
}

struct ConstructionPosition: Codable, Equatable {
    var x: Double
    var y: Double
    var z: Double // Hauteur relative au sol (pour empilement éventuel)
    var rotation: Double // En degrés (0, 90, 180, 270)
}

struct ConstructionItem: Identifiable, Codable {
    var id: UUID = UUID()
    let name: String
    let type: ConstructionType
    var position: ConstructionPosition
    var dimensions: BuildingDimensions?
    // Pour les convoyeurs
    var fromID: UUID?
    var toID: UUID?
    var path: [ConstructionPosition]?
}

struct ConstructionPlan: Identifiable, Codable {
    var id: UUID = UUID()
    let name: String
    var items: [ConstructionItem]
    var width: Double
    var length: Double
}

// MARK: - CONSTRUCTION ENGINE

class ConstructionEngine {

    // Configuration de base
    private let foundationSize: Double = 8.0
    private let machineSpacing: Double = 2.0 // Espace entre les machines
    private let manifoldOffset: Double = 4.0 // Espace devant les ports pour splitters/mergers

    // Génère un plan de construction pour une étape donnée
    func generateManifold(for step: ConsolidatedStep, db: FICSITDatabase) -> ConstructionPlan {
        var items: [ConstructionItem] = []

        // 1. Récupérer les infos du bâtiment
        guard let building = db.buildings.first(where: { $0.name == step.buildingName }),
              let dims = building.dimensions,
              let ports = building.ports else {
            return ConstructionPlan(name: "Error", items: [], width: 0, length: 0)
        }

        let machineCount = Int(ceil(step.machineCount))
        let machineWidth = dims.width
        let machineLength = dims.length

        // Espace total requis par machine (largeur + espacement)
        // On aligne sur la grille de 8m si possible pour faire propre, sinon minimum vital
        // Calcul pour alignement grille : arrondi au multiple de 8 supérieur ?
        // Pour l'instant : compact
        let strideX = machineWidth + machineSpacing

        // 2. Placer les machines
        var machineIDs: [UUID] = []

        for i in 0..<machineCount {
            let xPos = Double(i) * strideX
            let yPos = 0.0 // Ligne de base

            let item = ConstructionItem(
                name: building.name,
                type: .machine,
                position: ConstructionPosition(x: xPos, y: yPos, z: 0, rotation: 0),
                dimensions: dims
            )
            items.append(item)
            machineIDs.append(item.id)
        }

        // 3. Placer les Splitters (Entrées) et Mergers (Sorties)
        // On identifie les ports d'entrée et de sortie
        let inputPorts = ports.filter { $0.type == .input }
        let outputPorts = ports.filter { $0.type == .output }

        // --- MANIFOLD D'ENTRÉE ---
        for (portIndex, port) in inputPorts.enumerated() {
            // Le manifold court le long des machines
            // Position Y relative : Si le port est à y=0 (arrière), le splitter est à y = -offset
            // Si le port est à y=length (avant), le splitter est à y = length + offset

            // Calculer un décalage en profondeur pour éviter que les manifolds se chevauchent (ex: Assembler/Manufacturer)
            // On décale de 2m pour chaque port supplémentaire
            let depthOffset = Double(portIndex) * 2.0

            let isBack = port.y < (machineLength / 2)
            let splitterY = isBack ? -(manifoldOffset + depthOffset) : (machineLength + manifoldOffset + depthOffset)

            var previousSplitterID: UUID? = nil
            var previousSplitterPos: ConstructionPosition? = nil

            for i in 0..<machineCount {
                let machineX = Double(i) * strideX
                // Position X du port par rapport à l'origine de la machine
                let portGlobalX = machineX + port.x

                // Placer le Splitter
                let splitterPos = ConstructionPosition(
                    x: portGlobalX,
                    y: splitterY,
                    z: port.z,
                    rotation: isBack ? 180 : 0 // Orienter vers la machine
                )

                let splitter = ConstructionItem(
                    name: "Splitter",
                    type: .splitter,
                    position: splitterPos,
                    dimensions: BuildingDimensions(width: 2, length: 2, height: 2)
                )
                items.append(splitter)

                // Connecter Splitter -> Machine
                let machinePortPos = ConstructionPosition(
                    x: portGlobalX,
                    y: isBack ? 0 : machineLength,
                    z: port.z,
                    rotation: 0
                )

                let beltToMachine = ConstructionItem(
                    name: "Belt",
                    type: .belt,
                    position: machinePortPos,
                    fromID: splitter.id,
                    toID: machineIDs[i],
                    path: [splitterPos, machinePortPos]
                )
                items.append(beltToMachine)

                // Connecter Splitter précédent -> Splitter actuel (Ligne principale)
                if let prevID = previousSplitterID, let prevPos = previousSplitterPos {
                    let beltMain = ConstructionItem(
                        name: "Belt",
                        type: .belt,
                        position: splitterPos, // Pour ref
                        fromID: prevID,
                        toID: splitter.id,
                        path: [prevPos, splitterPos]
                    )
                    items.append(beltMain)
                }

                previousSplitterID = splitter.id
                previousSplitterPos = splitterPos
            }
        }

        // --- MANIFOLD DE SORTIE ---
        for (portIndex, port) in outputPorts.enumerated() {
            // Décalage en profondeur pour les sorties aussi (rarement multiple mais possible ex: Refinery)
            let depthOffset = Double(portIndex) * 2.0

            let isBack = port.y < (machineLength / 2)
            let mergerY = isBack ? -(manifoldOffset + depthOffset) : (machineLength + manifoldOffset + depthOffset)

            var previousMergerID: UUID? = nil
            var previousMergerPos: ConstructionPosition? = nil

            for i in 0..<machineCount {
                let machineX = Double(i) * strideX
                let portGlobalX = machineX + port.x

                // Placer le Merger
                let mergerPos = ConstructionPosition(
                    x: portGlobalX,
                    y: mergerY,
                    z: port.z,
                    rotation: isBack ? 0 : 180 // Orienter vers l'extérieur
                )

                let merger = ConstructionItem(
                    name: "Merger",
                    type: .merger,
                    position: mergerPos,
                    dimensions: BuildingDimensions(width: 2, length: 2, height: 2)
                )
                items.append(merger)

                // Connecter Machine -> Merger
                let machinePortPos = ConstructionPosition(
                    x: portGlobalX,
                    y: isBack ? 0 : machineLength,
                    z: port.z,
                    rotation: 0
                )

                let beltFromMachine = ConstructionItem(
                    name: "Belt",
                    type: .belt,
                    position: mergerPos,
                    fromID: machineIDs[i],
                    toID: merger.id,
                    path: [machinePortPos, mergerPos]
                )
                items.append(beltFromMachine)

                // Connecter Merger précédent -> Merger actuel
                if let prevID = previousMergerID, let prevPos = previousMergerPos {
                    let beltMain = ConstructionItem(
                        name: "Belt",
                        type: .belt,
                        position: mergerPos,
                        fromID: prevID,
                        toID: merger.id,
                        path: [prevPos, mergerPos]
                    )
                    items.append(beltMain)
                }

                previousMergerID = merger.id
                previousMergerPos = mergerPos
            }
        }

        // Calcul dimensions totales
        let totalWidth = Double(machineCount) * strideX
        let totalLength = machineLength + (2 * manifoldOffset) + 4 // Marge

        return ConstructionPlan(
            name: "\(step.machineCount)x \(building.name)",
            items: items,
            width: totalWidth,
            length: totalLength
        )
    }
}
