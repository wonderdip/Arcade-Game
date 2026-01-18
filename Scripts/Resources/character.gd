extends Resource
class_name CharacterStat

@export var name: String = "P1"
@export var sprite_frame: SpriteFrames
@export_range(1, 100, 1) var Speed: int # do *2
@export_range(1, 100, 1) var Jumping: int # do *4
@export_range(1, 100, 1) var Setting: int 
@export_range(1, 100, 1) var Recieving: int # do * 2
@export_range(1, 100, 1) var Blocking: int
@export_range(1, 100, 1) var Hitting: int
@export var Player_Number: int = 1
