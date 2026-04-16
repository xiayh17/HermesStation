import Foundation

enum AppBuildInfo {
    static var versionLine: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "n/a"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "n/a"
        let builtAt = bundle.object(forInfoDictionaryKey: "HermesBuildTimestamp") as? String ?? "unknown build time"
        return "v\(version) (\(build)) · built \(builtAt)"
    }
}
