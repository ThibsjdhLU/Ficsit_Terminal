import SwiftUI

struct FactoryDashboardView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // HEADER
                HStack {
                    VStack(alignment: .leading) {
                        Text(viewModel.currentProjectName)
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .fontDesign(.monospaced)
                            .foregroundColor(.white)

                        Text(Localization.translate("PRODUCTION SITE"))
                            .font(.caption)
                            .tracking(2)
                            .foregroundColor(.ficsitOrange)
                    }
                    Spacer()
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text(Localization.translate("HUB"))
                        }
                        .fontDesign(.monospaced)
                        .foregroundColor(.ficsitOrange)
                        .padding(8)
                        .background(Color.ficsitDark.opacity(0.8))
                        .cornerRadius(8)
                    }
                }
                .padding()

                // QUICK STATS SCROLL
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        StatCard(
                            title: Localization.translate("POWER USAGE"),
                            value: String(format: "%.1f MW", viewModel.totalPower),
                            icon: "bolt.fill",
                            color: .yellow
                        )

                        StatCard(
                            title: Localization.translate("MAX OUTPUT"),
                            value: String(format: "%.1f /min", viewModel.maxBundlesPossible * (viewModel.goals.first?.ratio ?? 0)),
                            icon: "gearshape.2.fill",
                            color: .green
                        )

                        StatCard(
                            title: Localization.translate("ACTIVE GOALS"),
                            value: "\(viewModel.goals.count)",
                            icon: "target",
                            color: .blue
                        )

                        StatCard(
                            title: Localization.translate("INPUTS"),
                            value: "\(viewModel.userInputs.count)",
                            icon: "arrow.down.circle.fill",
                            color: .ficsitGray
                        )
                    }
                    .padding(.horizontal)
                }

                // ACTIVE PRODUCTION LIST
                VStack(alignment: .leading, spacing: 10) {
                    Text(Localization.translate("ACTIVE PRODUCTION"))
                        .font(.headline)
                        .fontDesign(.monospaced)
                        .foregroundColor(.ficsitOrange)
                        .padding(.horizontal)

                    if viewModel.goals.isEmpty {
                        Text(Localization.translate("No production goals set."))
                            .font(.caption)
                            .italic()
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        ForEach(viewModel.goals) { goal in
                            ProductionGoalCard(goal: goal, maxRate: viewModel.maxBundlesPossible)
                        }
                    }
                }

                // SHOPPING LIST SUMMARY
                if !viewModel.shoppingList.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(Localization.translate("BUILDING REQUIREMENTS"))
                                .font(.headline)
                                .fontDesign(.monospaced)
                                .foregroundColor(.ficsitOrange)
                            Spacer()
                            Text("\(viewModel.shoppingList.reduce(0) { $0 + $1.count }) " + Localization.translate("Items"))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.shoppingList.prefix(5)) { item in
                                    VStack {
                                        Image(item.item.iconName)
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(5)
                                        Text("\(item.count)")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    .padding(8)
                                    .background(Color.ficsitDark)
                                    .cornerRadius(8)
                                }
                                if viewModel.shoppingList.count > 5 {
                                    Text("+\(viewModel.shoppingList.count - 5)")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer()
            }
        }
        .background(Color.black.opacity(0.8)) // Darker background for dashboard
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .fontDesign(.monospaced)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption2)
                .fontDesign(.monospaced)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 140, height: 100)
        .background(Color.ficsitDark)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

struct ProductionGoalCard: View {
    let goal: ProductionGoal
    let maxRate: Double

    var body: some View {
        HStack {
            Image(goal.item.iconName) // Ensure iconName is valid
                .resizable()
                .frame(width: 40, height: 40)
                .cornerRadius(5)
                .background(Color.gray.opacity(0.2))

            VStack(alignment: .leading) {
                Text(goal.item.localizedName)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(Localization.translate("Target")): \(String(format: "%.1f", goal.ratio * maxRate))/min")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill") // Placeholder status
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.ficsitDark)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}
