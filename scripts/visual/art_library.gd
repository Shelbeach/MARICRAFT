@tool
extends RefCounted

const ROOT := "res://assets/forest_art/"
static var actors: Dictionary
static var objects: Dictionary
static var environment: Dictionary
static var calibration: Dictionary
static var resources := {}

static func initialize() -> void:
	if not actors.is_empty(): return
	actors=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"characters/animations.json"))
	objects=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"gameplay/registry.json"))
	environment=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"environment/registry.json"))
	calibration=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"calibration.json"))

static func resource(path: String):
	if not resources.has(path): resources[path]=load(ROOT+path)
	return resources[path]

static func enabled() -> bool:
	var campaign=Engine.get_main_loop().root.get_node("Campaign")
	if campaign.p.get("status","")=="result":
		return campaign.last_level().begins_with("1-")
	return campaign.p.get("level",campaign.store.first_level).begins_with("1-")
