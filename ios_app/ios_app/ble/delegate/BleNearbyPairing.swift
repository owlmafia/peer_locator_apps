import CoreBluetooth
import Combine

// TODO write only to a validated peripheral! (uuid)
// it seems we need a new component, that uses BleDeviceValidatorService to check if peripheral
// is valid (and ready). Or we can do this directly here.
//
// TODO actually, we have to use validated peripheral everywhere, as we of course can detect more than one peripheral
// (everyone using the app)
// --> ensure that we're reading and writing to our peer's peripheral
// TODO confirm too that we can detect only one validated peripheral at a time.
// Note that during normal operation, we will be reading from _all_ nearby users of the app, until a validation
// succeeds (we find our peer) -> TODO ensure this doesn't cause problems (validation is expensive: how many devices
// max can we support? we should expose the session id in clear text and validate only if session id matches.
// note that this allows observers to detect who belongs together. TODO clarify about using variable characteristic and service uuid
// if this is possible we can use this instead of session id,
// it would be a bit more difficult to track for others as they can't use the service uuid to identify our app.
// so a given pair would have the same service/char uuid but this could be _any_ service, so it _should_ (?) be more
// difficult to track.
// keep in mind nonce also: if we don't encrypt, where would it be? if we encrypt, what's there to encrypt if
// the session id has to be plain text? should we add a (clear text) random number nonce to the clear text (session id)?


/*
 * Writes the Nearby discovery token to peer.
 * If both devices support Nearby, a session will be created, by each writing its discovery token to the peer.
 * If a device doesn't support Nearby, it just does nothing (don't write the token)
 * This way a session isn't established, so there's no nearby measurements and we stay with ble.
 */
protocol NearbyPairing {
    var token: AnyPublisher<SerializedSignedNearbyToken, Never> { get }
    
    func sendDiscoveryToken(token: SerializedSignedNearbyToken)
}

class BleNearbyPairing: NearbyPairing {
    private let tokenSubject = CurrentValueSubject<SerializedSignedNearbyToken?, Never>(nil)
    lazy var token = tokenSubject.compactMap{ $0 }.eraseToAnyPublisher()

    private let characteristicUuid = CBUUID(string: "0be778a3-2096-46c8-82c9-3a9d63376513")

    private var peripheral: CBPeripheral?

    private var discoveredCharacteristic: CBCharacteristic?

    func sendDiscoveryToken(token: SerializedSignedNearbyToken) {
        guard let peripheral = peripheral else {
            log.e("Attempted to write, but peripheral is not set.", .ble)
            return
        }
        guard let characteristic = discoveredCharacteristic else {
            log.e("Attempted to write, but nearby characteristic is not set.", .ble)
            return
        }
        peripheral.writeValue(token.data, for: characteristic, type: .withResponse)
    }
}

extension BleNearbyPairing: BlePeripheralDelegateWriteOnly {

    var characteristic: CBMutableCharacteristic {
        CBMutableCharacteristic(
            type: characteristicUuid,
            properties: [.write],
            value: nil,
            // TODO what is .writeEncryptionRequired / .readEncryptionRequired? does it help us?
            permissions: [.writeable]
        )
    }

    func handleWrite(data: Data) {
        tokenSubject.send(SerializedSignedNearbyToken(data: data))
    }
}

extension BleNearbyPairing: BleCentralDelegate {

    func onDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        self.peripheral = peripheral
    }

    func onDiscoverCaracteristics(_ characteristics: [CBCharacteristic], peripheral: CBPeripheral,
                                  error: Error?) -> Bool {
        if let discoveredCharacteristic = characteristics.first(where: {
            $0.uuid == characteristicUuid
        }) {
            log.d("Setting the nearby characteristic", .ble)
            self.discoveredCharacteristic = discoveredCharacteristic
            return true

        } else {
            log.e("Service doesn't have nearby characteristic.", .ble)
            return false
        }
    }

    func onReadCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral, error: Error?) -> Bool {
        if characteristic.uuid == characteristicUuid {
            fatalError("We don't read nearby characteristic")
        }
        return false
    }
}
