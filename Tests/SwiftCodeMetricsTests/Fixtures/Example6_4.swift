func displayName(for user: User?) -> String {
    if let user, let nickname = user.nickname, !nickname.isEmpty {
        return nickname
    } else if let user {
        return user.fullName
    } else {
        return "Guest"
    }
}
