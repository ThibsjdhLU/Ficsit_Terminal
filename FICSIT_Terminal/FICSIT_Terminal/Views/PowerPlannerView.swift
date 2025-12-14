import SwiftUI

struct PowerPlannerView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    var body: some View {
        let consumption = viewModel.totalPower
        let production = viewModel.getGridCapacity()
        let effectiveProduction = production > 0 ? production : (viewModel.powerResult?.totalMW ?? 0)

        let loadPercentage = effectiveProduction > 0 ? (consumption / effectiveProduction) : 0
        let isOverloaded = consumption > effectiveProduction

        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 25) {
                        VStack(alignment: .leading) {
                            Text(Localization.translate("GRID MONITOR")).font(.headline).foregroundColor(.ficsitOrange).padding(.top)
                            Text(Localization.translate("Balance production vs consumption.")).font(.caption).foregroundColor(.ficsitGray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        VStack(spacing: 15) {
                            HStack { Text(Localization.translate("FUEL TYPE")).font(.caption).fontWeight(.bold).foregroundColor(.ficsitGray); Spacer() }
                            Picker("Fuel", selection: $viewModel.selectedFuel) {
                                ForEach(PowerFuel.allCases) { fuel in
                                    Text(fuel.localizedName).tag(fuel)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .colorMultiply(.ficsitOrange)
                            
                            HStack { Text(Localization.translate("AVAILABLE AMOUNT")).font(.caption).fontWeight(.bold).foregroundColor(.ficsitGray); Spacer() }
                            HStack {
                                TextField("Quantité", text: $viewModel.fuelInputAmount)
                                    .keyboardType(.decimalPad)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                    .font(.system(.title3, design: .monospaced))
                                Text(viewModel.selectedFuel == .coal ? "/ min" : "m³/min").foregroundColor(.ficsitGray)
                            }
                            Button(action: { withAnimation { viewModel.calculatePower() } }) {
                                HStack { Image(systemName: "bolt.fill"); Text(Localization.translate("UPDATE GRID")) }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.ficsitOrange)
                                    .foregroundColor(.black)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(15)
                        .padding(.horizontal)
                        
                        // --- CAPACITY PLANNER (New Section) ---
                        VStack(alignment: .leading, spacing: 10) {
                            Text(Localization.translate("GENERATOR CAPACITY"))
                                .font(.headline)
                                .foregroundColor(.ficsitOrange)
                                .padding(.horizontal)

                            VStack(spacing: 1) {
                                let generatorTypes = ["Biomass Burner", "Coal Generator", "Fuel Generator", "Nuclear Power Plant"]
                                ForEach(generatorTypes, id: \.self) { genName in
                                    HStack {
                                        Text(Localization.translate(genName))
                                            .font(.body)
                                            .foregroundColor(.white)
                                        Spacer()

                                        HStack {
                                            Button(action: {
                                                let current = viewModel.generatorCounts[genName] ?? 0
                                                viewModel.updateGeneratorCount(name: genName, count: max(0, current - 1))
                                                HapticManager.shared.click()
                                            }) {
                                                Image(systemName: "minus.square.fill")
                                                    .foregroundColor(.ficsitGray)
                                                    .font(.title2)
                                            }

                                            Text("\(Int(viewModel.generatorCounts[genName] ?? 0))")
                                                .font(.system(.body, design: .monospaced))
                                                .frame(width: 40)
                                                .foregroundColor(.white)

                                            Button(action: {
                                                let current = viewModel.generatorCounts[genName] ?? 0
                                                viewModel.updateGeneratorCount(name: genName, count: current + 1)
                                                HapticManager.shared.click()
                                            }) {
                                                Image(systemName: "plus.square.fill")
                                                    .foregroundColor(.ficsitOrange)
                                                    .font(.title2)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color.black.opacity(0.3))
                                }
                            }
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }

                        // --- UPDATED VISUALIZATION ---
                        VStack(spacing: 20) {
                            
                            ZStack {
                                Circle()
                                    .trim(from: 0, to: 0.5)
                                    .stroke(Color.ficsitGray.opacity(0.3), style: StrokeStyle(lineWidth: 25, lineCap: .round))
                                    .frame(width: 220, height: 220)
                                    .rotationEffect(.degrees(180))
                                    .offset(y: 50)
                                
                                Circle()
                                    .trim(from: 0, to: min(0.5, 0.5 * loadPercentage))
                                    .stroke(isOverloaded ? Color(red: 0.8, green: 0.3, blue: 0.3) : (loadPercentage > 0.9 ? .yellow : .green), style: StrokeStyle(lineWidth: 25, lineCap: .round))
                                    .frame(width: 220, height: 220)
                                    .rotationEffect(.degrees(180))
                                    .offset(y: 50)
                                    .animation(.easeOut, value: loadPercentage)
                                
                                VStack(spacing: 5) {
                                    Text(isOverloaded ? Localization.translate("OVERLOAD") : Localization.translate("STABLE"))
                                        .font(.caption)
                                        .fontWeight(.black)
                                        .foregroundColor(isOverloaded ? Color(red: 0.8, green: 0.3, blue: 0.3) : .green)
                                        .padding(5)
                                        .background(Color.black.opacity(0.5))
                                        .cornerRadius(5)
                                    
                                    HStack(alignment: .lastTextBaseline, spacing: 0) {
                                        Text("\(Int(consumption))")
                                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        Text(" / \(Int(effectiveProduction)) MW")
                                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                                            .foregroundColor(.ficsitGray)
                                    }
                                    Text("\(Localization.translate("Load")): \(Int(loadPercentage * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.ficsitOrange)
                                }
                                .offset(y: 10)
                            }
                            .frame(height: 160)
                            .padding(.top, 20)

                            // ALERTS & RECOMMENDATIONS
                            VStack(spacing: 15) {
                                HStack {
                                    Image(systemName: isOverloaded ? "exclamationmark.triangle.fill" : "battery.100.bolt")
                                        .foregroundColor(isOverloaded ? .red : .green)

                                    if isOverloaded {
                                        VStack(alignment: .leading) {
                                            Text(Localization.translate("GRID UNSTABLE"))
                                                .fontWeight(.bold)
                                                .foregroundColor(.red)
                                            Text(viewModel.getBackupRecommendation(excessMW: effectiveProduction - consumption))
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                    } else {
                                        Text("\(Localization.translate("Reserve Capacity")): \(Int(effectiveProduction - consumption)) MW")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.ficsitDark)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isOverloaded ? Color.red : Color.green, lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                        }

                        // OLD SIMULATION SECTION (Optional or Hidden)
                        if let result = viewModel.powerResult, effectiveProduction == 0 {
                            // Only show scenario calculation if manual planner is unused
                            Text("Use the planner above or Fuel Simulation to verify capacity.")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fermer") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(.ficsitOrange)
                }
            }
        }
    }
}
