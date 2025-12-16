import SwiftUI
import Combine

struct BlueprintListView: View {
    @StateObject private var service = BlueprintService.shared
    @State private var showingAddSheet = false

    var body: some View {
        ZStack {
            // Apply ficsitBackground to the ZStack container, not the VStack
            FicsitBackground()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIBRARY")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.ficsitGray)
                        .tracking(2)

                    Text("BLUEPRINTS")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.ficsitDark)

                if service.blueprints.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.ficsitGray)
                        Text("No Blueprints Saved")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Save your factory plans as blueprints to reuse them later.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(service.blueprints) { blueprint in
                                BlueprintCard(blueprint: blueprint)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            service.delete(blueprint)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

struct BlueprintCard: View {
    let blueprint: Blueprint

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)

                Image(systemName: "doc.text.fill") // Placeholder for item icon
                    .font(.title2)
                    .foregroundColor(.ficsitOrange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(blueprint.name)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.white)

                Text(blueprint.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)

                HStack {
                    Label("\(blueprint.goals.count) outputs", systemImage: "arrow.up.forward.square")
                    Spacer()
                    Text(blueprint.createdDate, style: .date)
                }
                .font(.caption2)
                .foregroundColor(.ficsitGray)
            }
        }
        .padding()
        .ficsitCard()
    }
}
