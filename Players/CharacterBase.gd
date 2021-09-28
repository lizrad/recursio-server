extends KinematicBody

onready var Server = get_node("/root/Server")
var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var rotation_velocity := 0.0
var last_player_state = {}
var _highest_velocity := 0.0


func apply_player_state(player_state, physics_delta):
	_validate_position(player_state)

	# TODO: validate attack data

	var goal_position = player_state["P"]
	var current_position = transform.origin

	var physics_velocity = (goal_position - current_position) / physics_delta
	var new_velocity = move_and_slide(physics_velocity)
	acceleration = (new_velocity - velocity) / physics_delta
	velocity = new_velocity
	rotation_velocity = (player_state["R"] - rotation.y) / physics_delta
	rotation.y = player_state["R"]


#TODO: fix this
func _validate_position(player_state):
	if last_player_state.empty():
		last_player_state = player_state
		return
	var goal_position = player_state["P"]
	var start_position = last_player_state["P"]
	var delta = (player_state["T"] - last_player_state["T"]) / 1000.0
	if delta <= 0:
		return
	var distance = goal_position - start_position
	var current_velocity = distance / delta
	if _highest_velocity < current_velocity.length():
		_highest_velocity = current_velocity.length()
	print(_highest_velocity)
	last_player_state = player_state
