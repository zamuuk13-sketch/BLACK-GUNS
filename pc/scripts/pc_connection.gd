extends Node

const TCP_PORT := 39100
const DISCOVERY_PORT := 39101
const PROTOCOL := "BLACK_GUNS_VR"
const VERSION := 1

var tcp_server := TCPServer.new()
var udp := PacketPeerUDP.new()
var client: StreamPeerTCP
var client_buffer := ""
var video_port := 39103

@onready var status_label: Label = get_node_or_null("../UI/ConnectionStatus")
@onready var vr_stream: Node = get_node_or_null("../VRStream")

func _ready() -> void:
    udp.set_broadcast_enabled(true)
    udp.bind(DISCOVERY_PORT)
    tcp_server.listen(TCP_PORT)
    _set_status("Servidor aguardando celular...\nTCP %d • UDP %d" % [TCP_PORT, DISCOVERY_PORT])
    set_process(true)

func _process(_delta: float) -> void:
    _accept_tcp_client()
    _receive_tcp()
    _answer_discovery()

func _accept_tcp_client() -> void:
    if not tcp_server.is_connection_available():
        return
    client = tcp_server.take_connection()
    client_buffer = ""
    _send_packet({"type":"hello","protocol":PROTOCOL,"version":VERSION,"transport":"tcp","server_time_us":Time.get_ticks_usec()})
    _set_status("Celular conectado • aguardando handshake")

func _receive_tcp() -> void:
    if client == null or client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
        return
    var available := client.get_available_bytes()
    if available <= 0:
        return
    client_buffer += client.get_utf8_string(available)
    while "\n" in client_buffer:
        var newline := client_buffer.find("\n")
        var line := client_buffer.substr(0, newline).strip_edges()
        client_buffer = client_buffer.substr(newline + 1)
        if line.is_empty():
            continue
        var parsed = JSON.parse_string(line)
        if parsed is Dictionary:
            _handle_packet(parsed)

func _handle_packet(packet: Dictionary) -> void:
    match str(packet.get("type", "")):
        "hello":
            video_port = int(packet.get("video_port", 39103))
            _send_packet({"type":"hello_ack","protocol":PROTOCOL,"version":VERSION,"video_port":video_port,"stream_width":640,"stream_height":360,"stream_fps":20,"server_time_us":Time.get_ticks_usec()})
            if vr_stream and client:
                vr_stream.video_port = video_port
                vr_stream.start_stream(client.get_connected_host())
            _set_status("✓ Handshake OK • Mobile conectado • VR stream ativo")
        "ping":
            _send_packet({"type":"pong","client_time_us":packet.get("client_time_us",0),"server_time_us":Time.get_ticks_usec()})
        "tracking":
            pass
        "disconnect":
            _close_client()

func _answer_discovery() -> void:
    while udp.get_available_packet_count() > 0:
        var data := udp.get_packet().get_string_from_utf8()
        if data == "BLACK_GUNS_DISCOVER":
            var address := udp.get_packet_ip()
            udp.set_dest_address(address, DISCOVERY_PORT)
            udp.put_packet(("BLACK_GUNS_HERE|%s|%d|%d" % [PROTOCOL, VERSION, TCP_PORT]).to_utf8_buffer())

func _send_packet(packet: Dictionary) -> void:
    if client == null or client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
        return
    client.put_data((JSON.stringify(packet) + "\n").to_utf8_buffer())

func _close_client() -> void:
    if vr_stream:
        vr_stream.stop_stream()
    if client != null:
        client.disconnect_from_host()
    client = null
    client_buffer = ""
    _set_status("Celular desconectado • aguardando conexão")

func _set_status(text: String) -> void:
    if status_label:
        status_label.text = text
