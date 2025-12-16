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
- [ ] **Node Type Database** (pure/normal/impure nodes with extraction rates)
- [ ] **Mining Head Efficiency Calculator** based on resource purity
- [ ] **Miner Placement Planning** (normal miners vs. oil extractors vs. wells)
- [ ] **Extraction Rate Optimization** for impure nodes
- [ ] **Resource Sustainability Analysis** (can the map supply your factory?)

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
- [ ] **Tab-Based Organization** (Calculator, Factory, To-Do, Database, Settings)
- [ ] **Smart Contextual Navigation**
  - [x] Persistent search bar
  - [ ] Recent items list
  - [ ] Breadcrumb navigation
  - [ ] Undo/redo functionality
  - [ ] Recent searches or favorites quick-access

### Onboarding & Tutorials
- [ ] First-time user walkthrough
- [ ] Contextual help tooltips on first use
- [ ] "How-to" guides
- [ ] Guided production chain planning template
- [ ] Beginner vs. Advanced mode toggle

### Workflow Optimization
- [ ] **Quick-Add Features**
  - [ ] Swipe to add item
  - [ ] Long-press for options menu
  - [ ] Preset quantities
  - [ ] Copy production chain

- [ ] **Smart Calculations**
  - [x] Auto-calculate as you type
  - [x] Show immediate feedback
  - [x] Highlight inefficiencies
  - [ ] Suggest optimizations

- [ ] **Batch Operations**
  - [ ] Select multiple items
  - [ ] Bulk add items to to-do list
  - [ ] Multi-item comparison
  - [ ] Export multiple blueprints

- [ ] **Smart Defaults**
  - [ ] Remember last-used production rates
  - [ ] Auto-fill common intermediates
  - [ ] Suggest next logical step
  - [ ] Pre-fill quantities

### Data Management
- [x] Auto-save every change
- [ ] Cloud sync option
- [ ] Local backup option
- [ ] Version history
- [ ] Export/import to JSON/CSV
- [x] Offline Functionality

### Error Prevention & Recovery
- [ ] Confirm before deleting
- [x] Input validation
- [x] Warning for impossible production chains
- [ ] Auto-correction of common mistakes

### Accessibility & Inclusivity
- [x] Dynamic type support
- [x] High contrast mode
- [x] Large touch targets
- [x] Clear visual hierarchy
- [ ] Color-blind friendly palette
- [x] Support for light and dark modes
- [ ] Texture + color for all indicators
- [x] Sufficient contrast ratios
- [ ] Motor & Gesture Support improvements
- [ ] Voice input option

### Performance & Responsiveness
- [x] Sub-100ms response
- [x] Instant search results
- [ ] Smooth animations
- [x] Progress indicators
- [ ] Background loading

## 3. USER INTERFACE (UI)

### Layout & Visual Hierarchy
- [x] Clean, Minimal Aesthetic
- [ ] **Production Input Screen** (Specific Layout Requested)
- [ ] **Project/Factory Dashboard** (Specific Layout Requested)
- [ ] **To-Do List Screen** (Specific Layout Requested)

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
- [x] Micro-Interactions
- [ ] Lottie Animations
