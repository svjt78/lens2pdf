import SwiftUI

struct VisionScannerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController

    let completion: (Result<CaptureResult, Error>) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        context.coordinator.makeCaptureViewController(completion: completion)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private let captureCoordinator = VisionCaptureCoordinator()

        func makeCaptureViewController(completion: @escaping (Result<CaptureResult, Error>) -> Void) -> UIViewController {
            captureCoordinator.makeViewController { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
}

