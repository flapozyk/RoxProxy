import SwiftUI

struct MainWindowView: View {
    @Environment(ProxySessionStore.self) private var sessionStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var store = sessionStore

        NavigationSplitView {
            RequestListView()
                .navigationSplitViewColumnWidth(min: 400, ideal: 520)
                .navigationTitle("Rox Proxy")
        } detail: {
            if let exchange = sessionStore.selectedExchange {
                DetailView(exchange: exchange)
            } else {
                ContentUnavailableView(
                    "No Request Selected",
                    systemImage: "network",
                    description: Text("Select a captured request to inspect its headers and body.")
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !settingsStore.isCATrusted
                && !settingsStore.settings.domainRules.filter(\.isEnabled).isEmpty
            {
                CAWarningBanner()
            }
        }
        .searchable(text: $store.filterText, prompt: "Filter by URL, host or method")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                proxyToggleButton
            }
            ToolbarItemGroup(placement: .primaryAction) {
                recordToggleButton
                clearButton
                Spacer()
                settingsButton
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StatusBar()
        }
    }

    // MARK: - Toolbar Buttons

    @ViewBuilder
    private var proxyToggleButton: some View {
        let isRunning = sessionStore.proxyState.isRunning
        Button {
            // AppDelegate handles start/stop — post notification
            NotificationCenter.default.post(
                name: isRunning ? .stopProxy : .startProxy,
                object: nil
            )
        } label: {
            Label(
                isRunning ? "Stop Proxy" : "Start Proxy",
                systemImage: isRunning ? "stop.circle.fill" : "play.circle.fill"
            )
        }
        .help(isRunning ? "Stop the proxy server" : "Start the proxy server")
        .tint(isRunning ? .red : .green)
    }

    private var recordToggleButton: some View {
        @Bindable var store = sessionStore
        return Toggle(isOn: $store.isRecording) {
            Label(
                sessionStore.isRecording ? "Recording" : "Paused",
                systemImage: sessionStore.isRecording ? "record.circle" : "pause.circle"
            )
        }
        .toggleStyle(.button)
        .tint(sessionStore.isRecording ? .red : .secondary)
        .help(sessionStore.isRecording ? "Pause recording" : "Resume recording")
    }

    private var clearButton: some View {
        Button {
            sessionStore.clear()
        } label: {
            Label("Clear", systemImage: "trash")
        }
        .help("Clear all captured requests")
        .disabled(sessionStore.exchanges.isEmpty)
    }

    private var settingsButton: some View {
        Button {
            openSettings()
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
        .help("Open settings")
    }
}

// MARK: - CA Warning Banner

private struct CAWarningBanner: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("CA certificate not trusted — HTTPS decryption won't work for configured domains.")
                .font(.caption)
            Spacer()
            Button("Open Settings") { openSettings() }
                .font(.caption)
                .buttonStyle(.link)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - Status Bar

private struct StatusBar: View {
    @Environment(ProxySessionStore.self) private var sessionStore

    var body: some View {
        HStack(spacing: 12) {
            // Proxy state indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                Text(sessionStore.proxyState.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 12)

            // Request count
            Text("\(sessionStore.exchanges.count) request\(sessionStore.exchanges.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !sessionStore.filterText.isEmpty {
                Text("(\(sessionStore.filteredExchanges.count) visible)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var stateColor: Color {
        switch sessionStore.proxyState {
        case .running:  return .green
        case .starting: return .orange
        case .error:    return .red
        case .stopped:  return .gray
        }
    }
}

// MARK: - Notification names for proxy control

extension Notification.Name {
    static let startProxy = Notification.Name("RoxProxy.startProxy")
    static let stopProxy  = Notification.Name("RoxProxy.stopProxy")
}
