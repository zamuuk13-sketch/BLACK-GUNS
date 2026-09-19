extends Node3D

@onready var player_camera: Camera3D = $PlayerCamera
@onready var status_label: Label = $UI/Status

func _ready() -> void:
    player_camera.current = true
    status_label.text = "BLACK GUNS • PC STAGE 1\nAMBIENTE 3D DE TESTE\n\nWASD: mover câmera\nMouse: olhar\nESC: liberar mouse"
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        player_camera.rotate_y(-event.relative.x * 0.002)
        player_camera.rotation.x = clamp(player_camera.rotation.x - event.relative.y * 0.002, deg_to_rad(-80.0), deg_to_rad(80.0))

func _process(delta: float) -> void:
    var direction := Vector3.ZERO
    var basis := player_camera.global_transform.basis
    if Input.is_key_pressed(KEY_W):
        direction -= basis.z
    if Input.is_key_pressed(KEY_S):
        direction += basis.z
    if Input.is_key_pressed(KEY_A):
        direction -= basis.x
    if Input.is_key_pressed(KEY_D):
        direction += basis.x
    if Input.is_key_pressed(KEY_Q):
        direction -= Vector3.UP
    if Input.is_key_pressed(KEY_E):
        direction += Vector3.UP
    if direction.length_squared() > 0.0:
        player_camera.position += direction.normalized() * 4.0 * delta
