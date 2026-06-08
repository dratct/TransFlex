import XCTest

final class UserFacingEnglishTextTests: XCTestCase {
    func testAppSourceDoesNotContainVietnameseDiacritics() throws {
        let sourceRoot = try repositoryRoot().appendingPathComponent("TransFlex/Sources")
        let sourceFiles = try swiftSourceFiles(under: sourceRoot)
        let vietnamesePattern = #"[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ]"#
        let regex = try NSRegularExpression(pattern: vietnamesePattern)

        let offenders = try sourceFiles.compactMap { file -> String? in
            let content = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            guard regex.firstMatch(in: content, range: range) != nil else { return nil }
            return file.path.replacingOccurrences(of: sourceRoot.path + "/", with: "")
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "Vietnamese text found in app source files: \(offenders.joined(separator: ", "))"
        )
    }

    private func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "TransFlexTests" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                throw NSError(
                    domain: "UserFacingEnglishTextTests",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not locate TransFlexTests from \(#filePath)"]
                )
            }
            url = parent
        }
        return url.deletingLastPathComponent()
    }

    private func swiftSourceFiles(under root: URL) throws -> [URL] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys)
        )

        var files: [URL] = []
        while let file = enumerator?.nextObject() as? URL {
            let values = try file.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, file.pathExtension == "swift" else { continue }
            files.append(file)
        }
        return files
    }
}
