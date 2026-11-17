func canEdit(_ user: User, _ document: Document) -> Bool {
    if user.isBanned { return false }
    return user.isAdmin
        || document.ownerID == user.id && !document.isLocked
        || document.isShared && !(user.isGuest || document.isArchived)
}
