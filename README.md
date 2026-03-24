# Rox Proxy

A macOS 14+ desktop HTTP/HTTPS proxy inspector, similar to Charles Proxy or Proxyman. Built with Flutter (UI) and Swift/SwiftNIO (native proxy engine).

## Features

- Intercept and inspect HTTP and HTTPS traffic
- MITM TLS decryption for configured domains
- Live request/response stream with filtering
- Body viewer with gzip decompression
- CA certificate installer for macOS System Keychain
- Certificate download endpoint for mobile/LAN devices (`http://cert.roxproxy/`)
- Crash recovery: system proxy is restored on unclean exit

## Requirements

- macOS 14 (Sonoma) or later
- Flutter 3.x
- Xcode 15+
- Swift 5.9+

## Getting started

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d macos

# Build release
flutter build macos
```

## Architecture

The UI is Flutter/Dart. All proxy logic lives in the local plugin `packages/rox_proxy_native`, written in Swift with SwiftNIO.

```
lib/                         # Flutter/Dart app
  main.dart                  # Entry point
  app.dart                   # MaterialApp + theme
  models/                    # CapturedExchange, DomainRule, ProxySettings, ProxyState
  services/                  # ProxyChannel (MethodChannel/EventChannel), SettingsService
  providers/                 # Riverpod providers
  utils/                     # DataFormatting, BodyRenderer
  ui/                        # Widgets

packages/rox_proxy_native/   # Swift plugin
  Sources/rox_proxy_native/
    Bridge/                  # Flutter ↔ Swift bridge
    Proxy/                   # SwiftNIO handlers
    Certificate/             # CA generation, per-domain certs, Keychain installer
    SystemProxy/             # networksetup integration, crash guard
    Models/                  # Swift-side models
```

### Platform channels

| Channel | Direction | Methods |
|---|---|---|
| `com.roxproxy/control` | Flutter → Swift | `startProxy`, `stopProxy`, `getProxyState`, `installCACertificate`, `checkCATrust`, `getCAStatus`, `fetchBody`, `releaseBody`, `releaseAllBodies`, `decompressBody` |
| `com.roxproxy/exchanges` | Swift → Flutter | streams `{type, exchange}` events |

## Inspecting traffic from mobile / LAN devices

The proxy listens on all network interfaces (`0.0.0.0`), so devices on the same Wi-Fi network can route traffic through it.

1. Find your Mac's local IP (shown in Settings → Certificate).
2. On the mobile device, set the HTTP/HTTPS proxy to `<mac-ip>:<port>` (default port `8888`).
3. Open `http://cert.roxproxy/` in the device browser — the proxy serves the CA certificate directly (similar to Charles's `chls.pro/ssl`).
4. Install and trust the certificate in the device settings.

> **iOS**: Settings → General → VPN & Device Management → install, then Settings → General → About → Certificate Trust Settings → enable.
>
> **Android**: Settings → Security → Install certificate → CA certificate.

## Certificate infrastructure

On first launch, `CertificateAuthority` generates a self-signed P-256 root CA stored in `~/Library/Application Support/RoxProxy/`. Per-domain leaf certificates are signed on demand and cached in memory. `KeychainInstaller` installs the root CA into the macOS System Keychain (requires admin password).

## macOS entitlements

App Sandbox is disabled — required for TCP binding on all interfaces, `networksetup` subprocess calls, and Keychain trust operations.
