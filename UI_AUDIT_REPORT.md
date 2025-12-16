# Rapport d'Audit UI/UX - FICSIT Terminal

Ce document recense de manière exhaustive les problèmes d'interface, d'expérience utilisateur (UX) et de localisation identifiés lors de l'analyse statique du code (SwiftUI).

**Périmètre :** iPhone Only.
**Objectif :** Présentation, Localisation (FR), Design System FICSIT.

---

## 1. Problèmes Globaux & Architecture

### Navigation & Structure
- **Navigation Imbriquée (Critical UX) :** L'application utilise une structure de navigation fractale confuse.
    - `ContentView` (Root) définit un `TabView` avec 7 onglets.
    - `HubDashboardView` (Onglet 0 de ContentView) définit *son propre* `TabView` interne avec 5 onglets.
    - **Conséquence :** Risque de double barre d'onglets, navigation circulaire et perte de contexte pour l'utilisateur.
    - **Recommandation :** Aplatir la hiérarchie de navigation. Le Hub devrait être le seul point d'entrée ou alors `ContentView` doit gérer toute la navigation sans sous-onglets.
- **Utilisation abusive de `NavigationView` :** De nombreuses vues enfants (`CalculatorView`, `InputView`, `RecipeLibraryView`, etc.) instancient leur propre `NavigationView`. Lorsqu'elles sont intégrées dans un `TabView` ou poussées dans une pile existante, cela crée des doubles barres de navigation ou des comportements imprévisibles.

### Design System & Thème
- **Couleurs Hardcodées :** De nombreuses vues définissent des couleurs en dur (RGB ou noms système) au lieu d'utiliser les sémantiques définies dans `Models/Models.swift` ou `DesignSystem.swift`.
    - Ex: `Color(red: 0.1, green: 0.1, blue: 0.12)` au lieu de `.ficsitDark`.
- **Typographie :** L'utilisation de `.fontDesign(.monospaced)` est fréquente (ce qui est bien pour le thème) mais n'est pas systématique ni centralisée dans un modifier commun, créant des disparités visuelles légères.

### Localisation (FR)
- **État Critique :** L'application est majoritairement en Anglais (hardcodé dans les chaînes de caractères). Très peu de vues utilisent systématiquement `Localization.translate`.

---

## 2. Analyse par Vue

### `HubDashboardView.swift`
*   **Localisation :**
    *   Tout le dashboard est en ANGLAIS : "Factory", "Calculator", "Tools", "Database", "To-Do", "FICSIT OS", "DASHBOARD", "CURRENT PROJECT", "ONLINE", "Open Calculator", "ALL PROJECTS", etc.
*   **UI/UX :**
    *   `StatCard` : Largeur fixe à `140`. Risque de débordement ou d'espace vide selon la taille de l'écran iPhone.
    *   Boutons images (ex: `plus.circle.fill`) sans labels, problématique pour la clarté et l'accessibilité.

### `FactoryDashboardView.swift`
*   **Navigation :** Bouton "Back" implémenté manuellement (`onBack`) au lieu d'utiliser la navigation native. Visuellement incohérent (Header custom).
*   **Localisation :** Mélange de `Localization.translate` (bien) et de texte dur (flèche Back).
*   **UI :**
    *   `StatCard` : Même problème de taille fixe.

### `CalculatorView.swift`
*   **UI :**
    *   Menu "Add" utilise des icônes système standard qui jurent un peu avec le style FICSIT très angulaire.
    *   Sections vides ("Tap to Plan Production") : Bon UX (Empty State).
*   **Localisation :**
    *   Headers en Anglais : "Resource Inputs", "Production Lines", "Factory Overview".
    *   "No inputs defined", "Total Power", "Buildings" non traduits.

### `InputView.swift`
*   **UI :**
    *   Sélecteur `BeltLevel` : Scroll horizontal sans indication claire qu'il y a plus d'options. Difficile à découvrir.
    *   Modale `ResourceEditorSheet` :
        *   Picker "Source" (Resource Node / Logistics Import) : Style système par défaut (`SegmentedPickerStyle`), manque de personnalisation FICSIT.
        *   Boutons "Cancel"/"Save" standards dans la barre de navigation, mériteraient un style FICSIT.

### `MachineRow.swift`
*   **UX (Overclocking) :**
    *   Slider 1-250% caché dans un accordéon.
    *   Le slider n'offre pas de feedback visuel direct sur l'impact (puissance/production) *pendant* le drag (uniquement après relâchement si le state ne suit pas bien).
    *   Formule de puissance approximative notée en commentaire (`pow(clock, 0.6)`), vérifier la précision par rapport au jeu.

### `FactoryFlowGraphView.swift` (Visualisation)
*   **Code Quality / Perf :** Très bon usage de `.drawingGroup()` pour le rendu Metal.
*   **UI :**
    *   Couleurs des connexions et nœuds définies en dur dans le code de dessin. Difficile à maintenir.
    *   Badge "FINAL" : Style très spécifique (gradients verts) défini localement.
*   **Localisation :**
    *   Textes durs : "BLUEPRINT USINE", "Diagramme de Flux", "Aucun Plan de Production", "LÉGENDE", "Entrée", "Fonderie", etc.
    *   Légende : Textes en dur.

### `FactoryLayoutView.swift` (Canvas Blueprint)
*   **Localisation :**
    *   Code de dessin (`drawItem`) utilise des lettres "S" (Splitter) et "M" (Merger) en dur. Devrait être localisé ou iconographique.
    *   Légende : Traduction partielle.
*   **UI :** Rendu très technique (lignes simples), correspond à la demande mais manque un peu de "polish" FICSIT (glow, grille plus stylisée).

### `PowerPlannerView.swift`
*   **UI :**
    *   Jauge circulaire : Bon visuel.
    *   Liste "GENERATOR CAPACITY" : Les noms des générateurs ("Biomass Burner", etc.) sont des chaînes en dur utilisées comme clés de dictionnaire.
*   **Localisation :**
    *   Si la clé du dictionnaire est affichée directement, elle sera en anglais.
    *   "GRID MONITOR", "Balance production vs consumption", "FUEL TYPE" non traduits ou traduits partiellement.

### `ResourceExtractionView.swift`
*   **UI :**
    *   Header "RESOURCE EXTRACTION" en double (petit titre + grand titre).
    *   Liste des ressources (`LazyVGrid`) propre.
*   **Localisation :**
    *   Tout en Anglais : "Target Resource", "Configuration", "Node Purity", "Miner Tier", "Clock Speed", "Output Analysis".
    *   Unités ("/ min", "MW") en dur.

### `RecipeLibraryView.swift` & `RecipeComparisonView.swift`
*   **UI :**
    *   Bouton de comparaison (Balance) : Style flottant rond qui diffère des boutons carrés/angulaires du reste de l'app.
    *   Bouton de recherche dans ComparisonView : Style très gros titre, non standard.
*   **Localisation :**
    *   "M.A.M. LIBRARY", "RECIPE ANALYSIS", "Output", "Machine", "Ingredients" en Anglais.

### `ToDoListView.swift`
*   **Localisation :**
    *   "Task Log", "CONSTRUCTION TASKS", "Search tasks...", "New Task" en Anglais.
    *   Filtres ("All", "In Progress") définis par `rawValue` enum en Anglais.

### `BlueprintListView.swift`
*   **UI :**
    *   Empty State ("No Blueprints Saved") bien présent.
    *   Pas de bouton pour *créer* un blueprint (logique si c'est une vue de consultation, mais l'utilisateur pourrait chercher comment faire).
*   **Localisation :**
    *   Tout en Anglais : "LIBRARY", "BLUEPRINTS", "No Blueprints Saved".

---

## 3. Recommandations Prioritaires

1.  **Uniformisation de la Navigation :** Refondre `ContentView` et `HubDashboardView` pour n'avoir qu'une seule barre d'onglets au niveau racine. Supprimer les `NavigationView` imbriqués.
2.  **Campagne de Localisation :** Remplacer TOUTES les chaînes de caractères utilisateur par des appels à `Localization.translate(key)`. Créer un fichier de constantes pour les clés de traduction.
3.  **Nettoyage du Design System :** Remplacer les valeurs de couleurs RGB/Hex en dur par les constantes de `Models.swift` ou `DesignSystem.swift`.
4.  **Composants Réutilisables :** Créer des composants SwiftUI génériques pour les Headers de section et les Cartes de statistiques pour éviter la duplication de code et d'incohérences de taille (`StatCard`).
