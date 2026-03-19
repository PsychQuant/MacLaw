import ArgumentParser
import Foundation

struct PipelineCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pipeline",
        abstract: "Manage and run pipelines",
        subcommands: [PipelineList.self, PipelineRun.self, PipelineRm.self]
    )
}

struct PipelineList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all configured pipelines"
    )

    func run() throws {
        let config = try ConfigLoader.load()
        let pipelines = config.pipelines ?? []
        if pipelines.isEmpty {
            print("No pipelines configured.")
            return
        }
        for p in pipelines {
            print("  \(p.id)  (\(p.steps.count) steps)")
            for (i, step) in p.steps.enumerated() {
                let strategy = step.errorStrategy == .stop ? "" : " [\(step.errorStrategy.rawValue)]"
                print("    \(i + 1). \(step.name)\(strategy)")
            }
        }
    }
}

struct PipelineRun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Manually run a pipeline"
    )

    @Option(name: .long, help: "Pipeline ID")
    var id: String

    @Option(name: .long, help: "Context string passed to the first step")
    var context: String?

    func run() async throws {
        let config = try ConfigLoader.load()
        guard let pipeline = config.pipelines?.first(where: { $0.id == id }) else {
            print("Error: Pipeline '\(id)' not found")
            return
        }

        let backendName = config.backend ?? "codex"
        print("Running pipeline '\(id)' (\(pipeline.steps.count) steps) with backend '\(backendName)'...")

        let runner = PipelineRunner { prompt in
            // Shell out to backend
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

            if backendName == "claude" {
                process.arguments = ["claude", "-p", prompt, "--output-format", "text"]
            } else {
                process.arguments = ["codex", "exec", prompt, "--full-auto"]
            }

            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return process.terminationStatus == 0 ? .success(output) : .failure(PipelineError.stepFailed(step: "", error: output))
            } catch {
                return .failure(error)
            }
        }

        let activationContext = ActivationContext(
            activationId: "manual",
            message: context,
            matchedGroups: [],
            filePath: nil
        )

        let result = await runner.run(pipeline: pipeline, context: activationContext)
        switch result {
        case .success(let steps):
            print("\nPipeline '\(id)' completed:")
            for step in steps {
                let status = step.succeeded ? "OK" : "FAILED"
                print("  [\(status)] \(step.name)")
                if !step.output.isEmpty {
                    let preview = step.output.prefix(200)
                    print("    → \(preview)\(step.output.count > 200 ? "..." : "")")
                }
            }
        case .failure(let error):
            print("\nPipeline '\(id)' failed: \(error)")
        }
    }
}

struct PipelineRm: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Remove a pipeline"
    )

    @Argument(help: "Pipeline ID to remove")
    var id: String

    func run() throws {
        var config = try ConfigLoader.load()
        var pipelines = config.pipelines ?? []
        guard pipelines.contains(where: { $0.id == id }) else {
            print("Error: Pipeline '\(id)' not found")
            return
        }
        pipelines.removeAll { $0.id == id }
        config.pipelines = pipelines

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: ConfigLoader.configPath))
        print("Removed pipeline '\(id)'")
    }
}
