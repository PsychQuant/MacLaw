import Foundation
import Testing
@testable import MacLaw

@Test func parseEveryHour() {
    guard case .recurring(let seconds) = CronJobParser.parseSchedule("every 1h") else {
        Issue.record("Expected recurring")
        return
    }
    #expect(seconds == 3600)
}

@Test func parseEvery30Minutes() {
    guard case .recurring(let seconds) = CronJobParser.parseSchedule("every 30m") else {
        Issue.record("Expected recurring")
        return
    }
    #expect(seconds == 1800)
}

@Test func parseEvery6Hours() {
    guard case .recurring(let seconds) = CronJobParser.parseSchedule("every 6h") else {
        Issue.record("Expected recurring")
        return
    }
    #expect(seconds == 21600)
}

@Test func parseEveryDay() {
    guard case .recurring(let seconds) = CronJobParser.parseSchedule("every 1d") else {
        Issue.record("Expected recurring")
        return
    }
    #expect(seconds == 86400)
}

@Test func parseOneShot() {
    guard case .oneShot(let date) = CronJobParser.parseSchedule("at 2026-03-17T10:00:00Z") else {
        Issue.record("Expected oneShot")
        return
    }
    let formatter = ISO8601DateFormatter()
    #expect(formatter.string(from: date) == "2026-03-17T10:00:00Z")
}

@Test func parseInvalidReturnsNil() {
    #expect(CronJobParser.parseSchedule("garbage") == nil)
    #expect(CronJobParser.parseSchedule("") == nil)
    #expect(CronJobParser.parseSchedule("every") == nil)
}

@Test func backoffSchedule() {
    #expect(BackoffSchedule.delay(forConsecutiveErrors: 1) == 30)
    #expect(BackoffSchedule.delay(forConsecutiveErrors: 2) == 60)
    #expect(BackoffSchedule.delay(forConsecutiveErrors: 3) == 300)
    #expect(BackoffSchedule.delay(forConsecutiveErrors: 4) == 900)
    #expect(BackoffSchedule.delay(forConsecutiveErrors: 5) == 3600)
    #expect(BackoffSchedule.delay(forConsecutiveErrors: 99) == 3600)  // capped
}

// MARK: - CronExpression tests

@Test func cronParseEveryMinute() {
    let cron = CronExpression.parse("* * * * *")
    #expect(cron != nil)
    #expect(cron!.minutes.count == 60)
    #expect(cron!.hours.count == 24)
}

@Test func cronParseDailyAt9AM() {
    let cron = CronExpression.parse("0 9 * * *")
    #expect(cron != nil)
    #expect(cron!.minutes == [0])
    #expect(cron!.hours == [9])
    #expect(cron!.daysOfMonth.count == 31)
}

@Test func cronParseWeekdays() {
    let cron = CronExpression.parse("0 9 * * 1-5")
    #expect(cron != nil)
    #expect(cron!.daysOfWeek == [1, 2, 3, 4, 5])
}

@Test func cronParseSteps() {
    let cron = CronExpression.parse("*/15 * * * *")
    #expect(cron != nil)
    #expect(cron!.minutes == [0, 15, 30, 45])
}

@Test func cronParseList() {
    let cron = CronExpression.parse("0 9,12,18 * * *")
    #expect(cron != nil)
    #expect(cron!.hours == [9, 12, 18])
}

@Test func cronParseRangeWithStep() {
    let cron = CronExpression.parse("0-30/10 * * * *")
    #expect(cron != nil)
    #expect(cron!.minutes == [0, 10, 20, 30])
}

@Test func cronParseInvalidExpression() {
    #expect(CronExpression.parse("invalid") == nil)
    #expect(CronExpression.parse("") == nil)
    #expect(CronExpression.parse("* * *") == nil)  // only 3 fields
    #expect(CronExpression.parse("60 * * * *") == nil)  // minute out of range
    #expect(CronExpression.parse("* 25 * * *") == nil)  // hour out of range
}

@Test func cronNextFireTime() {
    let cron = CronExpression.parse("0 9 * * *")!
    let formatter = ISO8601DateFormatter()
    let date = formatter.date(from: "2026-03-19T08:30:00Z")!
    let next = cron.nextFireTime(after: date)
    #expect(next != nil)
    let nextComponents = Calendar.current.dateComponents([.hour, .minute], from: next!)
    #expect(nextComponents.hour == 9)
    #expect(nextComponents.minute == 0)
}

@Test func cronMatchesDate() {
    // Use local time components to avoid UTC vs local timezone mismatch
    var calendar = Calendar.current
    var matchComponents = DateComponents()
    matchComponents.year = 2026; matchComponents.month = 3; matchComponents.day = 19
    matchComponents.hour = 14; matchComponents.minute = 30; matchComponents.second = 0
    let matching = calendar.date(from: matchComponents)!

    var nonMatchComponents = matchComponents
    nonMatchComponents.minute = 31
    let nonMatching = calendar.date(from: nonMatchComponents)!

    let cron = CronExpression.parse("30 14 * * *")!
    #expect(cron.matches(matching))
    #expect(!cron.matches(nonMatching))
}
