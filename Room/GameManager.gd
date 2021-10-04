extends Node
class_name GameManager

signal round_started(round_index, warm_up)
signal round_ended(round_index)

# A delay before the round starts
var _warm_up_delay: float = 2.0
# The index of the current round
var _round_index: int = 0
# The length of one round
var _round_length: float = 10.0


var _round_timer: float = 0.0
var _round_in_progress: bool = false


# Game-State behavior 
func _process(delta):
	_round_timer += delta
	
	# DEBUG: Add winning condition for completing a game
	if _round_index >= 5:
		self.set_process(false)
		return
	
	# Pre-Round
	if _round_timer < _warm_up_delay:
		return
	
	# Round Start
	if _round_timer >= _warm_up_delay and not _round_in_progress:
		_round_in_progress = true
		_round_index += 1
		_start_round()
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
	_start_round()



# Called every round
func _start_round():
	Logger.info("Round " + str(_round_index) + " started", "gameplay")
	emit_signal("round_started", _round_index, _warm_up_delay)
	


func _end_round():
	Logger.info("Round " + str(_round_index) + " ended", "gameplay")
	emit_signal("round_ended", _round_index)
