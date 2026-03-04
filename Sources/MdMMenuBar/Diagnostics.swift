enum Diagnostics {
    #if DEBUG
    static let verboseEventLogging = true
    #else
    static let verboseEventLogging = false
    #endif
}
