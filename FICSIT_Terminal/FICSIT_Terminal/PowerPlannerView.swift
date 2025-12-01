import SwiftUI

struct PowerPlannerView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 25) {
                        VStack(alignment: .leading) {
                            Text("POWER GRID MONITOR").font(.headline).foregroundColor(.ficsitOrange).padding(.top)
                            Text("Balance production vs consumption.").font(.caption).foregroundColor(.gray)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                        
                        VStack(spacing: 15) {
                            HStack { Text("FUEL TYPE").font(.caption).fontWeight(.bold).foregroundColor(.gray); Spacer() }
                            Picker("Fuel", selection: $viewModel.selectedFuel) { ForEach(PowerFuel.allCases) { fuel in Text(fuel.rawValue).tag(fuel) } }.pickerStyle(SegmentedPickerStyle()).colorMultiply(.ficsitOrange)
                            HStack { Text("AMOUNT AVAILABLE").font(.caption).fontWeight(.bold).foregroundColor(.gray); Spacer() }
                            HStack {
                                TextField("Amount", text: $viewModel.fuelInputAmount).keyboardType(.decimalPad).padding().background(Color.white.opacity(0.1)).cornerRadius(8).foregroundColor(.white).font(.system(.title3, design: .monospaced))
                                Text(viewModel.selectedFuel == .coal ? "/ min" : "m³/min").foregroundColor(.gray)
                            }
                            Button(action: { withAnimation { viewModel.calculatePower() } }) { HStack { Image(systemName: "bolt.fill"); Text("UPDATE GRID") }.font(.headline).frame(maxWidth: .infinity).padding().background(Color.ficsitOrange).foregroundColor(.black).cornerRadius(10) }
                        }.padding().background(Color.black.opacity(0.3)).cornerRadius(15).padding(.horizontal)
                        
                        if let result = viewModel.powerResult {
                            VStack(spacing: 20) {
                                let consumption = viewModel.totalPower
                                let production = result.totalMW
                                let loadPercentage = production > 0 ? (consumption / production) : 0
                                let isOverloaded = consumption > production
                                
                                ZStack {
                                    Circle().trim(from: 0, to: 0.5).stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 25, lineCap: .round)).frame(width: 220, height: 220).rotationEffect(.degrees(180)).offset(y: 50)
                                    Circle().trim(from: 0, to: min(0.5, 0.5 * loadPercentage)).stroke(isOverloaded ? Color.red : (loadPercentage > 0.9 ? Color.yellow : Color.green), style: StrokeStyle(lineWidth: 25, lineCap: .round)).frame(width: 220, height: 220).rotationEffect(.degrees(180)).offset(y: 50).animation(.easeOut, value: loadPercentage)
                                    VStack(spacing: 5) {
                                        Text(isOverloaded ? "OVERLOAD" : "STABLE").font(.caption).fontWeight(.black).foregroundColor(isOverloaded ? .red : .green).padding(5).background(Color.black.opacity(0.5)).cornerRadius(5)
                                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                                            Text("\(Int(consumption))").font(.system(size: 30, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                            Text(" / \(Int(production)) MW").font(.system(size: 16, weight: .medium, design: .monospaced)).foregroundColor(.gray)
                                        }
                                        Text("Grid Load: \(Int(loadPercentage * 100))%").font(.caption).foregroundColor(.ficsitOrange)
                                    }.offset(y: 10)
                                }.frame(height: 160).padding(.top, 20)
                                Divider().background(Color.gray)
                                VStack(spacing: 15) {
                                    HStack {
                                        ItemIcon(item: ProductionItem(name: result.fuel.rawValue, category: "Fuel", sinkValue: 0), size: 40)
                                        VStack(alignment: .leading) { Text(result.fuel.generatorType).font(.headline).foregroundColor(.white); Text("Burn rate: \(String(format: "%.1f", 60/result.fuel.burnTime))/min").font(.caption).foregroundColor(.gray) }
                                        Spacer(); Text("\(String(format: "%.1f", result.generators))x").font(.title2).fontWeight(.bold).foregroundColor(.ficsitOrange)
                                    }
                                    if result.fuel == .coal {
                                        HStack {
                                            ZStack { RoundedRectangle(cornerRadius: 6).fill(Color.blue.opacity(0.2)).frame(width: 40, height: 40); Image(systemName: "drop.fill").foregroundColor(.blue) }
                                            VStack(alignment: .leading) { Text("Water Needed").font(.headline).foregroundColor(.white); Text("\(Int(result.waterNeeded)) m³/min").font(.caption).foregroundColor(.blue) }
                                            Spacer(); VStack(alignment: .trailing) { Text("\(String(format: "%.1f", result.waterExtractors))x").font(.title2).fontWeight(.bold).foregroundColor(.blue); Text("Extractors").font(.caption).foregroundColor(.gray) }
                                        }
                                    }
                                    HStack {
                                        Image(systemName: isOverloaded ? "exclamationmark.triangle.fill" : "battery.100.bolt").foregroundColor(isOverloaded ? .red : .green)
                                        if isOverloaded { Text("Grid failure imminent! Add \(Int(consumption - production)) MW.").font(.caption).foregroundColor(.red) }
                                        else { Text("Spare Capacity: \(Int(production - consumption)) MW").font(.caption).foregroundColor(.green) }
                                    }.padding().frame(maxWidth: .infinity).background(isOverloaded ? Color.red.opacity(0.1) : Color.green.opacity(0.1)).cornerRadius(8)
                                }.padding()
                            }.background(Color.black.opacity(0.3)).cornerRadius(15).padding(.horizontal)
                        } else { Text("Enter fuel amount and simulate to see grid status.").foregroundColor(.gray).padding(.top, 40) }
                        Spacer()
                    }
                }
            }.navigationBarHidden(true)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }.foregroundColor(.ficsitOrange) } }
        }
    }
}
