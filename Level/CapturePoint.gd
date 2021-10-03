class_name CapturePoint
extends Spatial

signal capture_team_changed(team_id)
signal captured(team_id)
signal capture_lost(team_id)

var capture_progress: float = 0
# Team that currently 'owns' the capturing point
var capture_team: int = -1
# Team that currently takes over the capturing point
var _current_capture_team: int = -1

var _being_captured: bool = false
var _capturing_paused: bool = false
var _is_captured: bool = false
var _capturing_entities := [0, 0]

var capture_speed: float = 1.0
var recapture_speed: float = 2.0
var capture_release_speed: float = 0.5
var capture_time: float = 3.0


func _ready():
	$Area.connect("body_entered", self, "_on_body_entered_area")
	$Area.connect("body_exited", self, "_on_body_exited_area")


func _process(delta):
	if _capturing_paused:
		return

	if _being_captured:
		if _current_capture_team == capture_team:
			# Current team increases the capture process
			_capture(delta / capture_time)
		else:
			# Enemy team decreases capture process and takes over point
			_recapture(delta / capture_time)
	else:
		# No team is capturing -> progress decreases
		_release(delta / capture_time)


func reset_point() -> void:
	_capturing_entities[0] = 0
	_capturing_entities[1] = 0
	capture_team = -1
	capture_progress = 0
	_check_capturing_status()


func _capture(delta: float):
	capture_progress = min(1, capture_progress + delta * capture_speed)
	if not _is_captured:
		Logger.debug("Capture progress: " + str(capture_progress), "capture point")
	if capture_progress == 1 and not _is_captured:
		_is_captured = true
		Logger.info("Point captured by " + str(capture_team), "capture point")
		emit_signal("captured", capture_team)


func _recapture(delta: float):
	if capture_progress > 0:
		capture_progress = max(0, capture_progress - delta * recapture_speed)
		Logger.debug("Recapture progress: " + str(capture_progress), "capture point")
	else:
		Logger.info("Capturing team changed to  " + str(_current_capture_team), "capture point")
		_switch_capturing_teams(_current_capture_team)


func _release(delta: float):
	if capture_progress > 0:
		if capture_progress == 1:
			_is_captured = false
			emit_signal("capture_lost", capture_team)
			Logger.info("Point lost by " + str(capture_team), "capture point")
		capture_progress = max(0, capture_progress - delta * capture_release_speed)
		Logger.debug("Release progress: " + str(capture_progress), "capture point")
	elif capture_team != -1:
		# Process reached zero with no team currently capturing
		_reset_capture_point()


func _reset_capture_point():
	_capturing_entities[0] = 0
	_capturing_entities[1] = 0
	capture_team = -1
	capture_progress = 0
	_check_capturing_status()
	emit_signal("capture_team_changed", -1)


func _switch_capturing_teams(new_team: int):
	capture_team = new_team
	emit_signal("capture_team_changed", new_team)


func _on_body_entered_area(body):
	if body is CharacterBase:
		start_capturing(body.game_id)


func start_capturing(game_id: int):
	_capturing_entities[game_id] += 1
	_check_capturing_status()


func _check_capturing_status():
	_capturing_paused = _capturing_entities[0] > 0 and _capturing_entities[1] > 0
	_being_captured = _capturing_entities[0] > 0 or _capturing_entities[1] > 0
	_current_capture_team = 0 if _capturing_entities[0] > _capturing_entities[1] else 1


func _on_body_exited_area(body):
	if body is CharacterBase:
		stop_capturing(body.game_id)


func stop_capturing(game_id: int):
	_capturing_entities[game_id] -= 1
	_check_capturing_status()
