extends Node
class_name WorldStateManager

signal on_world_state_update(world_state)

onready var _server = get_node("/root/Server")
onready var _player_manager = get_node("../PlayerManager")

#
# World States are structured like this:
# {
# 	"T": timestamp,
# 	"S": {
#		player_id: {
# 			"P": position,
# 			"V": velocity,
# 			"A": acceleration,
# 			"R": rotation,
# 			"H": rotationvelocity
# 		}
# 	}
# }
#

func _physics_process(delta):
	if _server.player_amount > 0:
		var world_state = define_world_state()
		_server.send_world_state(world_state)

func define_world_state():
	var time = _server.get_server_time()
	var player_states = {}
	for player_id in _player_manager.player_states:
		player_states[player_id] = _player_manager.player_states[player_id]
	
	var world_state = {}
	
	world_state["T"] = time
	world_state["S"] = player_states
	
	#TODO add other necessary information
	
	return world_state
