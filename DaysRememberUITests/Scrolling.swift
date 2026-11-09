import XCTest

extension XCUIApplication {
    /// Scrolls the content up in short drags until `element` can be tapped clear of the screen's
    /// bottom edge. A full swipe can carry a cell of a lazy grid (我的's categories) past the top,
    /// where it leaves the accessibility tree and can't be found again; short content-area drags
    /// also avoid Home's horizontal scrollers.
    func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 8) {
        for _ in 0..<attempts where !isClearOfBottomEdge(element) {
            let start = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.48))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    /// Hittable, with its centre at least 60 points above the bottom of the screen. An element whose
    /// top only just shows there counts as hittable, but the tap lands on the Home indicator and
    /// never reaches it: on iOS 26.5, the category editor left 删除分类's top 3 points showing, and a
    /// tap at y 872 of 874 opened nothing. (`isHittable` comes first: reading `frame` of an element
    /// that doesn't exist fails the test.)
    private func isClearOfBottomEdge(_ element: XCUIElement) -> Bool {
        element.isHittable && element.frame.midY <= frame.maxY - 60
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
