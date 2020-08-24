import Foundation

// TODO probably has to be abstracted to include Nearby id too
protocol BleIdService {
    func id() -> BleId?
    func validate(bleId: BleId) -> Bool
}

class BleIdServiceImpl: BleIdService {
    private let crypto: Crypto
    private let json: Json
    private let sessionService: SessionService
    private let keyChain: KeyChain

    init(crypto: Crypto, json: Json, sessionService: SessionService, keyChain: KeyChain) {
        self.crypto = crypto
        self.json = json
        self.sessionService = sessionService
        self.keyChain = keyChain
    }

    func id() -> BleId? {
        let sessionDataRes: Result<MySessionData?, ServicesError> = keyChain.getDecodable(key: .mySessionData)
        switch sessionDataRes {
        case .success(let sessionData):
            if let sessionData = sessionData {
                return id(sessionData: sessionData)
            } else {
                // TODO handling
                log.e("Critical: there's no session data. Can't generate Ble id", .ble)
                return nil
            }
        case .failure(let e):
            // TODO handling
            log.e("Critical: couldn't retrieve my session data: (\(e)). Can't generate Ble id", .ble)
            return nil
        }
    }

    private func id(sessionData: MySessionData) -> BleId? {
        // Some data to be signed
        // We don't need this data directly: we're just interested in verifying the user, i.e. the signature
        // TODO actual random string. For now hardcoded for easier debugging.
        // this is anyway a temporary solution. We want to send encrypted (with peer's public key) json (with an index)
        let randomString = "randomString"

        // Create our signature
        let signature = crypto.sign(privateKey: sessionData.privateKey,
                                    payload: SessionSignedPayload(id: randomString))
        let signatureStr = String(data: signature, encoding: .utf8)!

        // The total data sent to participants: "data"(useless) with the corresponding signature
        let payload = SignedParticipantPayload(data: randomString, sig: signatureStr)
        let payloadStr = json.toJson(encodable: payload)
        return BleId(data: payloadStr.data(using: .utf8)!)
    }

    func validate(bleId: BleId) -> Bool {
        switch sessionService.currentSessionParticipants() {
        case .success(let participants):
            if let participants = participants {
                return validate(bleId: bleId, participants: participants)
            } else {
                log.e("Invalid state?: validating, but no current session. bleId: \(bleId)")
                return false
            }

        case .failure(let e):
            log.e("Error retrieving participants: \(e), returning validate = false")
            return false
        }
    }

    private func validate(bleId: BleId, participants: Participants) -> Bool {
        let dataStr = bleId.str()

        let signedParticipantPayload: SignedParticipantPayload = json.fromJson(json: dataStr)

        let randomData = signedParticipantPayload.data.data(using: .utf8)!
        let signData = signedParticipantPayload.sig.data(using: .utf8)!

        return participants.participants.contains { publicKey in
            crypto.validate(data: randomData, signature: signData, publicKey: publicKey)
        }
    }
}

struct SignedParticipantPayload: Encodable, Decodable {
    let data: String // random
    let sig: String
}
