// Author: Zeno Ren
import Foundation
import UsageCore

@main struct UsageCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.contains("--help") {
            print("Usage Tracking · Author: Zeno Ren\nusage-tracking scan [--data-dir PATH]\nusage-tracking export PATH [--data-dir PATH]\nusage-tracking status [--data-dir PATH]\nusage-tracking clients [--data-dir PATH]")
            return
        }
        let dataDirectory: URL
        if let i = args.firstIndex(of: "--data-dir"), args.indices.contains(i+1) { dataDirectory = URL(fileURLWithPath: args[i+1]) }
        else { dataDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Usage Tracking") }
        if args.first == "--claude-statusline" { StatusLineBridge.run(directory:dataDirectory); return }
        if args.first == "quota" {
            do {
                let windows = try CodexQuotaClient.fetch()
                let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted; encoder.dateEncodingStrategy = .iso8601
                print(String(decoding:try encoder.encode(windows),as:UTF8.self))
            } catch { FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1) }
            return
        }
        do {
            let scanner = try UsageScanner(dataDirectory: dataDirectory)
            let snapshot = args.first == "scan" ? try await scanner.scan(sources: SourceFolder.defaults(dataDirectory: dataDirectory)) : try await scanner.cached()
            let prices = AppConfiguration.load(from:dataDirectory).prices
            if args.first == "clients" {
                print(String(decoding:try ClientAnalytics.json(ClientAnalytics.summarize(snapshot.events,catalog:prices)),as:UTF8.self))
                return
            }
            if args.first == "export", args.count > 1 {
                let pricedEvents = snapshot.events.map { event in var e = event; let quote = prices.quote(event); e.costUSD = quote?.amount; e.costBasis = quote?.basis; return e }
                try UsageExporter.json(pricedEvents, includePaths: false).write(to: URL(fileURLWithPath: args[1]), options: .atomic)
                print("Exported redacted report. Author: Zeno Ren")
            } else {
                struct Summary: Encodable { let author = "Zeno Ren"; let pricingSource = CopilotPublicPricing.sourceURL; let priceAsOf = CopilotPublicPricing.asOf; var events: Int; var tokens: Int64; var toolEvents: [String: Int]; var sources: [SourceHealth]; var windows: [ToolWindowUsage] }
                let s = Summary(events: snapshot.events.count, tokens: snapshot.events.reduce(0) { $0 + $1.tokens.total }, toolEvents: Dictionary(grouping: snapshot.events, by: { $0.tool.title }).mapValues(\.count), sources: snapshot.sources, windows:UsageWindows.summarize(snapshot.events,catalog:prices))
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
                print(String(decoding: try encoder.encode(s), as: UTF8.self))
            }
        } catch { FileHandle.standardError.write(Data("Usage Tracking: \(error.localizedDescription)\n".utf8)); exit(1) }
    }
}
