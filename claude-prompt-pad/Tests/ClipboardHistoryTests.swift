import XCTest
@testable import ClipboardHistoryKit

@MainActor
final class ClipboardHistoryTests: XCTestCase {

    func test_add_appendsItem() {
        let history = ClipboardHistory()
        history.add("hello")
        XCTAssertEqual(history.items, ["hello"])
    }

    func test_add_prependsNewest() {
        let history = ClipboardHistory()
        history.add("first")
        history.add("second")
        XCTAssertEqual(history.items, ["second", "first"])
    }

    func test_add_trimsToMaxCount() {
        let history = ClipboardHistory()
        for i in 1...11 {
            history.add("item \(i)")
        }
        XCTAssertEqual(history.items.count, 10)
        XCTAssertEqual(history.items.first, "item 11")
        XCTAssertFalse(history.items.contains("item 1"))
    }

    func test_add_deduplicatesAndMovesToFront() {
        let history = ClipboardHistory()
        history.add("hello")
        history.add("world")
        history.add("hello")
        XCTAssertEqual(history.items, ["hello", "world"])
    }

    func test_add_ignoresEmptyString() {
        let history = ClipboardHistory()
        history.add("")
        history.add("   ")
        XCTAssertTrue(history.items.isEmpty)
    }
}
