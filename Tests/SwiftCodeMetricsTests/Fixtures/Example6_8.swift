func verifiedEmails(in teams: [Team]) -> [String] {
    teams
        .filter { $0.isActive }
        .flatMap { team in
            team.members.compactMap { member in
                guard member.isVerified else { return nil }
                return member.email.isEmpty ? nil : member.email
            }
        }
        .sorted { $0.lowercased() < $1.lowercased() }
}
