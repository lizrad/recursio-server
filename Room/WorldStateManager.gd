extends Node
class_name WorldStateManager

signal world_state_updated(world_state)

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
	if _player_manager.players.size() >= 2:
		var world_state = define_world_state()
		emit_signal("world_state_updated", world_state)


func define_world_state():
	var time = _server.get_server_time()
	var player_states = {}
	for player_id in _player_manager.players:
		if not _player_manager.player_states.has(player_id):
			# We're trying to send a world state with this player before a player state has arrived
			continue
		_player_manager.players[player_id].correct_illegal_movement()
		player_states[player_id] = {}
		player_states[player_id]["T"] = _player_manager.player_states[player_id]["T"]
		player_states[player_id]["P"] = _player_manager.players[player_id].transform.origin
		player_states[player_id]["V"] = _player_manager.players[player_id].velocity
		player_states[player_id]["A"] = _player_manager.players[player_id].acceleration
		player_states[player_id]["R"] = _player_manager.players[player_id].rotation.y
		player_states[player_id]["H"] = _player_manager.players[player_id].rotation_velocity

	var world_state = {}

	world_state["T"] = time
	world_state["S"] = player_states

	#TODO add other necessary information

	return world_state
