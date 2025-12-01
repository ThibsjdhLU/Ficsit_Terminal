import SwiftUI

struct HubDashboardView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @State private var animate = false
    
    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // HEADER
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("EMPLOYEE #8294")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                                Text(viewModel.currentProjectName.uppercased())
                                    .font(.system(size: 24, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Image(systemName: "hexagon.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.ficsitOrange)
                                .overlay(Image(systemName: "person.fill").foregroundColor(.black).font(.caption))
                        }
                        .padding()
                        
                        // MAIN STATS GRID
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            // Energy Card
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "bolt.fill").foregroundColor(.yellow)
                                    Text("GRID").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                }
                                Spacer()
                                let percent = viewModel.powerResult?.totalMW ?? 0 > 0 ? (viewModel.totalPower / viewModel.powerResult!.totalMW) : 0
                                Text("\(Int(percent * 100))%")
                                    .font(.system(size: 30, weight: .black, design: .monospaced))
                                    .foregroundColor(percent > 1 ? .red : .white)
                                Text("\(Int(viewModel.totalPower)) MW LOAD")
                                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                            }
                            .frame(height: 100)
                            .ficsitCard(borderColor: .yellow)
                            
                            // Factory Card
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: "gearshape.2.fill").foregroundColor(.blue)
                                    Text("FACTORY").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                }
                                Spacer()
                                Text("\(viewModel.consolidatedPlan.count)")
                                    .font(.system(size: 30, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("ACTIVE STEPS")
                                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                            }
                            .frame(height: 100)
                            .ficsitCard(borderColor: .blue)
                        }
                        .padding(.horizontal)
                        
                        // SINK CARD (NOUVEAU)
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "ticket.fill").foregroundColor(.purple)
                                Text("AWESOME SINK").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                            }
                            Spacer()
                            if let sink = viewModel.sinkResult {
                                Text("\(sink.totalPoints)")
                                    .font(.system(size: 24, weight: .black, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("POINTS/MIN")
                                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                                Text("via \(sink.bestItem.name)")
                                    .font(.system(size: 8, design: .monospaced)).foregroundColor(.purple)
                            } else {
                                Text("0")
                                    .font(.system(size: 30, weight: .black, design: .monospaced))
                                    .foregroundColor(.gray)
                                Text("NO SURPLUS")
                                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                            }
                        }
                        .frame(height: 100)
                        .ficsitCard(borderColor: .purple)
                        // ACTIVE GOALS LIST
                        VStack(alignment: .leading, spacing: 10) {
                            FicsitHeader(title: "Production Targets", icon: "target")
                            
                            if viewModel.goals.isEmpty {
                                Text("// NO ACTIVE TARGETS //")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.03))
                            } else {
                                ForEach(viewModel.goals) { goal in
                                    HStack {
                                        ItemIcon(item: goal.item, size: 30)
                                        Text(goal.item.name)
                                            .font(.system(.subheadline, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("x\(String(format: "%.1f", goal.ratio * viewModel.maxBundlesPossible))")
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundColor(.ficsitOrange)
                                    }
                                    .padding(8)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(5)
                                }
                            }
                        }
                        .ficsitCard()
                        .padding(.horizontal)
                        
                        // SHORTCUTS
                        VStack(alignment: .leading) {
                            FicsitHeader(title: "Quick Actions", icon: "command")
                            
                            HStack {
                                NavigationLink(destination: Text("New Project Flow")) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("New Project")
                                    }
                                }
                                .buttonStyle(FicsitButtonStyle(primary: false, color: .gray))
                                
                                Button(action: {
                                    // Action
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text("Notes")
                                    }
                                }
                                .buttonStyle(FicsitButtonStyle(primary: false, color: .gray))
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}
