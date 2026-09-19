extends Node3D

const DEFAULT_PC_HOST := "192.168.4.1"
const DEFAULT_PC_PORT := 42424
const SENSOR_SEND_HZ := 60.0
const ACCEL_FILTER := 0.12
const ORIENTATION_CORRECTION := 0.02
const CALIBRATION_SECONDS := 2.0

var udp := PacketPeerUDP.new()
var socket_open := false
var tracking_enabled := false

var head_rotation := Vector3.ZERO
var head_position := Vector3(0.0, 1.65, 0.0)
var velocity := Vector3.ZERO
var packet_sequence := 0

var gyro_raw := Vector3.ZERO
var accel_raw := Vector3.ZERO
var gyro_bias := Vector3.ZERO
var accel_filtered := Vector3(0.0, -9.81, 0.0)
var gyro_filtered := Vector3.ZERO
var sensor_timestamp_us := 0
var sensor_elapsed := 0.0
var packet_accumulator := 0.0

var calibrating := false
var calibration_elapsed := 0.0
var calibration_gyro_sum := Vector3.ZERO
var calibration_samples := 0

@onready var status: Label = $UI/Panel/Status
@onready var sensor_status: Label = $UI/Panel/SensorStatus
@onready var connect_button: Button = $UI/Panel/ConnectButton
@onready var start_button: Button = $UI/Panel/StartButton
@onready var calibrate_button: Button = $UI/Panel/CalibrateButton
@onready var test_button: Button = $UI/Panel/TestButton
@onready var ip_edit: LineEdit = $UI/Panel/Ip
@onready var port_edit: LineEdit = $UI/Panel/Port
@onready var player_camera: Camera3D = $PlayerCamera

func _ready() -> void:
	connect_button.pressed.connect(_toggle_connection)
	start_button.pressed.connect(_start_tracking)
	calibrate_button.pressed.connect(_start_calibration)
	test_button.pressed.connect(_send_test_packet)
	_request_camera_permission()
	_refresh_status("Etapa 2 pronta. Inicie os sensores e calibre o celular.")
	_update_sensor_status()

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
	_refresh_status("Socket UDP aberto para %s:%d." % [host, port])

func _start_tracking() -> void:
	tracking_enabled = true
	start_button.text = "SENSORES ATIVOS"
	_refresh_status("Sensores ativos. Deixe o celular parado para calibrar.")
	_start_calibration()

func _start_calibration() -> void:
	calibrating = true
	calibration_elapsed = 0.0
	calibration_gyro_sum = Vector3.ZERO
	calibration_samples = 0
	calibrate_button.text = "CALIBRANDO..."
	calibrate_button.disabled = true
	_refresh_status("Calibrando gyro por %.1f s. Não mova o celular." % CALIBRATION_SECONDS)

func _process(delta: float) -> void:
	var safe_delta := clamp(delta, 0.001, 0.05)

	if tracking_enabled:
		_read_sensors(safe_delta)
		if socket_open:
			packet_accumulator += safe_delta
			var packet_interval := 1.0 / SENSOR_SEND_HZ
			if packet_accumulator >= packet_interval:
				packet_accumulator = fmod(packet_accumulator, packet_interval)
				_send_tracking_packet()

	$TeleportArc.head_position = player_camera.position
	$TeleportArc.head_rotation = head_rotation
	_update_sensor_status()

func _read_sensors(delta: float) -> void:
	gyro_raw = Input.get_gyroscope()
	accel_raw = Input.get_accelerometer()
	sensor_timestamp_us = Time.get_ticks_usec()
	sensor_elapsed += delta

	gyro_filtered = gyro_raw - gyro_bias
	accel_filtered = accel_filtered.lerp(accel_raw, ACCEL_FILTER)

	if calibrating:
		calibration_gyro_sum += gyro_raw
		calibration_samples += 1
		calibration_elapsed += delta
		if calibration_elapsed >= CALIBRATION_SECONDS:
			gyro_bias = calibration_gyro_sum / max(calibration_samples, 1)
			calibrating = false
			calibrate_button.disabled = false
			calibrate_button.text = "RECALIBRAR SENSORES"
			_refresh_status("Calibração concluída. Bias gyro: %s" % _format_vector(gyro_bias))

	# O gyro fornece a resposta rápida. O acelerômetro corrige apenas
	# pitch/roll usando a direção da gravidade. O yaw continua relativo,
	# porque o celular não possui uma referência absoluta de norte nesta etapa.
	head_rotation += gyro_filtered * delta

	var accel_magnitude := accel_filtered.length()
	if accel_magnitude > 7.0 and accel_magnitude < 13.0:
		var gravity_dir := accel_filtered.normalized()
		var target_pitch := atan2(-gravity_dir.x, sqrt(gravity_dir.y * gravity_dir.y + gravity_dir.z * gravity_dir.z))
		var target_roll := atan2(gravity_dir.y, gravity_dir.z)
		head_rotation.x = lerp_angle(head_rotation.x, target_pitch, ORIENTATION_CORRECTION)
		head_rotation.z = lerp_angle(head_rotation.z, target_roll, ORIENTATION_CORRECTION)

	head_rotation.x = wrapf(head_rotation.x, -PI, PI)
	head_rotation.y = wrapf(head_rotation.y, -PI, PI)
	head_rotation.z = wrapf(head_rotation.z, -PI, PI)

	# Positional tracking visual ainda não está implementado nesta etapa.
	# Portanto não integramos acelerômetro duas vezes para inventar posição,
	# evitando um deslocamento falso e enorme por drift.
	head_position = Vector3(0.0, 1.65, 0.0)

func _send_test_packet() -> void:
	if not socket_open:
		_refresh_status("Abra a conexão UDP primeiro.")
		return

	packet_sequence += 1
	var packet := {
		"type": "black_guns_handshake",
		"version": 2,
		"sequence": packet_sequence,
		"timestamp_us": Time.get_ticks_usec(),
		"device": "android_mobile_vr",
		"sensor_stage": 2
	}
	var bytes := JSON.stringify(packet).to_utf8_buffer()
	var err := udp.put_packet(bytes)
	_refresh_status("Pacote de teste enviado (%d bytes). Resultado: %s" % [bytes.size(), err])

func _send_tracking_packet() -> void:
	packet_sequence += 1
	var packet := {
		"type": "black_guns_tracking",
		"version": 2,
		"sequence": packet_sequence,
		"timestamp_us": sensor_timestamp_us,
		"sensor_stage": 2,
		"head_rotation": [head_rotation.x, head_rotation.y, head_rotation.z],
		"head_position": [head_position.x, head_position.y, head_position.z],
		"gyroscope": [gyro_raw.x, gyro_raw.y, gyro_raw.z],
		"gyroscope_corrected": [gyro_filtered.x, gyro_filtered.y, gyro_filtered.z],
		"accelerometer": [accel_raw.x, accel_raw.y, accel_raw.z],
		"accelerometer_filtered": [accel_filtered.x, accel_filtered.y, accel_filtered.z],
		"gyro_bias": [gyro_bias.x, gyro_bias.y, gyro_bias.z],
		"hand_tracking": {
			"provider": "pending_camera_provider",
			"left": [],
			"right": []
		}
	}
	udp.put_packet(JSON.stringify(packet).to_utf8_buffer())

func _update_sensor_status() -> void:
	if not is_instance_valid(sensor_status):
		return
	var state := "DESLIGADO"
	if tracking_enabled:
		state = "CALIBRANDO" if calibrating else "ATIVO"
	sensor_status.text = "SENSORES: %s\nGYRO  %s\nACCEL %s\nBIAS   %s" % [
		state,
		_format_vector(gyro_filtered),
		_format_vector(accel_filtered),
		_format_vector(gyro_bias)
	]

func _format_vector(value: Vector3) -> String:
	return "(%+.3f, %+.3f, %+.3f)" % [value.x, value.y, value.z]

func _refresh_status(message: String) -> void:
	status.text = message
