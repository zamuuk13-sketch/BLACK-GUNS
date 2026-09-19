extends Node3D

@export_enum("Left", "Right") var hand := 0
const JOINT_COUNT := 21
var joints: Array[MeshInstance3D] = []

func _ready() -> void:
	var joint_mesh := SphereMesh.new()
	joint_mesh.radius = 0.025
	joint_mesh.height = 0.05
	for i in JOINT_COUNT:
		var joint := MeshInstance3D.new()
		joint.mesh = joint_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.75, 1.0, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(0.05, 0.35, 1.0)
		joint.material_override = mat
		add_child(joint)
		joints.append(joint)

func set_landmarks(points: Array[Vector3]) -> void:
	for i in min(points.size(), JOINT_COUNT):
		joints[i].position = points[i]

func set_tracked_visible(value: bool) -> void:
	visible = value
