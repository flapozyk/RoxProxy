import SwiftUI

/// Full implementation in Step 9. Shows a placeholder for now.
struct DomainListView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        @Bindable var store = settingsStore

        VStack(alignment: .leading, spacing: 12) {
            Text("Add domains here to enable HTTPS decryption (MITM).")
                .font(.callout)
                .foregroundStyle(.secondary)

            // Domain list — full UI in Step 9
            List(store.settings.domainRules) { rule in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { rule.isEnabled },
                        set: { newVal in
                            if let idx = store.settings.domainRules.firstIndex(where: { $0.id == rule.id }) {
                                store.settings.domainRules[idx].isEnabled = newVal
                                settingsStore.save()
                            }
                        }
                    ))
                    .labelsHidden()
                    Text(rule.domain)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(role: .destructive) {
                        settingsStore.removeDomain(id: rule.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }

            AddDomainField(settingsStore: settingsStore)
        }
    }
}

private struct AddDomainField: View {
    let settingsStore: SettingsStore
    @State private var newDomain = ""

    var body: some View {
        HStack {
            TextField("e.g. api.example.com or *.example.com", text: $newDomain)
                .onSubmit { addDomain() }
            Button("Add") { addDomain() }
                .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func addDomain() {
        settingsStore.addDomain(newDomain)
        newDomain = ""
    }
}
