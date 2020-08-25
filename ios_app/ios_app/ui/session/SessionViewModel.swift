import Foundation
import Combine
import SwiftUI

class SessionViewModel: ObservableObject {
    private let sessionService: CurrentSessionService
    private let p2pService: P2pService
    private let clipboard: Clipboard

    @Published var createdSessionLink: String = ""
    @Published var sessionStartedMessage: String = ""
    @Published var sessionLinkInput: String = ""

    private var sessionCancellable: AnyCancellable?

    init(sessionService: CurrentSessionService, p2pService: P2pService, clipboard: Clipboard) {
        self.sessionService = sessionService
        self.p2pService = p2pService
        self.clipboard = clipboard

        sessionCancellable = sessionService.session
            .sink(receiveCompletion: { completion in }) { [weak self] sessionRes in
                switch sessionRes {
                case .success(let session):
                    self?.createdSessionLink = session?.id.createLink().value ?? ""
                case .failure(let e):
                    // TODO handle
                    log.e("Current session error: \(e)")
                }
        }
    }

    func createSession() {
        sessionService.create()
    }

    func joinSession() {
        guard !sessionLinkInput.isEmpty else {
            log.e("Session link is empty. Nothing to join", .session)
            // TODO this state should be impossible: if there's no link in input, don't allow to press join
            return
            // TODO failable SessionLink initializer
        }
        sessionService.join(link: SessionLink(value: sessionLinkInput))
    }

    // TODO call when opening the screen, maybe also pull to refresh "update participants status..."
    // show a progress indicator when checking, next to the sessions status label
    // maybe also button? "is the session ready?" with
    // text yes: "all the participants are connected and ready to meet", no: "not all participants are ready"
    func refreshSessionData() {
        sessionService.refresh()
    }

    func onCopyLinkTap() {
        // TODO check that link isn't empty
        clipboard.putInClipboard(text: createdSessionLink)
        // TODO notification
        log.d("Copied link to clipboard: \(createdSessionLink)", .ui)
    }

    func onPasteLinkTap() {
        sessionLinkInput = clipboard.getFromClipboard()
    }

    func activateSession() {
        p2pService.activateSession()
    }
}
