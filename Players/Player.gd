extends CharacterBase
class_name Player

var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var rotation_velocity := 0.0
var last_player_state = {}

onready var dash_activation_timer = get_node("DashActivationTimer")
var dash_charges = Constants.get_value("dash", "charges")
var dash_cooldown = Constants.get_value("dash", "cooldown")
var dash_start_times = []

onready var dash_confirmation_timer = get_node("DashConfirmationTimer")
var _waiting_for_dash := false
var _collected_illegal_movement_if_not_dashing := Vector3.ZERO
var _collected_illegal_movement := Vector3.ZERO
var _dashing := false
var wait_for_player_to_correct = 0

var _recording = false
var action_last_frame
var gameplay_record = {}

var can_move: bool = false

var action_manager


func reset():
	_recording=false
	gameplay_record.clear()
	velocity = Vector3.ZERO
	acceleration = Vector3.ZERO
	rotation_velocity = 0.0
	last_player_state = {}
	for i in range(dash_start_times.size()):
		dash_start_times[i]=-1
	_waiting_for_dash = false
	_collected_illegal_movement_if_not_dashing= Vector3.ZERO
	_collected_illegal_movement = Vector3.ZERO
	_dashing = false
	wait_for_player_to_correct = 0
	can_move = false
	ghost_index = 0

	
func start_recording():
	gameplay_record.clear()
	_recording = true
	#time the recording started
	gameplay_record["T"] = Server.get_server_time()
	#index of the ghost
	gameplay_record["G"] = ghost_index
	#TODO: connect weapon information recording with actuall weapon system when ready
	gameplay_record["W"] = action_manager.ActionType.HITSCAN \
			if ghost_index != Constants.get_value("ghosts", "wall_placing_ghost_index") \
			else action_manager.ActionType.WALL
	#array of gameplay data per frame
	gameplay_record["F"] = []

func stop_recording():
	_recording = false


func _create_record_frame(time, position, rotation, attack = action_manager.Trigger.NONE, dash = action_manager.Trigger.NONE) -> Dictionary:
	var frame = {"T": time, "P": position, "R": rotation, "A": attack, "D": dash}
	return frame


func _ready():
	action_last_frame = action_manager.Trigger.NONE
	
	for i in range(dash_charges):
		dash_start_times.append(-1)
	dash_confirmation_timer.connect("timeout", self, "_on_dash_confirmation_timeout")
	#TODO: value found by testing think about correct value
	dash_confirmation_timer.wait_time = 0.5
	dash_activation_timer.connect("timeout", self, "_on_dash_activation_timeout")
	#TOOD: value found by testing think about correct value
	dash_activation_timer.wait_time = 1.25


func apply_player_state(player_state, physics_delta):
	if wait_for_player_to_correct <= 0:
		_validate_position(player_state, physics_delta)
	else:
		wait_for_player_to_correct -= 1

	# TODO: validate attack data



	var last_position
	if last_player_state.empty():
		last_position = transform.origin
	else:
		last_position = last_player_state["P"]

	# Ignore movement if player cannot move
	if can_move:
		var next_position = player_state["P"]
		var physics_velocity = (next_position - last_position) / physics_delta
		var new_velocity = move_and_slide(player_state["V"])
		acceleration = (new_velocity - velocity) / physics_delta
		velocity = new_velocity
		rotation_velocity = (player_state["R"] - rotation.y) / physics_delta
		rotation.y = player_state["R"]

	if _recording:
		gameplay_record["F"].append(
			_create_record_frame(Server.get_server_time(), transform.origin, rotation.y, action_last_frame)
		)
		action_last_frame = action_manager.Trigger.NONE

	last_player_state = player_state


func correct_illegal_movement():
	#using epsilon here to make it a bit fuzzy, so random networking and floating point errors etc. are ignored
	var epsilon = 0.1
	if _collected_illegal_movement.length() > epsilon:
		Logger.info(
			"Correcting illegal movement of " + str(_collected_illegal_movement),
			"movement_validation"
		)
		#TODO: if collected_illegal_movement is too big kick bc player had to have cheated
		transform.origin -= _collected_illegal_movement
		_collected_illegal_movement = Vector3.ZERO
		#TODO: adapt to latency or something i dunno once we know it on server, just a random magic number that worked for now
		wait_for_player_to_correct = 120


func update_dash_state(dash_state):
	if dash_state["S"] == 1:
		if _valid_dash_start_time(dash_state["T"]):
			Logger.info("Dash received", "movement_validation")
			_dashing = true
			dash_activation_timer.start()
			#reset collection of illegal movement if we get confirmation of dash
			_waiting_for_dash = false
			_collected_illegal_movement_if_not_dashing = Vector3.ZERO
			
			if _recording:
				var i = max(0,gameplay_record["F"].size() - 1)
				while gameplay_record["F"][i]["T"] > dash_state["T"] && i >= 0:
					i -= 1
				gameplay_record["F"][i]["D"] = action_manager.Trigger.SPECIAL_MOVEMENT_START
		else:
			Logger.info("Illegal dash", "movement_validation")
	#TODO: this does not work correctly as the client only sends dash_state 0 a long time after it actually has ended
	else:
		if _recording:
			var i = gameplay_record["F"].size() - 1
			while gameplay_record["F"][i]["T"] > dash_state["T"] && i >= 0:
				i -= 1
			gameplay_record["F"][i]["D"] = action_manager.Trigger.SPECIAL_MOVEMENT_END


func _valid_dash_start_time(time):
	for i in range(dash_charges):
		if dash_start_times[i] == -1:
			dash_start_times[i] = time
			return true
		if time - dash_start_times[i] >= dash_cooldown * 1000:
			dash_start_times[i] = time
			return true
	return false


func _validate_position(player_state, physics_delta):
	if last_player_state.empty():
		return
	var new_player_packet = player_state["T"] != last_player_state["T"]
	if not new_player_packet:
		return

	var goal_position = player_state["P"]
	var start_position = last_player_state["P"]
	var distance = goal_position - start_position
	
	# Don't let the player move in prep-phase
	if not can_move:
		goal_position = start_position
		distance = Vector3.ZERO

	var packet_number_diff = -1
	#checking if ids are currently looping
	if player_state["I"] > last_player_state["I"]:
		packet_number_diff = player_state["I"] - last_player_state["I"]
	else:
		packet_number_diff = (
			player_state["I"]
			+ Constants.get_value("network", "max_packet_id")
			- last_player_state["I"]
		)

	var server_client_tick_rate_ratio = Constants.get_value(
		"network", "server_client_tick_rate_ratio"
	)
	var delta = physics_delta * server_client_tick_rate_ratio * packet_number_diff
	var current_velocity = distance / delta
	#values found by testing
	#TODO: values were fuzzy, find factually true values
	var max_normal_speed := 3.5
	var max_dash_speed := 22.5
	#illegal movement regardless of wether player is dashing or not
	if current_velocity.length() > max_dash_speed:
		#Logger.debug("Velocity bigger than max_dash_speed","movement_validation")
		var normalized_velocity = current_velocity.normalized()
		var illegal_velocity_length = current_velocity.length() - max_dash_speed
		_collected_illegal_movement += (normalized_velocity * illegal_velocity_length) * delta
		current_velocity -= normalized_velocity * illegal_velocity_length
	#illegal movement if not dashingw
	if current_velocity.length() > max_normal_speed:
		#start illegal movement collection and timer waiting for dash confirmation
		if not _waiting_for_dash and not _dashing:
			dash_confirmation_timer.start()
			_waiting_for_dash = true
		#collect excess movement in case we have to restore  movement after the timer runs out
		if _waiting_for_dash:
			var normalized_velocity = current_velocity.normalized()
			var illegal_velocity_length = current_velocity.length() - max_normal_speed
			Logger.debug("Adding to illegal movement", "movement_validation")
			_collected_illegal_movement_if_not_dashing += (
				normalized_velocity
				* illegal_velocity_length
				* delta
			)


func _on_dash_activation_timeout():
	Logger.info("Turn off dashing", "movement_validation")
	_dashing = false


func _on_dash_confirmation_timeout():
	if _waiting_for_dash:
		_waiting_for_dash = false
		_collected_illegal_movement += _collected_illegal_movement_if_not_dashing
		_collected_illegal_movement_if_not_dashing = Vector3.ZERO


# TODO: Move partially to CharacterBase?
func receive_hit():
	emit_signal("hit")
