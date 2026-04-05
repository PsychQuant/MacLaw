import Foundation

/// Executes pipeline steps sequentially, passing output between steps.
actor PipelineRunner {
    private let executeStep: @Sendable (String) async -> Result<String, Error>
    private let maxRetries: Int

    init(
        maxRetries: Int = 2,
        executeStep: @Sendable @escaping (String) async -> Result<String, Error>
    ) {
        self.maxRetries = maxRetries
        self.executeStep = executeStep
    }

    /// Run a pipeline with the given context. Returns all step results.
    func run(pipeline: PipelineConfig, context: ActivationContext) async -> Result<[StepResult], PipelineError> {
        var results: [StepResult] = []
        let contextVars = buildContextVars(from: context)

        for step in pipeline.steps {
            let resolvedPrompt = interpolate(step.prompt, stepResults: results, contextVars: contextVars)

            let stepResult = await executeWithStrategy(
                stepName: step.name,
                prompt: resolvedPrompt,
                strategy: step.errorStrategy
            )

            results.append(stepResult)

            if !stepResult.succeeded && step.errorStrategy == .stop {
                return .failure(.stepFailed(step: step.name, error: stepResult.output))
            }
        }

        return .success(results)
    }

    // MARK: - Step execution with error strategy

    private func executeWithStrategy(stepName: String, prompt: String, strategy: ErrorStrategy) async -> StepResult {
        let result = await executeStep(prompt)

        switch result {
        case .success(let output):
            return StepResult(name: stepName, output: output, succeeded: true)

        case .failure(let error):
            if strategy == .retry {
                // Retry up to maxRetries times
                for attempt in 1...maxRetries {
                    let retryResult = await executeStep(prompt)
                    if case .success(let output) = retryResult {
                        return StepResult(name: stepName, output: output, succeeded: true)
                    }
                    log("Step '\(stepName)' retry \(attempt)/\(maxRetries) failed")
                }
            }

            if strategy == .skip {
                log("Step '\(stepName)' failed, skipping: \(error.localizedDescription)")
                return StepResult(name: stepName, output: "", succeeded: false)
            }

            // stop or retry exhausted
            return StepResult(name: stepName, output: error.localizedDescription, succeeded: false)
        }
    }

    // MARK: - Template interpolation

    /// Replace {{stepName.output}} and {{activation.*}} placeholders in the prompt.
    func interpolate(_ template: String, stepResults: [StepResult], contextVars: [String: String]) -> String {
        var result = template

        // Replace step output references: {{stepName.output}}
        for step in stepResults {
            result = result.replacingOccurrences(of: "{{\(step.name).output}}", with: step.output)
        }

        // Replace activation context references: {{activation.message}}, {{activation.filePath}}, etc.
        for (key, value) in contextVars {
            result = result.replacingOccurrences(of: "{{activation.\(key)}}", with: value)
        }

        return result
    }

    private func buildContextVars(from context: ActivationContext) -> [String: String] {
        var vars: [String: String] = [:]
        if let message = context.message {
            vars["message"] = message
        }
        if let filePath = context.filePath {
            vars["filePath"] = filePath
        }
        for (i, group) in context.matchedGroups.enumerated() {
            vars["match\(i)"] = group
        }
        return vars
    }

    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] [pipeline] \(message)")
    }
}
