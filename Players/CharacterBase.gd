extends KinematicBody
class_name CharacterBase

onready var Server = get_node("/root/Server")
onready var dash_confirmation_timer = get_node("DashConfirmationTimer")
onready var dash_activation_timer = get_node("DashActivationTimer")
var id := -1
var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var rotation_velocity := 0.0
var last_player_state = {}

var dash_charges = Constants.get_value("dash", "charges")
var dash_cooldown = Constants.get_value("dash", "cooldown")
var dash_start_times = []

var _waiting_for_dash := false
var _collected_illegal_movement_if_not_dashing := Vector3.ZERO
var _collected_illegal_movement:= Vector3.ZERO
var _dashing :=false
var _wait_for_player_to_correct = 0

func _ready():
	for i in range(dash_charges):
		dash_start_times.append(-1)
	dash_confirmation_timer.connect("timeout",self,"_on_dash_confirmation_timeout")
	#TODO: value found by testing think about correct value
	dash_confirmation_timer.wait_time = 0.5
	dash_activation_timer.connect("timeout",self, "_on_dash_activation_timeout")
	#TOOD: value found by testing think about correct value
	dash_activation_timer.wait_time = 1.25

func correct_illegal_movement():
	#using epsilon here to make it a bit fuzzy, so random networking and floating point errors etc. are ignored
	var epsilon = 0.1
	if _collected_illegal_movement.length()>epsilon:
		Logger.info("Correcting illegal movement of "+str(_collected_illegal_movement),"movement validation")
		#TODO: if collected_illegal_movement is too big kick bc player had to have cheated
		transform.origin -= _collected_illegal_movement
		_collected_illegal_movement = Vector3.ZERO
		#TODO: adapt to latency or something i dunno once we know it on server, just a random magic number that worked for now
		_wait_for_player_to_correct = 120

func apply_player_state(player_state, physics_delta):
	if _wait_for_player_to_correct<=0:
		_validate_position(player_state, physics_delta)
	else:
		_wait_for_player_to_correct-=1
	
	# TODO: validate attack data
	
	var last_position
	if last_player_state.empty():
		last_position = transform.origin
	else:
		last_position = last_player_state["P"]
	
	var next_position = player_state["P"]

	var physics_velocity = (next_position - last_position) / physics_delta
	var new_velocity = move_and_slide(player_state["V"])
	acceleration = (new_velocity - velocity) / physics_delta
	velocity = new_velocity
	rotation_velocity = (player_state["R"] - rotation.y) / physics_delta
	rotation.y = player_state["R"]
	last_player_state = player_state

func _valid_dash_start_time(time):
	for i in range(dash_charges):
		if dash_start_times[i] == -1:
			dash_start_times[i]=time
			return true
		if time-dash_start_times[i] >= dash_cooldown*1000:
			dash_start_times[i]=time
			return true
	return false

func update_dash_state(dash_state):
	if dash_state["S"]==1:
		if _valid_dash_start_time(dash_state["T"]):
			Logger.info("Dash received", "movement validation")
			_dashing = true
			dash_activation_timer.start()
			#reset collection of illegal movement if we get confirmation of dash
			_waiting_for_dash = false
			_collected_illegal_movement_if_not_dashing = Vector3.ZERO
		else:
			Logger.info("Illegal dash","movement validation")

func _validate_position(player_state, physics_delta):
	if last_player_state.empty():
		return
	var new_player_packet = player_state["T"] != last_player_state["T"]
	if not new_player_packet:
		return
	
	var goal_position = player_state["P"]
	var start_position = last_player_state["P"]
	var distance = goal_position - start_position
	
	var packet_number_diff = -1
	#checking if ids are currently looping
	if player_state["I"]>last_player_state["I"]:
		packet_number_diff = player_state["I"]-last_player_state["I"]
	else:
		packet_number_diff = player_state["I"]+Constants.get_value("network", "max_packet_id")-last_player_state["I"]
	
	var server_client_tick_rate_ratio = Constants.get_value("network", "server_client_tick_rate_ratio")
	var delta = physics_delta*server_client_tick_rate_ratio*packet_number_diff
	var current_velocity = distance / delta
	#values found by testing
	#TODO: values were fuzzy, find factually true values
	var max_normal_speed := 3.5
	var max_dash_speed := 22.5
	#illegal movement regardless of wether player is dashing or not
	if current_velocity.length() > max_dash_speed:
		#Logger.debug("Velocity bigger than max_dash_speed","movement validation")
		var normalized_velocity = current_velocity.normalized()
		var illegal_velocity_length = current_velocity.length()-max_dash_speed
		_collected_illegal_movement += (normalized_velocity*illegal_velocity_length)*delta;
		current_velocity-=normalized_velocity*illegal_velocity_length
	#illegal movement if not dashingw
	if current_velocity.length() > max_normal_speed:
		#start illegal movement collection and timer waiting for dash confirmation
		if not _waiting_for_dash and not _dashing:
			dash_confirmation_timer.start()
			_waiting_for_dash = true
		#collect excess movement in case we have to restore  movement after the timer runs out
		if _waiting_for_dash:
			var normalized_velocity = current_velocity.normalized()
			var illegal_velocity_length = current_velocity.length()-max_normal_speed
			Logger.debug("Adding to illegal movement","movement validation")
			_collected_illegal_movement_if_not_dashing += normalized_velocity*illegal_velocity_length*delta;

func _on_dash_activation_timeout():
	Logger.info("Turn off dashing", "movement validation")
	_dashing = false

func _on_dash_confirmation_timeout():
	if _waiting_for_dash:
		_waiting_for_dash = false
		_collected_illegal_movement += _collected_illegal_movement_if_not_dashing
		_collected_illegal_movement_if_not_dashing = Vector3.ZERO
