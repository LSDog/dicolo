class_name MapCard
extends Panel

@onready var labelDiff := $LabelDiff;
@onready var labelInfo := $LabelInfo;
@onready var labelRating := $LabelRating;

@export var str_star :String = '★';
@export var str_star_half :String = '☆';

var map_path;


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if !event.pressed:
				Global.scene_MainMenu.play_song(map_path);

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
