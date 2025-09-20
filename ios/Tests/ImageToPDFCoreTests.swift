import XCTest
@testable import ImageToPDFCore

final class ImageToPDFCoreTests: XCTestCase {
    func testReceiptInit() {
        let r = Receipt()
        XCTAssertNotNil(r.id)
    }
}

