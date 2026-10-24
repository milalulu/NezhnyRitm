import Foundation

struct Repository {
    let url: URL
    static var live: Repository {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NezhnyRitm", isDirectory: true)
        return Repository(url: folder.appendingPathComponent("journal.json"))
    }
    func load() throws -> AppData {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppData() }
        return try Self.decode(Data(contentsOf: url))
    }
    static func decode(_ bytes: Data) throws -> AppData {
        guard bytes.count <= 100_000_000 else { throw DataError.tooLarge }
        return try JSONDecoder().decode(AppData.self, from: bytes).validated()
    }
    static func encode(_ data: AppData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(data)
    }
    func save(_ data: AppData) throws {
        let bytes = try Self.encode(data.validated())
        guard bytes.count <= 100_000_000 else { throw DataError.tooLarge }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var directory = url.deletingLastPathComponent()
        var resource = URLResourceValues()
        resource.isExcludedFromBackup = false
        try? directory.setResourceValues(resource)
    }
    func safetyCopy() throws -> URL? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let copy = url.deletingLastPathComponent().appendingPathComponent("before-import-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }
}
