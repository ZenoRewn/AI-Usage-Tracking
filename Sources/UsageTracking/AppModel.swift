// Author: Zeno Ren
import SwiftUI
import Observation
import UserNotifications
import UsageCore

struct UsageGroup: Identifiable {
    var id: String
    var name: String
    var events: [UsageEvent]
    var total: Int64 { events.reduce(0) { $0 + $1.tokens.total } }
    var input: Int64 { events.reduce(0) { $0 + $1.tokens.input } }
    var output: Int64 { events.reduce(0) { $0 + $1.tokens.output } }
    var cache: Int64 { events.reduce(0) { $0 + $1.tokens.cacheRead } }
    var tools: [Tool] { Tool.allCases.filter { tool in events.contains { $0.tool == tool } } }
    var last: Date { events.first?.date ?? .distantPast }
}
struct DailyUsage: Identifiable {
    var date: Date
    var tool: Tool
    var tokens: Int64
    var id: String { "\(date.timeIntervalSince1970):\(tool.rawValue)" }
}

@MainActor @Observable final class AppModel {
    let dataDirectory: URL
    let scanner: UsageScanner?
    var config: AppConfiguration
    var snapshot = ScanSnapshot()
    var isScanning = false
    var scanProgress = "准备读取本地数据"
    var error: String?
    var statusMessage: String?
    var paused: Bool { schedule.paused }
    var selectedPage: AppPage = .overview
    var rangeDays = 30
    var selectedTool = "all"
    var selectedClient = "all"
    var search = ""
    var quotaLoading: Bool { schedule.isRunning(.codex) || schedule.isRunning(.copilot) }
    var quotaErrors: [Tool: String] = [:]
    private var schedule = RefreshSchedule()
    var selectedGroup: UsageGroup?
    var showConnection: String?
    var windowUsage = UsageWindows.summarize([])
    var todayProjects = TodayProjects.summarize([])
    private var windowTask: Task<Void,Never>?
    private var loop: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var started = false
    private var notified: Set<String> = []

    init(dataDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Usage Tracking"), collectsUsage: Bool = true) {
        self.dataDirectory = dataDirectory
        config = AppConfiguration.load(from: dataDirectory)
        guard collectsUsage else { scanner = nil; return }
        do { scanner = try UsageScanner(dataDirectory: dataDirectory) }
        catch { scanner = nil; self.error = error.localizedDescription }
    }
    func start() {
        guard !started else { return }; started = true
        Task {
            if let scanner, let cached = try? await scanner.cached() { snapshot = cached; updateWindows() }
            refreshAll()
            restartLoop()
        }
    }
    private func restartLoop() {
        loop?.cancel()
        guard started, !paused else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                refresh(automatic: true)
                refreshQuota(tool: .codex, automatic: true)
                refreshQuota(tool: .copilot, automatic: true)
                let next = RefreshTarget.allCases.compactMap { schedule.nextDate($0, seconds: config.refreshSeconds) }.min()
                // Short upper bound also handles system clock changes and wake from sleep.
                let delay = min(60, max(1, next?.timeIntervalSinceNow ?? 60))
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            }
        }
    }
    func refreshAll() {
        refresh()
        refreshQuota(tool: .codex)
        refreshQuota(tool: .copilot)
    }
    func refresh(automatic: Bool = false) {
        guard let scanner, schedule.begin(.local, at: Date(), seconds: config.refreshSeconds, forced: !automatic) else { return }
        isScanning = true; error = nil
        let sources = config.sources
        scanTask = Task {
            var succeeded = false
            do {
                var scanned = try await scanner.scan(sources: sources) { [weak self] message in
                    Task { @MainActor in self?.scanProgress = message }
                }
                scanned.quotas = QuotaWindow.mergingScan(scanned.quotas, current: snapshot.quotas)
                snapshot = scanned
                succeeded = true
                statusMessage = "已更新 · \(snapshot.events.count.formatted()) 条本地记录"
                updateWindows()
                checkNotifications()
            } catch { self.error = error.localizedDescription }
            isScanning = false
            schedule.finish(.local, at: Date(), succeeded: succeeded)
            restartLoop()
        }
    }
    func togglePause() {
        schedule.paused.toggle()
        if paused { scanTask?.cancel() } else { refreshAll() }
        restartLoop()
    }
    func save() {
        do { try config.save(to: dataDirectory); updateWindows(); restartLoop() }
        catch { self.error = error.localizedDescription }
    }
    func quotaIsLoading(_ tool: Tool) -> Bool { tool != .claude && schedule.isRunning(tool == .copilot ? .copilot : .codex) }
    func refreshStatus(_ target: RefreshTarget) -> String {
        if schedule.isRunning(target) { return "正在刷新…" }
        if paused { return "自动刷新已暂停" }
        guard let next = schedule.nextDate(target, seconds: config.refreshSeconds), next > Date() else { return "即将自动刷新" }
        return "下次自动刷新 " + next.formatted(.dateTime.month().day().hour().minute())
    }
    func refreshMenuDayIfNeeded(at now: Date) {
        if todayProjects.dayStart != Calendar.current.startOfDay(for:now) { updateWindows(at:now) }
    }
    private func updateWindows(at now: Date = Date()) {
        windowTask?.cancel()
        let events = snapshot.events, prices = config.prices, calendar = Calendar.current
        windowTask = Task {
            let (rows, projects) = await Task.detached {
                (UsageWindows.summarize(events,catalog:prices,calendar:calendar,now:now),
                 TodayProjects.summarize(events,catalog:prices,calendar:calendar,now:now))
            }.value
            if !Task.isCancelled { windowUsage = rows; todayProjects = projects }
        }
    }

    var filtered: [UsageEvent] {
        let start = rangeDays == 0 ? Date.distantPast : Calendar.current.date(byAdding: .day, value: -(rangeDays-1), to: Calendar.current.startOfDay(for: Date()))!
        return snapshot.events.filter { e in
            e.date >= start && (selectedTool == "all" || e.tool.rawValue == selectedTool)
                && (selectedPage != .clients || selectedClient == "all" || clientID(e) == selectedClient)
                && (search.isEmpty || [e.project,e.model,e.surface,projectName(e.project)].joined(separator: " ").localizedCaseInsensitiveContains(search))
        }
    }
    func clientID(_ event: UsageEvent) -> String { event.tool.rawValue + ":" + ClientAnalytics.clientName(event) }
    func selectMenuProject(_ path: String, dayStart: Date, now: Date = Date(), calendar: Calendar = .current) {
        selectedPage = .projects
        rangeDays = 1; selectedTool = "all"; selectedClient = "all"; search = ""
        selectedGroup = nil
        guard dayStart == calendar.startOfDay(for:now) else {
            statusMessage = "日期已切换，请查看今天的项目。"
            return
        }
        let rows = snapshot.events.filter { $0.project == path && $0.date >= dayStart && $0.date <= now }
            .sorted { $0.date > $1.date }
        guard !path.isEmpty, !rows.isEmpty else {
            statusMessage = "该项目今天暂时没有可显示的记录。"
            return
        }
        statusMessage = "今日项目 · " + projectName(path)
        selectedGroup = UsageGroup(id:path,name:projectName(path),events:rows)
    }
    var clientOptions: [(id:String,title:String)] {
        var options: [String:String] = [:]
        for event in snapshot.events where selectedTool == "all" || event.tool.rawValue == selectedTool { options[clientID(event)] = ClientAnalytics.clientName(event) }
        return options.map { (id:$0.key,title:$0.value) }.sorted { $0.title < $1.title }
    }
    var clientAnalysis: [ClientUsage] { ClientAnalytics.summarize(filtered,catalog:config.prices) }
    func showClientModel(_ client: ClientUsage, _ row: ClientModelUsage) {
        let rows = filtered.filter { $0.tool == client.tool && ClientAnalytics.clientName($0) == client.client && ($0.model.isEmpty ? "unknown" : $0.model) == row.model && ClientAnalytics.mode($0) == row.mode }
        selectedGroup = UsageGroup(id:"client-model:"+client.id+":"+row.id,name:client.client+" · "+row.displayName,events:rows)
    }
    var total: Int64 { filtered.reduce(0) { $0 + $1.tokens.total } }
    var projects: [UsageGroup] { groups(filtered, by: { $0.project }, name: projectName) }
    var sessions: [UsageGroup] {
        groups(filtered, by: { "\($0.tool.rawValue):\($0.session)" }, name: { String($0.suffix(8)) }).sorted { $0.last > $1.last }
    }
    var models: [UsageGroup] { groups(filtered, by: { "\($0.tool.rawValue) / \($0.model)" }, name: { $0 }) }
    var daily: [DailyUsage] {
        let groups = Dictionary(grouping: filtered) { e in "\(Calendar.current.startOfDay(for: e.date).timeIntervalSince1970):\(e.tool.rawValue)" }
        return groups.values.map { rows in DailyUsage(date: Calendar.current.startOfDay(for: rows[0].date), tool: rows[0].tool, tokens: rows.reduce(0) { $0 + $1.tokens.total }) }.sorted { $0.date < $1.date }
    }
    var displayedQuotas: [QuotaWindow] {
        let rpc = snapshot.quotas.filter { $0.id.hasPrefix("rpc:") }
        return snapshot.quotas.filter { $0.tool != .codex || (rpc.isEmpty ? true : $0.id.hasPrefix("rpc:")) }.sorted { $0.tool.rawValue < $1.tool.rawValue }
    }
    func projectName(_ path: String) -> String { config.projectNames[path] ?? (path.isEmpty ? "未归属项目" : URL(fileURLWithPath: path).lastPathComponent) }
    func groups(_ events: [UsageEvent], by key: (UsageEvent) -> String, name: (String) -> String) -> [UsageGroup] {
        Dictionary(grouping: events, by: key).map { UsageGroup(id: $0.key, name: name($0.key), events: $0.value) }.sorted { $0.total > $1.total }
    }
    func estimate(_ event: UsageEvent) -> Double? { config.prices.quote(event)?.amount }
    func costLabel(_ events: [UsageEvent]) -> String {
        let values = events.compactMap(estimate)
        guard !values.isEmpty else { return "未定价" }
        return "≈" + values.reduce(0,+).formatted(.currency(code:"USD")) + (values.count < events.count ? "*" : "")
    }
    var costCoverage: (Double, Int64) {
        var cost = 0.0, tokens: Int64 = 0
        for e in filtered { if let value = estimate(e) { cost += value; tokens += e.tokens.total } }
        return (cost,tokens)
    }
    func refreshQuota(tool: Tool = .codex, automatic: Bool = false) {
        guard tool != .claude, let scanner else { return }
        let target: RefreshTarget = tool == .copilot ? .copilot : .codex
        guard schedule.begin(target, at: Date(), seconds: config.refreshSeconds, forced: !automatic) else { return }
        quotaErrors[tool] = nil
        Task {
            var succeeded = false
            do {
                let quotas = try await Task.detached { tool == .copilot ? try CopilotQuotaClient.fetch() : try CodexQuotaClient.fetch() }.value
                guard !quotas.isEmpty else { throw QuotaError.unavailable("账户未提供可显示的额度窗口。") }
                try await scanner.saveQuotas(quotas)
                let prefix = tool == .copilot ? "copilot-rpc:" : "rpc:"
                snapshot.quotas.removeAll { $0.id.hasPrefix(prefix) }
                snapshot.quotas.append(contentsOf: quotas)
                succeeded = true
                statusMessage = "\(tool.title) 账户额度已更新"; checkNotifications()
            } catch { quotaErrors[tool] = error.localizedDescription }
            schedule.finish(target, at: Date(), succeeded: succeeded)
            restartLoop()
        }
    }
    func setNotifications(_ enabled: Bool) {
        config.notifications = enabled; save()
        if enabled {
            Task {
                do { let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound]); if !granted { config.notifications = false; save() } }
                catch { self.error = error.localizedDescription }
            }
        }
    }
    private func checkNotifications() {
        guard config.notifications else { return }
        for q in displayedQuotas where !q.isStale() && q.usedPercent >= 90 {
            let key = "\(q.id):\(q.resetsAt?.timeIntervalSince1970 ?? 0):90"
            guard notified.insert(key).inserted else { continue }
            let content = UNMutableNotificationContent(); content.title = "\(q.tool.title) 额度提醒"; content.body = "\(q.title) 已使用 \(Int(q.usedPercent))%。"; content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: StableID.hash(key), content: content, trigger: nil))
        }
    }
    func export(json: Bool) {
        let summary = selectedPage == .clients
        let panel = NSSavePanel(); panel.nameFieldStringValue = "usage-tracking-\(summary ? "clients-" : "")\(String(TimeCodec.string(Date()).prefix(10))).\(json ? "json" : "csv")"
        panel.title = summary ? "导出当前客户端与模型统计 · 不含项目路径或会话 ID" : "导出当前筛选结果 · 路径与会话 ID 自动脱敏"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if summary {
                let clients = clientAnalysis
                let data = json ? try ClientAnalytics.json(clients) : Data(ClientAnalytics.csv(clients).utf8)
                try data.write(to:url,options:.atomic)
                statusMessage = "已导出 \(clients.count) 个客户端、\(clients.reduce(0){$0+$1.models.count}) 个模型组合 · Author: Zeno Ren"
                return
            }
            let events = filtered.map { e in var copy = e; let quote = config.prices.quote(e); copy.costUSD = quote?.amount; copy.costBasis = quote?.basis; return copy }
            let data = json ? try UsageExporter.json(events, includePaths: false) : Data(UsageExporter.csv(events, includePaths: false).utf8)
            try data.write(to: url, options: .atomic); statusMessage = "已导出 \(events.count) 条记录 · Author: Zeno Ren"
        } catch { self.error = error.localizedDescription }
    }
}

enum AppPage: String, CaseIterable, Identifiable {
    case overview = "总览", projects = "项目", sessions = "会话", clients = "客户端与模型", quotas = "账户额度", costs = "成本", sources = "数据源", prices = "模型价格", settings = "设置"
    var id: String { rawValue }
    var symbol: String { switch self { case .overview: "square.grid.2x2"; case .projects: "folder"; case .sessions: "bubble.left.and.bubble.right"; case .clients: "desktopcomputer"; case .quotas: "gauge.with.dots.needle.67percent"; case .costs: "dollarsign.circle"; case .sources: "externaldrive.connected.to.line.below"; case .prices: "tag"; case .settings: "slider.horizontal.3" } }
    var subtitle: String { switch self { case .overview: "看清每个工具与项目的投入"; case .projects: "跨工具聚合，保留可核对的项目归属"; case .sessions: "从会话深入到模型与用量记录"; case .clients: "比较每个客户端调用的模型与用量"; case .quotas: "账户窗口独立显示，不与 Token 消耗混算"; case .costs: "按明确价格估算，实际账单单独核对"; case .sources: "查看入口覆盖、采集状态和数据精度"; case .prices: "统一公价与自定义覆盖，在此集中管理"; case .settings: "本机数据、连接、通知与个性设置" } }
}

enum Display {
    static func tokens(_ value: Int64) -> String {
        if value >= 1_000_000_000 { return String(format: "%.2fB",Double(value)/1e9) }
        if value >= 1_000_000 { return String(format: "%.2fM",Double(value)/1e6) }
        if value >= 1_000 { return String(format: "%.1fK",Double(value)/1e3) }
        return String(value)
    }
    static let purple = Color(red:134/255,green:97/255,blue:197/255)
    static let blue = Color(red:0,green:120/255,blue:212/255)
    static let lavender = Color(red:197/255,green:180/255,blue:227/255)
    static let sky = Color(red:141/255,green:200/255,blue:232/255)
    static let accent = purple
    static func color(_ tool: Tool) -> Color {
        switch tool {
        case .codex: Color.primary
        case .claude: Color(red:217/255,green:119/255,blue:87/255)
        case .copilot: Color(nsColor:NSColor(name:nil) { appearance in
            appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
                ? NSColor(srgbRed:163/255,green:113/255,blue:247/255,alpha:1)
                : NSColor(srgbRed:130/255,green:80/255,blue:223/255,alpha:1)
        })
        }
    }
    static func shortName(_ tool: Tool) -> String { switch tool { case .codex: "Codex"; case .claude: "Claude"; case .copilot: "Copilot" } }
}
