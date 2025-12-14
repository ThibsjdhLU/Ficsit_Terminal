import SwiftUI

struct MachineRow: View {
    let step: ConsolidatedStep
    @State private var sliderValue: Double
    @State private var isExpanded = false

    init(step: ConsolidatedStep) {
        self.step = step
        // Initialize slider with current clockSpeed (default 1.0 or 100%)
        _sliderValue = State(initialValue: step.clockSpeed * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Main Row
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    // Recipe Icon (if available, else Machine icon logic)
                    if let recipe = step.recipe {
                        // Ideally we'd have recipe icons, but we use product icon
                        ItemIcon(item: step.item, size: 30)
                    } else {
                        Image(systemName: "gear").font(.title2)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.recipe?.localizedName ?? step.item.localizedName)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(String(format: "%.1f x %@", adjustedMachineCount, Localization.translate(step.buildingName)))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.ficsitOrange)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(String(format: "%.1f", step.totalRate))/min")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        // Show power with overclock adjustment
                        Text("\(Int(adjustedPower)) MW")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }

                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded Section: Overclocking
            if isExpanded {
                VStack(alignment: .leading) {
                    Divider().background(Color.gray.opacity(0.3))

                    Text(Localization.translate("OVERCLOCKING"))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.ficsitOrange)

                    HStack {
                        Slider(value: $sliderValue, in: 1...250, step: 1)
                            .accentColor(.ficsitOrange)

                        Text("\(Int(sliderValue))%")
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 50)
                            .foregroundColor(.white)
                    }

                    Text(Localization.translate("Adjusts machine count and power usage simulation."))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.top, 5)
            }
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(isExpanded ? 0.3 : 0.0))
        .cornerRadius(8)
    }

    // Computed Properties for Display Only
    var adjustedMachineCount: Double {
        let clock = sliderValue / 100.0
        return step.machineCount / clock
    }

    var adjustedPower: Double {
        let clock = sliderValue / 100.0
        // Power formula: Base * (Clock/100)^1.6
        // Wait, Satisfactory power formula is roughly: Consumption * (Clock)^1.321928 (approx) or 1.6 in older versions.
        // Let's use simple exponent for simulation: P = P_base * (clk)^1.6
        // step.powerUsage is the total power for ALL machines at 100%.
        // New Total Power = (New Machine Count) * (Power per Machine @ Clock)
        // Power per Machine @ Clock = BasePower * (clock)^1.6
        // New Machine Count = OldCount / clock
        // Total = (OldCount / clock) * BasePower * (clock)^1.6
        //       = OldCount * BasePower * clock^0.6
        //       = OldTotalPower * clock^0.6

        return step.powerUsage * pow(clock, 0.6) // Corrected for fixed output
    }
}
