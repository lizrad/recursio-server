extends KinematicBody

var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var rotation_velocity := 0.0

func apply_player_state(player_state, delta):
	var goal_position = player_state["P"]
	var current_position = transform.origin
	var current_velocity = (goal_position-current_position)/delta
	var new_velocity = move_and_slide(current_velocity)
	acceleration = (new_velocity-velocity)/delta
	velocity = new_velocity
	rotation_velocity = (player_state["R"]-rotation.y)/delta
	rotation.y = player_state["R"]
