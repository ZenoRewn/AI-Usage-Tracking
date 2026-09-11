// Author: Zeno Ren
import SwiftUI
import ServiceManagement
import UsageCore

struct CostsView: View {
    @Bindable var model: AppModel
    var body: some View {
        let coverage = model.costCoverage
        HStack(spacing:14) {
            MetricCard(title:"已定价部分的参考成本",value:coverage.1 == 0 ? "待定价" : coverage.0.formatted(.currency(code:"USD")),note:"统一公价折算 · USD · 非订阅实付",symbol:"dollarsign.circle")
            MetricCard(title:"价格覆盖",value:model.total == 0 ? "—" : "\(Int(Double(coverage.1)/Double(max(1,model.total))*100))%",note:"未定价部分不会自动当作免费",symbol:"checkmark.seal")
            MetricCard(title:"使用的模型组合",value:String(model.models.count),note:"当前工具与时间筛选范围",symbol:"square.stack.3d.up")
        }
        SurfaceCard(title:"模型成本",subtitle:"当前筛选范围") {
            HStack {
                Text("按工具与模型汇总").font(.caption).foregroundStyle(.secondary)
                Spacer(); Button("按客户端分析 ›") { model.selectedPage = .clients }.buttonStyle(.plain).foregroundStyle(Display.accent)
            }
            ForEach(model.models.prefix(40)) { group in
                HStack(spacing:10) {
                    if let tool = group.events.first?.tool { BrandLogo(tool:tool,size:18) }
                    Text(group.name).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text(Display.tokens(group.total)).monospacedDigit().frame(width:100,alignment:.trailing)
                    Text(model.costLabel(group.events)).foregroundStyle(Display.accent).frame(width:120,alignment:.trailing)
                }
                Divider()
            }
        }
        HStack {
            Text("金额为参考成本；* 为部分定价。价格表与自定义覆盖在“模型价格”中管理。").font(.caption).foregroundStyle(.secondary)
            Spacer(); Button("模型价格 ›") { model.selectedPage = .prices }.buttonStyle(.plain).foregroundStyle(Display.accent)
        }
    }
}

struct SourcesView: View {
    @Bindable var model: AppModel
    var body: some View {
        Notice(text:"每个来源独立报告状态。读取到历史文件不等于正在运行，也不代表覆盖所有 IDE 补全或云端任务。")
        ForEach(model.config.sources) { source in
            let health = model.snapshot.sources.first { $0.id == source.id }
            SurfaceCard(title:source.title) {
                HStack(alignment:.top,spacing:20) {
                    BrandLogo(tool:source.tool,size:30).frame(width:48,height:48).background(Display.color(source.tool).opacity(0.08),in:RoundedRectangle(cornerRadius:11))
                    VStack(alignment:.leading,spacing:7) {
                        HStack { Text(health?.state ?? (model.isScanning ? "正在扫描" : "待扫描")).font(.subheadline.weight(.semibold)); if let health { Text("\(health.files) 文件 · \(health.eventCount.formatted()) 记录").font(.caption).foregroundStyle(.secondary) } }
                        Text(health?.detail ?? "首次扫描会发现该来源的本地记录。").font(.caption).foregroundStyle(.secondary)
                        if let date = health?.latestEvent { Text("最新用量：" + date.formatted(.dateTime.year().month().day().hour().minute())).font(.caption).foregroundStyle(.secondary) }
                        ForEach(source.paths,id:\.self) { path in Text(path.replacingOccurrences(of:FileManager.default.homeDirectoryForCurrentUser.path,with:"~")).font(.system(size:10,design:.monospaced)).foregroundStyle(.tertiary).textSelection(.enabled) }
                    }
                    Spacer()
                    VStack(alignment:.trailing,spacing:9) {
                        if source.id == "copilot-vscode" { Button("连接 VS Code") { model.showConnection = "vscode" } }
                        if source.id == "copilot-cli" { Button("连接 CLI") { model.showConnection = "copilot-cli" } }
                        if source.id == "claude" { Button("连接额度快照") { model.showConnection = "claude" } }
                        Button("选择数据路径…") { choose(source) }.font(.caption)
                    }
                }
                if let warnings = health?.warnings, !warnings.isEmpty {
                    Divider()
                    ForEach(warnings,id:\.self) { warning in Label(warningText(warning),systemImage:"info.circle").font(.caption).foregroundStyle(warning == "session-summary-time-approximate" ? Color.secondary : .orange) }
                }
            }
        }
        SurfaceCard(title:"Copilot App 的覆盖情况") {
            let rows = model.snapshot.events.filter { $0.surface == "Copilot App" }
            Text(rows.isEmpty ? "已支持 agency 来源的会话汇总解析，目前没有观察到该入口的可计量记录。" : "已采集 \(rows.count) 条 App 会话汇总。")
            Text("只读取本地 events.jsonl 中实际提供的用量。不会用 CLI 数据冒充 App 数据；没有调用记录时保持缺失状态。").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func choose(_ source: SourceFolder) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = source.surface == nil; panel.canChooseFiles = source.surface != nil; panel.allowsMultipleSelection = true; panel.title = "选择 \(source.title) 的数据源"
        guard panel.runModal() == .OK, let i = model.config.sources.firstIndex(where:{ $0.id == source.id }) else { return }
        model.config.sources[i].paths = panel.urls.map(\.path); model.save(); model.refresh()
    }
    private func warningText(_ code: String) -> String {
        switch code {
        case "fork-baseline-unavailable": "部分分叉缺少父基线，已排除无法确认的累计量。"
        case "counter-reset-or-lineage-change": "检测到累计值回退或线程变化；不确定增量未计入。"
        case "session-summary-time-approximate": "来源为会话累计汇总；跨日归属近似，不能视作逐请求流水。"
        case "invalid-json": "部分记录格式不完整、损坏或超出大小上限，已跳过。"
        default: "采集提示：" + code
        }
    }
}

struct SettingsContentView: View {
    @Bindable var model: AppModel
    @State private var login = SMAppService.mainApp.status == .enabled
    var body: some View {
        SurfaceCard(title:"采集与运行") {
            HStack { VStack(alignment:.leading) { Text("自动刷新"); Text("启动后仅在菜单栏运行；打开工作台时显示 Dock 图标，关闭窗口后继续刷新。").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(model.paused ? "继续刷新" : "暂停刷新") { model.togglePause() } }
            Divider()
            Picker("刷新间隔",selection:$model.config.refreshSeconds) {
                ForEach(RefreshPolicy.options,id:\.self) { seconds in Text(RefreshPolicy.label(seconds)).tag(seconds) }
                if !RefreshPolicy.options.contains(model.config.refreshSeconds) {
                    Text(RefreshPolicy.label(model.config.refreshSeconds)).tag(model.config.refreshSeconds)
                }
            }.onChange(of:model.config.refreshSeconds) { model.save() }.frame(maxWidth:460)
            Text("默认：本地 30 秒、Codex / Copilot 账户 5 分钟。选择 5 分钟及以上时，两者按所选周期刷新；修改立即生效。Claude 额度随 statusLine 更新。").font(.caption).foregroundStyle(.secondary)
            Text("暂停会停止后续自动刷新，正在查询的账户请求会完成；仍可手动刷新。查询失败保留快照并延后重试，详情见账户额度。").font(.caption).foregroundStyle(.secondary)
            Text(model.refreshStatus(.local)).font(.caption).foregroundStyle(Display.accent)
            Toggle("账户额度达到 90% 时提醒",isOn:Binding(get:{model.config.notifications},set:{model.setNotifications($0)}))
            Toggle("登录时启动",isOn:$login).onChange(of:login) { _, value in
                do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                catch { model.error = error.localizedDescription; login = SMAppService.mainApp.status == .enabled }
            }
        }
        SurfaceCard(title:"本机数据") {
            Text(model.dataDirectory.path).font(.system(.caption,design:.monospaced)).textSelection(.enabled)
            HStack { Button("打开数据目录") { NSWorkspace.shared.open(model.dataDirectory) }; Button("导出脱敏 JSON") { model.export(json:true) } }
            Text("数据库只保存用量、时间、模型和项目元信息；不保存提示词、回答正文或密钥。当前预览版保留已导入历史，自动保留周期将在后续版本加入。").font(.caption).foregroundStyle(.secondary)
        }
        SurfaceCard(title:"关于 Usage Tracking") {
            Text("Version \(UsageCoreVersion.current) · macOS 原生应用").font(.subheadline)
            Text("Author: Zeno Ren").font(.headline)
            Text("本地用量与账户额度分开计量。参考 CodexBar、token-tracker、usage-monitor 和 coding-tool 的设计，当前实现独立编写，使用 Apple 系统框架和 SQLite。").font(.caption).foregroundStyle(.secondary)
            Link("查看 Codex App Server 官方文档",destination:URL(string:"https://learn.chatgpt.com/docs/app-server")!)
        }
    }
}

struct ConnectionView: View {
    let kind: String
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var change: SettingsChange?
    @State private var message = ""
    private var telemetryPath: String { model.dataDirectory.appendingPathComponent("telemetry/\(kind == "vscode" ? "vscode" : "cli").jsonl").path }
    private var shellSnippet: String {
        "export COPILOT_OTEL_FILE_EXPORTER_PATH='\(telemetryPath.replacingOccurrences(of:"'",with:"'\\''"))'\nexport OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=false\ncopilot"
    }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack { Text(kind == "vscode" ? "连接 Copilot VS Code" : kind == "claude" ? "连接 Claude 额度快照" : "连接 Copilot CLI").font(.title2.bold()); Spacer(); Button("完成") { dismiss() } }
            if kind == "copilot-cli" {
                Text("在启动 Copilot 的终端执行以下命令。启用后的调用会写入本机文件，不捕获提示词或回答内容。").font(.subheadline).foregroundStyle(.secondary)
                Text(shellSnippet).font(.system(.caption,design:.monospaced)).textSelection(.enabled).padding(16).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
                Button("复制启动命令") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(shellSnippet,forType:.string); message = "已复制。启动后进行正常使用即可，无需为监控发送额外请求。" }
            } else if kind == "vscode" {
                Text("更新 VS Code 用户设置中的以下四项，保留其他设置与注释，并创建备份。重载 VS Code 窗口后生效。").font(.subheadline).foregroundStyle(.secondary)
                Text("github.copilot.chat.otel.enabled = true\ngithub.copilot.chat.otel.exporterType = file\ngithub.copilot.chat.otel.captureContent = false\ngithub.copilot.chat.otel.outfile = \(telemetryPath)").font(.system(.caption,design:.monospaced)).textSelection(.enabled).padding(16).background(.quaternary,in:RoundedRectangle(cornerRadius:8))
                Notice(text:"已有 OTel 导出目标会被这次连接改为本地文件。若需要保留现有遥测管道，请取消并在数据源页选择已有本地导出文件。")
                Button("应用上述设置") { applyVSCode() }.buttonStyle(.borderedProminent).disabled(!message.isEmpty)
            } else {
                Text("将轻量桥接程序加入 Claude statusLine。它保存配额白名单字段，并将相同输入交给原有状态栏命令，保留原显示。设置会先备份。").font(.subheadline).foregroundStyle(.secondary)
                Notice(text:"只在 Claude 正常更新状态栏时获取配额；不会发起模型请求。重新启动 Claude 会话后生效。")
                Button("安装 statusLine 桥接") { installClaude() }.buttonStyle(.borderedProminent).disabled(!message.isEmpty)
            }
            if !message.isEmpty { Text(message).font(.caption).foregroundStyle(Display.accent).textSelection(.enabled) }
            Text("Author: Zeno Ren · 只在本机保存").font(.caption2).foregroundStyle(.secondary)
        }.padding(28).frame(width:640).onAppear { try? FileManager.default.createDirectory(at:model.dataDirectory.appendingPathComponent("telemetry"),withIntermediateDirectories:true) }
    }
    private func applyVSCode() {
        do {
            let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Code/User/settings.json")
            let change = try SettingsChange(path:path,values:["github.copilot.chat.otel.enabled":true,"github.copilot.chat.otel.exporterType":"file","github.copilot.chat.otel.captureContent":false,"github.copilot.chat.otel.outfile":telemetryPath])
            let backup = try change.apply(); message = "已保存。请重载 VS Code 窗口。备份：\(backup.lastPathComponent)"; model.refresh()
        } catch { model.error = error.localizedDescription }
    }
    private func installClaude() {
        do {
            let path = URL(fileURLWithPath:ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path).appendingPathComponent("settings.json")
            let original = (try? String(contentsOf:path,encoding:.utf8)) ?? "{}"
            let object = try JSONCSettings.object(original)
            let old = object["statusLine"] as? [String:Any] ?? [:]
            let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/usage-tracking").path
            guard FileManager.default.isExecutableFile(atPath:helper) else { throw QuotaError.unavailable("请从打包的 Usage Tracking.app 安装桥接。") }
            let command = "'" + helper.replacingOccurrences(of:"'",with:"'\\''") + "' --claude-statusline"
            if old["command"] as? String == command { message = "桥接已安装；等待 Claude 状态栏更新。"; return }
            let bridge = model.dataDirectory.appendingPathComponent("bridge-config.json")
            try JSONSerialization.data(withJSONObject:["author":"Zeno Ren","originalStatusLine":old],options:.prettyPrinted).write(to:bridge,options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:bridge.path)
            let change = try SettingsChange(path:path,values:["statusLine":["type":"command","command":command]])
            let backup = try change.apply(); message = "已安装，请重启 Claude 会话。原配置备份：\(backup.lastPathComponent)"
        } catch { model.error = error.localizedDescription }
    }
}
