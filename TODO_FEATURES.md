# FICSIT_Terminal Feature Checklist

## 1. FUNCTIONALITIES

### Core Production Planning
- [x] **Advanced Production Calculator**
  - [x] Input desired output rate (items/min) for any item
  - [x] Auto-calculate required input rates for all intermediate components
  - [x] Support for alternate recipes with toggle switching
  - [x] Recipe comparison tool (show efficiency gains/losses between alternates)
  - [ ] Batch production planning (set quantities instead of rates)
  - [x] Multi-product production chains (plan several items simultaneously)

### Power Management
- [x] Real-time power consumption calculation for entire production chain
- [x] Power generation capacity calculator (list all generators and their output)
- [x] Overclocking/underclocking simulation with power impact visualization
- [x] Power deficit/surplus alerts
- [x] Backup power source recommendations
- [ ] Power distribution network planning helper

### Resource Extraction
- [ ] Node type database (pure/normal/impure nodes with extraction rates)
- [ ] Mining head efficiency calculator based on resource purity
- [ ] Miner placement planning (normal miners vs. oil extractors vs. wells)
- [ ] Extraction rate optimization for impure nodes
- [ ] Resource sustainability analysis (can the map supply your factory?)

### Building Simulation
- [x] Machine production rates with overclock/underclock sliders
- [ ] Building footprint and space requirements calculator
- [ ] Conveyor belt capacity checker (confirm throughput matches)
- [ ] Storage requirements calculator for buffers
- [ ] Splitter/merger balancing help
- [ ] Manifold vs. main bus logistics recommendations

### Recipe Management
- [x] Complete item and recipe database (auto-updated from game files)
- [x] Ingredient breakdown tree (show all raw materials needed for end product)
- [x] Recipe filtering (by tier, by alternate recipes, by machine type)
- [ ] Recipe notes/comments system (add personal preferences or tips)
- [ ] Favorite recipes bookmarking

### Planning & Tracking
- [ ] **Production Blueprint System**
  - [ ] Save custom production setups as templates
  - [ ] Multi-version blueprint saving (plan iterations)
  - [ ] Blueprint duplication and modification
  - [ ] Blueprint sharing with community
  - [ ] Blueprint import/export for team coordination

- [x] **Factory Project Management**
  - [x] Multiple factory projects (per playthrough or per location)
  - [ ] Project hierarchy (main factory, sub-factories, outposts)
  - [x] Progress tracking (% of plan completed)
  - [ ] Notes and documentation per project
  - [ ] Screenshots/image attachment for planning reference

- [x] **To-Do List System**
  - [x] Add items to build with specific quantities
  - [ ] Break down production chains into buildable tasks
  - [x] Categorize by production tier or location
  - [x] Priority tagging (must-build now vs. future expansion)
  - [x] Check-off system with progress visualization
  - [ ] Time estimates for building each item (based on machine count)

- [x] **Resource Tracking**
  - [ ] Current inventory tracking (manual input or cloud sync from save file)
  - [ ] Surplus/deficit calculator based on plan vs. inventory
  - [x] Shopping list generation from production plan
  - [ ] Cost calculator (hard drives, biomass, electricity consumption)

- [ ] **Logistics Planning**
  - [ ] Conveyor belt routing helper (suggest optimal paths)
  - [ ] Train station planning (frequency, length, capacity)
  - [ ] Truck station recommendations
  - [ ] Hypertube network mapping
  - [ ] Splitter/merger configuration guides

### Database & Information
- [x] **Complete Game Database**
  - [x] All buildings with full specifications
  - [x] All items and their properties
  - [x] All recipes with machine requirements
  - [ ] Research/unlock data (which tier unlocks what)
  - [ ] Item weights and stack sizes (for logistics)

- [x] **Search & Filter System**
  - [x] Search items by name, recipe, or resource type
  - [x] Advanced filters (by item type, production method, tier)
  - [x] Quick access to related recipes and alternatives
  - [ ] Tag system for custom categorization

- [ ] **Wiki Integration**
  - [x] In-app tips for each machine and item
  - [ ] Best practice guides (vertical builds, power routing, blueprint strategies)
  - [ ] Video tutorial links (YouTube or external)
  - [ ] Community tips section (crowdsourced player advice)
  - [x] Off-line access to documentation

## 2. USER EXPERIENCE (UX)

### Navigation & Information Architecture
- [x] **Tab-Based Organization**
- [x] **Smart Contextual Navigation**
  - [x] Persistent search bar (quick access to items/recipes from anywhere)
  - [ ] Recent items list (quick revisit of recently planned items)
  - [ ] Breadcrumb navigation (know where you are in the hierarchy)
  - [ ] Undo/redo functionality
  - [ ] Recent searches or favorites quick-access

### Onboarding & Tutorials
- [ ] First-time user walkthrough (interactive tutorial)
- [ ] Contextual help tooltips on first use
- [ ] "How-to" guides for major features (1-2 minute reads)
- [ ] Guided production chain planning template
- [ ] Beginner vs. Advanced mode toggle

### Workflow Optimization
- [ ] **Quick-Add Features**
  - [ ] Swipe to add item to current production
  - [ ] Long-press for options menu (edit, delete, duplicate)
  - [ ] Preset quantities (common values like 10, 30, 60 items/min)
  - [ ] Copy production chain from other players' blueprints

- [ ] **Smart Calculations**
  - [x] Auto-calculate as you type (no "calculate" button needed) - *Partially implemented via debounce*
  - [x] Show immediate feedback (machine count, power, space required)
  - [x] Highlight inefficiencies or problems in red
  - [ ] Suggest optimizations or alternate recipes

- [ ] **Batch Operations**
  - [ ] Select multiple items and adjust together
  - [ ] Bulk add items to to-do list
  - [ ] Multi-item comparison (which recipe is most efficient?)
  - [ ] Export multiple blueprints at once

- [ ] **Smart Defaults**
  - [ ] Remember last-used production rates
  - [ ] Auto-fill common intermediates (iron plates, copper ingots)
  - [ ] Suggest next logical step in production chain
  - [ ] Pre-fill quantities based on available resources

### Data Management
- [x] Auto-save every change (transparent to user)
- [ ] Cloud sync option (for multi-device continuity)
- [ ] Local backup option
- [ ] Version history (rollback to previous states)
- [ ] Export/import to JSON or CSV for backup
- [x] Offline Functionality

### Error Prevention & Recovery
- [ ] Confirm before deleting (with undo option)
- [x] Input validation (prevent invalid quantities)
- [x] Warning for impossible production chains
- [ ] Auto-correction of common mistakes

### Accessibility & Inclusivity
- [x] Dynamic type support
- [x] High contrast mode for readability
- [x] Large touch targets
- [x] Clear visual hierarchy
- [ ] Color-blind friendly palette
- [x] Support for light and dark modes
- [ ] Texture + color for all indicators
- [x] Sufficient contrast ratios
- [ ] Motor & Gesture Support improvements
- [ ] Voice input option for searches

### Performance & Responsiveness
- [x] Sub-100ms response to user input
- [x] Instant search results
- [ ] Smooth animations (60 FPS)
- [x] Progress indicators for long operations
- [ ] Background loading of heavy features

## 3. USER INTERFACE (UI)

### Layout & Visual Hierarchy
- [x] Clean, Minimal Aesthetic
- [x] Single-column layout for mobile-first design
- [x] Production Input Screen
- [x] Project/Factory Dashboard
- [x] To-Do List Screen

### Visual Design Elements
- [x] Color System
- [x] Typography
- [x] Icons
- [x] Input Controls
- [x] Cards & Containers
- [x] Charts & Visualizations
- [x] Dark Mode Support

### Animations & Micro-Interactions
- [ ] Transitions
- [x] Micro-Interactions (Haptic feedback)
- [ ] Lottie Animations
