import Foundation
import Testing
@testable import MacLaw

@Test func pipelineSequentialExecution() async {
    let callLog = CallLog()
    let runner = PipelineRunner { prompt in
        await callLog.append(prompt)
        return .success("output-of-\(prompt)")
    }

    let pipeline = PipelineConfig(id: "test", steps: [
        PipelineStepConfig(name: "step1", prompt: "do first", onError: nil),
        PipelineStepConfig(name: "step2", prompt: "do second with {{step1.output}}", onError: nil),
    ])

    let result = await runner.run(pipeline: pipeline, context: .empty(id: "test"))
    guard case .success(let steps) = result else {
        Issue.record("Expected success")
        return
    }

    #expect(steps.count == 2)
    #expect(steps[0].name == "step1")
    #expect(steps[0].succeeded)
    #expect(steps[1].name == "step2")
    #expect(steps[1].succeeded)
    let calls = await callLog.all()
    #expect(calls[1] == "do second with output-of-do first")
}

/// Thread-safe call log for tests.
private actor CallLog {
    private var entries: [String] = []
    func append(_ entry: String) { entries.append(entry) }
    func all() -> [String] { entries }
}

@Test func pipelineStopOnError() async {
    let runner = PipelineRunner { prompt in
        if prompt.contains("fail") {
            return .failure(PipelineError.stepFailed(step: "test", error: "forced failure"))
        }
        return .success("ok")
    }

    let pipeline = PipelineConfig(id: "test", steps: [
        PipelineStepConfig(name: "step1", prompt: "fail here", onError: .stop),
        PipelineStepConfig(name: "step2", prompt: "should not run", onError: nil),
    ])

    let result = await runner.run(pipeline: pipeline, context: .empty(id: "test"))
    guard case .failure(let error) = result else {
        Issue.record("Expected failure")
        return
    }
    #expect(error.description.contains("step1"))
}

@Test func pipelineSkipOnError() async {
    let runner = PipelineRunner { prompt in
        if prompt.contains("fail") {
            return .failure(PipelineError.stepFailed(step: "test", error: "forced failure"))
        }
        return .success("ok")
    }

    let pipeline = PipelineConfig(id: "test", steps: [
        PipelineStepConfig(name: "step1", prompt: "fail here", onError: .skip),
        PipelineStepConfig(name: "step2", prompt: "should run", onError: nil),
    ])

    let result = await runner.run(pipeline: pipeline, context: .empty(id: "test"))
    guard case .success(let steps) = result else {
        Issue.record("Expected success (skip strategy)")
        return
    }
    #expect(steps.count == 2)
    #expect(!steps[0].succeeded)
    #expect(steps[1].succeeded)
}

@Test func pipelineTemplateInterpolation() async {
    let runner = PipelineRunner { prompt in .success("result") }

    let template = "Process {{activation.message}} from {{activation.filePath}}"
    let result = await runner.interpolate(template, stepResults: [], contextVars: ["message": "hello world", "filePath": "/tmp/file.txt"])

    #expect(result == "Process hello world from /tmp/file.txt")
}
