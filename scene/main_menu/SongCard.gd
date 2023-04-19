class_name SongCard
extends Panel

@onready var title_label := $Title;
@onready var info_label := $Info;
@onready var image_rect := $Image;

# 颜色:v的状态
var modulate_v_origin = 1;
var modulate_v_hover = 1.3;
var modulate_v_select = 1.5;
var modulate_v_target = modulate_v_origin;
# 长度的状态
@onready var width_origin := custom_minimum_size.x;
@onready var width_select_mul := 1.2;
@onready var width_target := width_origin;
var width_offset := 0.0;

var is_mouse_entered := false;
var pressed_pos;
var selected = false;

## 难度，结构为{ "The Normal": [4, "res://map/a_map_folder/map_normal.txt"] }
var levels :Dictionary = {};

## 用来提供展示的beatmap对象, 并非实际用于游玩的铺面
var example_beatmap :BeatMap = null:
	set(value):
		example_beatmap = value;
		title_label.text = example_beatmap.title;
		info_label.text = example_beatmap.singer;
		if example_beatmap.bg_image_path != "":
			image_rect.texture = load(example_beatmap.bg_image_path);

## readme.txt 里的话
var readme :String;

signal song_selected;
signal song_play_request;

func _ready():
	
	mouse_entered.connect(func():
		is_mouse_entered = true;
		modulate_v_target = modulate_v_hover;
	);
	
	mouse_exited.connect(func():
		is_mouse_entered = false;
		unhover();
	);
	
	title_label.resized.connect(resize_labels);
	info_label.resized.connect(resize_labels);

func _process(_delta):
	
	if modulate.v != modulate_v_target:
		modulate.v = Global.stick_edge(lerpf(modulate.v, modulate_v_target, 0.1));
	if custom_minimum_size.x != width_target + width_offset:
		custom_minimum_size.x = Global.stick_edge(lerpf(custom_minimum_size.x, width_target + width_offset, 0.2));
		resize_labels();

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index > MOUSE_BUTTON_LEFT: return;
		if event.pressed:
			# 在当前card上按下了
			accept_event();
			if !selected:
				pressed_pos = event.global_position;
		else:
		# 在当前card上松手了
			if !selected:
				var y_relate = event.global_position.y - pressed_pos.y;
				pressed_pos = null;
				# 松手后和点击位置距离小于5px时断定为“选中”
				if abs(y_relate) <= 5.0:
					select();
				else:
					unhover();
			else:
				song_play_request.emit();

func select():
	selected = true;
	modulate_v_target = modulate_v_select;
	width_target = width_origin * width_select_mul;
	song_selected.emit();

func unselect():
	modulate_v_target = modulate_v_origin;
	width_target = width_origin;
	selected = false;

func unhover():
	if !selected: modulate_v_target = modulate_v_origin;

func resize_labels():
	if title_label.size.x > (size.x - title_label.position.x):
		title_label.scale.x = maxf(0.6, (size.x - title_label.position.x) / title_label.size.x);
	if info_label.size.x > (size.x - info_label.position.x):
		info_label.scale.x = maxf(0.6, (size.x - info_label.position.x) / info_label.size.x);
