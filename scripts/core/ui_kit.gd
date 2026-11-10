extends RefCounted

const Art:=preload("res://scripts/visual/art_library.gd")
const ForestUI:=preload("res://scripts/ui/forest_ui.gd")

const PAPER := Color("#eaf2e9")
const MUTED := Color("#aec9c7")
const MINT := Color("#88dec1")
const GOLD := Color("#ffce78")
const INK := Color("#10252e")

static func place(node: Control, parent: Node, x: float, y: float, w: float, h: float) -> Control:
	parent.add_child(node)
	node.position = Vector2(x,y)
	node.size = Vector2(w,h)
	return node

static func box(parent: Node,x: float,y: float,w: float,h: float,color: Color) -> Control:
	if w>200 and h>75 and w<960:
		return ForestUI.panel(parent,Rect2(x,y,w,h))
	var node := ColorRect.new()
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(node,parent,x,y,w,h)
	return node

static func label(parent: Node,caption: String,x: float,y: float,w: float,h: float,font_size := 18,color := PAPER) -> Label:
	var node := Label.new()
	node.text = caption
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	place(node,parent,x,y,w,h)
	return node

static func style(color: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = edge
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	return s

static func button(parent:Node,caption:String,callback:Callable,x:float,y:float,w:float,h:=48.0,primary:=false) -> Button:
	var node:=Button.new()
	node.text=caption
	if primary: node.theme_type_variation="PrimaryButton"
	node.pressed.connect(func(): SFX.play("ui_click",node))
	node.pressed.connect(callback)
	place(node,parent,x,y,w,maxf(48,h))
	return node

static func counter(parent:Node,caption:String,x:float,y:float,w:float,h:=32.0) -> Label:
	var node:=Label.new()
	node.theme_type_variation="Counter"
	node.text=caption
	node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	place(node,parent,x,y,w,h)
	return node

static func clock(seconds: float) -> String:
	var n := int(seconds)
	return "%02d:%02d" % [n/60,n%60]

static func symbols(parent: Node, kind: String, filled: int, x: int, y: int, unit: int) -> Control:
	var node := preload("res://scripts/ui/status_symbols.gd").new()
	node.kind = kind
	node.unit = unit
	node.filled = filled
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(node,parent,x,y,(unit+4)*3,unit)
	return node
