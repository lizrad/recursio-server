extends Viewport
class_name Room

var room_name : String
var id : int
var player_count : int = 0

signal world_state_updated(world_state, id)
signal room_filled()

onready var _player_manager : PlayerManager = get_node("PlayerManager")
onready var _world_state_manager : WorldStateManager = get_node("WorldStateManager")


func _ready():
	_world_state_manager.connect("world_state_updated", self, "_on_world_state_update")


func add_player(player_id : int) -> void:
	_player_manager.spawn_player(player_id)
	player_count += 1


func remove_player(player_id : int) -> void:
	_player_manager.despawn_player(player_id)
	player_count -= 1


func update_player_state(player_id, player_state):
	_player_manager.update_player_state(player_id, player_state)


func get_players():
	return _player_manager.players


func _on_world_state_update(world_state):
	emit_signal("world_state_updated", world_state, id)
