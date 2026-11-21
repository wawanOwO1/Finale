class_name CardInstance
extends RefCounted
## A card in a pile. `uid` tells two copies of the same CardDef apart.

var uid: int
var def: CardDef


func _init(uid_: int, def_: CardDef) -> void:
	uid = uid_
	def = def_
