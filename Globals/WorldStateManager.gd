extends Node
onready var Server = get_node("/root/Server")

func _physics_process(delta):
	if Server.player_amount>0:
		var world_state = define_world_state()
		Server.send_world_state(world_state)

func define_world_state():
	var time = Server.get_server_time()
	var player_states={}
	for player_id in PlayerManager.player_states:
		player_states[player_id]=PlayerManager.player_states[player_id]["P"]
	var world_state = {}
	world_state["T"]=time
	world_state["P"]=player_states
	#TODO add other necessary information
	return world_state
