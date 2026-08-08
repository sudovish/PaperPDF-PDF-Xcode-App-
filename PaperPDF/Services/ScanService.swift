import Foundation

final class ScanService {
    var scannerAvailableMessage: String {
        #if targetEnvironment(simulator)
        return "Document scanning requires a real iPhone camera. Import a PDF or image in Simulator."
        #else
        return "Scanner available."
        #endif
    }
}
