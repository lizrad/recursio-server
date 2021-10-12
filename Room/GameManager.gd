extends Node
class_name GameManager

# Round started signal
# Includes the index of the round and a latency delay
signal round_started(round_index)

signal countdown_halfway_point
# Game phase started signal
# Includes the round index
signal game_phase_started(round_index)

# Round ended signal
# Inculdes the round index
signal round_ended(round_index)


signal capture_point_team_changed(team_id, capture_point)
signal capture_point_captured(team_id, capture_point)
signal capture_point_status_changed(capture_progress, team_id, capture_point)
signal capture_point_capture_lost(team_id, capture_point)
signal game_result(team_id)

var level

# A delay before the prep phase starts to counteract latency
onready var _latency_delay: float = Constants.get_value("gameplay", "latency_delay")

# The length of the preperation phase
onready var _prep_phase_time: float = Constants.get_value("gameplay", "prep_phase_time")

# The length of the countdown phase
onready var _countdown_phase_time: int = Constants.get_value("gameplay", "countdown_phase_seconds")

# The length of one round
onready var _game_phase_length: float = Constants.get_value("gameplay", "game_phase_time")

# The index of the current round
var round_index: int = 0


var _round_timer: float = 0.0

var _round_in_progress: bool = false
var _before_second_half_of_countdown: bool = true


var countdown_halfway_point_reached: bool = false
var game_phase_in_progress: bool = false

func _ready():
	set_process(false)


func reset():
	round_index = 0
	_round_timer = 0.0
	_round_in_progress = false
	game_phase_in_progress = false
	countdown_halfway_point_reached = false
	_before_second_half_of_countdown = true
	for i in range(level.get_capture_points().size()):
		level.get_capture_points()[i].disconnect("capture_status_changed", self, "_on_capture_status_changed")
		level.get_capture_points()[i].disconnect("captured", self, "_on_captured")
		level.get_capture_points()[i].disconnect("capture_team_changed",self, "_on_capture_team_changed")
		level.get_capture_points()[i].disconnect("capture_lost",self, "_on_capture_lost")
	set_process(false)
	
# Game-State behavior 
func _process(delta):
	if _round_timer == 0:
		round_index += 1
		_on_round_start()
	
	_round_timer += delta

	var time_to_game_phase: float =  _prep_phase_time + _latency_delay
	
	# Pre-Game-Phase -> Do nothing
	if _round_timer < time_to_game_phase:
		return
	
	# Wait for half the countdown time
	if _round_timer < time_to_game_phase + float(_countdown_phase_time)*0.5:
		return
	
	# Halfway through the countdown send picks to clients
	if _round_timer<time_to_game_phase + _countdown_phase_time and not countdown_halfway_point_reached:
		_before_second_half_of_countdown = false
		countdown_halfway_point_reached = true
		_countdown_halfway_done()
		return
	
	# Game-Phase Start
	if _round_timer >= time_to_game_phase +_countdown_phase_time and not game_phase_in_progress:
		game_phase_in_progress = true
		_game_phase_start()
		return
	
	# Game-Phase/Round End
	if _round_timer >= time_to_game_phase +_countdown_phase_time + _game_phase_length and game_phase_in_progress:
		game_phase_in_progress = false
		countdown_halfway_point_reached = false
		_on_round_end()
		_round_timer = 0
		_before_second_half_of_countdown = true


# Called when the room is full
func start_game():
	Logger.info("Game started", "gameplay")
	for i in range(level.get_capture_points().size()):
		level.get_capture_points()[i].connect("capture_status_changed", self, "_on_capture_status_changed", [i])
		level.get_capture_points()[i].connect("captured", self, "_on_captured", [i])
		level.get_capture_points()[i].connect("capture_team_changed",self, "_on_capture_team_changed", [i])
		level.get_capture_points()[i].connect("capture_lost",self, "_on_capture_lost", [i])
	# DEBUG: Replace with 'All players are ready' functionality
	yield (get_tree().create_timer(3), "timeout")
	set_process(true)

func _on_capture_status_changed(capture_progress, team_id, capture_point):
	emit_signal("capture_point_status_changed", capture_progress, team_id, capture_point)

func _on_captured(team_id, capture_point):
	emit_signal("capture_point_captured", team_id, capture_point)
	_check_for_win()

func _on_capture_team_changed(team_id, capture_point):
	emit_signal("capture_point_team_changed", team_id, capture_point)

func _on_capture_lost(team_id, capture_point):
	emit_signal("capture_point_capture_lost", team_id, capture_point)

func _check_for_win():
	var captured_points_score = [0,0]
	for capture_point in level.get_capture_points():
		if capture_point.capture_progress==1:
			captured_points_score[capture_point.capture_team]+=1
	
	var win_score = floor(level.get_capture_points().size()*0.5)+1
	for i in range(captured_points_score.size()):
		if captured_points_score[i] >= win_score:
			emit_signal("game_result", i)
	
# Called when the round starts
func _on_round_start():
	Logger.info("Round " + str(round_index) + " started", "gameplay")
	emit_signal("round_started", round_index)
	
# Called when the preperation phase ends
func _game_phase_start():
	Logger.info("Game Phase "+ str(round_index) + " started", "gameplay")
	level.toggle_capture_points(true)
	emit_signal("game_phase_started", round_index)

func _countdown_halfway_done():
	Logger.info("Countdown halfway done", "gameplay")	
	emit_signal("countdown_halfway_point")
	
func _on_round_end():
	Logger.info("Round " + str(round_index) + " ended", "gameplay")
	level.reset()
	emit_signal("round_ended", round_index)
