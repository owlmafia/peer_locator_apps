import Foundation
import Dip

protocol ViewModelProvider {
    func session() -> PairingTypeViewModel
    func root() -> RootViewModel
    func settings() -> SettingsViewModel

    func colocatedPairingRole() -> ColocatedPairingRoleSelectionViewModel
    func colocatedPairingJoiner() -> ColocatedPairingJoinerViewModel
    func colocatedPassword() -> ColocatedPairingPasswordViewModel

    func remotePairingRole() -> RemotePairingRoleSelectionViewModel
    func meetingCreated() -> MeetingCreatedViewModel
    func meetingJoined() -> MeetingJoinedViewModel
    func meetingJoiner() -> RemotePairingJoinerViewModel

    func meeting() -> MeetingViewModel
}

class Dependencies {
    func createContainer() -> DependencyContainer {

        let container = DependencyContainer()

        registerCore(container: container)
        registerSystem(container: container)
        registerBle(container: container)
        registerServices(container: container)
        registerViewModels(container: container)
        registerWatch(container: container)
        registerAccessibility(container: container)

        // Throws if components fail to instantiate
        try! container.bootstrap()

        return container
    }

    private func registerCore(container: DependencyContainer) {
        let core = CoreImpl()
        let res = core.bootstrap()
        if res.isFailure() {
            fatalError("CRITICAL: Couldn't initialize core: \(res)")
        }
        container.register(.singleton) { core as SessionApi }
    }

    private func registerSystem(container: DependencyContainer) {
        container.register(.singleton) { PreferencesImpl() as Preferences }
        container.register(.singleton) { KeyChainImpl(json: try container.resolve()) as KeyChain }
        container.register(.singleton) { JsonImpl() as Json }
        container.register(.singleton) { CryptoImpl() as Crypto }
        container.register(.singleton) { ClipboardImpl() as Clipboard }
        container.register(.singleton) { UINotifierImpl() as UINotifier }
        container.register(.singleton) { DeeplinkHandlerImpl(
            sessionManager: try container.resolve(),
            colocatedPasswordService: try container.resolve()
        ) as DeeplinkHandler }
        container.register(.singleton) { SettingsShowerImpl() as SettingsShower }
    }

    private func registerBle(container: DependencyContainer) {

        container.register(.singleton) { BleIdServiceImpl(
            crypto: try container.resolve(),
            json: try container.resolve(),
            sessionService: try container.resolve(),
            keyChain: try container.resolve()
        ) as BleIdService }

        #if arch(x86_64)
        container.register(.eagerSingleton) { SimulatorBleManager() as BleManager }
        let multipeerTokenService = container.register(.eagerSingleton) {
            MultipeerTokenServiceImpl()
        }
        container.register(multipeerTokenService, type: NearbyTokenReceiver.self)
        container.register(multipeerTokenService, type: NearbyTokenSender.self)
        container.register(.singleton) { SimulatorBleEnabledServiceImpl() as BleEnabledService }
        #else
        container.register(.eagerSingleton) { BleCentralImpl(idService: try container.resolve()) as BleCentral }

        let peripheral = container.register(.eagerSingleton) {
            BlePeripheralImpl(idService: try container.resolve()) as BlePeripheral
        }
        let bleManager = container.register(.eagerSingleton) { BleManagerImpl(
            peripheral: try container.resolve(),
            central: try container.resolve()
        ) as BleManager }

        // TODO check that these are actually singletons
        // see https://github.com/AliSoftware/Dip/wiki/type-forwarding
        // and https://github.com/AliSoftware/Dip/issues/196
        container.register(peripheral, type: NearbyTokenReceiver.self)
        container.register(peripheral, type: ColocatedPublicKeyReceiver.self)
        container.register(bleManager, type: NearbyTokenSender.self)

        container.register(.singleton) {
            BleEnabledServiceImpl(bleCentral: try container.resolve()) as BleEnabledService
        }
        container.register(.eagerSingleton) {
            BleRestarterWhenAppComesToFgImpl(bleCentral: try container.resolve()) as BleRestarterWhenAppComesToFg
        }
        #endif
    }

    private func registerServices(container: DependencyContainer) {
        container.register(.singleton) { MultipeerTokenServiceImpl() }

        container.register(.eagerSingleton) { NearbyImpl() as Nearby }
        container.register(.eagerSingleton) { PeerForWidgetRecorderImpl(
            peerService: try container.resolve(),
            preferences: try container.resolve(),
            json: try container.resolve()
        ) as PeerForWidgetRecorder }

        container.register(.eagerSingleton) { NearbySessionCoordinatorImpl(
            bleManager: try container.resolve(),
            bleIdService: try container.resolve(),
            nearby: try container.resolve(),
            nearbyTokenSender: try container.resolve(),
            nearbyTokenReceiver: try container.resolve(),
            keychain: try container.resolve(),
            uiNotifier: try container.resolve(),
            sessionService: try container.resolve(),
            tokenProcessor: try container.resolve()
        ) as NearbySessionCoordinator }

        container.register(.eagerSingleton) { PeerServiceImpl(nearby: try container.resolve(),
                                             bleManager: try container.resolve(),
                                             bleIdService: try container.resolve()) as PeerService }
        container.register(.singleton) { NotificationServiceImpl() as NotificationService }
        container.register(.singleton) { NotificationPermissionImpl() as NotificationPermission }
        container.register(.eagerSingleton) { NotificationsDelegate() }
        container.register(.eagerSingleton) { PeerDistanceNotificationService(
            peerService: try container.resolve(),
            notificationService: try container.resolve()
        )}
        container.register(.singleton) { SessionServiceImpl(
            sessionApi: try container.resolve(),
            crypto: try container.resolve(),
            keyChain: try container.resolve()
        ) as SessionService }
        container.register(.eagerSingleton) { P2pServiceImpl(bleManager: try container.resolve(),
                                                             sessionService: try container.resolve()) as P2pService }
        container.register(.singleton) {
            CurrentSessionServiceImpl(sessionService: try container.resolve(),
                                      uiNotifier: try container.resolve()) as CurrentSessionService
        }
        container.register(.singleton) {
            NearbyTokenProcessorImpl(
                crypto: try container.resolve(),
                json: try container.resolve()
            ) as NearbyTokenProcessor
        }
//        container.register(.eagerSingleton) {
//            CloseSessionServiceImpl(
//                bleCentral: try container.resolve(),
//                keyChain: try container.resolve()
//            ) as CloseSessionService }

        container.register(.singleton) {
            RemoteSessionManagerImpl(
                sessionService: try container.resolve(),
                currentSessionService: try container.resolve()
            ) as RemoteSessionManager }

        container.register(.singleton) { ColocatedPairingPasswordServiceImpl() as ColocatedPairingPasswordService }
        container.register(.singleton) { ColocatedPasswordProviderImpl() as ColocatedPasswordProvider }
        container.register(.singleton) { ColocatedSessionServiceImpl(
            bleCentral: try container.resolve(),
            peerKeyReceiver: try container.resolve(),
            keyChain: try container.resolve(),
            passwordProvider: try container.resolve(),
            passwordService: try container.resolve(),
            crypto: try container.resolve(),
            uiNotifier: try container.resolve(),
            sessionService: try container.resolve(),
            bleManager: try container.resolve()
        ) as ColocatedSessionService }
    }

    private func registerViewModels(container: DependencyContainer) {
        container.register { MeetingViewModel(peerService: try container.resolve(),
                                              sessionService: try container.resolve(),
                                              settingsShower: try container.resolve(),
                                              bleEnabledService: try container.resolve()) }
        container.register { PairingTypeViewModel(settingsShower: try container.resolve()) }
        container.register { RootViewModel(sessionService: try container.resolve(),
                                           uiNotifier: try container.resolve(),
                                           settingsShower: try container.resolve()) }
        container.register { MeetingCreatedViewModel(sessionManager: try container.resolve(),
                                                     sessionService: try container.resolve(),
                                                     clipboard: try container.resolve(),
                                                     uiNotifier: try container.resolve(),
                                                     settingsShower: try container.resolve()) }
        container.register { MeetingJoinedViewModel(sessionManager: try container.resolve(),
                                                    sessionService: try container.resolve(),
                                                    clipboard: try container.resolve(),
                                                    uiNotifier: try container.resolve(),
                                                    settingsShower: try container.resolve()) }
        container.register { SettingsViewModel() }
        container.register { ColocatedPairingRoleSelectionViewModel(sessionService: try container.resolve()) }
        container.register { ColocatedPairingPasswordViewModel(sessionService: try container.resolve()) }
        container.register { ColocatedPairingJoinerViewModel(passwordService: try container.resolve(),
                                                             uiNotifier: try container.resolve()) }
        container.register { RemotePairingRoleSelectionViewModel(
            remoteSessionManager: try container.resolve(),
            sessionService: try container.resolve(),
            uiNotifier: try container.resolve())
        }
        container.register { RemotePairingJoinerViewModel(
            sessionManager: try container.resolve(),
            sessionService: try container.resolve(),
            clipboard: try container.resolve(),
            uiNotifier: try container.resolve(),
            settingsShower: try container.resolve())
        }
    }

    private func registerWatch(container: DependencyContainer) {
        container.register(.eagerSingleton) { ConnectivityHandler() as WatchBridge }
        container.register(.eagerSingleton) { WatchEventsForwarderImpl(
            sessionService: try container.resolve(),
            watchBridge: try container.resolve(),
            peerService: try container.resolve()) as WatchEventsForwarder }
    }

    private func registerAccessibility(container: DependencyContainer) {
        container.register(.singleton) { VoiceImpl() as Voice }
//        container.register(.eagerSingleton) { LocationVoiceImpl(peerService: try container.resolve(),
//                                                                voice: try container.resolve()) as LocationVoice }
        container.register(.singleton) { SoundPlayerImpl() as SoundPlayer }
        container.register(.eagerSingleton) { PeerSoundsImpl(peerService: try container.resolve(),
                                                             soundPlayer: try container.resolve()) as PeerSounds }
    }
}

extension DependencyContainer: ViewModelProvider {

    func meeting() -> MeetingViewModel {
        try! resolve()
    }

    func session() -> PairingTypeViewModel {
        try! resolve()
    }

    func root() -> RootViewModel {
        try! resolve()
    }

    func meetingCreated() -> MeetingCreatedViewModel {
        try! resolve()
    }

    func meetingJoined() -> MeetingJoinedViewModel {
        try! resolve()
    }

    func settings() -> SettingsViewModel {
        try! resolve()
    }

    func colocatedPairingRole() -> ColocatedPairingRoleSelectionViewModel {
        try! resolve()
    }

    func colocatedPassword() -> ColocatedPairingPasswordViewModel {
        try! resolve()
    }

    func colocatedPairingJoiner() -> ColocatedPairingJoinerViewModel {
        try! resolve()
    }

    func remotePairingRole() -> RemotePairingRoleSelectionViewModel {
        try! resolve()
    }

    func meetingJoiner() -> RemotePairingJoinerViewModel {
        try! resolve()
    }
}
