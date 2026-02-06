import SwiftUI

private enum Bootstrap {
    static func settingsURL() -> URL {
        do {
            return try SettingsArguments.settingsFileURL(from: CommandLine.arguments)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(2)
        }
    }
}

@main
struct TextShotSettingsApp: App {
    @StateObject private var model = SettingsViewModel(settingsURL: Bootstrap.settingsURL())

    var body: some Scene {
        WindowGroup("Text Shot Settings") {
            ContentView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}
