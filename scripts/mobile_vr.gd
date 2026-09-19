extends Node3D

const DEFAULT_PC_HOST := "192.168.4.1"
const DEFAULT_PC_PORT := 42424

var udp := PacketPeerUDP.new()
var socket_open := false
var tracking_enabled := false
var head_rotation := Vector3.ZERO
var head_position := Vector3(0.0, 1.65, 0.0)
var velocity := Vector3.ZERO
var packet_sequence := 0

@onready var status: Label = $UI/Panel/Status
@onready var connect_button: Button = $UI/Panel/ConnectButton
@onready var start_button: Button = $UI/Panel/StartButton
@onready var test_button: Button = $UI/Panel/TestButton
@onready var ip_edit: LineEdit = $UI/Panel/Ip
@onready var port_edit: LineEdit = $UI/Panel/Port
@onready var player_camera: Camera3D = $PlayerCamera

func _ready() -> void:
	connect_button.pressed.connect(_toggle_connection)
	start_button.pressed.connect(_start_tracking)
	test_button.pressed.connect(_send_test_packet)
	_request_camera_permission()
	_refresh_status("Sistema pronto. Configure o IP do PC.")

func _exit_tree() -> void:
	udp.close()

func _request_camera_permission() -> void:
	if OS.has_feature("android") and OS.has_method("request_permission"):
		OS.request_permission("android.permission.CAMERA")

func _toggle_connection() -> void:
	if socket_open:
		udp.close()
		socket_open = false
		connect_button.text = "ABRIR CONEXÃO UDP"
		_refresh_status("Conexão UDP fechada.")
		return

	var host := ip_edit.text.strip_edges()
	var port := int(port_edit.text)
	if host.is_empty():
		host = DEFAULT_PC_HOST
	if port <= 0 or port > 65535:
		port = DEFAULT_PC_PORT
		port_edit.text = str(port)

	var err := udp.connect_to_host(host, port)
	if err != OK:
		_refresh_status("Não foi possível abrir o socket UDP: %s" % err)
		return

	socket_open = true
	connect_button.text = "FECHAR CONEXÃO UDP"
	_refresh_status("Socket UDP aberto para %s:%d. Ainda aguardando o receiver do PC." % [host, port])

func _start_tracking() -> void:
	tracking_enabled = true
	start_button.text = "SENSORES ATIVOS"
	_refresh_status("Sensores ativos. Gyro/acelerômetro serão enviados quando a conexão estiver aberta.")

func _process(delta: float) -> void:
	if tracking_enabled:
		_read_sensors(delta)
		if socket_open:
			_send_tracking_packet()
	$TeleportArc.head_position = player_camera.position
	$TeleportArc.head_rotation = head_rotation

func _read_sensors(delta: float) -> void:
	var gyro := Input.get_gyroscope()
	var accel := Input.get_accelerometer()
	head_rotation += gyro * delta

	var gravity := Vector3(0.0, -9.81, 0.0)
	var linear_accel := accel - gravity
	velocity = velocity.lerp(velocity + linear_accel * delta, 0.35)
	head_position += velocity * delta
	head_position.y = 1.65

func _send_test_packet() -> void:
	if not socket_open:
		_refresh_status("Abra a conexão UDP primeiro.")
		return
	packet_sequence += 1
	var packet := {
		"type": "black_guns_handshake",
		"version": 1,
		"sequence": packet_sequence,
		"timestamp_ms": Time.get_ticks_msec(),
		"device": "android_mobile_vr"
	}
	var bytes := JSON.stringify(packet).to_utf8_buffer()
	var err := udp.put_packet(bytes)
	_refresh_status("Pacote de teste enviado (%d bytes). Resultado: %s" % [bytes.size(), err])

func _send_tracking_packet() -> void:
	packet_sequence += 1
	var gyro := Input.get_gyroscope()
	var accel := Input.get_accelerometer()
	var packet := {
		"type": "black_guns_tracking",
		"version": 1,
		"sequence": packet_sequence,
		"timestamp_ms": Time.get_ticks_msec(),
		"head_rotation": [head_rotation.x, head_rotation.y, head_rotation.z],
		"head_position": [head_position.x, head_position.y, head_position.z],
		"gyroscope": [gyro.x, gyro.y, gyro.z],
		"accelerometer": [accel.x, accel.y, accel.z],
		"hand_tracking": {
			"provider": "pending_camera_provider",
			"left": [],
			"right": []
		}
	}
	udp.put_packet(JSON.stringify(packet).to_utf8_buffer())

func _refresh_status(message: String) -> void:
	status.text = message
