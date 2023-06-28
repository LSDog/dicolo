class_name MapCard
extends Panel

@onready var labelDiff := $LabelDiff;
@onready var labelInfo := $LabelInfo;
@onready var labelRating := $LabelRating;
@onready var stylebox := get_theme_stylebox("panel") as StyleBoxFlat;

@export var str_star :String = '★';
@export var str_star_half :String = '☆';

var map_name :String;
var map_path :String;

var is_mouse_entered := false;
var pressed_pos;
var selected := false;

signal map_select();
signal map_play_request(map_path: String);


func _ready():
	stylebox = stylebox.duplicate();
	add_theme_stylebox_override("panel", stylebox);

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if !event.pressed:
				if !selected:
					map_select.emit();
					select();
					Global.play_sound(preload("res://audio/ui/click_dthen.wav"), 0, 1, "Effect");
				else:
					map_play_request.emit(map_path);

func select():
	selected = true;
	create_tween().tween_property(stylebox, "bg_color:a", 0.4, 0.2
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);

func unselect():
	create_tween().tween_property(stylebox, "bg_color:a", 0.2, 0.2
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
	selected = false;

# 设置难度的星星
func set_diff(star: float):
	star = clampf(star, 0, 7);
	var full_star :int = floori(star);
	var half_star :int = 0 if (star - full_star < 0.5) else 1;
	labelDiff.text = str_star.repeat(full_star) + str_star_half.repeat(half_star);

# 设置铺面信息
func set_info(info: String):
	labelInfo.text = info;

# 设置评级
func set_rating(rating: String):
	labelRating.text = rating;
