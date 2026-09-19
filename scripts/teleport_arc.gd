extends Node3D

@export var max_distance := 5.0
@export var segments := 32
@export var arc_height := 1.25
@export var curve_color := Color(0.12, 0.55, 1.0, 0.65)
@export var valid_color := Color(0.1, 0.8, 1.0, 0.9)
@export var invalid_color := Color(1.0, 0.2, 0.15, 0.9)
@export var confirm_hold_time := 0.18
@export var hand_forward_scale := 1.8

var head_position := Vector3.ZERO
var head_rotation := Vector3.ZERO
var destination := Vector3.ZERO
var valid_target := false
var confirm_progress := 0.0
var confirm_requested := false
var teleport_triggered := false

var left_hand_points: Array[Vector3] = []
var right_hand_points: Array[Vector3] = []

var line := ImmediateMesh.new()
var line_instance := MeshInstance3D.new()
var target_mesh := SphereMesh.new()
var target_instance := MeshInstance3D.new()

func _ready() -> void:
	line_instance.mesh = line
	add_child(line_instance)
	target_mesh.radius = 0.09
	target_mesh.height = 0.18
	target_instance.mesh = target_mesh
	add_child(target_instance)
	_build_materials()
	target_instance.visible = false

func _process(delta: float) -> void:
	_update_arc()
	_update_confirmation(delta)

func set_hand_landmarks(left: Array[Vector3], right: Array[Vector3]) -> void:
	left_hand_points = left
	right_hand_points = right

func request_confirm() -> void:
	confirm_requested = true

func _update_arc() -> void:
	line.clear_surfaces()
	var origin := head_position
	var forward := _get_teleport_direction()
	var points: Array[Vector3] = []

	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := origin + forward * max_distance * t
		p.y += sin(t * PI) * arc_height
		points.append(p)

	var destination_point := points[-1]
	valid_target = false
	var space := get_world_3d().direct_space_state

	for i in range(points.size() - 1):
		var query := PhysicsRayQueryParameters3D.create(points[i], points[i + 1])
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			destination_point = hit.position
			valid_target = _is_valid_floor_target(hit.position, hit.normal)
			break

	if not valid_target:
		# Sem colisão, o arco termina no máximo alcance, mas não autoriza teleporte.
		destination_point = points[-1]

	destination = destination_point
	var material := line_instance.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = valid_color if valid_target else invalid_color

	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		if p.distance_to(origin) <= origin.distance_to(destination) + 0.01:
			line.surface_add_vertex(p)
	line.surface_end()

	target_instance.position = destination
	target_instance.visible = valid_target

func _get_teleport_direction() -> Vector3:
	# Preferimos a direção da mão direita; se não houver, usamos a esquerda.
	var points := right_hand_points if right_hand_points.size() >= 21 else left_hand_points
	if points.size() >= 21:
		var wrist := points[0]
		var index_mcp := points[5]
		var middle_mcp := points[9]
		var palm_normal := (index_mcp - wrist).cross(middle_mcp - wrist).normalized()
		if palm_normal.length_squared() > 0.001:
			var direction := palm_normal * hand_forward_scale
			direction.y += 0.35
			return direction.normalized()

	var fallback := -Basis.from_euler(head_rotation) * Vector3.FORWARD
	fallback.y = 0.15
	return fallback.normalized()

func _is_valid_floor_target(point: Vector3, normal: Vector3) -> bool:
	if normal.dot(Vector3.UP) < 0.65:
		return false
	var test := PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 1.0,
		point + Vector3.DOWN * 0.15
	)
	var result := get_world_3d().direct_space_state.intersect_ray(test)
	return not result.is_empty()

func _update_confirmation(delta: float) -> void:
	if confirm_requested:
		confirm_requested = false
		if valid_target:
			confirm_progress = min(confirm_progress + delta, confirm_hold_time)
		else:
			confirm_progress = 0.0
	else:
		confirm_progress = max(confirm_progress - delta * 3.0, 0.0)

	teleport_triggered = confirm_progress >= confirm_hold_time

func consume_teleport() -> bool:
	if not teleport_triggered or not valid_target:
		return false
	teleport_triggered = false
	confirm_progress = 0.0
	return true

func _build_materials() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = curve_color
	material.emission_enabled = true
	material.emission = Color(0.05, 0.25, 0.8)
	line_instance.material_override = material

	var target_material := StandardMaterial3D.new()
	target_material.albedo_color = valid_color
	target_material.emission_enabled = true
	target_material.emission = Color(0.05, 0.35, 1.0)
	target_instance.material_override = target_material
