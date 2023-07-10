@tool
extends Path2D

var slash_right_texture := preload("res://visual/texture/slash_right.svg");
var width_curve := preload("res://scene/playground/bar_width_curve.tres");

func _ready() -> void:
	var line := Line2D.new();
	line.width = 30;
	line.width_curve = width_curve;
	line.points = curve.get_baked_points();
	line.texture_mode = Line2D.LINE_TEXTURE_TILE;
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED;
	line.texture = slash_right_texture;
	add_child(line);
