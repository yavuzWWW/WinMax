import Cocoa

final class UpdateChecker {
    static let shared = UpdateChecker()

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private let session: URLSession
    private var requestInFlight = false

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        session = URLSession(configuration: configuration)
    }

    func checkForUpdates(presenting window: NSWindow? = nil) {
        guard !requestInFlight else { return }
        requestInFlight = true

        var request = URLRequest(url: WinMaxProduct.latestReleaseAPIURL)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("WinMax/\(WinMaxProduct.version)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.requestInFlight = false

                if let error {
                    self.presentError("Couldn’t check for updates", detail: error.localizedDescription, window: window)
                    return
                }

                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let data,
                      data.count <= 1_000_000 else {
                    self.presentError(
                        "Couldn’t check for updates",
                        detail: "GitHub did not return a valid release response.",
                        window: window
                    )
                    return
                }

                do {
                    let release = try JSONDecoder().decode(Release.self, from: data)
                    guard Self.isTrustedReleaseURL(release.htmlURL) else {
                        self.presentError(
                            "Couldn’t check for updates",
                            detail: "The release response contained an unexpected destination.",
                            window: window
                        )
                        return
                    }

                    let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                    if WinMaxVersioning.compare(latest, WinMaxProduct.version) == .orderedDescending {
                        self.presentUpdate(latest: latest, url: release.htmlURL, window: window)
                    } else {
                        self.presentCurrent(window: window)
                    }
                } catch {
                    self.presentError(
                        "Couldn’t check for updates",
                        detail: "The latest release information could not be read.",
                        window: window
                    )
                }
            }
        }.resume()
    }

    private static func isTrustedReleaseURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "github.com" else {
            return false
        }
        return url.path.hasPrefix("/yavuzWWW/WinMax/releases/")
    }

    private func presentUpdate(latest: String, url: URL, window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = "WinMax \(latest) is available"
        alert.informativeText = "You’re using WinMax \(WinMaxProduct.version). Open the official release page to download the update."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Release")
        alert.addButton(withTitle: "Later")
        present(alert, window: window) { response in
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func presentCurrent(window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = "WinMax is up to date"
        alert.informativeText = "You’re running the latest public release, WinMax \(WinMaxProduct.version)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        present(alert, window: window, completion: nil)
    }

    private func presentError(_ title: String, detail: String, window: NSWindow?) {
        WinMaxLogger.shared.warning("Update check failed")
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Releases")
        present(alert, window: window) { response in
            if response == .alertSecondButtonReturn {
                NSWorkspace.shared.open(WinMaxProduct.releasesURL)
            }
        }
    }

    private func present(_ alert: NSAlert, window: NSWindow?, completion: ((NSApplication.ModalResponse) -> Void)?) {
        if let window, window.isVisible {
            alert.beginSheetModal(for: window) { response in completion?(response) }
        } else {
            completion?(alert.runModal())
        }
    }
}
