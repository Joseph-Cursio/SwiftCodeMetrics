func validate(_ form: SignUpForm) throws -> Account {
    guard let name = form.name, !name.isEmpty else {
        throw ValidationError.missingName
    }
    guard let email = form.email, email.contains("@") else {
        throw ValidationError.invalidEmail
    }
    guard form.age >= 18 || form.hasGuardianConsent else {
        throw ValidationError.underage
    }
    return Account(name: name, email: email)
}
