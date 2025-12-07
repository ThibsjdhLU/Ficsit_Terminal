import SwiftUI

struct ShoppingListView: View {
    @ObservedObject var viewModel: CalculatorViewModel
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                if viewModel.shoppingList.isEmpty {
                    VStack { Image(systemName: "cart.badge.minus").font(.system(size: 50)).foregroundColor(.ficsitGray); Text(Localization.translate("No materials required")).font(.headline).foregroundColor(.ficsitGray).padding(); Text(Localization.translate("Calculate a plan first.")).font(.caption).foregroundColor(.ficsitGray) }
                } else {
                    VStack {
                        HStack { Image(systemName: "hammer.fill").foregroundColor(.ficsitOrange); Text(Localization.translate("CONSTRUCTION MATERIALS")).font(.headline).foregroundColor(.ficsitOrange); Spacer() }.padding().background(Color.white.opacity(0.05))
                        List { ForEach(viewModel.shoppingList) { entry in ShoppingRow(item: entry.item, count: entry.count) } }.listStyle(InsetGroupedListStyle())
                    }
                }
            }
            .navigationBarTitle(Localization.translate("SHOPPING LIST"), displayMode: .inline)
            .navigationBarItems(trailing: Button(Localization.translate("Close")) { presentationMode.wrappedValue.dismiss() })
        }.accentColor(.ficsitOrange)
    }
}

struct ShoppingRow: View {
    let item: ProductionItem
    let count: Int
    @State private var isChecked: Bool = false
    var body: some View {
        Button(action: { withAnimation(.spring()) { isChecked.toggle(); let generator = UIImpactFeedbackGenerator(style: .medium); generator.impactOccurred() } }) {
            HStack {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle").font(.title2).foregroundColor(isChecked ? .green : .ficsitGray)
                ItemIcon(item: item, size: 35).opacity(isChecked ? 0.5 : 1.0)
                Text(item.localizedName).fontWeight(.bold).foregroundColor(isChecked ? .ficsitGray : .white).strikethrough(isChecked)
                Spacer()
                Text("\(count)").font(.system(.body, design: .monospaced)).foregroundColor(isChecked ? .ficsitGray : .ficsitOrange)
            }
        }.listRowBackground(Color.ficsitDark.opacity(0.8))
    }
}
