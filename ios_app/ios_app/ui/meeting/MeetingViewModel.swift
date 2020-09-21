import Foundation
import Combine
import SwiftUI

enum MeetingMainViewContent {
    case enableBle, connected, unavailable
}

class MeetingViewModel: ObservableObject {
    @Published var distance: String = ""
    @Published var directionAngle: Angle = Angle(radians: 0)
    @Published var mainViewContent: MeetingMainViewContent = .connected

    private var peerCancellable: AnyCancellable?
    private var bleEnabledCancellable: AnyCancellable?

    private let sessionManager: RemoteSessionManager
    private let settingsShower: SettingsShower
    private let bleEnabler: BleEnabler
    private let bleManager: BleManager

    init(peerService: DetectedPeerService, sessionManager: RemoteSessionManager, settingsShower: SettingsShower,
         bleEnabler: BleEnabler, bleState: BleStateObservable, bleManager: BleManager) {
        self.sessionManager = sessionManager
        self.settingsShower = settingsShower
        self.bleEnabler = bleEnabler
        self.bleManager = bleManager

        peerCancellable = peerService.peer.sink { [weak self] peer in
            self?.handlePeer(peerMaybe: peer)
        }

        // TODO test that state updates corrently when ble disabled, enabled, open again...
        bleEnabledCancellable = bleState.bleEnabled.sink { [weak self] enabled in
            self?.mainViewContent = enabled ? .connected : .enableBle
        }
    }

    private func handlePeer(peerMaybe: DetectedPeer?) {
        if let peer = peerMaybe {
            let formattedDistance = peer.dist.flatMap { NumberFormatters.oneDecimal.string(from: $0) }
            // TODO is "?" ok for missing distance? when can this happen? should fallback to bluetooth
            distance = formattedDistance.map { "\($0)m" } ?? "?"
            if let dir = peer.dir {
                directionAngle.radians = toAngle(dir: dir)
            }
            mainViewContent = .connected
        } else {
            mainViewContent = .unavailable
        }
    }

    func deleteSession() {
        sessionManager.delete()
    }

    func onSettingsButtonTap() {
        settingsShower.show()
    }

    func requestEnableBle() {
        bleEnabler.showEnableDialogIfDisabled()
        // Try to start immediately. If ble is not enabled, showEnableDialogIfDisabled will show the enable dialog,
        // and when app comes to fg again, ActivateBleWhenAppComesToFg will try to start again.
        bleManager.start()

    }
}

struct BleIdRow: Identifiable {
    let id: UUID
    let bleId: BleId
}

// TODO use the toAngle() extension on Direction and adjust result for iOS coords
private func toAngle(dir: Direction) -> Double {
    // "normal" formula to get angle from x, y (only for positive quadrant): atan(dir.y / dir.x)
    // additions:
    // atan needs adjustment for negative quadrants (x or y < 0)
    // + (Double.pi / 2): iOS coordinate system adjustment
    // -dir.y: iOS coordinate system adjustment
    let res = Double(atan(-dir.y / dir.x)) + (Double.pi / 2)
    if dir.x < 0 {
        return res + Double.pi
    } else if dir.y < 0 {
        return res + (Double.pi * 2)
    } else {
        return res
    }
}
