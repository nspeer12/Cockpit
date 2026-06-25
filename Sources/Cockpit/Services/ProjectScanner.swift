import Foundation

struct Project: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let status: String
    let lastModified: Date

    init(name: String, path: String, status: String, lastModified: Date) {
        self.id = path
        self.name = name
        self.path = path
        self.status = status
        self.lastModified = lastModified
    }
}

enum ProjectScanner {
    static let defaultProjectsPath = "/Users/nickspeer/Desktop/Hermes-Projects"

    static func scanProjects(at rootPath: String = defaultProjectsPath) -> [Project] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: rootPath) else {
            return []
        }

        return contents
            .filter { item in
                var isDirectory: ObjCBool = false
                let fullPath = rootPath + "/" + item
                return fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue
            }
            .sorted()
            .map { folder in
                let fullPath = rootPath + "/" + folder
                return Project(
                    name: folder,
                    path: fullPath,
                    status: gitStatus(for: fullPath),
                    lastModified: lastModified(for: fullPath)
                )
            }
    }

    static func gitStatus(for path: String) -> String {
        guard FileManager.default.fileExists(atPath: path + "/.git") else {
            return "No Git"
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path, "status", "--porcelain"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return "Git Error"
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Clean" : "Modified"
        } catch {
            return "Git Error"
        }
    }

    static func lastModified(for path: String) -> Date {
        let url = URL(fileURLWithPath: path)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date ?? Date.distantPast
        } catch {
            return Date.distantPast
        }
    }
}
