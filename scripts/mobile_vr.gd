extends Node3D

const PC_PORT := 42424
const PC_HOST := "192.168.4.1"

var udp := PacketPeerUDP.new()
var connected := false
var tracking_enabled := false
var head_rotation := Vector3.ZERO
var head_position := Vector3.ZERO
var velocity := Vector3.ZERO

@onready var status: Label = $UI/Status
@onready var connect_button: Button = $UI/ConnectButton
@onready var start_button: Button = $UI/StartButton

func _ready() -> void:
	connect_button.pressed.connect(_connect_to_pc)
	start_button.pressed.connect(_start_tracking)
	_request_camera_permission()
	_refresh_status("Pronto. Conecte ao PC.")

func _request_camera_permission() -> void:
	if OS.has_feature("android") and OS.has_method("request_permission"):
		OS.request_permission("android.permission.CAMERA")

func _start_tracking() -> void:
	tracking_enabled = true
	_refresh_status("Tracking ativo: giroscópio + acelerômetro. Câmera reservada para hand tracking.")

func _connect_to_pc() -> void:
	var err := udp.connect_to_host(PC_HOST, PC_PORT)
	connected = err == OK
	if connected:
		_refresh_status("PC conectado em %s:%d" % [PC_HOST, PC_PORT])
	else:
		_refresh_status("PC não encontrado. Transporte será refinado na próxima etapa.")

func _process(delta: float) -> void:
	if not tracking_enabled:
		return
	_read_sensors(delta)
	_send_tracking_packet()
	$TeleportArc.head_position = head_position
	$TeleportArc.head_rotation = head_rotation

func _read_sensors(delta: float) -> void:
	var gyro := Input.get_gyroscope()
	var accel := Input.get_accelerometer()
	head_rotation += gyro * delta

	# Fallback experimental. Inertial-only position drifts; real 6DoF
	# will be supplied by visual/inertial fusion in the Android provider.
	var linear_accel := accel - Vector3(0.0, -9.81, 0.0)
	velocity = velocity.lerp(velocity + linear_accel * delta, 0.35)
	head_position += velocity * delta
	head_position = head_position.clamp(Vector3(-3, -1.5, -3), Vector3(3, 1.5, 3))

func _send_tracking_packet() -> void:
	if not connected:
		return
	var packet := {
		"type": "black_guns_tracking",
		"timestamp_ms": Time.get_ticks_msec(),
		"head_rotation": [head_rotation.x, head_rotation.y, head_rotation.z],
		"head_position": [head_position.x, head_position.y, head_position.z],
		"gyroscope": [Input.get_gyroscope().x, Input.get_gyroscope().y, Input.get_gyroscope().z],
		"accelerometer": [Input.get_accelerometer().x, Input.get_accelerometer().y, Input.get_accelerometer().z],
		"hand_tracking": {
			"provider": "pending_camera_provider",
			"left": [],
			"right": []
		}
	}
	udp.put_packet(JSON.stringify(packet).to_utf8_buffer())

func _refresh_status(message: String) -> void:
	status.text = "BLACK GUNS MOBILE VR\n\n" + message
