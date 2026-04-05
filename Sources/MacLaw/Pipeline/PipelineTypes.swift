import Foundation

struct PipelineConfig: Codable {
    let id: String
    let steps: [PipelineStepConfig]
}

struct PipelineStepConfig: Codable {
    let name: String
    let prompt: String
    let onError: ErrorStrategy?

    var errorStrategy: ErrorStrategy { onError ?? .stop }
}

enum ErrorStrategy: String, Codable {
    case stop
    case skip
    case retry
}

struct StepResult {
    let name: String
    let output: String
    let succeeded: Bool
}

enum PipelineError: Error, CustomStringConvertible {
    case stepFailed(step: String, error: String)
    case pipelineNotFound(id: String)

    var description: String {
        switch self {
        case .stepFailed(let step, let error):
            return "Step '\(step)' failed: \(error)"
        case .pipelineNotFound(let id):
            return "Pipeline '\(id)' not found"
        }
    }
}
