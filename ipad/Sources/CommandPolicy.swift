import Foundation

enum CommandPolicy {
    static let origin = "https://www.houseofpizzagaffney.com"
    static let methods: Set<String> = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"]
    static func apiURL(_ value: String, method: String) -> URL? {
        guard methods.contains(method), let url = URL(string: value),
              url.scheme == "https", url.host == "www.houseofpizzagaffney.com",
              url.port == nil || url.port == 443,
              url.user == nil, url.password == nil, url.fragment == nil,
              url.path.hasPrefix("/api/"), !url.path.contains("\\"),
              !url.path.split(separator: "/").contains(".."),
              let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath,
              !encoded.contains("%") else { return nil }
        return url
    }
    static func externalURL(_ value: String) -> URL? {
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(),
              ["https", "tel", "mailto"].contains(scheme), url.user == nil, url.password == nil else { return nil }
        return url
    }
    static func exportName(_ value: String) -> String? {
        let name = String(value.prefix(150)).replacingOccurrences(of: "[^A-Za-z0-9 ._-]", with: "-", options: .regularExpression)
        guard !name.hasPrefix("."), !name.contains(".."), ["png", "csv", "pdf"].contains(URL(fileURLWithPath: name).pathExtension.lowercased()) else { return nil }
        return name
    }
    static func isBundledPage(_ url: URL?, root: URL) -> Bool {
        guard let url, url.isFileURL else { return false }
        return url.standardizedFileURL.path == root.appendingPathComponent("index.html").standardizedFileURL.path
    }
}
