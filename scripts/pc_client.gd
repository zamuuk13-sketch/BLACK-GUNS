extends Node
class_name BlackGunsPCClient

signal connection_state_changed(connected: bool, message: String)
signal server_packet_received(packet: Dictionary)

const PROTOCOL := "BLACK_GUNS_VR"
const VERSION := 1
const TCP_PORT := 39100
const DISCOVERY_PORT := 39101
const DISCOVERY_MESSAGE := "BLACK_GUNS_DISCOVER"

var tcp := StreamPeerTCP.new()
var discovery := PacketPeerUDP.new()
var connected := false
var connecting := false
var discovered_host := ""
var discovered_port := TCP_PORT
var buffer := ""

func _process(_delta: float) -> void:
    _poll_tcp()
    _poll_discovery()

func discover_pc() -> bool:
    discovery.close()
    var err := discovery.bind(0)
    if err != OK:
        return false
    discovery.set_broadcast_enabled(true)
    discovery.set_dest_address("255.255.255.255", DISCOVERY_PORT)
    discovery.put_packet(DISCOVERY_MESSAGE.to_utf8_buffer())
    connecting = true
    return true

func connect_to_host(host: String, port: int = TCP_PORT) -> int:
    disconnect_from_host()
    var target := host.strip_edges()
    if target.is_empty():
        return ERR_INVALID_PARAMETER
    var final_port := port if port > 0 and port <= 65535 else TCP_PORT
    connecting = true
    var err := tcp.connect_to_host(target, final_port)
    if err != OK:
        connecting = false
        connection_state_changed.emit(false, "Falha ao iniciar TCP: %s" % err)
    return err

func connect_discovered() -> int:
    if discovered_host.is_empty():
        return ERR_DOES_NOT_EXIST
    return connect_to_host(discovered_host, discovered_port)

func is_connected() -> bool:
    return connected and tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED

func send_packet(packet: Dictionary) -> int:
    if not is_connected():
        return ERR_UNAVAILABLE
    return tcp.put_data((JSON.stringify(packet) + "\n").to_utf8_buffer())

func send_tracking(packet: Dictionary) -> int:
    return send_packet(packet)

func disconnect_from_host() -> void:
    if tcp.get_status() != StreamPeerTCP.STATUS_NONE:
        tcp.disconnect_from_host()
    connected = false
    connecting = false
    buffer = ""
    connection_state_changed.emit(false, "Desconectado")

func _poll_tcp() -> void:
    var state := tcp.get_status()
    if state == StreamPeerTCP.STATUS_CONNECTING:
        connecting = true
        return
    if state == StreamPeerTCP.STATUS_CONNECTED:
        if not connected:
            connected = true
            connecting = false
            buffer = ""
            connection_state_changed.emit(true, "TCP conectado. Enviando handshake...")
            send_packet({
                "type": "hello",
                "protocol": PROTOCOL,
                "version": VERSION,
                "transport": "tcp",
                "device": "android_mobile_vr",
                "client_time_us": Time.get_ticks_usec()
            })
        var available := tcp.get_available_bytes()
        if available > 0:
            buffer += tcp.get_utf8_string(available)
            while "\n" in buffer:
                var newline := buffer.find("\n")
                var line := buffer.substr(0, newline).strip_edges()
                buffer = buffer.substr(newline + 1)
                if line.is_empty():
                    continue
                var parsed = JSON.parse_string(line)
                if parsed is Dictionary:
                    _handle_server_packet(parsed)
        return

    if connected or connecting:
        connected = false
        connecting = false
        buffer = ""
        connection_state_changed.emit(false, "Conexão TCP encerrada")

func _poll_discovery() -> void:
    while discovery.get_available_packet_count() > 0:
        var data := discovery.get_packet().get_string_from_utf8()
        if not data.begins_with("BLACK_GUNS_HERE|"):
            continue
        var parts := data.split("|")
        if parts.size() < 4 or parts[1] != PROTOCOL:
            continue
        discovered_host = discovery.get_packet_ip()
        discovered_port = int(parts[3])
        connection_state_changed.emit(false, "PC encontrado em %s:%d" % [discovered_host, discovered_port])
        discovery.close()
        connecting = false
        connect_to_host(discovered_host, discovered_port)
        return

func _handle_server_packet(packet: Dictionary) -> void:
    server_packet_received.emit(packet)
    match str(packet.get("type", "")):
        "hello":
            send_packet({
                "type": "hello",
                "protocol": PROTOCOL,
                "version": VERSION,
                "transport": "tcp",
                "device": "android_mobile_vr",
                "client_time_us": Time.get_ticks_usec()
            })
        "hello_ack":
            connection_state_changed.emit(true, "Handshake OK • PC conectado")
        "pong":
            pass
        "disconnect":
            disconnect_from_host()

func _exit_tree() -> void:
    disconnect_from_host()
    discovery.close()
