class_name SongList
extends ScrollContainer

@onready var container := $VBoxContainer;

var scroll_speed := 0.0; # 滚动速度，向下为正方向
var touch_scroll_speed := 0.0; # 最后一次手拖动的速度
@onready var v_scroll_bar := get_v_scroll_bar(); # 滚动条
@onready var v_scroll_bar_style := theme.get_stylebox("scroll", "VScrollBar").duplicate() as StyleBoxFlat; # 滚动条

@export var base_scroll_speed := 300; # 滚动速度
@export var friction := 0.08; # 缓动结束的摩擦力
@export var max_card_width := 420; # 歌曲卡片的最大宽度(用于突出选中者)
@export var min_card_width := 400; # 歌曲卡片的最小宽度
var selected_card :SongCard; # 选中的卡片

var is_mouse_entered := false;
var center_song_index :int = 0; # 当前在屏幕“中间”的歌曲位数
var center_song_index_float :float = 0.0; # 当前在屏幕“中间”的歌曲位数的小数形式
var dragging_index := [];

var randomed_index_list := []; # 随机抽取到的歌曲index，防止重复

var song_card_tscn = preload("res://scene/main_menu/SongCard.tscn");

func _ready():
	
	mouse_entered.connect(func(): is_mouse_entered = true);
	mouse_exited.connect(func(): is_mouse_entered = false);
	
	_ready_later.call_deferred();

func _ready_later():
	
	Debugger.count_time("Map Load");
	load_maps();
	Debugger.count_time("Map Load");
	for node in container.get_children():
		node.song_selected.connect(handle_song_select.bind(node));
		node.song_play_request.connect(handle_song_play_request.bind(node));
	
	# 载完图后随机播放歌曲
	choose_song_random();

## 处理选中(点击)歌曲卡片
func handle_song_select(song_card: SongCard):
	print("Select song: ", song_card.example_beatmap.title);
	# 停止滚动
	touch_scroll_speed = 0;
	scroll_speed = 0;
	# 让上一个被选中的songcard缩回去
	if selected_card != null && selected_card != song_card: selected_card.unselect();
	selected_card = song_card;
	# 更改界面预览当前歌曲
	var main_menu := get_parent() as MainMenu;
	if song_card.example_beatmap.bg_image_path != "":
		main_menu.background.texture = load(song_card.example_beatmap.bg_image_path);
	else:
		# 没有bg的情况下加载这个
		main_menu.background.texture = load("res://image/background/トトリの夢の中.png");
	main_menu.music_player.play_music(
		load(song_card.example_beatmap.audio_path),
		song_card.example_beatmap.title+" - "+song_card.example_beatmap.singer,
		song_card.example_beatmap.start_time,
		song_card.example_beatmap.bpm
	);
	# 设置readme文本
	main_menu.readme_label.text = song_card.readme;
	main_menu.readme_label.scroll_to_line(0);
	main_menu.readme_label.get_v_scroll_bar().value = 0.0;
	# 设置levels
	for child in main_menu.levels_bar.get_children():
		main_menu.levels_bar.remove_child(child);
	for levelname in song_card.levels.keys():
		var label := Label.new();
		label.text = str(song_card.levels[levelname][0])+'/'+levelname;
		label.add_theme_font_size_override("font_size", 28);
		label.mouse_filter = Control.MOUSE_FILTER_PASS;
		main_menu.levels_bar.add_child(label);
	# 自动选择第一个level（如果有）
	if main_menu.levels_bar.get_child_count() > 0:
		main_menu.levels_bar.select_label(main_menu.levels_bar.get_child(0));
	# 设置背景里面啥用也没有的透明大字
	main_menu.bg_label.text = song_card.example_beatmap.title;

## 处理请求游玩歌曲
func handle_song_play_request(song_card: SongCard):
	var main_menu := get_parent() as MainMenu;
	if main_menu.levels_bar.selected_label == null:
		return;
	var level_name := main_menu.levels_bar.selected_label.text.split('/', 2)[1] as String;
	print("play song: ", song_card.example_beatmap.title, ", level: ", level_name);
	
	var play_ground_scene := preload("res://scene/play_ground/Playground.tscn") as PackedScene;
	var play_ground := play_ground_scene.instantiate() as PlayGroundControl;
	get_tree().root.add_child(play_ground);
	get_tree().current_scene = play_ground;
	Global.freeze(main_menu);
	play_ground.play(selected_card.levels[level_name][1]);
	

func _process(delta):
	
	# 速度过小设零
	if abs(scroll_speed * delta) < 0.5: scroll_speed = 0;
	# 触底减速
	if (scroll_speed < 0 && scroll_vertical <= 0) || \
		(scroll_speed > 0 && scroll_vertical + size.y >= container.size.y):
		Global.stick_edge(lerpf(scroll_speed, 0, 0.95));
	
	if scroll_speed != 0:
		
		# 丝滑滚动
		scroll_vertical += scroll_speed * delta;
		scroll_speed = lerp(scroll_speed, 0.0, friction);
		
		# 额外触发鼠标移动更新song_card
		warp_mouse(get_local_mouse_position());
	
	if scroll_speed != 0 || offset_right != 0:
		var speed_rate = abs(scroll_speed / base_scroll_speed);
		# 滚动列表会使列表整体右偏（根据滚动速度）
		offset_right = Global.stick_edge(lerp(offset_right, speed_rate, 0.5));
		# 右移时加点儿阴影
		v_scroll_bar_style.shadow_color = Color(1, 0.843137, 0, 0.1);
		v_scroll_bar_style.shadow_size = 5 * speed_rate;
	
	# 计算呢当前在屏幕“中间”的是哪首歌曲
	var ratio = (v_scroll_bar.value+v_scroll_bar.page/2)/v_scroll_bar.max_value;
	# 0->1全覆盖的算法
	#var ratio = v_scroll_bar.value/(v_scroll_bar.max_value-v_scroll_bar.page);
	center_song_index_float = get_song_count() * ratio if !is_nan(ratio) else get_song_count()/2.0;
	center_song_index = roundi(center_song_index_float);
	
	# 让靠近屏幕中间的歌曲形成向外的弧线
	var i = 0;
	var wide = 4 / (Global.stretch_scale); # 弧线的长度
	for song_card in container.get_children():
		#song_card = song_card as ColorRect;
		var distance = abs(i-center_song_index_float+0.5);
		var width_add = ( ((1-cos(PI/wide*distance))/2.0) if abs(distance) <= wide else 1.0 ) * 60.0;
		song_card.width_offset = width_add;
		i += 1;

func _gui_input(event):
	match event.get_class():
		"InputEventMouseButton":
			var button_index = event.button_index;
			match button_index:
				MOUSE_BUTTON_WHEEL_DOWN:
					if scroll_speed < 0: scroll_speed = 0; # 若之前和现在操作反向则先停下
					else: scroll_speed += base_scroll_speed;
					accept_event();
				MOUSE_BUTTON_WHEEL_UP:
					if scroll_speed > 0: scroll_speed = 0;
					else: scroll_speed -= base_scroll_speed;
					accept_event();
				MOUSE_BUTTON_LEFT:
					if event.pressed:
						touch_scroll_speed = 0;
					else:
						scroll_speed = touch_scroll_speed;
		"InputEventScreenDrag":
			accept_event();
			#if !has_point(event.position): return;
			scroll_vertical -= floori(event.relative.y);
			touch_scroll_speed = -event.velocity.y;
		"InputEventScreenTouch":
			if event.pressed:
				touch_scroll_speed = 0;
			else:
				scroll_speed = touch_scroll_speed;

func has_point(point: Vector2) -> bool:
	return get_rect().has_point(point);

## 加载铺面
func load_maps():
	
	var dir_res := DirAccess.open("res://map");
	if dir_res != null:
		print("Loading maps in res://")
		load_maps_in_dir(dir_res);
		
	var dir_user := DirAccess.open("user://map");
	if dir_user != null:
		print("Loading maps in user://")
		load_maps_in_dir(dir_user);

## 加载特定目录下的文件夹形式的铺面
func load_maps_in_dir(dir: DirAccess):
	for song_dir_name in dir.get_directories():
		print(" - Looking folder: " + song_dir_name);
		load_map_of_dir(Global.get_sub_dir(dir, song_dir_name));

## 加载文件夹形式的铺面
func load_map_of_dir(dir: DirAccess):
	
	var beatmap :BeatMap;
	var readme :String;
	var levels :Dictionary = {};
	var keys := ["levelname", "level"];
	
	for file_name in dir.get_files():
		if !file_name.ends_with(".txt"): continue;
		
		var map_file := Global.get_sub_file(dir, file_name, FileAccess.READ);
		
		if file_name.to_lower() == "readme.txt":
			readme = map_file.get_as_text();
		else:
			if beatmap == null:
				var temp_beatmap := BeatMap.new(dir, map_file);
				if temp_beatmap != null && temp_beatmap.loaded:
					beatmap = temp_beatmap;
				levels[beatmap.levelname] = [beatmap.level, beatmap.file_path];
			else:
				var level_values = find_map_value(keys, map_file);
				levels[level_values[0]] = [level_values[1], map_file.get_path()];
		
		map_file.close();
	
	if beatmap != null:
		print("    - ", beatmap.file_path);
		add_song(beatmap, levels, readme if readme != null else "");
		print("   ↑ Loaded: ", beatmap.title);

## 获取map中
func find_map_value(need_keys :Array[String], map_file :FileAccess) -> Array:
	var need_count := need_keys.size();
	var find_count := 0;
	var values := [];
	while find_count < need_count || map_file.get_position() < map_file.get_length():
		var line := map_file.get_line();
		if line.begins_with("//") || !line.contains(":"): continue;
		var parts := line.split(":", true, 2);
		#if parts.size() < 2: parts[1] = "null";
		var i := 0;
		while i < need_count:
			if parts[0] == need_keys[i]:
				values[i] = parts[1];
			i += 1;
	return values;

## 添加一首歌
func add_song(example_beatmap: BeatMap, levels: Dictionary, readme: String = ""):
	var song_card :SongCard = song_card_tscn.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as SongCard;
	container.add_child(song_card);
	song_card.example_beatmap = example_beatmap;
	song_card.levels = levels;
	song_card.readme = readme;
	# 清除之前的随机
	if !randomed_index_list.is_empty():
		randomed_index_list.clear()

## 获取总歌曲数
func get_song_count() -> int:
	return container.get_child_count();

## 获取某个歌曲
func get_song(index: int) -> SongCard:
	return container.get_child(index);

## 滚动到某个歌曲
func scroll_to(index: int):
	index = clampi(index, 0, get_song_count());
	var distance = (index - center_song_index_float) / get_song_count() * container.size.y;
	create_tween().tween_property(self
		, "scroll_vertical"
		, float(index) / get_song_count() * container.size.y - size.y / 2.0
		, 0.75
	).from_current().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);

## 选择某个曲子
func choose_song(index: int):
	get_song(index).select();

## 随机选曲
func choose_song_random():
	# 防重复
	if randomed_index_list.size() >= get_song_count():
		randomed_index_list.clear();
	var last_indexes = range(0, get_song_count()).filter(func(i):
		return !randomed_index_list.has(i);
	);
	var index = last_indexes.pick_random();
	randomed_index_list.append(index);
	choose_song(index);
	scroll_to(index);

func _unhandled_input(event: InputEvent):
	if event is InputEventKey:
		if event.physical_keycode == KEY_R && event.pressed:
			choose_song_random();
