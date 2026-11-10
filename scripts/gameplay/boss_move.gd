extends Resource
## One telegraphed ability. Individual boss scenes supply their own patterns.
@export_enum("Shot","Dash","Leap") var kind := 0
@export var warning := 0.9
@export var execution := 0.28
@export var recovery := 1.8
@export var travel := 0.0
@export var arc_height := 0.0
