extends Resource
class_name CharacterStat

@export_enum("P1", "P2", "P3") var name: String = "P1"
@export var sprite_frame: SpriteFrames
@export_range(1, 100, 1) var Speed: int # do *2
@export_range(1, 100, 1) var Jumping: int # do *4
@export_range(1, 100, 1) var Setting: int 
@export_range(1, 50, 1) var Recieving: int # do * 2
@export_range(1, 100, 1) var Blocking: int
@export_range(1, 100, 1) var Hitting: int
