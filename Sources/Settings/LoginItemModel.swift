import Combine
import ServiceManagement

final class LoginItemModel: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var error: String?
    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void

    init(readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
         register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
         unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }) {
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        refresh()
    }

    var requested: Bool { status == .enabled || status == .requiresApproval }
    var description: String {
        switch status {
        case .enabled: return "Enabled"
        case .requiresApproval: return "Approval required in System Settings."
        case .notFound: return "Login registration is unavailable for this app copy. Install it in Applications and try again."
        case .notRegistered: return "Off"
        @unknown default: return "Status unavailable"
        }
    }

    func refresh() { status = readStatus() }

    func setEnabled(_ enabled: Bool) {
        refresh()
        guard enabled != requested else { return }
        error = nil
        do {
            if enabled { try register() } else { try unregister() }
        } catch { self.error = error.localizedDescription }
        refresh()
    }
}
