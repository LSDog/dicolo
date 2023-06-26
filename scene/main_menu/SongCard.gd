class_name SongCard
extends Panel

@onready var labelTitle := $LabelTitle;
@onready var labelInfo := $LabelInfo;
@onready var image_rect := $Mask/Image;
@onready var scroll_map := $ScrollMap;
@onready var map_box := $ScrollMap/VBox;
@onready var stylebox := get_theme_stylebox("panel") as StyleBoxFlat;

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
var selected := false;

## 是否在ScrollMap的VBox里生成了对应的MapCard
var map_card_generated := false;

## 难度，结构为{ "The Normal": [4, "res://map/a_map_folder/map_normal.txt"] }
var levels :Dictionary = {};


var scene_MapCard :PackedScene = preload("res://scene/main_menu/MapCard.tscn");


## 用来提供展示的beatmap对象, 并非实际用于游玩的铺面
var example_beatmap :BeatMap = null:
	set(value):
		example_beatmap = value;
		labelTitle.text = example_beatmap.title;
		labelInfo.text = example_beatmap.singer;
		if example_beatmap.bg_image_path != "":
			image_rect.texture = load(example_beatmap.bg_image_path);

## readme.txt 里的话
var readme :String;

signal song_selected;
signal song_play_request;

func _ready():
	
	# 资源唯一化
	stylebox = stylebox.duplicate(true);
	add_theme_stylebox_override("panel", stylebox);
	
	mouse_entered.connect(func():
		is_mouse_entered = true;
		modulate_v_target = modulate_v_hover;
	);
	
	mouse_exited.connect(func():
		is_mouse_entered = false;
		unhover();
	);
	
	labelTitle.resized.connect(resize_labels);
	labelInfo.resized.connect(resize_labels);

func _process(_delta):
	if !get_global_rect().intersects(get_viewport_rect()): return;
	if modulate.v != modulate_v_target:
		modulate.v = lerpf(modulate.v, modulate_v_target, 0.1);
	if custom_minimum_size.x != width_target + width_offset:
		custom_minimum_size.x = lerpf(custom_minimum_size.x, width_target + width_offset, 0.2);
		resize_labels();

func resize_labels():
	if labelTitle.size.x > (size.x - labelTitle.position.x):
		labelTitle.scale.x = maxf(0.6, (size.x - labelTitle.position.x) / labelTitle.size.x);
	if labelInfo.size.x > (size.x - labelInfo.position.x):
		labelInfo.scale.x = maxf(0.6, (size.x - labelInfo.position.x) / labelInfo.size.x);

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
	
	if !map_card_generated:
		generate_map_cards();
	
	# map_box.size 无法正常更新 采用计算方法
	var vbox_height := 0.0;
	var separation := map_box.get_theme_constant("separation", "int") as int;
	for node in map_box.get_children():
		vbox_height += node.size.y + separation;
	vbox_height -= separation;
	
	var total_height :float = size.y + vbox_height;
	custom_minimum_size.y = 500 if total_height >= 500 else total_height;
	size.y = total_height;
	image_rect.visible = false;
	stylebox.skew.x = 0;
	stylebox.border_color.a = 0.2;
	#stylebox.shadow_color.a = 0;
	
	song_selected.emit();

func unselect():
	modulate_v_target = modulate_v_origin;
	width_target = width_origin;
	
	custom_minimum_size.y = 80;
	image_rect.visible = true;
	stylebox.skew.x = -0.25;
	stylebox.border_color.a = 0.8;
	stylebox.shadow_color.a = 0.3;
	
	selected = false;

func generate_map_cards():
	for node in map_box.get_children():
		map_box.remove_child(node);
		node.queue_free();
	for level_name in levels.keys():
		var data = levels.get(level_name);
		add_map(data[0], level_name, ['C','B','A','S','SS'].pick_random(), data[1]);
	map_card_generated = true;


func add_map(diff: float, info: String, rating: String, map_path: String):
	var map_card := scene_MapCard.instantiate() as MapCard;
	map_box.add_child(map_card);
	map_card.set_diff(diff);
	map_card.set_info(info);
	map_card.set_rating(rating);
	map_card.map_path = map_path;

func unhover():
	if !selected: modulate_v_target = modulate_v_origin;

