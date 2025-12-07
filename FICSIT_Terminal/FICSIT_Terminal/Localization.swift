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
        "FINAL PRODUCT": "PRODUIT FINAL",

        // TAB BAR
        "HUB": "HUB",
        "Resources": "Ressources",
        "Factory": "Usine",
        "Power": "Énergie",
        "Library": "M.A.M.",
        "Flow": "Flux",

        // DASHBOARD
        "WELCOME, PIONEER": "BIENVENUE, PIONNIER",
        "GRID STATUS": "ÉTAT DU RÉSEAU",
        "CALCULATING...": "CALCUL EN COURS...",
        "OPERATIONAL": "OPÉRATIONNEL",
        "ACTIVE GOALS": "OBJECTIFS ACTIFS",
        "IDLE": "EN ATTENTE",
        "A.W.E.S.O.M.E. SINK": "BROYEUR A.W.E.S.O.M.E.",
        "POINTS/MIN": "POINTS/MIN",
        "via": "via",
        "NO OVERFLOW": "AUCUN SURPLUS",
        "Quick Actions": "Actions Rapides",
        "New Project": "Nouveau Projet",
        "Notes": "Notes",
        "others...": "autres...",

        // INPUT VIEW
        "RESOURCE SURVEY": "SURVEY RESSOURCES",
        "ADD NODE": "AJOUTER UN NOEUD",
        "Claimed Nodes": "Noeuds Revendiqués",
        "No scanned resources.": "Aucune ressource scannée.",
        "Belt Level": "Niveau de Convoyeur",
        "Cancel": "Annuler",
        "Save": "Sauver",
        "RESOURCE TYPE": "TYPE DE RESSOURCE",
        "Select Resource": "Choisir Ressource",
        "NODE PURITY": "PURETÉ DU NOEUD",
        "MINER LEVEL": "NIVEAU DE MINEUR",
        "EXTRACTION RATE": "DÉBIT EXTRACTION",
        "Add Node": "Ajouter Noeud",
        "Edit Node": "Modifier Noeud",

        // OUTPUT VIEW
        "PRODUCTION MANAGEMENT": "GESTION DE PRODUCTION",
        "Select Part...": "Sélectionner Pièce...",
        "CALCULATE": "CALCULER",
        "ERROR": "ERREUR",
        "POWER USAGE": "CONSO ÉLECTRIQUE",
        "REAL OUTPUTS": "SORTIES RÉELLES",
        "Insufficient resources or bottleneck detected.": "Ressources insuffisantes ou goulot d'étranglement détecté.",
        "Target Ratio": "Ratio Cible",
        "Delete Goal": "Supprimer Objectif",
        "Edit Goal": "Modifier Objectif",

        // SHOPPING LIST
        "SHOPPING LIST": "Liste d'Achats",
        "No materials required": "Aucun matériel requis",
        "Calculate a plan first.": "Calculez d'abord un plan.",
        "CONSTRUCTION MATERIALS": "MATÉRIAUX DE CONSTRUCTION",
        "Close": "Fermer",

        // RECIPE LIBRARY
        "M.A.M. LIBRARY": "BIBLIOTHÈQUE M.A.M.",
        "active": "active",

        // POWER PLANNER
        "GRID MONITOR": "MONITEUR DE RÉSEAU",
        "Balance production vs consumption.": "Équilibrer production vs consommation.",
        "FUEL TYPE": "TYPE DE CARBURANT",
        "AVAILABLE AMOUNT": "QUANTITÉ DISPONIBLE",
        "UPDATE GRID": "METTRE À JOUR RÉSEAU",
        "OVERLOAD": "SURCHARGE",
        "STABLE": "STABLE",
        "Load": "Charge",
        "Cons": "Conso",
        "Water Required": "Eau Requise",
        "Extractors": "Extracteurs",
        "Power Failure Imminent! Add": "Panne imminente! Ajoutez",
        "Reserve Capacity": "Capacité de réserve",
        "Enter fuel amount to simulate.": "Entrez une quantité de carburant pour simuler.",

        // PROJECT MANAGER
        "PROJECT MANAGER": "Gestion de Projets",
        "No saved projects": "Aucun projet sauvegardé",
        "Modified": "Modifié le",
        "SAVE PROJECT": "SAUVEGARDER PROJET",
        "NEW EMPTY PROJECT": "NOUVEAU PROJET VIDE",
        "Save Project": "Sauvegarder Projet",
        "Project Name": "Nom du Projet",
        "Enter a name for your factory.": "Entrez un nom pour votre usine.",

        // BOTTLENECK SUGGESTIONS
        "Add more nodes for": "Ajouter un nœud supplémentaire de",
        "Use a Pure node for": "Utiliser un nœud Pur de",
        "Upgrade Miner to Mk3": "Améliorer le foreur à Mk3",
        "Increase production of": "Augmenter la production de",
        "Check alternate recipes": "Vérifier les recettes alternatives",
        "Verify Mk5 belts are used": "Vérifier que les convoyeurs Mk5 sont utilisés",

        // BLUEPRINT
        "BLUEPRINT": "PLAN",
        "Splitter/Merger": "Répartiteur/Groupeur"
    ]

    static func translate(_ key: String) -> String {
        return map[key] ?? key
    }
}
