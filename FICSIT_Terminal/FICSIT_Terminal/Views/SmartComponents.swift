//
//  ItemIcon.swift
//  FICSIT_Terminal
//
//  Created by Thibault Leray-Beer on 30/11/2025.
//


import SwiftUI

// --- ICONE INTELLIGENTE ---
struct ItemIcon: View {
    let item: ProductionItem
    let size: CGFloat
    var body: some View {
        if UIImage(named: item.name.lowercased().replacingOccurrences(of: " ", with: "_")) != nil {
            Image(item.name.lowercased().replacingOccurrences(of: " ", with: "_")).resizable().aspectRatio(contentMode: .fit).frame(width: size, height: size).background(Color.ficsitGray.opacity(0.3)).cornerRadius(4)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color.ficsitGray).frame(width: size, height: size)
                Image(systemName: getSystemIconName(for: item.name)).resizable().aspectRatio(contentMode: .fit).frame(width: size * 0.6, height: size * 0.6).foregroundColor(getColor(for: item.name))
            }
        }
    }
    func getSystemIconName(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("screw") { return "bolt.fill" }
        if n.contains("rod") { return "capsule.portrait.fill" }
        if n.contains("plate") { return "square.fill" }
        if n.contains("wire") { return "scribble" }
        if n.contains("cable") { return "alternatingcurrent" }
        if n.contains("rotor") { return "fanblades.fill" }
        if n.contains("frame") { return "square.grid.3x3.fill"}
        if n.contains("ore") { return "hexagon.fill" }
        if n.contains("ingot") { return "rectangle.roundedtop.fill" }
        if n.contains("concrete") || n.contains("limestone") { return "building.columns.fill" }
        return "cube.fill"
    }
    func getColor(for name: String) -> Color {
        let n = name.lowercased()
        if n.contains("iron") { return Color.gray }
        if n.contains("copper") || n.contains("wire") { return Color(red: 0.8, green: 0.5, blue: 0.3) }
        if n.contains("caterium") { return Color.yellow }
        if n.contains("screw") { return Color.blue.opacity(0.7) }
        return Color.white
    }
}



// --- SELECTEUR INTELLIGENT ---
struct ItemSelectorView: View {
    let title: String
    let items: [ProductionItem]
    @Binding var selection: ProductionItem?
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    var filteredItems: [ProductionItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    var body: some View {
        NavigationView {
            ZStack {
                Color.ficsitDark.ignoresSafeArea()
                List {
                    ForEach(filteredItems) { item in
                        Button(action: { selection = item; presentationMode.wrappedValue.dismiss() }) {
                            HStack {
                                ItemIcon(item: item, size: 30)
                                Text(item.localizedName).foregroundColor(.white)
                                Spacer()
                                if selection?.id == item.id { Image(systemName: "checkmark").foregroundColor(.ficsitOrange) }
                            }
                        }.listRowBackground(Color.ficsitGray.opacity(0.3))
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .searchable(text: $searchText, prompt: "Rechercher...")
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(trailing: Button("Annuler") { presentationMode.wrappedValue.dismiss() })
        }.accentColor(.ficsitOrange)
    }
}

// --- WIKI RECIPE ---
struct RecipeDetailView: View {
    let recipe: Recipe
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(recipe.localizedName).font(.title).fontWeight(.black).foregroundColor(.white)
                if recipe.isAlternate { Text("ALT").font(.caption).fontWeight(.bold).padding(5).background(Color.ficsitOrange).cornerRadius(5) }
            }
            Divider().background(Color.gray)
            HStack {
                Text("Fabriqué dans :").foregroundColor(.gray)
                Text(recipe.machine.localizedName).fontWeight(.bold).foregroundColor(.ficsitOrange)
                Spacer()
                Text("\(Int(recipe.machine.powerConsumption)) MW").font(.system(.body, design: .monospaced)).foregroundColor(.yellow)
            }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text("ENTRÉES / min").font(.caption).foregroundColor(.gray)
                    ForEach(recipe.ingredients.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack { Text("• \(Localization.translate(key))"); Spacer(); Text("\(String(format: "%.1f", value))") }.padding(.vertical, 2)
                    }
                }.frame(maxWidth: .infinity)
                Divider().background(Color.gray)
                VStack(alignment: .leading) {
                    Text("SORTIES / min").font(.caption).foregroundColor(.gray)
                    ForEach(recipe.products.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack { Text("• \(Localization.translate(key))"); Spacer(); Text("\(String(format: "%.1f", value))") }.padding(.vertical, 2)
                    }
                }.frame(maxWidth: .infinity)
            }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
            Spacer()
        }.padding().background(Color.ficsitDark)
    }
}
