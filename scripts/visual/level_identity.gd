@tool
extends RefCounted
static func id(level:Node) -> String:
	var base:=level.scene_file_path.get_file().get_basename().split("_")
	return base[-2]+"-"+base[-1] if base.size()>=3 else "1-1"
