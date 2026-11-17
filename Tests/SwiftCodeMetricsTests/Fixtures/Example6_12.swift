func refresh() async {
    async let profile = api.fetchProfile()
    async let feed = api.fetchFeed()
    do {
        let (newProfile, newFeed) = try await (profile, feed)
        self.profile = newProfile
        self.feed = newFeed.filter { !$0.isHidden }
    } catch {
        Task { @MainActor in
            if self.isVisible {
                self.showError(error)
            }
        }
    }
}
