import Foundation

@main
struct SettingsProfileTests {
    static func main() throws {
        let profile = WinMaxSettingsProfile(
            enabled: true,
            overrideGreenButton: false,
            titleBarDoubleClick: true,
            overrideFullscreenShortcut: false,
            aeroSnapEnabled: true,
            menuVaultEnabled: true,
            showWindowOnLaunch: false,
            layoutShortcutsEnabled: false
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(profile)
        let decoded = try JSONDecoder().decode(WinMaxSettingsProfile.self, from: data)
        expect(decoded == profile, "round-trip preserves settings")
        expect(decoded.layoutShortcutsEnabled == false, "round-trip preserves shortcut preference")
        let validated = try decoded.validated()
        expect(validated == profile, "current schema validates")

        let legacyJSON = """
        {
          "schemaVersion": 1,
          "enabled": true,
          "overrideGreenButton": true,
          "titleBarDoubleClick": true,
          "overrideFullscreenShortcut": true,
          "aeroSnapEnabled": true,
          "menuVaultEnabled": true,
          "showWindowOnLaunch": false
        }
        """.data(using: .utf8)!

        let legacy = try JSONDecoder().decode(WinMaxSettingsProfile.self, from: legacyJSON)
        expect(legacy.schemaVersion == 1, "legacy schema version is preserved")
        expect(legacy.layoutShortcutsEnabled == true, "legacy profiles default layout shortcuts on")
        _ = try legacy.validated()

        let future = WinMaxSettingsProfile(
            schemaVersion: WinMaxSettingsProfile.currentSchemaVersion + 1,
            enabled: true,
            overrideGreenButton: true,
            titleBarDoubleClick: true,
            overrideFullscreenShortcut: true,
            aeroSnapEnabled: true,
            menuVaultEnabled: true,
            showWindowOnLaunch: false,
            layoutShortcutsEnabled: true
        )

        do {
            _ = try future.validated()
            fail("future schema should be rejected")
        } catch WinMaxSettingsProfileError.newerSchema(let version) {
            expect(version == WinMaxSettingsProfile.currentSchemaVersion + 1, "future schema version is preserved")
        }

        print("Settings profile tests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        fputs("Settings profile test failed: \(message)\n", stderr)
        exit(1)
    }
}
