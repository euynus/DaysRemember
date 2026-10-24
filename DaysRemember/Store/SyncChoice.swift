import Foundation

/// Whether this device syncs with iCloud, chosen on onboarding and changed in 数据与同步. Each
/// device decides for itself: it is never synced.
enum SyncChoice: String {
    case iCloud
    case localOnly
}
