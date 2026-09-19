extends Node3D

const DEFAULT_PC_HOST := "192.168.4.1"
const DEFAULT_PC_PORT := 42424
const SENSOR_SEND_HZ := 60.0
const ACCEL_FILTER := 0.12
const ORIENTATION_CORRECTION := 0.02
const CALIBRATION_SECONDS := 2.0
const CAMERA_SAMPLE_HZ := 10.0
const VISUAL_POSITION_SCALE := 0.006
const VISUAL_MAX_STEP := 0.035
const HAND_SAMPLE_HZ := 8.0
const HAND_IMAGE_WIDTH := 256
const HAND_IMAGE_HEIGHT := 192

var udp := PacketPeerUDP.new()
var socket_open := false
var tracking_enabled := false

var head_rotation := Vector3.ZERO
var head_position := Vector3(0.0, 1.65, 0.0)
var packet_sequence := 0

var gyro_raw := Vector3.ZERO
var accel_raw := Vector3.ZERO
var gyro_bias := Vector3.ZERO
var accel_filtered := Vector3(0.0, -9.81, 0.0)
var gyro_filtered := Vector3.ZERO
var sensor_timestamp_us := 0

var calibrating := false
var calibration_elapsed := 0.0
var calibration_gyro_sum := Vector3.ZERO
var calibration_samples := 0
var packet_accumulator := 0.0

# Etapa 3: câmera traseira usada somente como sensor.
var camera_feed: CameraFeed = null
var camera_feed_texture: Texture2D = null
var camera_available := false
var camera_active := false
var camera_frame_size := Vector2i.ZERO
var camera_sample_accumulator := 0.0
var camera_sample_count := 0
var camera_last_sample_us := 0

# Etapa 4: movimento visual relativo da câmera + fusão leve com IMU.
var visual_estimator := BlackGunsVisualEstimator.new()
var visual_tracking_valid := false
var visual_dx := 0.0
var visual_dy := 0.0
var visual_confidence := 0.0
var visual_tracked_points := 0
var visual_timestamp_us := 0
var visual_position_offset := Vector3.ZERO

var hand_tracker := BlackGunsHandTracking.new()
var hand_sample_accumulator := 0.0
var hands_detected := 0
var hand_confidence := 0.0
var left_hand_landmarks: Array[Vector3] = []
var right_hand_landmarks: Array[Vector3] = []
var hand_timestamp_us := 0
var hand_frame_delta := 0.016
var previous_left_palm := Vector3.ZERO
var previous_right_palm := Vector3.ZERO

@onready var status: Label = $UI/Panel/Status
@onready var sensor_status: Label = $UI/Panel/SensorStatus
@onready var camera_status: Label = $UI/Panel/CameraStatus
@onready var visual_status: Label = $UI/Panel/VisualStatus
@onready var hand_status: Label = $UI/Panel/HandStatus
@onready var connect_button: Button = $UI/Panel/ConnectButton
@onready var start_button: Button = $UI/Panel/StartButton
@onready var calibrate_button: Button = $UI/Panel/CalibrateButton
@onready var test_button: Button = $UI/Panel/TestButton
@onready var ip_edit: LineEdit = $UI/Panel/Ip
@onready var port_edit: LineEdit = $UI/Panel/Port
@onready var player_camera: Camera3D = $PlayerCamera
@onready var hand_interaction: Node = $HandInteraction
@onready var left_hand_skeleton: Node3D = $PlayerCamera/LeftHandSkeleton
@onready var right_hand_skeleton: Node3D = $PlayerCamera/RightHandSkeleton

func _ready() -> void:
	connect_button.pressed.connect(_toggle_connection)
	start_button.pressed.connect(_start_tracking)
	calibrate_button.pressed.connect(_start_calibration)
	test_button.pressed.connect(_send_test_packet)
	_request_camera_permission()
	_start_camera_sensor()
	_refresh_status("Etapa 8 pronta. Mãos com interação física, grab e throw.")
	_update_sensor_status()
	_update_camera_status()
	_update_visual_status()
	_update_hand_status()
	$TeleportArc.set_hand_landmarks(left_hand_landmarks, right_hand_landmarks)
	if Input.is_key_pressed(KEY_F):
		$TeleportArc.request_confirm()
	if $TeleportArc.consume_teleport():
		player_camera.position = $TeleportArc.destination + Vector3.UP * 1.65
		head_position = player_camera.position
		visual_position_offset = player_camera.position - Vector3(0.0, 1.65, 0.0)

func _exit_tree() -> void:
	if camera_feed != null:
		camera_feed.set_active(false)
	hand_tracker.close()
	udp.close()

func _request_camera_permission() -> void:
	if OS.has_feature("android") and OS.has_method("request_permission"):
		OS.request_permission("android.permission.CAMERA")

func _start_camera_sensor() -> void:
	camera_available = false
	camera_active = false

	var feed_count := CameraServer.get_feed_count()
	for i in feed_count:
		var feed := CameraServer.get_feed(i)
		if feed == null:
			continue

		# Preferimos a câmera traseira. Em aparelhos onde a posição não é
		# informada, usamos o primeiro feed disponível como fallback.
		if feed.get_position() == CameraFeed.CAMERA_BACK or camera_feed == null:
			camera_feed = feed

	if camera_feed == null:
		_refresh_status("Nenhum feed de câmera disponível. Verifique a permissão do Android.")
		return

	camera_feed.set_active(true)
	camera_active = camera_feed.is_active()
	camera_available = true
	if camera_active:
		camera_feed_texture = camera_feed.get_texture()
		camera_frame_size = camera_feed.get_frame_size()
		_refresh_status("Câmera traseira ativa como sensor. A imagem não é exibida.")
	else:
		_refresh_status("Feed encontrado, mas não foi possível ativar a câmera.")

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
	start_button.text = "TRACKING ATIVO"
	_refresh_status("Tracking ativo. Deixe o celular parado para calibrar.")
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

	camera_sample_accumulator += safe_delta
	hand_sample_accumulator += safe_delta
	if camera_sample_accumulator >= 1.0 / CAMERA_SAMPLE_HZ:
		camera_sample_accumulator = fmod(camera_sample_accumulator, 1.0 / CAMERA_SAMPLE_HZ)
		_sample_camera_sensor()

	if hand_sample_accumulator >= 1.0 / HAND_SAMPLE_HZ:
		hand_sample_accumulator = fmod(hand_sample_accumulator, 1.0 / HAND_SAMPLE_HZ)
		_sample_hand_tracker()

	if tracking_enabled and socket_open:
		packet_accumulator += safe_delta
		var packet_interval := 1.0 / SENSOR_SEND_HZ
		if packet_accumulator >= packet_interval:
			packet_accumulator = fmod(packet_accumulator, packet_interval)
			_send_tracking_packet()

	$TeleportArc.head_position = player_camera.position
	$TeleportArc.head_rotation = head_rotation
	if is_instance_valid(hand_interaction):
		hand_interaction.update_hands(left_hand_skeleton, right_hand_skeleton, hand_frame_delta)
	_update_sensor_status()
	_update_camera_status()
	_update_visual_status()
	_update_hand_status()

func _read_sensors(delta: float) -> void:
	gyro_raw = Input.get_gyroscope()
	accel_raw = Input.get_accelerometer()
	sensor_timestamp_us = Time.get_ticks_usec()

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

	# Orientação inercial estável: gyro para resposta rápida + gravidade
	# para correção lenta de pitch/roll.
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

		# Não usamos dupla integração do acelerômetro; a posição visual continua relativa.
	head_position = Vector3(0.0, 1.65, 0.0) + visual_position_offset

func _sample_camera_sensor() -> void:
	if camera_feed == null or not camera_feed.is_active():
		return

	camera_feed_texture = camera_feed.get_texture()
	camera_frame_size = camera_feed.get_frame_size()
	camera_last_sample_us = Time.get_ticks_usec()
	camera_sample_count += 1

	if camera_feed_texture != null:
		var visual_result := visual_estimator.process_texture(camera_feed_texture)
		visual_tracking_valid = visual_result.valid
		visual_dx = visual_result.dx
		visual_dy = visual_result.dy
		visual_confidence = visual_result.confidence
		visual_tracked_points = visual_result.tracked_points
		visual_timestamp_us = visual_result.timestamp_us
		if visual_tracking_valid and visual_confidence >= 0.25:
			var relative_step := Vector3(-visual_dx, visual_dy, 0.0) * VISUAL_POSITION_SCALE
			relative_step.x = clamp(relative_step.x, -VISUAL_MAX_STEP, VISUAL_MAX_STEP)
			relative_step.y = clamp(relative_step.y, -VISUAL_MAX_STEP, VISUAL_MAX_STEP)
			visual_position_offset += relative_step

	# A imagem continua invisível; somente os dados dela alimentam os estimadores.

func _sample_hand_tracker() -> void:
	var previous_time := hand_timestamp_us
	if not hand_tracker.is_available() or camera_feed_texture == null:
		return
	var image := camera_feed_texture.get_image()
	if image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_RGB8)
	image.resize(HAND_IMAGE_WIDTH, HAND_IMAGE_HEIGHT, Image.INTERPOLATE_BILINEAR)
	var result := hand_tracker.process_rgb_frame(image.get_data(), HAND_IMAGE_WIDTH, HAND_IMAGE_HEIGHT, Time.get_ticks_usec())
	hands_detected = int(result.get("hands", 0))
	hand_confidence = float(result.get("confidence", 0.0))
	hand_timestamp_us = int(result.get("timestamp_us", 0))
	if previous_time > 0 and hand_timestamp_us > previous_time:
		hand_frame_delta = clamp(float(hand_timestamp_us - previous_time) / 1000000.0, 0.001, 0.2)
	left_hand_landmarks = _parse_landmarks(str(result.get("left", "")))
	right_hand_landmarks = _parse_landmarks(str(result.get("right", "")))


func _update_3d_hands() -> void:
	if not hand_tracker.is_available():
		left_hand_skeleton.set_tracked_visible(false)
		right_hand_skeleton.set_tracked_visible(false)
		return

	left_hand_skeleton.set_landmarks(left_hand_landmarks, hand_frame_delta)
	right_hand_skeleton.set_landmarks(right_hand_landmarks, hand_frame_delta)

func _parse_landmarks(encoded: String) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if encoded.is_empty():
		return points
	for token in encoded.split(";"):
		var values := token.split(",")
		if values.size() == 3:
			points.append(Vector3(float(values[0]), float(values[1]), float(values[2])))
	return points

func _send_test_packet() -> void:
	if not socket_open:
		_refresh_status("Abra a conexão UDP primeiro.")
		return

	packet_sequence += 1
	var packet := {
		"type": "black_guns_handshake",
		"version": 7,
		"sequence": packet_sequence,
		"timestamp_us": Time.get_ticks_usec(),
		"device": "android_mobile_vr",
		"sensor_stage": 8,
		"camera_sensor": camera_active
	}
	var bytes := JSON.stringify(packet).to_utf8_buffer()
	var err := udp.put_packet(bytes)
	_refresh_status("Pacote de teste enviado (%d bytes). Resultado: %s" % [bytes.size(), err])

func _send_tracking_packet() -> void:
	packet_sequence += 1
	var packet := {
		"type": "black_guns_tracking",
		"version": 7,
		"sequence": packet_sequence,
		"timestamp_us": sensor_timestamp_us,
		"sensor_stage": 8,
		"head_rotation": [head_rotation.x, head_rotation.y, head_rotation.z],
		"head_position": [head_position.x, head_position.y, head_position.z],
		"gyroscope": [gyro_raw.x, gyro_raw.y, gyro_raw.z],
		"gyroscope_corrected": [gyro_filtered.x, gyro_filtered.y, gyro_filtered.z],
		"accelerometer": [accel_raw.x, accel_raw.y, accel_raw.z],
		"accelerometer_filtered": [accel_filtered.x, accel_filtered.y, accel_filtered.z],
		"gyro_bias": [gyro_bias.x, gyro_bias.y, gyro_bias.z],
		"camera_sensor": {
			"active": camera_active,
			"frame_width": camera_frame_size.x,
			"frame_height": camera_frame_size.y,
			"sample_count": camera_sample_count,
			"last_sample_us": camera_last_sample_us,
			"visible_to_user": false
		},
		"visual_tracking": {
			"provider": "lightweight_monocular_block_matching",
			"position_valid": visual_tracking_valid,
			"position_is_relative": true,
			"metric_scale_valid": false,
			"rotation_correction_valid": false,
			"dx": visual_dx,
			"dy": visual_dy,
			"confidence": visual_confidence,
			"tracked_points": visual_tracked_points,
			"timestamp_us": visual_timestamp_us
		},
		"hand_tracking": {
			"provider": "mediapipe_android_hand_landmarker",
			"available": hand_tracker.is_available(),
			"hands": hands_detected,
			"confidence": hand_confidence,
			"timestamp_us": hand_timestamp_us,
			"left": _landmarks_to_arrays(left_hand_landmarks),
			"right": _landmarks_to_arrays(right_hand_landmarks)
		},
		"physical_interaction": {
			"stage": 8,
			"grabbing_enabled": true
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

func _update_camera_status() -> void:
	if not is_instance_valid(camera_status):
		return

	var state := "SEM FEED"
	if camera_available:
		state = "ATIVA / SENSOR INVISÍVEL" if camera_active else "FEED ENCONTRADO / INATIVO"

	camera_status.text = "CÂMERA: %s\nFRAME: %dx%d\nAMOSTRAS: %d" % [
		state,
		camera_frame_size.x,
		camera_frame_size.y,
		camera_sample_count
	]

func _landmarks_to_arrays(points: Array[Vector3]) -> Array:
	var output: Array = []
	for point in points:
		output.append([point.x, point.y, point.z])
	return output

func _update_visual_status() -> void:
	if not is_instance_valid(visual_status):
		return
	var state := "SEM TRACKING"
	if visual_tracking_valid:
		state = "RASTREAMENTO RELATIVO"
	visual_status.text = "VISUAL: %s\\nFLOW dx/dy: %+.2f / %+.2f\\nPONTOS: %d  CONFIANÇA: %.2f" % [state, visual_dx, visual_dy, visual_tracked_points, visual_confidence]

func _update_hand_status() -> void:
	if not is_instance_valid(hand_status):
		return
	var state := "BACKEND INDISPONÍVEL"
	if hand_tracker.is_available():
		state = "MEDIAPIPE ATIVO"
	hand_status.text = "MÃOS: %s\\nDETECTADAS: %d  CONFIANÇA: %.2f\\nLANDMARKS L/R: %d / %d" % [state, hands_detected, hand_confidence, left_hand_landmarks.size(), right_hand_landmarks.size()]

func _format_vector(value: Vector3) -> String:
	return "(%+.3f, %+.3f, %+.3f)" % [value.x, value.y, value.z]

func _refresh_status(message: String) -> void:
	status.text = message
