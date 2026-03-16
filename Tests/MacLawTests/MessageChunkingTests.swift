import Testing
@testable import MacLaw

@Test func shortMessageNotSplit() {
    let chunks = TelegramSender.splitMessage("Hello", maxLength: 4096)
    #expect(chunks.count == 1)
    #expect(chunks[0] == "Hello")
}

@Test func exactLimitNotSplit() {
    let text = String(repeating: "a", count: 4096)
    let chunks = TelegramSender.splitMessage(text, maxLength: 4096)
    #expect(chunks.count == 1)
}

@Test func longMessageSplitsAtNewline() {
    let line = String(repeating: "x", count: 100)
    // 50 lines × 101 chars (100 + newline) = 5050 chars
    let text = (0..<50).map { _ in line }.joined(separator: "\n")
    let chunks = TelegramSender.splitMessage(text, maxLength: 4096)
    #expect(chunks.count >= 2)
    for chunk in chunks {
        #expect(chunk.count <= 4096)
    }
}

@Test func splitPreservesAllContent() {
    let text = (0..<100).map { "Line \($0)" }.joined(separator: "\n")
    let chunks = TelegramSender.splitMessage(text, maxLength: 200)
    let reassembled = chunks.joined(separator: "\n")
    #expect(reassembled == text)
}

@Test func noNewlineHardCuts() {
    let text = String(repeating: "a", count: 5000)  // no newlines
    let chunks = TelegramSender.splitMessage(text, maxLength: 4096)
    #expect(chunks.count == 2)
    #expect(chunks[0].count == 4096)
    #expect(chunks[1].count == 904)
}
