import XCTest
@testable import TransFlex

final class ModelCatalogCacheTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("model-catalog-\(UUID().uuidString).json")
    }

    func testPutThenCachedReturnsFreshEntry() async {
        var now = Date(timeIntervalSince1970: 1_000_000)
        let cache = ModelCatalogCache(fileURL: tempURL(), now: { now })
        let models = [Model(id: "m", name: "M", supportsVision: false, source: .fetched)]
        await cache.put(models, for: "openai")
        now = now.addingTimeInterval(60)
        let cached = await cache.cached(for: "openai")
        XCTAssertEqual(cached, models)
    }

    func testExpiredEntryReturnsNil() async {
        var now = Date(timeIntervalSince1970: 2_000_000)
        let cache = ModelCatalogCache(fileURL: tempURL(), now: { now })
        await cache.put([Model(id: "m", name: "M", supportsVision: false, source: .fetched)], for: "openai")
        now = now.addingTimeInterval(24 * 3600 + 1)
        let cached = await cache.cached(for: "openai")
        XCTAssertNil(cached)
    }

    func testInvalidateRemovesEntry() async {
        let cache = ModelCatalogCache(fileURL: tempURL(), now: { Date() })
        await cache.put([Model(id: "m", name: "M", supportsVision: false, source: .fetched)], for: "openai")
        await cache.invalidate("openai")
        let cached = await cache.cached(for: "openai")
        XCTAssertNil(cached)
    }

    func testPersistsAcrossInstances() async {
        let url = tempURL()
        let now = Date(timeIntervalSince1970: 3_000_000)
        let first = ModelCatalogCache(fileURL: url, now: { now })
        let models = [Model(id: "m", name: "M", supportsVision: false, source: .fetched)]
        await first.put(models, for: "openai")

        let second = ModelCatalogCache(fileURL: url, now: { now.addingTimeInterval(60) })
        let cached = await second.cached(for: "openai")
        XCTAssertEqual(cached, models)
    }
}
