import Foundation

enum NCOMProgramBootstrap {
    static let start: Void = {
        NCOMBackgroundProgramScheduler.register()
    }()
}
