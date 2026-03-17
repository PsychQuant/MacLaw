import Foundation

/// Thread-safe mutable model selection, changeable at runtime via /model set.
actor CurrentModel {
    private var model: String?

    func get() -> String? { model }

    func set(_ newModel: String?) {
        model = newModel
    }
}
