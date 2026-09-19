extends Node3D

@export var max_distance := 5.0
@export var segments := 32
@export var arc_height := 1.25
@export var curve_color := Color(0.12, 0.55, 1.0, 0.65)

var head_position := Vector3.ZERO
var head_rotation := Vector3.ZERO
var destination := Vector3.ZERO

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

func _process(_delta: float) -> void:
	_update_arc()

func _update_arc() -> void:
	line.clear_surfaces()
	var origin := head_position
	var forward := -Basis.from_euler(head_rotation) * Vector3.FORWARD
	forward = forward.normalized()

	var points: Array[Vector3] = []
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := origin + forward * max_distance * t
		p.y += sin(t * PI) * arc_height
		points.append(p)

	var destination_point := points[-1]
	var space := get_world_3d().direct_space_state
	for i in range(points.size() - 1):
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(points[i], points[i + 1]))
		if not hit.is_empty():
			destination_point = hit.position
			break

	destination = destination_point
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		if p.distance_to(origin) <= origin.distance_to(destination) + 0.01:
			line.surface_add_vertex(p)
	line.surface_end()
	target_instance.position = destination

func _build_materials() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = curve_color
	material.emission_enabled = true
	material.emission = Color(0.05, 0.25, 0.8)
	line_instance.material_override = material

	var target_material := StandardMaterial3D.new()
	target_material.albedo_color = Color(0.1, 0.65, 1.0, 0.9)
	target_material.emission_enabled = true
	target_material.emission = Color(0.05, 0.35, 1.0)
	target_instance.material_override = target_material
