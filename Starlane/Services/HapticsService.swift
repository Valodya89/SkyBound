import UIKit

protocol HapticsService: AnyObject {
    var isEnabled: Bool { get set }
    func light()
    func medium()
    func heavy()
    func selection()
    func success()
    func warning()
}

final class SystemHapticsService: HapticsService {
    var isEnabled = true

    private let lightGen = UIImpactFeedbackGenerator(style: .light)
    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGen = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGen = UISelectionFeedbackGenerator()
    private let notifyGen = UINotificationFeedbackGenerator()

    init() {
        lightGen.prepare()
        mediumGen.prepare()
        heavyGen.prepare()
    }

    func light() { guard isEnabled else { return }; lightGen.impactOccurred(intensity: 0.6) }
    func medium() { guard isEnabled else { return }; mediumGen.impactOccurred() }
    func heavy() { guard isEnabled else { return }; heavyGen.impactOccurred() }
    func selection() { guard isEnabled else { return }; selectionGen.selectionChanged() }
    func success() { guard isEnabled else { return }; notifyGen.notificationOccurred(.success) }
    func warning() { guard isEnabled else { return }; notifyGen.notificationOccurred(.warning) }
}

final class SilentHapticsService: HapticsService {
    var isEnabled = false
    func light() {}
    func medium() {}
    func heavy() {}
    func selection() {}
    func success() {}
    func warning() {}
}
