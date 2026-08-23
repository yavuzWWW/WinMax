import Foundation

@main
struct VersioningTests {
    static func main() {
        expect(WinMaxVersioning.compare("1.1.0", "1.1.0") == .orderedSame, "equal versions")
        expect(WinMaxVersioning.compare("1.1.1", "1.1.0") == .orderedDescending, "patch upgrade")
        expect(WinMaxVersioning.compare("1.2.0", "1.1.9") == .orderedDescending, "minor upgrade")
        expect(WinMaxVersioning.compare("2.0.0", "1.99.99") == .orderedDescending, "major upgrade")
        expect(WinMaxVersioning.compare("1.0", "1.0.0") == .orderedSame, "missing patch segment")
        expect(WinMaxVersioning.compare("v1.2.3", "1.2.3") == .orderedSame, "v-prefixed release")
        expect(WinMaxVersioning.compare("1.2.3", "1.2.4") == .orderedAscending, "older patch")
        expect(WinMaxVersioning.compare("1.2.3-beta", "1.2.3") == .orderedSame, "numeric prerelease prefix")
        print("Versioning tests passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Versioning test failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
