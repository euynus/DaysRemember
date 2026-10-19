import XCTest

extension XCUIApplication {
    /// Scrolls the content up in short drags until `element` can be tapped. A full swipe can carry a
    /// cell of a lazy grid (我的's categories) past the top, where it leaves the accessibility tree
    /// and can't be found again; short content-area drags also avoid Home's horizontal scrollers.
    func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 8) {
        for _ in 0..<attempts where !element.isHittable {
            let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    /// Taps where `element` is right now. Elements in another process's UI, such as the document
    /// picker, can vanish mid-transition; a tap through the element would then fail the test, while
    /// a tap at its last position is simply ignored and can be tried again. False if it was gone.
    @discardableResult
    func tapWhereItIs(_ element: XCUIElement) -> Bool {
        guard let frame = try? element.snapshot().frame, !frame.isEmpty else { return false }
        coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        return true
    }
}
