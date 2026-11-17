func loadConfig(from url: URL, attempt: Int = 0) -> Config {
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    } catch let error as DecodingError where error.isRecoverable {
        return .fallback
    } catch is DecodingError, is CocoaError {
        return .default
    } catch {
        if attempt < 3 {
            return loadConfig(from: url, attempt: attempt + 1)
        }
        return .default
    }
}
