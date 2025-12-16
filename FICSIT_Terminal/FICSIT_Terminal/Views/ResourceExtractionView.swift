import SwiftUI

struct ResourceExtractionView: View {
    // Switch to EnvironmentObject to receive the shared instance from HubDashboardView
    // Fallback to StateObject if not provided (e.g. preview) - but EnvironmentObject is safer for shared state
    @EnvironmentObject var viewModel: ExtractionViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("RESOURCE EXTRACTION")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.ficsitGray)
                    .tracking(2)

                Text("MINING CALCULATOR")
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.ficsitDark)

            // Content
            ScrollView {
                VStack(spacing: 24) {

                    // 1. SELECT RESOURCE
                    VStack(alignment: .leading, spacing: 10) {
                        FicsitHeader(title: "Target Resource", icon: "cube.fill")

                        if let selected = viewModel.selectedResource {
                            HStack {
                                Image(systemName: "cube.fill") // Placeholder icon
                                    .foregroundColor(.ficsitOrange)
                                Text(selected.localizedName)
                                    .font(.headline)
                                Spacer()
                                Button("Change") {
                                    viewModel.selectedResource = nil
                                }
                                .font(.caption)
                                .padding(6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                            }
                            .padding()
                            .ficsitCard()
                        } else {
                            // Resource List
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                                ForEach(viewModel.filteredItems) { item in
                                    Button(action: { viewModel.select(item) }) {
                                        HStack {
                                            Image(systemName: "circle.fill")
                                                .font(.caption)
                                            Text(item.localizedName)
                                                .font(.subheadline)
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }

                    if viewModel.selectedResource != nil {

                        // 2. CONFIGURATION
                        VStack(alignment: .leading, spacing: 15) {
                            FicsitHeader(title: "Configuration", icon: "gearshape.fill")

                            // Purity
                            HStack {
                                Text("Node Purity")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Picker("Purity", selection: $viewModel.selectedPurity) {
                                    ForEach(NodePurity.allCases) { purity in
                                        Text(purity.rawValue.capitalized).tag(purity)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 200)
                            }

                            // Miner
                            HStack {
                                Text("Miner Tier")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Picker("Miner", selection: $viewModel.selectedMiner) {
                                    ForEach(MinerLevel.allCases) { miner in
                                        Text(miner.rawValue.uppercased()).tag(miner)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 200)
                            }

                            // Overclock
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Clock Speed")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(Int(viewModel.clockSpeed * 100))%")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.ficsitOrange)
                                }
                                Slider(value: $viewModel.clockSpeed, in: 0.01...2.5, step: 0.01)
                                    .accentColor(.ficsitOrange)
                            }
                        }
                        .padding()
                        .ficsitCard()

                        // 3. RESULTS
                        VStack(alignment: .leading, spacing: 15) {
                            FicsitHeader(title: "Output Analysis", icon: "chart.bar.fill")

                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("Extraction Rate")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(String(format: "%.1f", viewModel.extractionRate))
                                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                                            .foregroundColor(.ficsitOrange)
                                        Text("/ min")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("Power Usage")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(String(format: "%.1f", viewModel.powerConsumption))
                                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        Text("MW")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .padding()
                        .ficsitCard(borderColor: .green.opacity(0.5))

                        // 4. WORLD STATS (SUSTAINABILITY)
                        if let stats = viewModel.mapStats {
                            VStack(alignment: .leading, spacing: 10) {
                                FicsitHeader(title: "Global Sustainability", icon: "globe")

                                Text("Map Availability for \(stats.resourceName)")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                HStack(spacing: 10) {
                                    StatBox(label: "Impure", value: "\(stats.impure)")
                                    StatBox(label: "Normal", value: "\(stats.normal)")
                                    StatBox(label: "Pure", value: "\(stats.pure)")
                                }

                                Divider().background(Color.white.opacity(0.1))

                                HStack {
                                    Text("Max Global Output")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.0f / min", stats.calculateMaxPotential()))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.ficsitOrange)
                                }
                            }
                            .padding()
                            .ficsitCard()
                        }
                    }
                }
                .padding()
            }
        }
        .ficsitBackground()
        .navigationBarHidden(true)
    }
}

struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(4)
    }
}
