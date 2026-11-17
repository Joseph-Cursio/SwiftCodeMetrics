func defaultLevel(verbose: Bool) -> LogLevel {
    #if DEBUG
    if verbose { return .trace }
    return .debug
    #else
    if verbose { return .info }
    return .warning
    #endif
}
