import Foundation

struct CronJobState: Codable {
    var jobs: [String: JobRunState]
}

struct JobRunState: Codable {
    var lastRunAt: String?
    var nextRunAt: String?
    var consecutiveErrors: Int
    var lastError: String?
    var enabled: Bool
    var completed: Bool  // for one-shot jobs
}

enum CronScheduleType {
    case recurring(intervalSeconds: TimeInterval)
    case oneShot(at: Date)
}

enum CronJobParser {
    /// Parse "every 1h", "every 30m", "every 6h", "at 2026-03-17T10:00:00Z"
    static func parseSchedule(_ schedule: String) -> CronScheduleType? {
        let trimmed = schedule.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("every ") {
            let value = String(trimmed.dropFirst(6))
            if let seconds = parseInterval(value) {
                return .recurring(intervalSeconds: seconds)
            }
        }

        if trimmed.hasPrefix("at ") {
            let dateStr = String(trimmed.dropFirst(3))
            if let date = ISO8601DateFormatter().date(from: dateStr) {
                return .oneShot(at: date)
            }
        }

        return nil
    }

    private static func parseInterval(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let suffix = trimmed.last!
        guard let number = Double(trimmed.dropLast()) else { return nil }
        switch suffix {
        case "s": return number
        case "m": return number * 60
        case "h": return number * 3600
        case "d": return number * 86400
        default: return nil
        }
    }
}

enum BackoffSchedule {
    private static let delays: [TimeInterval] = [30, 60, 300, 900, 3600]

    static func delay(forConsecutiveErrors count: Int) -> TimeInterval {
        let index = min(count - 1, delays.count - 1)
        return index >= 0 ? delays[index] : delays[0]
    }
}
