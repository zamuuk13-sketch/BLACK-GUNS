extends Node3D

@export var grab_radius := 0.32
@export var pinch_threshold := 0.72
@export var release_threshold := 0.35
@export var throw_velocity_scale := 1.35

var left_hand: Node3D
var right_hand: Node3D
var hand_delta := 0.016
var grabbed_left: RigidBody3D
var grabbed_right: RigidBody3D
var left_last_position := Vector3.ZERO
var right_last_position := Vector3.ZERO
var left_velocity := Vector3.ZERO
var right_velocity := Vector3.ZERO

func update_hands(left: Node3D, right: Node3D, delta: float) -> void:
	left_hand = left
	right_hand = right
	hand_delta = max(delta, 0.001)
	_update_hand_velocity()
	_update_grab(0, left_hand)
	_update_grab(1, right_hand)

func _update_hand_velocity() -> void:
	if is_instance_valid(left_hand) and left_hand.has_method("get_palm_world_position"):
		var p: Vector3 = left_hand.get_palm_world_position()
		left_velocity = (p - left_last_position) / hand_delta if left_last_position != Vector3.ZERO else Vector3.ZERO
		left_last_position = p
	if is_instance_valid(right_hand) and right_hand.has_method("get_palm_world_position"):
		var p: Vector3 = right_hand.get_palm_world_position()
		right_velocity = (p - right_last_position) / hand_delta if right_last_position != Vector3.ZERO else Vector3.ZERO
		right_last_position = p

func _update_grab(side: int, hand: Node3D) -> void:
	if not is_instance_valid(hand) or not hand.has_method("get_pinch_strength"):
		return
	if not hand.visible:
		_release(side)
		return
	var pinch := float(hand.get_pinch_strength())
	var current: RigidBody3D = grabbed_left if side == 0 else grabbed_right

	if is_instance_valid(current):
		if pinch <= release_threshold:
			_release(side)
		else:
			_hold_object(current, hand)
		return

	if pinch < pinch_threshold:
		return

	var target := _find_grabbable(hand)
	if target != null:
		_grab(side, target, hand)

func _find_grabbable(hand: Node3D) -> RigidBody3D:
	var palm: Vector3 = hand.get_palm_world_position()
	var index_tip: Vector3 = hand.get_index_tip_world_position()
	var best: RigidBody3D
	var best_distance := grab_radius
	for node in get_tree().get_nodes_in_group("grabbable"):
		if node is RigidBody3D and not node.freeze:
			var body := node as RigidBody3D
			var d := min(body.global_position.distance_to(palm), body.global_position.distance_to(index_tip))
			if d <= best_distance:
				best = body
				best_distance = d
	return best

func _grab(side: int, body: RigidBody3D, hand: Node3D) -> void:
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	_hold_object(body, hand)
	if side == 0:
		grabbed_left = body
	else:
		grabbed_right = body

func _hold_object(body: RigidBody3D, hand: Node3D) -> void:
	var target: Vector3 = hand.get_index_tip_world_position()
	body.global_position = target

func _release(side: int) -> void:
	var body: RigidBody3D = grabbed_left if side == 0 else grabbed_right
	if not is_instance_valid(body):
		if side == 0:
			grabbed_left = null
		else:
			grabbed_right = null
		return
	body.freeze = false
	var velocity := left_velocity if side == 0 else right_velocity
	body.linear_velocity = velocity * throw_velocity_scale
	body.angular_velocity = Vector3.ZERO
	if side == 0:
		grabbed_left = null
	else:
		grabbed_right = null
