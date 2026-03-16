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
