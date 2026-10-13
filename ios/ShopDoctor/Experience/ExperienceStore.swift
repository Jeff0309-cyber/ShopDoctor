import Foundation

/// On-device bits of the shop-experience check: which fixes are done, and the owner's photos
/// (kept locally so the fix plan can show the photo each issue came from).
enum ExperienceStore {
    private static var folder: URL {
        let dir = URL.applicationSupportDirectory.appending(path: "experience", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func savePhotos(_ photos: [Shot: Data]) {
        for shot in Shot.allCases { try? FileManager.default.removeItem(at: folder.appending(path: "\(shot.rawValue).jpg")) }
        for (shot, data) in photos { try? data.write(to: folder.appending(path: "\(shot.rawValue).jpg")) }
    }

    static func photo(_ shot: String) -> Data? {
        try? Data(contentsOf: folder.appending(path: "\(shot).jpg"))
    }

    // Done state is per audit, so a re-check starts a fresh plan.
    private static func key(_ audit: ExperienceAudit) -> String { "doneIssues-\(audit.generatedAt)" }

    static func done(for audit: ExperienceAudit) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(audit)) ?? [])
    }

    static func setDone(_ ids: Set<String>, for audit: ExperienceAudit) {
        UserDefaults.standard.set(Array(ids), forKey: key(audit))
    }
}
