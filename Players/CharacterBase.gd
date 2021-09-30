extends KinematicBody

onready var Server = get_node("/root/Server")
onready var dash_confirmation_timer = get_node("DashConfirmationTimer")
onready var dash_activation_timer = get_node("DashActivationTimer")

var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var rotation_velocity := 0.0
var last_player_state = {}

var dash_charges = Constants.get_value("dash", "charges")
var dash_cooldown = Constants.get_value("dash", "cooldown")

var dash_cooldown_timers = []

var _waiting_for_dash := false
var _collected_illegal_movement_if_not_dashing := Vector3.ZERO
var _collected_illegal_movement:= Vector3.ZERO
var _dashing :=false
var _wait_for_player_to_correct = 0

func _ready():
	dash_confirmation_timer.connect("timeout",self,"_on_dash_confirmation_timeout")
	#TODO: value found by testing think about correct value
	dash_confirmation_timer.wait_time = 0.5
	dash_activation_timer.connect("timeout",self, "_on_dash_activation_timeout")
	#TOOD: value found by testing think about correct value
	dash_activation_timer.wait_time = 1.0
	
	for i in range(dash_charges):
		var timer = Timer.new()
		#TODO: timer.wait_time has to adapt to latency so they actually stop at the same time on client and server
		timer.wait_time = (dash_cooldown-0.5)
		timer.autostart = false
		timer.one_shot = true
		timer.connect("timeout", self, "_on_dash_cooldown_timeout")
		self.add_child(timer)
		dash_cooldown_timers.append(timer)

func correct_illegal_movement():
	if _collected_illegal_movement.length()>0:
		#TODO: if collected_illegal_movement is too big kick bc player had to have cheated
		transform.origin -= _collected_illegal_movement
		_collected_illegal_movement = Vector3.ZERO
		#TODO: adapt to latency or something i dunno once we know it on server, just a random magic number that worked for now
		_wait_for_player_to_correct = 120

func apply_player_state(player_state, physics_delta):
	if _wait_for_player_to_correct<=0:
		_validate_position(player_state)
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

func update_dash_state(dash_state):
	if dash_state["S"]==1:
		if(dash_charges>0):
			dash_charges-=1
			dash_cooldown_timers[dash_charges].start()
			_dashing = true
			dash_activation_timer.start()
			#reset collection of illegal movement if we get confirmation of dash
			_waiting_for_dash = false
			_collected_illegal_movement_if_not_dashing = Vector3.ZERO

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
	
	#values found by testing
	#TODO: values were fuzzy, find out why and fix them
	var max_normal_speed := 3.1
	var max_dash_speed := 23
	#illegal movement regardless of wether player is dashing or not
	if current_velocity.length() > max_dash_speed:
		var normalized_velocity = current_velocity.normalized()
		var illegal_velocity_length = current_velocity.length()-max_dash_speed
		_collected_illegal_movement += (normalized_velocity*illegal_velocity_length)*delta;
		current_velocity-=normalized_velocity*illegal_velocity_length
	#illegal movement if not dashing
	if current_velocity.length() > max_normal_speed:
		#start illegal movement collection and timer waiting for dash confirmation
		if not _waiting_for_dash and not _dashing:
			dash_confirmation_timer.start()
			_waiting_for_dash = true
		#collect excess movement in case we have to restore  movement after the timer runs out
		if _waiting_for_dash:
			var normalized_velocity = current_velocity.normalized()
			var illegal_velocity_length = current_velocity.length()-max_normal_speed
			_collected_illegal_movement_if_not_dashing += normalized_velocity*illegal_velocity_length*delta;

func _on_dash_activation_timeout():
	_dashing = false

func _on_dash_confirmation_timeout():
	if _waiting_for_dash:
		_waiting_for_dash = false
		_collected_illegal_movement += _collected_illegal_movement_if_not_dashing
		_collected_illegal_movement_if_not_dashing = Vector3.ZERO

func _on_dash_cooldown_timeout():
	dash_charges+=1
