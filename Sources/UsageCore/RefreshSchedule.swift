// Author: Zeno Ren
import Foundation

public enum RefreshTarget: String, CaseIterable, Sendable { case local, codex, copilot }

public enum RefreshPolicy {
    // Keep the existing persisted 30-second default; remote queries have a 5-minute floor.
    public static let options = [30, 300, 1800, 3600, 10800, 21600, 43200, 86400]
    public static func interval(for target: RefreshTarget, seconds: Int) -> TimeInterval {
        TimeInterval(max(target == .local ? 10 : 300, min(86400, seconds)))
    }
    public static func label(_ seconds: Int) -> String {
        switch seconds {
        case 30: "默认（本地 30 秒 / 账户 5 分钟）"
        case 300: "5 分钟"
        case 1800: "30 分钟"
        case 3600, 10800, 21600, 43200, 86400: "\(seconds / 3600) 小时"
        default: "\(seconds) 秒（已保存设置）"
        }
    }
}

/// Completion-based deadlines prevent catch-up bursts after wake and overlapping queries.
public struct RefreshSchedule: Sendable {
    public var paused = false
    private var running: Set<RefreshTarget> = []
    private var finishedAt: [RefreshTarget: Date] = [:]
    private var failures: [RefreshTarget: Int] = [:]
    public init() {}
    public func isRunning(_ target: RefreshTarget) -> Bool { running.contains(target) }
    public func lastFinished(_ target: RefreshTarget) -> Date? { finishedAt[target] }
    public func nextDate(_ target: RefreshTarget, seconds: Int) -> Date? {
        guard !paused, !running.contains(target) else { return nil }
        let interval = RefreshPolicy.interval(for: target, seconds: seconds)
        let failures = failures[target, default: 0]
        let backoff = target == .local || failures == 0 ? 0 : min(3600, 300 * pow(2, Double(min(4, failures - 1))))
        return finishedAt[target]?.addingTimeInterval(max(interval, backoff)) ?? .distantPast
    }
    public mutating func begin(_ target: RefreshTarget, at now: Date, seconds: Int, forced: Bool = false) -> Bool {
        guard !running.contains(target) else { return false }
        guard forced || (nextDate(target, seconds: seconds).map { $0 <= now } ?? false) else { return false }
        running.insert(target)
        return true
    }
    public mutating func finish(_ target: RefreshTarget, at now: Date, succeeded: Bool) {
        running.remove(target)
        finishedAt[target] = now
        failures[target] = succeeded ? 0 : min(5, failures[target, default: 0] + 1)
    }
}
