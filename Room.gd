extends Viewport
class_name Room

var room_name : String
var room_id : int

onready var player_manager : PlayerManager = get_node("PlayerManager")
onready var world_state_manager : WorldStateManager = get_node("WorldStateManager")
