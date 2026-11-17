func label(for status: Subscription.Status) -> String {
    switch status {
    case .active, .trial:
        return "Active"
    case .suspended(let reason) where reason == .payment:
        return "Payment due"
    case .suspended:
        return "Suspended"
    case .cancelled, .expired:
        return "Ended"
    }
}
