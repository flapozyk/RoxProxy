import SwiftUI

// MARK: - Method Badge

struct MethodBadge: View {
    let method: String

    var color: Color {
        switch method.uppercased() {
        case "GET":     return Color(red: 0.13, green: 0.68, blue: 0.37)
        case "POST":    return Color(red: 0.20, green: 0.46, blue: 0.82)
        case "PUT":     return Color(red: 0.90, green: 0.55, blue: 0.10)
        case "PATCH":   return Color(red: 0.58, green: 0.30, blue: 0.80)
        case "DELETE":  return Color(red: 0.86, green: 0.25, blue: 0.22)
        case "HEAD":    return Color.gray
        case "OPTIONS": return Color.gray
        default:        return Color.gray
        }
    }

    var body: some View {
        Text(method.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 3))
            .fixedSize()
    }
}

// MARK: - Status View

struct StatusView: View {
    let exchange: CapturedExchange

    var body: some View {
        switch exchange.state {
        case .inProgress:
            ProgressView()
                .scaleEffect(0.55)
                .frame(width: 20, height: 16)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 11))
        case .completed:
            if let code = exchange.statusCode {
                Text("\(code)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statusColor(code: code))
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    private func statusColor(code: Int) -> Color {
        switch code {
        case 200..<300: return Color(red: 0.13, green: 0.68, blue: 0.37)
        case 300..<400: return Color(red: 0.20, green: 0.46, blue: 0.82)
        case 400..<500: return Color(red: 0.90, green: 0.55, blue: 0.10)
        default:        return Color(red: 0.86, green: 0.25, blue: 0.22)
        }
    }
}

// MARK: - HTTPS Lock Icon

struct HTTPSIndicator: View {
    let isHTTPS: Bool
    let isMITM: Bool

    var body: some View {
        if isHTTPS {
            Image(systemName: isMITM ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(isMITM ? .orange : .secondary)
                .help(isMITM ? "HTTPS decrypted (MITM)" : "HTTPS tunneled")
        }
    }
}
