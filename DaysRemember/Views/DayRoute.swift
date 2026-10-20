/// Navigation value for a day's detail. Routing by ID keeps photo bytes out of the
/// path's hashing and lets the detail read the live record.
struct DayRoute: Hashable {
    let id: String
}
