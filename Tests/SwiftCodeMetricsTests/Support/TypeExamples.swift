//
//  TypeExamples.swift
//  SwiftCodeMetricsTests
//
//  The sources of Spec §12.1–12.5, one module each. Each file imports
//  Foundation, as §12 assumes.
//

/// The worked examples' modules.
enum TypeExamples {
    /// §12.1: an extension in another file.
    static let shop: [(path: String, source: String)] = [
        ("Shop/Item.swift", """
        import Foundation
        struct Item { let name: String; let price: Decimal }
        """),
        ("Shop/Inventory.swift", """
        import Foundation
        struct Inventory {
            private(set) var items: [Item] = []
            var lastUpdated: Date?

            mutating func add(_ item: Item) {
                items.append(item)
                touch()
            }
            mutating func touch() {
                lastUpdated = Date()
            }
        }
        """),
        ("Shop/Inventory+Reporting.swift", """
        import Foundation
        extension Inventory: CustomStringConvertible {
            var totalPrice: Decimal {
                items.reduce(0) { $0 + $1.price }
            }
            var description: String {
                "Inventory(\\(items.count) items, \\(totalPrice))"
            }
            func isStale(after interval: TimeInterval) -> Bool {
                guard let lastUpdated else { return true }
                return Date().timeIntervalSince(lastUpdated) > interval
            }
        }
        """)
    ]

    /// §12.2: a type that splits into two cohesion groups.
    static let session: [(path: String, source: String)] = [
        ("Session.swift", """
        import Foundation
        final class SessionController {
            private var token: String?
            private var expiry: Date?
            private var recentSearches: [String] = []
            private let maxRecent = 10

            init() {}

            func signIn(token: String, validFor seconds: TimeInterval) {
                self.token = token
                expiry = Date().addingTimeInterval(seconds)
            }
            var isSignedIn: Bool {
                guard let expiry else { return false }
                return token != nil && expiry > Date()
            }
            func signOut() { token = nil; expiry = nil }

            func record(search: String) {
                recentSearches.insert(search, at: 0)
                trimRecent()
            }
            private func trimRecent() {
                if recentSearches.count > maxRecent {
                    recentSearches.removeLast(recentSearches.count - maxRecent)
                }
            }
            func clearSearches() { recentSearches.removeAll() }
        }
        """)
    ]

    /// §12.3: a struct whose methods use no stored properties.
    static let formatter: [(path: String, source: String)] = [
        ("PriceFormatter.swift", """
        import Foundation
        struct PriceFormatter {
            let currencyCode: String
            let locale: Locale

            func format(_ amount: Decimal) -> String {
                amount.formatted(.currency(code: "EUR"))
            }
            func formatRange(_ low: Decimal, _ high: Decimal) -> String {
                "\\(format(low)) – \\(format(high))"
            }
            static func rounded(_ amount: Decimal) -> Decimal {
                var value = amount
                var result = Decimal()
                NSDecimalRound(&result, &value, 2, .bankers)
                return result
            }
        }
        """)
    ]

    /// §12.4: a function using a singleton and globals.
    static let app: [(path: String, source: String)] = [
        ("App/Globals.swift", """
        import Foundation
        var requestCount = 0
        let defaultTimeout: TimeInterval = 30
        """),
        ("App/APIClient.swift", """
        import Foundation
        final class APIClient {
            static let shared = APIClient()
            static var verbose = false
            func send(_ request: URLRequest) async throws -> Data { Data() }
        }
        """),
        ("App/Endpoint.swift", """
        import Foundation
        enum Endpoint {
            case profile, settings
            var url: URL { URL(fileURLWithPath: "/") }
        }
        """),
        ("App/ProfileLoader.swift", """
        import Foundation
        struct Profile: Decodable { let name: String }

        struct ProfileLoader {
            func load(userID: String) async throws -> Profile {
                requestCount += 1
                var request = URLRequest(url: Endpoint.profile.url)
                request.timeoutInterval = defaultTimeout
                if APIClient.verbose { print("GET \\(request)") }
                let data = try await APIClient.shared.send(request)
                return try JSONDecoder().decode(Profile.self, from: data)
            }
        }
        """)
    ]

    /// §12.5: a protocol with a default implementation.
    static let shapes: [(path: String, source: String)] = [
        ("Shape.swift", """
        import Foundation
        protocol Shape {
            var area: Double { get }
            var name: String { get }
        }
        extension Shape {
            var summary: String { "\\(name): \\(area)" }
            func isLarger(than other: some Shape) -> Bool { area > other.area }
        }

        struct Circle: Shape {
            var radius: Double
            var area: Double { .pi * radius * radius }
            var name: String { "circle" }
            func scaled(by factor: Double) -> Circle { Circle(radius: radius * factor) }
            func describe() -> String { summary }
        }
        """)
    ]
}
