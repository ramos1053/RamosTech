//
//  MetricsGraphView.swift
//  Nimbus-Swift
//

import SwiftUI

struct MetricsGraphView: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    let maxValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formatValue(value)) \(unit)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(value / maxValue, 1.0))
                }
            }
            .frame(height: 8)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1f", value / 1000)
        } else if value >= 100 {
            return String(format: "%.0f", value)
        } else if value >= 10 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

struct ServerMonitoringView: View {
    @ObservedObject var viewModel: ServerViewModel

    var body: some View {
        GroupBox(label: Label("Server Monitoring", systemImage: "chart.xyaxis.line")) {
            VStack(spacing: 10) {
                // Server Status
                HStack {
                    Circle()
                        .fill(viewModel.serverStatus.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(viewModel.serverStatus.isRunning ? "Server Running" : "Server Stopped")
                        .font(.caption)
                        .fontWeight(.medium)

                    if let pid = viewModel.serverStatus.processID {
                        Text("(PID: \(pid))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("Uptime: \(viewModel.serverStatus.uptime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Metrics
                VStack(spacing: 8) {
                    MetricsGraphView(
                        title: "Server Memory",
                        value: viewModel.serverStatus.metrics.memoryUsageMB,
                        unit: "MB",
                        color: colorForMemory(viewModel.serverStatus.metrics.memoryUsageMB),
                        maxValue: 2048 // Show up to 2GB
                    )

                    MetricsGraphView(
                        title: "Server CPU",
                        value: viewModel.serverStatus.metrics.cpuUsage,
                        unit: "%",
                        color: colorForCPU(viewModel.serverStatus.metrics.cpuUsage),
                        maxValue: 100
                    )

                    MetricsGraphView(
                        title: "Catalog Size",
                        value: viewModel.serverStatus.metrics.catalogSizeGB,
                        unit: "GB",
                        color: colorForCatalogSize(viewModel.serverStatus.metrics.catalogSizeGB),
                        maxValue: 100 // Show up to 100GB
                    )
                }
            }
            .padding(.top, 6)
        }
    }

    private func colorForMemory(_ memoryMB: Double) -> Color {
        if memoryMB > 1536 { return .red }      // > 1.5GB
        if memoryMB > 1024 { return .orange }   // > 1GB
        return .green
    }

    private func colorForCPU(_ cpu: Double) -> Color {
        if cpu > 80 { return .red }
        if cpu > 50 { return .orange }
        return .blue
    }

    private func colorForCatalogSize(_ sizeGB: Double) -> Color {
        if sizeGB > 75 { return .red }      // > 75GB
        if sizeGB > 50 { return .orange }   // > 50GB
        return .green
    }
}

#Preview {
    ServerMonitoringView(viewModel: ServerViewModel())
        .frame(width: 500)
        .padding()
}
