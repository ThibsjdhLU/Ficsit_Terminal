import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                FicsitBackground()

                List {
                    Section(header: Text(Localization.translate("GENERAL")).fontDesign(.monospaced)) {
                        Toggle(isOn: .constant(true)) {
                            Label(Localization.translate("Dark Mode"), systemImage: "moon.fill")
                        }
                        .disabled(true) // Always Dark Mode for FICSIT

                        Toggle(isOn: .constant(true)) {
                            Label(Localization.translate("Haptic Feedback"), systemImage: "hand.tap.fill")
                        }
                    }
                    .listRowBackground(Color.ficsitDark.opacity(0.8))

                    Section(header: Text(Localization.translate("ABOUT")).fontDesign(.monospaced)) {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0 (FICSIT_Terminal)")
                                .foregroundColor(.gray)
                        }

                        Link(destination: URL(string: "https://satisfactory.wiki.gg")!) {
                            Label(Localization.translate("Official Wiki"), systemImage: "globe")
                        }
                    }
                    .listRowBackground(Color.ficsitDark.opacity(0.8))
                }
                .scrollContentBackground(.hidden)
                .navigationTitle(Localization.translate("Settings"))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
