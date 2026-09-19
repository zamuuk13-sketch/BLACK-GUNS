extends Node3D

@export_enum("Left", "Right") var hand := 0

const JOINT_COUNT := 21
const CONNECTIONS := [
	[0, 1], [1, 2], [2, 3], [3, 4],
	[0, 5], [5, 6], [6, 7], [7, 8],
	[0, 9], [9, 10], [10, 11], [11, 12],
	[0, 13], [13, 14], [14, 15], [15, 16],
	[0, 17], [17, 18], [18, 19], [19, 20],
	[5, 9], [9, 13], [13, 17], [0, 5], [0, 17]
]

@export var position_scale := 0.95
@export var depth_scale := 0.75
@export var smoothing := 14.0
@export var joint_radius := 0.018
@export var bone_radius := 0.010

var joints: Array[MeshInstance3D] = []
var bones: Array[MeshInstance3D] = []
var target_points: Array[Vector3] = []
var smoothed_points: Array[Vector3] = []
var tracked := false
var hand_size := 0.18
var palm_rotation := Basis.IDENTITY

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	var joint_mesh := SphereMesh.new()
	joint_mesh.radius = joint_radius
	joint_mesh.height = joint_radius * 2.0

	for i in JOINT_COUNT:
		var joint := MeshInstance3D.new()
		joint.mesh = joint_mesh
		joint.material_override = _make_material(Color(0.2, 0.75, 1.0, 0.95), Color(0.05, 0.35, 1.0))
		add_child(joint)
		joints.append(joint)

	for connection in CONNECTIONS:
		var bone_mesh := CylinderMesh.new()
		bone_mesh.top_radius = bone_radius
		bone_mesh.bottom_radius = bone_radius
		bone_mesh.height = 1.0
		var bone := MeshInstance3D.new()
		bone.mesh = bone_mesh
		bone.material_override = _make_material(Color(0.1, 0.55, 1.0, 0.9), Color(0.02, 0.18, 0.7))
		add_child(bone)
		bones.append(bone)

func _make_material(albedo: Color, emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return mat

func set_landmarks(points: Array[Vector3], delta: float = 0.016) -> void:
	if points.size() < JOINT_COUNT:
		set_tracked_visible(false)
		return

	tracked = true
	set_tracked_visible(true)
	target_points.clear()

	var wrist := points[0]
	var middle_mcp := points[9]
	var palm_width := wrist.distance_to(points[5]) + wrist.distance_to(points[17])
	var middle_length := wrist.distance_to(middle_mcp)
	hand_size = clamp((palm_width * 0.5 + middle_length) * 0.5, 0.07, 0.35)

	for point in points:
		# MediaPipe: x/y normalizados na imagem, z relativo ao pulso.
		# Convertemos para um espaço 3D local à câmera do celular.
		var x := (0.5 - point.x) * position_scale
		var y := (0.5 - point.y) * position_scale
		var z := -0.48 - ((point.z - wrist.z) * depth_scale)
		target_points.append(Vector3(x, y, z))

	if smoothed_points.size() != JOINT_COUNT:
		smoothed_points = target_points.duplicate()
	else:
		var alpha := 1.0 - exp(-smoothing * max(delta, 0.001))
		for i in JOINT_COUNT:
			smoothed_points[i] = smoothed_points[i].lerp(target_points[i], alpha)

	position = smoothed_points[0]
	palm_rotation = _calculate_palm_basis(smoothed_points)
	rotation = palm_rotation.get_euler()

	for i in JOINT_COUNT:
		joints[i].position = smoothed_points[i] - position

	for i in CONNECTIONS.size():
		_update_bone(bones[i], smoothed_points[CONNECTIONS[i][0]] - position, smoothed_points[CONNECTIONS[i][1]] - position)

func _calculate_palm_basis(points: Array[Vector3]) -> Basis:
	var wrist := points[0]
	var index_mcp := points[5]
	var pinky_mcp := points[17]
	var middle_mcp := points[9]

	var across := (pinky_mcp - index_mcp).normalized()
	var forward := across.cross((middle_mcp - wrist).normalized()).normalized()
	if forward.length_squared() < 0.001:
		return Basis.IDENTITY

	var up := forward.cross(across).normalized()
	return Basis(across, up, forward).orthonormalized()

func _update_bone(bone: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var direction := b - a
	var length := direction.length()
	if length < 0.001:
		bone.visible = false
		return

	bone.visible = true
	bone.position = (a + b) * 0.5
	bone.scale = Vector3(1.0, length, 1.0)
	bone.quaternion = Quaternion(Vector3.UP, direction.normalized())

func get_palm_world_position() -> Vector3:
	if smoothed_points.size() < JOINT_COUNT:
		return global_position
	return to_global(smoothed_points[0])

func get_index_tip_world_position() -> Vector3:
	if smoothed_points.size() < JOINT_COUNT:
		return global_position
	return to_global(smoothed_points[8])

func get_thumb_tip_world_position() -> Vector3:
	if smoothed_points.size() < JOINT_COUNT:
		return global_position
	return to_global(smoothed_points[4])

func get_pinch_strength() -> float:
	if smoothed_points.size() < JOINT_COUNT:
		return 0.0
	var pinch_distance := smoothed_points[4].distance_to(smoothed_points[8])
	return clamp(1.0 - (pinch_distance / 0.11), 0.0, 1.0)

func set_tracked_visible(value: bool) -> void:
	visible = value
	tracked = value
