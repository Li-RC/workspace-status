import AppKit

struct AppWindow: Decodable, Identifiable {
    let id: Int
    let app: String
    let bundle: String
    let title: String
    let workspace: String
    var isWorkspaceApplication: Bool {
        !["local.WorkspaceStatus", "com.apple.notificationcenterui", "com.apple.UserNotificationCenter"].contains(bundle)
    }
    enum CodingKeys: String, CodingKey {
        case id = "window-id", app = "app-name", bundle = "app-bundle-id"
        case title = "window-title", workspace
    }
}

struct Space: Decodable { let workspace: String }
struct Snapshot {
    let spaces: [String]
    let current: String
    let windows: [AppWindow]
    func windows(in space: String) -> [AppWindow] { windows.filter { $0.workspace == space } }
    var occupiedSpaces: [String] {
        Set(windows.map(\.workspace)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    var menuSpaces: [String] {
        Set(occupiedSpaces + [current]).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    func appBundles(in space: String) -> [String] {
        let names = Dictionary(windows(in: space).map { ($0.bundle, $0.app) }, uniquingKeysWith: { first, _ in first })
        return names.keys.sorted { left, right in
            let order = names[left]!.localizedStandardCompare(names[right]!)
            return order == .orderedSame ? left < right : order == .orderedAscending
        }
    }
}

enum AeroSpace {
    static var executable: String? {
        ["/opt/homebrew/bin/aerospace", "/usr/local/bin/aerospace",
         "/Applications/AeroSpace.app/Contents/MacOS/aerospace"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // Arguments go directly to Process, never through a shell.
    static func run(_ arguments: [String]) throws -> Data {
        guard let path = executable else {
            throw NSError(domain: "WorkspaceStatus", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Install AeroSpace to use workspace controls."])
        }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "AEROSPACE_WINDOW_ID")
        environment.removeValue(forKey: "AEROSPACE_WORKSPACE")
        process.environment = environment
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 4, execute: timeout)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeout.cancel()
        guard process.terminationStatus == 0 else {
            let message = String(data: data, encoding: .utf8) ?? "AeroSpace did not respond."
            throw NSError(domain: "AeroSpace", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return data
    }

    static func snapshot() throws -> Snapshot {
        let decoder = JSONDecoder()
        let spaces = try decoder.decode([Space].self, from: run(["list-workspaces", "--all", "--json"]))
        let current = try decoder.decode([Space].self, from: run(["list-workspaces", "--focused", "--json"]))
        let windows = try decoder.decode([AppWindow].self, from: run([
            "list-windows", "--all", "--json", "--format",
            "%{window-id}%{app-name}%{app-bundle-id}%{window-title}%{workspace}"
        ]))
        return Snapshot(spaces: spaces.map(\.workspace).sorted { $0.localizedStandardCompare($1) == .orderedAscending },
                        current: current.first?.workspace ?? "?", windows: windows.filter(\.isWorkspaceApplication))
    }
}

final class WorkspaceModel: ObservableObject {
    @Published var snapshot = Snapshot(spaces: [], current: "?", windows: [])
    @Published var error: String?
    var changed: (() -> Void)?
    private var loading = false
    private var pending = false
    private var subscription: Process?
    private var subscriptionPipe: Pipe?
    private var timer: Timer?

    func start() {
        refresh()
        subscribe()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
            if self?.subscription?.isRunning != true { self?.subscribe() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        guard !loading else { pending = true; return }
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try AeroSpace.snapshot() }
            DispatchQueue.main.async {
                self.loading = false
                switch result {
                case .success(let snapshot): self.snapshot = snapshot; self.error = nil
                case .failure(let error): self.error = error.localizedDescription
                }
                self.changed?()
                if self.pending { self.pending = false; self.refresh() }
            }
        }
    }

    private func subscribe() {
        guard let path = AeroSpace.executable else { return }
        subscriptionPipe?.fileHandleForReading.readabilityHandler = nil
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["subscribe", "--all"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard !handle.availableData.isEmpty else { handle.readabilityHandler = nil; return }
            DispatchQueue.main.async { self?.refresh() }
        }
        do { try process.run(); subscription = process; subscriptionPipe = pipe }
        catch { pipe.fileHandleForReading.readabilityHandler = nil }
    }

    func perform(_ arguments: [String], completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try AeroSpace.run(arguments) }
            DispatchQueue.main.async {
                switch result {
                case .success: completion(); self.refresh()
                case .failure(let error): self.error = error.localizedDescription; self.changed?()
                }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        subscriptionPipe?.fileHandleForReading.readabilityHandler = nil
        if subscription?.isRunning == true { subscription?.terminate() }
    }
}
