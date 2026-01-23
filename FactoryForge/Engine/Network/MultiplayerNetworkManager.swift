import Foundation
import Network

/// Manages client–server connection and protocol messages for authoritative multiplayer.
/// Separate from GameNetworkManager (MCP/debug). Uses Network.framework.
final class MultiplayerNetworkManager {
    private var connection: NWConnection?
    private var listener: NWListener?
    private(set) var isConnected = false
    private let queue = DispatchQueue(label: "com.factoryforge.multiplayer", qos: .userInitiated)
    private var receiveBuffer = Data()
    private let messageLengthPrefixBytes = 4

    /// Callbacks
    var onConnected: (() -> Void)?
    var onDisconnected: ((Error?) -> Void)?
    var onMessage: ((NetworkMessage) -> Void)?

    /// When set, send() uses this instead of the real connection. Harness wires peer's simulator.onDelivered to handleSimulatedInbound(_:).
    var simulatedOutbound: NetworkSimulator?

    // MARK: - Client: connect to server

    func connect(to host: String, port: UInt16) {
        disconnect()
        let endpoint = NWEndpoint.Host(host)
        let port = NWEndpoint.Port(integerLiteral: port)
        let conn = NWConnection(host: endpoint, port: port, using: .tcp)
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state, connection: conn)
        }
        conn.start(queue: queue)
        startReceive(on: conn)
    }

    // MARK: - Server: listen for clients

    func listen(port: UInt16) {
        stopListening()
        let params = NWParameters.tcp
        guard let listen = try? NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port)) else {
            return
        }
        listener = listen
        listen.newConnectionHandler = { [weak self] conn in
            self?.connection?.cancel()
            self?.connection = conn
            conn.stateUpdateHandler = { [weak self] state in
                self?.handleConnectionState(state, connection: conn)
            }
            conn.start(queue: self?.queue ?? .main)
            self?.startReceive(on: conn)
        }
        listen.start(queue: queue)
    }

    func stopListening() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Send / receive

    func send(_ message: NetworkMessage) {
        do {
            let data = try JSONEncoder().encode(message)
            var length = UInt32(data.count).bigEndian
            var payload = Data(bytes: &length, count: messageLengthPrefixBytes)
            payload.append(data)
            if let sim = simulatedOutbound {
                sim.send(payload)
                return
            }
            guard let conn = connection, isConnected else { return }
            conn.send(content: payload, completion: .contentProcessed { [weak self] err in
                if let e = err { self?.onDisconnected?(e) }
            })
        } catch {
            onDisconnected?(error)
        }
    }

    /// Handle data delivered by NetworkSimulator (harness). Same length-prefix format as wire.
    func handleSimulatedInbound(_ data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.receiveBuffer.append(data)
            self.drainReceivedMessages()
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        receiveBuffer.removeAll()
    }

    // MARK: - Private

    private func handleConnectionState(_ state: NWConnection.State, connection: NWConnection) {
        switch state {
        case .ready:
            isConnected = true
            DispatchQueue.main.async { [weak self] in self?.onConnected?() }
        case .failed(let err):
            isConnected = false
            DispatchQueue.main.async { [weak self] in self?.onDisconnected?(err) }
        case .cancelled:
            isConnected = false
            DispatchQueue.main.async { [weak self] in self?.onDisconnected?(nil) }
        default:
            break
        }
    }

    private func startReceive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, isComplete, err in
            guard let self = self else { return }
            if let e = err {
                DispatchQueue.main.async { self.onDisconnected?(e) }
                return
            }
            if let d = data, !d.isEmpty {
                self.receiveBuffer.append(d)
                self.drainReceivedMessages()
            }
            if !isComplete, self.connection != nil {
                self.startReceive(on: conn)
            }
        }
    }

    private func drainReceivedMessages() {
        while receiveBuffer.count >= messageLengthPrefixBytes {
            let len = receiveBuffer.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let total = messageLengthPrefixBytes + Int(len)
            guard total <= 1 << 20, receiveBuffer.count >= total else { break }
            let payload = receiveBuffer.subdata(in: messageLengthPrefixBytes ..< total)
            receiveBuffer.removeFirst(total)
            if let msg = try? JSONDecoder().decode(NetworkMessage.self, from: payload) {
                DispatchQueue.main.async { [weak self] in self?.onMessage?(msg) }
            }
        }
    }
}
