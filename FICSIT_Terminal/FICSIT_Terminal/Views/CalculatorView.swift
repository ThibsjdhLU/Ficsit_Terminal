import SwiftUI

struct CalculatorView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @StateObject private var db = FICSITDatabase.shared
    @State private var showingAddInput = false
    @State private var showingAddProduction = false

    var body: some View {
        ZStack {
            FicsitBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(viewModel.currentProjectName)
                            .font(.headline).fontDesign(.monospaced)
                            .foregroundColor(.white)
                        Text("PRODUCTION STATUS: ONLINE")
                            .font(.caption).bold().foregroundColor(.green)
                    }
                    Spacer()
                    // Add Menu
                    Menu {
                        Button(action: { showingAddProduction = true }) {
                            Label("Add Product Goal", systemImage: "plus.square")
                        }
                        Button(action: { showingAddInput = true }) {
                            Label("Add Resource Input", systemImage: "arrow.down.circle")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .padding()
                            .background(Color.ficsitOrange)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.ficsitDark)

                // Tab-like selection within Calculator (Inputs vs Outputs vs Graph)
                // For now, let's just show a unified view as per request for "Clean, Minimal"

                ScrollView {
                    VStack(spacing: 20) {

                        // INPUTS SECTION
                        VStack(alignment: .leading, spacing: 10) {
                            FicsitHeader(title: "Resource Inputs", icon: "arrow.down.circle.fill")

                            if viewModel.userInputs.isEmpty {
                                Text("No inputs defined.")
                                    .font(.caption).italic().foregroundColor(.gray)
                                    .padding(.horizontal)
                            } else {
                                ForEach(viewModel.userInputs) { input in
                                    InputCard(input: input, viewModel: viewModel) {
                                        // Edit callback
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // GOALS SECTION
                        VStack(alignment: .leading, spacing: 10) {
                            FicsitHeader(title: "Production Lines", icon: "gearshape.2.fill")

                            if viewModel.goals.isEmpty {
                                Button(action: { showingAddProduction = true }) {
                                    VStack(spacing: 10) {
                                        Image(systemName: "plus.square.dashed")
                                            .font(.largeTitle)
                                        Text("Tap to Plan Production")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.ficsitGray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                                    .background(Color.white.opacity(0.02))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [5])))
                                }
                                .padding(.horizontal)
                            } else {
                                ForEach(viewModel.goals) { goal in
                                    ProductionGoalCard(goal: goal, maxRate: viewModel.maxBundlesPossible)
                                        .onTapGesture {
                                            // Show details/edit
                                        }
                                }
                            }
                        }

                        // RESULTS / GRAPH PREVIEW
                        if !viewModel.consolidatedPlan.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                FicsitHeader(title: "Factory Overview", icon: "chart.bar.doc.horizontal.fill")

                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Total Power").font(.caption).foregroundColor(.gray)
                                        Text("\(Int(viewModel.totalPower)) MW").font(.headline).bold().foregroundColor(.yellow)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Buildings").font(.caption).foregroundColor(.gray)
                                        Text("\(viewModel.consolidatedPlan.count)").font(.headline).bold().foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .ficsitCard()
                                .padding(.horizontal)

                                // Simple list of machines
                                ForEach(viewModel.consolidatedPlan) { step in
                                    MachineRow(step: step)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .sheet(isPresented: $showingAddProduction) {
            ProductionInputView(viewModel: viewModel, db: db)
        }
        .sheet(isPresented: $showingAddInput) {
            ResourceEditorSheet(viewModel: viewModel, db: db, mode: .add)
        }
    }
}
