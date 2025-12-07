import Foundation

struct Localization {
    static let map: [String: String] = [
        // ORES
        "Iron Ore": "Minerai de Fer",
        "Copper Ore": "Minerai de Cuivre",
        "Limestone": "Calcaire",
        "Coal": "Charbon",
        "Caterium Ore": "Minerai de Caterium",
        "Raw Quartz": "Quartz Brut",
        "Sulfur": "Soufre",
        "Bauxite": "Bauxite",
        "Uranium": "Uranium",

        // FLUIDS
        "Water": "Eau",
        "Oil": "Pétrole Brut",
        "Heavy Oil Residue": "Résidu d'Huile Lourde",
        "Nitrogen Gas": "Azote",
        "Sulfuric Acid": "Acide Sulfurique",
        "Fuel": "Carburant",
        "Turbofuel": "Turbocarburant",
        "Alumina Solution": "Solution d'Alumine",

        // INGOTS
        "Iron Ingot": "Lingot de Fer",
        "Copper Ingot": "Lingot de Cuivre",
        "Steel Ingot": "Lingot d'Acier",
        "Caterium Ingot": "Lingot de Caterium",
        "Aluminum Ingot": "Lingot d'Aluminium",

        // PARTS
        "Concrete": "Béton",
        "Iron Plate": "Plaque de Fer",
        "Iron Rod": "Tige de Fer",
        "Screw": "Vis",
        "Reinforced Iron Plate": "Plaque de Fer Renforcée",
        "Wire": "Fil Électrique",
        "Cable": "Câble",
        "Quickwire": "Fil Actif",
        "Copper Sheet": "Tôle de Cuivre",
        "Alclad Aluminum Sheet": "Tôle d'Aluminium",
        "Aluminum Casing": "Boîtier en Aluminium",
        "Steel Beam": "Poutre en Acier",
        "Steel Pipe": "Tuyau en Acier",
        "Encased Industrial Beam": "Poutre en Béton Armé",
        "Modular Frame": "Cadre Modulaire",
        "Heavy Modular Frame": "Cadre Modulaire Lourd",
        "Fused Modular Frame": "Cadre Modulaire Fusionné",
        "Rotor": "Rotor",
        "Stator": "Stator",
        "Motor": "Moteur",
        "Turbo Motor": "Turbo Moteur",
        "Plastic": "Plastique",
        "Rubber": "Caoutchouc",
        "Quartz Crystal": "Cristal de Quartz",
        "Silica": "Silice",
        "Circuit Board": "Circuit Imprimé",
        "AI Limiter": "Limiteur IA",
        "High-Speed Connector": "Connecteur Haute Vitesse",
        "Computer": "Ordinateur",
        "Supercomputer": "Superordinateur",
        "Crystal Oscillator": "Oscillateur à Cristal",
        "Radio Control Unit": "Unité de Contrôle Radio",
        "Heat Sink": "Dissipateur Thermique",
        "Cooling System": "Système de Refroidissement",
        "Battery": "Batterie",
        "Electromagnetic Control Rod": "Barre de Contrôle Électromagnétique",
        "Smart Plating": "Plaquage Intelligent",
        "Versatile Framework": "Structure Polyvalente",
        "Automated Wiring": "Câblage Automatisé",
        "Modular Engine": "Moteur Modulaire",
        "Adaptive Control Unit": "Unité de Contrôle Adaptative",
        "Magnetic Field Generator": "Générateur de Champ Magnétique",
        "Thermal Propulsion Rocket": "Fusée à Propulsion Thermique",
        "Aluminum Scrap": "Déchets d'Aluminium",

        // BUILDINGS
        "Smelter": "Fonderie",
        "Foundry": "Fonderie Avancée",
        "Constructor": "Constructeur",
        "Assembler": "Façonneuse",
        "Manufacturer": "Façonneuse Industrielle",
        "Refinery": "Raffinerie",
        "Packager": "Conditionneuse",
        "Blender": "Mélangeur",
        "Particle Accelerator": "Accélérateur de Particules",
        "Coal Generator": "Générateur à Charbon",
        "Fuel Generator": "Générateur à Carburant",
        "Nuclear Power Plant": "Centrale Nucléaire",

        // RECIPES (Alternates often have "Alternate: " prefix or specific names)
        "Cast Screw": "Vis Moulée",
        "Stitched Iron Plate": "Plaque de Fer Cousue",

        // UI TERMS
        "Resource Node": "Noeud de Ressource",
        "Input": "Entrée",
        "Output": "Sortie",
        "Machine": "Machine",
        "SINK OVERFLOW": "BROYEUR (SURPLUS)",
        "FINAL PRODUCT": "PRODUIT FINAL"
    ]

    static func translate(_ key: String) -> String {
        return map[key] ?? key
    }
}
