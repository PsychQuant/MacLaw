import Foundation

/// Pure-Swift 5-field cron expression parser (minute hour day-of-month month day-of-week).
/// Supports: *, ranges (1-5), lists (1,3,5), steps (*/15, 1-30/5).
struct CronExpression {
    let minutes: Set<Int>       // 0-59
    let hours: Set<Int>         // 0-23
    let daysOfMonth: Set<Int>   // 1-31
    let months: Set<Int>        // 1-12
    let daysOfWeek: Set<Int>    // 0-6 (0=Sunday)

    /// Parse a 5-field cron expression string.
    static func parse(_ expression: String) -> CronExpression? {
        let fields = expression.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard fields.count == 5 else { return nil }

        guard let minutes = parseField(fields[0], min: 0, max: 59),
              let hours = parseField(fields[1], min: 0, max: 23),
              let daysOfMonth = parseField(fields[2], min: 1, max: 31),
              let months = parseField(fields[3], min: 1, max: 12),
              let daysOfWeek = parseField(fields[4], min: 0, max: 6) else {
            return nil
        }

        return CronExpression(
            minutes: minutes, hours: hours,
            daysOfMonth: daysOfMonth, months: months,
            daysOfWeek: daysOfWeek
        )
    }

    /// Calculate the next fire time after the given date.
    func nextFireTime(after date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        // Start from the next minute
        components.minute = (components.minute ?? 0) + 1
        components.second = 0

        guard var current = calendar.date(from: components) else { return nil }

        // Search up to 366 days ahead
        let limit = calendar.date(byAdding: .day, value: 366, to: date)!

        while current < limit {
            let c = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: current)
            let weekday = ((c.weekday ?? 1) + 5) % 7  // Convert 1=Sun..7=Sat to 0=Sun..6=Sat

            if months.contains(c.month ?? 0) &&
               daysOfMonth.contains(c.day ?? 0) &&
               daysOfWeek.contains(weekday) &&
               hours.contains(c.hour ?? 0) &&
               minutes.contains(c.minute ?? 0) {
                return current
            }

            // Advance: if month/day/weekday doesn't match, skip ahead faster
            if !months.contains(c.month ?? 0) || !daysOfMonth.contains(c.day ?? 0) || !daysOfWeek.contains(weekday) {
                current = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: current))!
            } else if !hours.contains(c.hour ?? 0) {
                current = calendar.date(byAdding: .hour, value: 1, to: current)!
                current = calendar.date(bySetting: .minute, value: 0, of: current)!
            } else {
                current = calendar.date(byAdding: .minute, value: 1, to: current)!
            }
        }

        return nil
    }

    /// Check if the given date matches this cron expression.
    func matches(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let c = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: date)
        let weekday = ((c.weekday ?? 1) + 5) % 7

        return minutes.contains(c.minute ?? -1) &&
               hours.contains(c.hour ?? -1) &&
               daysOfMonth.contains(c.day ?? -1) &&
               months.contains(c.month ?? -1) &&
               daysOfWeek.contains(weekday)
    }

    // MARK: - Field parsing

    private static func parseField(_ field: String, min: Int, max: Int) -> Set<Int>? {
        var result = Set<Int>()

        for part in field.components(separatedBy: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }

            if let values = parsePart(trimmed, min: min, max: max) {
                result.formUnion(values)
            } else {
                return nil
            }
        }

        return result.isEmpty ? nil : result
    }

    private static func parsePart(_ part: String, min: Int, max: Int) -> Set<Int>? {
        // Handle step: */2, 1-30/5
        let stepComponents = part.components(separatedBy: "/")
        guard stepComponents.count <= 2 else { return nil }

        let step = stepComponents.count == 2 ? Int(stepComponents[1]) : 1
        guard let step, step > 0 else { return nil }

        let rangePart = stepComponents[0]

        let rangeMin: Int
        let rangeMax: Int

        if rangePart == "*" {
            rangeMin = min
            rangeMax = max
        } else if rangePart.contains("-") {
            let bounds = rangePart.components(separatedBy: "-")
            guard bounds.count == 2,
                  let lo = Int(bounds[0]), let hi = Int(bounds[1]),
                  lo >= min, hi <= max, lo <= hi else { return nil }
            rangeMin = lo
            rangeMax = hi
        } else {
            guard let value = Int(rangePart), value >= min, value <= max else { return nil }
            return [value]
        }

        var values = Set<Int>()
        var current = rangeMin
        while current <= rangeMax {
            values.insert(current)
            current += step
        }
        return values
    }
}
