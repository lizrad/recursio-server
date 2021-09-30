extends KinematicBody

onready var Server = get_node("/root/Server")
onready var dash_confirmation_timer = get_node("DashConfirmationTimer")
var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var rotation_velocity := 0.0
var last_player_state = {}

var waiting_for_dash := false
var collected_illegal_movement := Vector3.ZERO
var dashing :=false
var dash_start_time := -1.0
var dash_was_unconfirmed = false
var do_once = false

func _ready():
	dash_confirmation_timer.connect("timeout",self,"_on_dash_unconfirmed")

func apply_player_state(player_state, physics_delta):
	if dash_was_unconfirmed:
		dash_was_unconfirmed = false
		print("restoring illegal movement of: "+ str(collected_illegal_movement))
		print("positon before: "+str(transform.origin))
		transform.origin -= collected_illegal_movement
		print("position afterwards: "+ str(transform.origin))
		collected_illegal_movement = Vector3.ZERO
		waiting_for_dash = false
		do_once = true
	if not do_once:
		_validate_position(player_state)
	else:
		print(transform.origin)
		
	
	var last_position
	if last_player_state.empty():
		last_position = transform.origin
	else:
		last_position = last_player_state["P"]
	
	# TODO: validate attack data
	var next_position = player_state["P"]

	var physics_velocity = (next_position - last_position) / physics_delta
	var new_velocity = move_and_slide(physics_velocity)
	acceleration = (new_velocity - velocity) / physics_delta
	velocity = new_velocity
	rotation_velocity = (player_state["R"] - rotation.y) / physics_delta
	rotation.y = player_state["R"]
	
	last_player_state = player_state


func update_dash_state(dash_state):
	#TODO: validate if dash is possible
	#TODO: automatically turn dash_state of if time runs out
	if dash_state["S"]==1:
		dashing = true
		dash_start_time = dash_state["T"]
	else:
		dashing = false
		dash_start_time = -1



func _validate_position(player_state):
	if last_player_state.empty():
		return
	var delta = (player_state["T"] - last_player_state["T"]) / 1000.0
	if delta<=0:
		return
	
	
	var physics_frame_delta = 0.01666666
	delta = delta if delta>=physics_frame_delta else physics_frame_delta
	var goal_position = player_state["P"]
	var start_position = last_player_state["P"]
	var distance = goal_position - start_position
	var current_velocity = distance / delta
	
	var max_normal_speed := 3.1
	if not waiting_for_dash:
		if current_velocity.length() > max_normal_speed:		
			print("Cheats!")
			dash_confirmation_timer.start(0)
			waiting_for_dash = true
	if waiting_for_dash:
			var normalized_velocity = current_velocity.normalized()
			var illegal_velocity_length = current_velocity.length()-max_normal_speed
			if illegal_velocity_length>0:
				collected_illegal_movement += normalized_velocity*illegal_velocity_length;

func _on_dash_unconfirmed():
	dash_was_unconfirmed = true
