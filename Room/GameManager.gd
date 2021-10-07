extends Node
class_name GameManager

signal round_started(round_index, warm_up)
signal prep_phase_over(round_index)
signal round_ended(round_index)

# A delay before the round starts
var _warm_up_delay: float = 2.0
# The index of the current round
var _round_index: int = 0
# The length of one round
var _round_length: float = 10.0


var _round_timer: float = 0.0
var _round_in_progress: bool = false

func _ready():
	set_process(false)

# Game-State behavior 
func _process(delta):
	if _round_timer == 0:
		_round_index += 1
		# DEBUG: Add winning condition for completing a game
		if _round_index >= 5:
			self.set_process(false)
			return
		_start_round()
	
	_round_timer += delta	
	
	# Pre-Round
	if _round_timer < _warm_up_delay:
		return
	
	# Round Start
	if _round_timer >= _warm_up_delay and not _round_in_progress:
		_round_in_progress = true
		_prep_phase_over()
		return
	
	# Round End
	if _round_timer >= _warm_up_delay + _round_length and _round_in_progress:
		_round_in_progress = false
		_end_round()
		_round_timer = 0



# Called when the room is full
func start_game():
	Logger.info("Game started", "gameplay")
	# DEGUB: Replace with 'All players are ready' functionality
	yield (get_tree().create_timer(3), "timeout")
	set_process(true)



# Called every round
func _start_round():
	Logger.info("Round " + str(_round_index) + " started", "gameplay")
	emit_signal("round_started", _round_index, _warm_up_delay)
	
func _prep_phase_over():
	Logger.info("Prep Phase "+ str(_round_index) + " over", "gameplay")
	emit_signal("prep_phase_over", _round_index)

func _end_round():
	Logger.info("Round " + str(_round_index) + " ended", "gameplay")
	emit_signal("round_ended", _round_index)
