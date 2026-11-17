func shouldSyncA(_ item: Item, now: Date) -> Bool {
    if item.isDirty, item.isOnline || item.forceSync, let last = item.lastSync, now > last {
        return true
    }
    return false
}

func shouldSyncB(_ item: Item, now: Date) -> Bool {
    if item.isDirty, let last = item.lastSync, now > last, item.isOnline || item.forceSync {
        return true
    }
    return false
}
