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
var maps :Dictionary = {};
var selected_mapCard :MapCard;

var scene_MapCard :PackedScene = preload("res://scene/main_menu/MapCard/MapCard.tscn");
var mapCard_copy :MapCard = scene_MapCard.instantiate();

## 用来提供展示的beatmap对象, 并非实际用于游玩的铺面
var example_beatmap :BeatMap = null:
	set(value):
		example_beatmap = value;
		labelTitle.text = value.title;
		labelInfo.text = value.author;
		if value.bg_image_path != "":
			image_rect.texture = ExternLoader.load_image(value.get_bg_image_path());

## readme.txt 里的话
var readme :String;

signal song_select;
signal song_menu_request;

func _ready():
	
	# 资源唯一化
	stylebox = stylebox.duplicate(true);
	add_theme_stylebox_override("panel", stylebox);
	
	mouse_entered.connect(func():
		is_mouse_entered = true;
		modulate_v_target = modulate_v_hover;
		Global.play_sound(preload("res://audio/ui/click_kak.wav"), -25, 1.25, "Effect");
		Global.play_sound(preload("res://audio/ui/click_hat.wav"), -15, 0.75, "Effect");
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
					Global.play_sound(preload("res://audio/ui/click_dvb.wav"), -20, 1, "Effect");
					Global.play_sound(preload("res://audio/ui/click_kak.wav"), -20, 1, "Effect");
				else:
					unhover();
			else:
				song_menu_request.emit();

func unhover():
	if !selected: modulate_v_target = modulate_v_origin;


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
	
	var total_height :int = size.y + roundi(vbox_height);
	custom_minimum_size.y = 500 if total_height >= 500 else total_height;
	size.y = total_height;
	image_rect.visible = false;
	stylebox.skew.x = 0;
	stylebox.bg_color.a = 0.1;
	stylebox.border_color.a = 0.7;
	#stylebox.shadow_color.a = 0;
	
	song_select.emit();
	select_mapCard_random();

func unselect():
	modulate_v_target = modulate_v_origin;
	width_target = width_origin;
	
	custom_minimum_size.y = 80;
	image_rect.visible = true;
	stylebox.skew.x = -0.25;
	stylebox.bg_color.a = 1;
	stylebox.border_color.a = 0.8;
	#stylebox.shadow_color.a = 0.3;
	
	selected = false;

func select_mapCard(index: int):
	var map_card := map_box.get_child(index) as MapCard;
	if map_card != null:
		map_card.select();

func select_mapCard_random():
	var count := map_box.get_child_count();
	if count > 0:
		select_mapCard(randi_range(0, count-1));


func generate_map_cards():
	for node in map_box.get_children():
		map_box.remove_child(node);
		node.queue_free();
	for map_name in maps.keys():
		var data = maps.get(map_name);
		add_mapCard(data[0], map_name, ['C','B','A','S','SS'].pick_random(), map_name, data[1]);
	map_card_generated = true;


func add_mapCard(diff: float, info: String, rating: String, map_name: String, map_path: String):
	var map_card := mapCard_copy.duplicate() as MapCard;
	map_box.add_child(map_card);
	map_card.set_diff(diff);
	map_card.set_info(info);
	map_card.set_rating(rating);
	map_card.map_name = map_name;
	map_card.map_path = map_path;
	var thread = Thread.new();
	thread.start((func(_map_card: MapCard):
		_map_card.example_map = BeatMap.new(
			_map_card.map_path.get_base_dir(),
			FileAccess.open(_map_card.map_path, FileAccess.READ), true);
		_map_card.example_map_loaded = true;
		
	).bind(map_card));
	thread.wait_to_finish();
	map_card.map_play_request.connect(Global.mainMenu.play_map);
	map_card.map_select.connect(func():
		if selected_mapCard != null && selected_mapCard != map_card:
			selected_mapCard.unselect();
		selected_mapCard = map_card;
		var mapcard_map = map_card.example_map;
		print("Select map: ", example_beatmap.map_name);
		# 更改界面预览当前背景
		if Global.mainMenu.last_background_path != mapcard_map.get_bg_image_path():
			if mapcard_map.bg_image_path != "":
				Global.mainMenu.last_background_path = mapcard_map.get_bg_image_path();
				Global.mainMenu.background.texture = ExternLoader.load_image(
					mapcard_map.get_bg_image_path());
			else:
				# 没有bg的情况下加载默认的
				Global.mainMenu.last_background_path = "default";
				Global.mainMenu.background.texture = Global.mainMenu.default_backgrounds.pick_random();
		# 更改界面预览当前歌曲
		if Global.mainMenu.last_audio_path != mapcard_map.get_audio_path():
			Global.mainMenu.last_audio_path = mapcard_map.get_audio_path();
			Global.mainMenu.musicPlayer.play_music(
				ExternLoader.load_audio(mapcard_map.get_audio_path()),
				mapcard_map.title+" - "+mapcard_map.author,
				mapcard_map.start_time,
				mapcard_map.bpm
			);
		# 设置readme文本
		Global.mainMenu.leftPanel.set_readme(readme);
		# 分数
		Global.mainMenu.leftPanel.set_score(randi_range(500_0000, 1000_0000));
		Global.mainMenu.leftPanel.set_count(randf_range(0.8, 1.0), randi_range(500, 1000));
	);

