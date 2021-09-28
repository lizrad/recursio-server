extends Node
class_name GameManager

onready var _room: Room = get_node("..")


func _ready():
	_room.connect("room_filled", self, "_on_room_filled")


func _start_round_counter():
	pass


func _on_room_filled():
	_start_round_counter()
