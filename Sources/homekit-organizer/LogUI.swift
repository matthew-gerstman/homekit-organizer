import SwiftUI

// MARK: - Log Manager

@MainActor
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: [String] = []
    @Published var isRunning = false
    @Published var isComplete = false
    
    func log(_ message: String) {
        logs.append(message)
    }
    
    func clear() {
        logs.removeAll()
        isComplete = false
    }
}

// Custom print that also logs to UI
func uiPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    print(message, terminator: terminator)  // Still print to console
    Task { @MainActor in
        LogManager.shared.log(message)
    }
}

// MARK: - Log View

struct LogView: View {
    @ObservedObject var logManager = LogManager.shared
    @State private var autoScroll = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("HomeKit Organizer")
                    .font(.headline)
                Spacer()
                if logManager.isRunning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Log output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(logManager.logs.enumerated()), id: \.offset) { index, log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(colorForLog(log))
                                .id(index)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.black)
                .onChange(of: logManager.logs.count) { _ in
                    if autoScroll, let lastIndex = logManager.logs.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Bottom bar
            if logManager.isComplete {
                HStack {
                    Text("✅ Complete")
                        .foregroundColor(.green)
                    Spacer()
                    Button("Run Again") {
                        runOrganizer()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }
    
    func colorForLog(_ log: String) -> Color {
        if log.contains("✅") || log.contains("SUCCESS") || log.contains("✓") {
            return .green
        } else if log.contains("❌") || log.contains("FAILED") || log.contains("Error") {
            return .red
        } else if log.contains("⚠️") || log.contains("Warning") {
            return .yellow
        } else if log.contains("[DEBUG]") {
            return .gray
        } else if log.contains("🗑️") || log.contains("Delete") {
            return .orange
        } else {
            return .white
        }
    }
}

// MARK: - App Entry Point

@main
struct HomeKitOrganizerApp: App {
    var body: some Scene {
        WindowGroup {
            LogView()
                .onAppear {
                    runOrganizer()
                }
        }
    }
}

// MARK: - Run Organizer

func runOrganizer() {
    Task { @MainActor in
        LogManager.shared.clear()
        LogManager.shared.isRunning = true
        
        do {
            try await runApplyBundled()
        } catch {
            uiPrint("❌ Error: \(error.localizedDescription)")
        }
        
        LogManager.shared.isRunning = false
        LogManager.shared.isComplete = true
    }
}

@MainActor
func runApplyBundled() async throws {
    uiPrint("📱 HomeKit Organizer")
    uiPrint("====================")
    uiPrint("")
    
    // Find bundled config
    guard let configURL = Bundle.main.url(forResource: "config", withExtension: "yaml") else {
        uiPrint("❌ No config.yaml found in app bundle!")
        throw HomeKitError.operationFailed("No config found")
    }
    
    uiPrint("📄 Loading config.yaml...")
    
    // Load and parse
    let configData = try Data(contentsOf: configURL)
    guard let configString = String(data: configData, encoding: .utf8) else {
        throw HomeKitError.operationFailed("Could not read config file")
    }
    
    let config = try ConfigParser.parse(yaml: configString)
    
    // Validate
    let validation = ConfigValidator.validate(config)
    for warning in validation.warnings {
        uiPrint("⚠️  \(warning)")
    }
    if !validation.isValid {
        for error in validation.errors {
            uiPrint("❌ \(error.errorDescription ?? "Unknown error")")
        }
        throw HomeKitError.operationFailed("Validation failed")
    }
    
    uiPrint("✅ Config valid: \(config)")
    uiPrint("")
    
    // Connect to HomeKit
    uiPrint("🏠 Connecting to HomeKit...")
    let manager = HomeKitManager()
    try await manager.waitForHomesLoaded()
    
    let home = try manager.getPrimaryHome()
    let snapshot = manager.loadSnapshot(for: home)
    uiPrint("✓ Home: \(snapshot.home.name)")
    uiPrint("✓ Rooms: \(snapshot.rooms.count)")
    uiPrint("✓ Accessories: \(snapshot.accessories.count)")
    uiPrint("")
    
    // Log all accessories for debugging
    uiPrint("📋 All Accessories:")
    uiPrint("-------------------")
    for room in snapshot.rooms.sorted(by: { $0.name < $1.name }) {
        let roomAccessories = snapshot.accessories.filter { 
            room.isDefault ? $0.roomId == nil : $0.roomId == room.id 
        }
        if !roomAccessories.isEmpty {
            uiPrint("  [\(room.name)]")
            for acc in roomAccessories.sorted(by: { $0.name < $1.name }) {
                uiPrint("    - \"\(acc.name)\" (\(acc.category))")
            }
        }
    }
    uiPrint("")
    
    // Plan operations
    let plan = Planner.plan(config: config, snapshot: snapshot, deleteUnlistedRooms: true)
    
    uiPrint("🗑️  Delete unlisted rooms: ENABLED")
    uiPrint("")
    
    if plan.isEmpty {
        uiPrint("✅ Nothing to do - HomeKit matches config!")
        return
    }
    
    // Show plan
    for (category, ops) in plan.operationsByCategory {
        uiPrint("\(category.rawValue) (\(ops.count)):")
        for op in ops {
            uiPrint("  • \(op.description)")
        }
        uiPrint("")
    }
    
    if !plan.warnings.isEmpty {
        uiPrint("Warnings:")
        for warning in plan.warnings {
            uiPrint("  ⚠️  \(warning)")
        }
        uiPrint("")
    }
    
    // Execute
    uiPrint("⚡ Executing \(plan.operations.count) operations...")
    uiPrint("")
    
    let executor = Executor(manager: manager, home: home, verbose: true)
    let result = await executor.execute(plan: plan)
    
    uiPrint("")
    uiPrint("✅ Succeeded: \(result.successCount)")
    if result.hasFailures {
        uiPrint("❌ Failed: \(result.failureCount)")
    }
}

