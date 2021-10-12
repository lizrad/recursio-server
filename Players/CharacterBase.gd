extends KinematicBody
class_name CharacterBase

onready var Server = get_node("/root/Server")
var game_id := -1
var player_id := -1
var ghost_index := -1
var round_index := -1

var spawn_point := Vector3.ZERO

signal hit
