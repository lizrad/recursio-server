extends Node
onready var Server = get_node("/root/Server")

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
	if Server.player_amount > 0:
		var world_state = define_world_state()
		Server.send_world_state(world_state)

func define_world_state():
	var time = Server.get_server_time()
	var player_states={}
	for player_id in PlayerManager.players:
		player_states[player_id]={}
		player_states[player_id]["P"]=PlayerManager.players[player_id].transform.origin
		player_states[player_id]["V"]=PlayerManager.players[player_id].velocity
		player_states[player_id]["A"]=PlayerManager.players[player_id].acceleration
		player_states[player_id]["R"]=PlayerManager.players[player_id].rotation.y
		player_states[player_id]["H"]=PlayerManager.players[player_id].rotation_velocity
		print(player_states[player_id])
	var world_state = {}
	
	world_state["T"] = time
	world_state["S"] = player_states
	
	#TODO add other necessary information
	
	return world_state
