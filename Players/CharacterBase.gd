extends KinematicBody
class_name CharacterBase

const NONE = 0

const DASH_START = 1
const DASH_END = 2

#TODO: connect weapon information recording with actuall weapon system when ready
const MELEE_START = 1
const WEAPON_START = 2
const MELEE_END = 3
const WEAPON_END = 4

const GUN = 0
const WALL = 1

onready var Server = get_node("/root/Server")
var id := -1

