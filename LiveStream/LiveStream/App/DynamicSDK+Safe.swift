import DynamicSDKSwift

extension DynamicSDK {
    /// Safe accessor — throws a descriptive error if the SDK was not initialized yet.
    static var shared: DynamicSDK {
        get throws { try getInstance() }
    }
}
