extends Control

@export var eye_width := 640
@export var eye_height := 720
@export var ipd_meters := 0.064
@export var eye_fov := 90.0
@export var lens_distortion_strength := 0.0
@export var calibration_scale := 1.0

var left_viewport: SubViewport
var right_viewport: SubViewport
var left_camera: Camera3D
var right_camera: Camera3D
var left_rect: TextureRect
var right_rect: TextureRect
var source_camera: Camera3D
var stereo_enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_camera = get_node_or_null("../PlayerCamera")
	_build_stereo()
	set_process(true)

func _build_stereo() -> void:
	left_viewport = _make_viewport()
	right_viewport = _make_viewport()
	left_camera = _make_eye_camera(left_viewport, "LeftEyeCamera")
	right_camera = _make_eye_camera(right_viewport, "RightEyeCamera")

	left_rect = _make_eye_rect(left_viewport.get_texture())
	right_rect = _make_eye_rect(right_viewport.get_texture())
	left_rect.position = Vector2(0, 0)
	right_rect.position = Vector2(eye_width, 0)
	size = Vector2(eye_width * 2, eye_height)

func _make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(eye_width, eye_height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.world_3d = get_viewport().world_3d
	add_child(viewport)
	return viewport

func _make_eye_camera(viewport: SubViewport, camera_name: String) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = camera_name
	camera.current = true
	camera.fov = eye_fov
	camera.near = 0.03
	camera.far = 1000.0
	viewport.add_child(camera)
	return camera

func _make_eye_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = Vector2(eye_width, eye_height)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect

func _process(_delta: float) -> void:
	if not stereo_enabled or not is_instance_valid(source_camera):
		return

	var center := source_camera.global_transform
	var half_ipd := (ipd_meters * calibration_scale) * 0.5
	var right_axis := center.basis.x.normalized()

	var left_transform := center
	left_transform.origin -= right_axis * half_ipd
	var right_transform := center
	right_transform.origin += right_axis * half_ipd

	left_camera.global_transform = left_transform
	right_camera.global_transform = right_transform
	left_camera.fov = eye_fov
	right_camera.fov = eye_fov

func set_ipd(value_meters: float) -> void:
	ipd_meters = clamp(value_meters, 0.045, 0.080)

func set_calibration_scale(value: float) -> void:
	calibration_scale = clamp(value, 0.85, 1.15)

func set_stereo_enabled(value: bool) -> void:
	stereo_enabled = value
	visible = value

func get_eye_textures() -> Dictionary:
	return {"left": left_viewport.get_texture(), "right": right_viewport.get_texture()}
