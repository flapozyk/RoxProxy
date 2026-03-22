# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build
swift build

# Run
swift run RoxProxy

# Test (all)
swift test

# Test (single test by name)
swift test --filter "DomainRuleTests/wildcardMatchWorks"

# Release build
swift build -c release
```

## Architecture

RoxProxy is a macOS 14+ SwiftUI desktop app that acts as an HTTP/HTTPS intercepting proxy. It is built as an SPM executable (not an `.app` bundle), so `main.swift` manually sets `NSApplication.activationPolicy(.regular)` before launching the SwiftUI lifecycle.

### Request flow

1. **`ProxyServer`** — bootstraps a SwiftNIO `ServerBootstrap` bound to `127.0.0.1:<port>`. Each accepted connection gets an HTTP codec pipeline plus `HTTPProxyHandler`.

2. **`HTTPProxyHandler`** (NIO `ChannelInboundHandler`) — the main proxy logic:
   - Plain HTTP requests: opens a `ClientBootstrap` TCP connection, forwards the request, streams the response back via `OutboundHTTPHandler`.
   - `CONNECT` requests (HTTPS tunnels): either blindly proxies bytes through `TunnelHandler`, or performs MITM TLS interception if the target host matches a `DomainRule`.

3. **MITM path** — when MITM is active for a host:
   - `CertificateAuthority` issues a forged leaf cert (signed by the local root CA, cached in `DomainCertificateCache`).
   - A `NIOSSLServerHandler` is inserted into the client-facing pipeline.
   - `MITMSetupHandler` waits for TLS handshake completion, then swaps in an HTTP codec + `MITMHandler`.
   - `MITMHandler` makes a fresh upstream TLS connection (certificate verification disabled — dev tool) and captures the exchange.

4. **`OutboundHTTPHandler`** — handles the upstream client channel; collects and streams the response body back to the client and updates the `CapturedExchange` in `ProxySessionStore`.

### State management

- **`ProxySessionStore`** (`@MainActor @Observable`) — single source of truth for all captured exchanges, filter text, recording state, and proxy run state. NIO handlers dispatch updates to it via `Task { @MainActor in store.update(exchange) }`.
- **`SettingsStore`** (`@MainActor @Observable`) — persists `ProxySettings` (port, domain rules, timeouts, etc.) to `UserDefaults`.

### Certificate infrastructure

`CertificateAuthority` generates a self-signed P-256 root CA on first launch and stores it in `~/Library/Application Support/RoxProxy/`. It signs per-domain leaf certificates on demand; `DomainCertificateCache` caches them (thread-safe, lock-based). `KeychainInstaller` installs the root CA into the macOS System Keychain so browsers trust it.

### Layers

| Layer | Directory | Responsibility |
|---|---|---|
| App | `App/` | `AppDelegate`, `RoxProxyApp` SwiftUI entry point |
| Proxy (NIO) | `Proxy/` | `HTTPProxyHandler`, `MITMHandler`, `OutboundHTTPHandler`, `TunnelHandler`, `RequestCapture` |
| Certificate | `Certificate/` | `CertificateAuthority`, `DomainCertificateCache`, `KeychainInstaller` |
| System | `SystemProxy/` | `SystemProxyManager` (sets macOS system proxy), `CrashGuard` |
| ViewModels | `ViewModels/` | `ProxySessionStore`, `SettingsStore` |
| Views | `Views/` | SwiftUI views |
| Models | `Models/` | `CapturedExchange`, `DomainRule`, `ProxySettings` |
| Utilities | `Utilities/` | `BodyRenderer`, `GzipDecompressor`, `DataFormatting` |

### Testing

Tests use Swift Testing (`@Test`, `#expect`), not XCTest. The test target imports `RoxProxy` with `@testable`.
