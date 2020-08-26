import Foundation
import SwiftUI
import Combine

class MeetingJoinedViewModel: ObservableObject {
    @Published var link: String = ""

    private let sessionService: CurrentSessionService
    private let clipboard: Clipboard
    private let uiNotifier: UINotifier

    private var sessionCancellable: Cancellable?

    init(sessionService: CurrentSessionService, clipboard: Clipboard, uiNotifier: UINotifier) {
        self.sessionService = sessionService
        self.clipboard = clipboard
        self.uiNotifier = uiNotifier

        sessionCancellable = sessionService.session.sink { [weak self] sharedSessionDataRes in
            switch sharedSessionDataRes {
            case .success(let sessionData):
                if let sessionData = sessionData {
                    self?.link = sessionData.id.createLink().value
                }
            case .failure(let e):
                // If there are issues retrieving session this screen normally shouldn't be presented
                let msg = "Couldn't retrieve session: \(e). NOTE: shouldn't happen in this screen."
                log.e(msg, .ui)
                uiNotifier.show(.error(msg))
            }
        }
    }

    func updateSession() {
        sessionService.refresh()
    }
}
