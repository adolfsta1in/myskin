import LocalAuthentication
import Observation

/// Face ID / Touch ID with the device passcode as fallback (`deviceOwnerAuthentication`).
enum BiometricAuth {
    enum Method: Equatable {
        case faceID, touchID, opticID
        /// No biometrics enrolled, but a passcode is set.
        case passcode
        /// No passcode on the device: the lock can't be used.
        case unavailable

        var title: String {
            switch self {
            case .faceID: "Face ID"
            case .touchID: "Touch ID"
            case .opticID: "Optic ID"
            case .passcode, .unavailable: "passcode"
            }
        }

        var systemImage: String {
            switch self {
            case .faceID: "faceid"
            case .touchID: "touchid"
            case .opticID: "opticid"
            case .passcode, .unavailable: "lock"
            }
        }
    }

    static var method: Method {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return .unavailable }
        // `biometryType` is only filled in after a `canEvaluatePolicy` call.
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .passcode
        }
    }

    /// Shows the system prompt. Returns false on cancel or failure.
    /// The context is created and used off the main actor, so it is never shared across isolation.
    @concurrent
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

/// Session lock state. Starts locked on launch when the lock is on.
@Observable
final class AppLock {
    var isLocked: Bool

    init(isLocked: Bool) {
        self.isLocked = isLocked
    }

    convenience init(settings: AppSettings) {
        self.init(isLocked: settings.faceIDEnabled && settings.hasCompletedOnboarding)
    }

    func unlock() async {
        if await BiometricAuth.authenticate(reason: "Unlock your skin diary") {
            isLocked = false
        }
    }
}
