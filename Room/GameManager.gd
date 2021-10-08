extends Node
class_name GameManager

# Round started signal
# Includes the index of the round and a latency delay
signal round_started(round_index, latency_delay)

# Preperation phase ended signal
# Includes the round index
signal prep_phase_ended(round_index)

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

# The length of one round
onready var _game_phase_length: float = Constants.get_value("gameplay", "game_phase_time")

# The index of the current round
var _round_index: int = 0


var _round_timer: float = 0.0

var _round_in_progress: bool = false


var _game_phase_in_progress: bool = false

func _ready():
	set_process(false)


func _reset():
	_round_index = 0
	_round_timer = 0.0
	_round_in_progress = false
	_game_phase_in_progress = false
	set_process(false)
	
# Game-State behavior 
func _process(delta):
	if _round_timer == 0:
		_round_index += 1
		_on_round_start()
	
	_round_timer += delta

	var time_to_game_phase: float = _prep_phase_time + _latency_delay
	
	# Pre-Game-Phase -> Do nothing
	if _round_timer < time_to_game_phase:
		return
	
	# Game-Phase Start
	if _round_timer >= time_to_game_phase and not _game_phase_in_progress:
		_game_phase_in_progress = true
		_on_prep_phase_end()
		return
	
	# Game-Phase/Round End
	if _round_timer >= time_to_game_phase + _game_phase_length and _game_phase_in_progress:
		_game_phase_in_progress = false
		_on_round_end()
		_round_timer = 0


# Called when the room is full
func start_game():
	for i in range(level.get_capture_points().size()):
		level.get_capture_points()[i].connect("capture_status_changed", self, "_on_capture_status_changed", [i])
		level.get_capture_points()[i].connect("captured", self, "_on_captured", [i])
		level.get_capture_points()[i].connect("capture_team_changed",self, "_on_capture_team_changed", [i])
		level.get_capture_points()[i].connect("capture_lost",self, "_on_capture_lost", [i])
	Logger.info("Game started", "gameplay")
	# DEGUB: Replace with 'All players are ready' functionality
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
	Logger.info("Round " + str(_round_index) + " started", "gameplay")
	emit_signal("round_started", _round_index, _latency_delay)
	
# Called when the preperation phase ends
func _on_prep_phase_end():
	Logger.info("Prep Phase "+ str(_round_index) + " ended", "gameplay")
	emit_signal("prep_phase_ended", _round_index)

# Called when the round ends
func _on_round_end():
	Logger.info("Round " + str(_round_index) + " ended", "gameplay")
	emit_signal("round_ended", _round_index)
