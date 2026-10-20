import Foundation

extension Data {
    /// Equal bytes, decided without reading them when both values share one buffer, as an
    /// unchanged day's photo does.
    func hasSameBytes(as other: Data) -> Bool {
        guard count == other.count else { return false }
        let sameBuffer = withUnsafeBytes { lhs in other.withUnsafeBytes { rhs in lhs.baseAddress == rhs.baseAddress } }
        return sameBuffer || self == other
    }
}
