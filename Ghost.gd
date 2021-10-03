extends CharacterBase
class_name Ghost

var _record := {}
var _start_time := -1
var _replaying = false
var _current_frame = -1
var dashing = false

func init(gameplay_record: Dictionary):
	_record = gameplay_record.duplicate(true)

func start_replay():
	_start_time = Server.get_server_time()
	_replaying = true
	_current_frame = 0

func _physics_process(delta):
	if not _replaying:
		return
	if _current_frame >= _record["F"].size():
		return
	var time_diff = _start_time - _record["T"]
	if _record["F"][_current_frame]["T"]+time_diff>=Server.get_server_time():
		_apply_frame(_record["F"][_current_frame])
		_current_frame+=1

#TODO: use move_and_slide for this
#TODO: also apply weapon and melee attacks
func _apply_frame(frame: Dictionary):
	Logger.debug("Moving ghost to "+str(frame["P"]), "ghost")
	transform.origin = frame["P"]
	rotation.y = frame["R"]
	if frame["D"]==DASH_START:
		dashing = true
	if frame["D"]== DASH_END:
		dashing = false
