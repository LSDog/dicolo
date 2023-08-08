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
var selected_index :int;

var is_mouse_entered := false;
var center_song_index :int = 0; # 当前在屏幕“中间”的歌曲位数
var center_song_index_float :float = 0.0; # 当前在屏幕“中间”的歌曲位数的小数形式
var dragging_index := [];

var randomed_index_list := []; # 随机抽取到的歌曲index，防止重复

var scene_SongCard :PackedScene = preload("res://scene/main_menu/SongCard/SongCard.tscn");

var map_loaded := false;
signal map_first_loaded;

func _ready():
	
	mouse_entered.connect(func(): is_mouse_entered = true);
	mouse_exited.connect(func(): is_mouse_entered = false);
	
	_ready_later.call_deferred();

func _ready_later():
	
	Debugger.count_time("Map Load");
	load_maps();
	Debugger.count_time("Map Load");
	
	map_loaded = true;
	map_first_loaded.emit();
	
	# 载完图后 开场动画结束会随机播放歌曲
	#select_song_random();

## 处理选中(点击)歌曲卡片
func handle_song_select(song_card: SongCard):
	print("Select song: ", song_card.example_beatmap.title);
	# 停止滚动
	touch_scroll_speed = 0;
	scroll_speed = 0;
	# 让上一个被选中的songcard缩回去
	if selected_card != null && selected_card != song_card: selected_card.unselect();
	selected_card = song_card;
	selected_index = song_card.get_index();
	
	# 设置背景里面啥用也没有的透明大字
	Global.mainMenu.bgLbael.text = song_card.example_beatmap.title;

func _process(delta):
	
	# 速度过小设零
	if abs(scroll_speed * delta) < 0.5: scroll_speed = 0;
	# 触底减速
	if (scroll_speed < 0 && scroll_vertical <= 0) || \
		(scroll_speed > 0 && scroll_vertical + size.y >= container.size.y):
		lerpf(scroll_speed, 0, 0.95);
	
	if scroll_speed != 0:
		
		# 丝滑滚动
		scroll_vertical += scroll_speed * delta;
		scroll_speed = lerp(scroll_speed, 0.0, friction);
		
		# 额外触发鼠标移动更新song_card
		warp_mouse(get_local_mouse_position());
	
	if scroll_speed != 0 || offset_right != 0:
		var speed_rate = abs(scroll_speed / base_scroll_speed);
		# 滚动列表会使列表整体右偏（根据滚动速度）
		offset_right = lerp(offset_right, speed_rate, 0.5);
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
			scroll_vertical -= floori(event.relative.y);
			touch_scroll_speed = -event.velocity.y;
		"InputEventScreenTouch":
			if event.pressed:
				touch_scroll_speed = 0;
			else:
				scroll_speed = touch_scroll_speed;

## 清理铺面
func clear_maps():
	for node in container.get_children():
		container.remove_child(node);
		node.free();

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
	var maps :Dictionary = {};
	var need_keys := ["map_name", "diff"];
	
	for file_name in dir.get_files():
		if !file_name.ends_with(".txt"): continue;
		
		var map_file := Global.get_sub_file(dir, file_name, FileAccess.READ);
		
		if file_name.to_lower() == "readme.txt":
			readme = map_file.get_as_text();
		else:
			if beatmap == null:
				var temp_beatmap := BeatMap.new(dir.get_current_dir(), map_file);
				if temp_beatmap != null && temp_beatmap.loaded:
					beatmap = temp_beatmap;
				maps[get_renamed_map_name(maps, beatmap.map_name)] = [
					beatmap.diff, beatmap.file_path];
			else:
				var map_values = find_map_value(need_keys, map_file);
				var diff = map_values[1];
				diff = -1.0 if !diff.is_valid_float() else diff.to_float();
				maps[get_renamed_map_name(maps, map_values[0])] = [
					diff, map_file.get_path()];
		
		map_file.close();
	
	if beatmap != null:
		print("    - ", beatmap.file_path);
		add_song(beatmap, maps, readme if readme != null else "");
		print("       ↑ Loaded: ", beatmap.title);

## 重命名重复的map_name -> map_name [1]
func get_renamed_map_name(maps: Dictionary, map_name: String) -> String:
	var exist_map = maps.get(map_name);
	if exist_map != null:
		var dup_value := 1;
		if map_name.match(" \\[[0-9]*\\]$"):
			var dup_value_string = map_name.substr(
				map_name.rfind('(')+1, map_name.rfind(')')-1);
			if dup_value_string.is_valid_int():
				dup_value = dup_value_string.to_int();
			map_name = map_name.substr(0, map_name.rfind(')')+1);
		else: map_name += " (";
		dup_value += 1;
		map_name += str(dup_value) + ")";
	return map_name;

## 获取map中的特定信息
func find_map_value(need_keys :Array, map_file :FileAccess) -> Array:
	var need_count := need_keys.size();
	var find_count := 0;
	var values := [];
	values.resize(need_keys.size());
	while find_count < need_count:
		var line := map_file.get_line();
		if line.begins_with("//") || !line.contains(":"): continue;
		var parts := line.split(":", true, 2);
		var need_index := need_keys.find(parts[0]);
		if need_index != -1:
			values[need_index] = parts[1];
			find_count += 1;
		# 找到头了就走
		if map_file.get_position() >= map_file.get_length():
			break;
	return values;

## 添加一首歌
func add_song(example_beatmap: BeatMap, maps: Dictionary, readme: String = ""):
	var song_card :SongCard = scene_SongCard.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as SongCard;
	container.add_child(song_card);
	song_card.example_beatmap = example_beatmap;
	song_card.maps = maps;
	song_card.readme = readme;
	song_card.song_select.connect(handle_song_select.bind(song_card));
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
	create_tween().tween_property(self
		, "scroll_vertical"
		, float(index) / get_song_count() * container.size.y - size.y / 2.0
		, 0.75
	).from_current().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);

## 选择某个曲子
func select_song(index: int):
	get_song(index).select();

## 获取选中的map
func get_selected_map_path() -> String:
	if selected_card != null && selected_card.selected_mapCard != null:
		return selected_card.selected_mapCard.map_path;
	else: return "";

## 随机选曲
func select_song_random():
	
	# 没加载就等
	if !map_loaded:
		await map_first_loaded;
	
	# 防重复
	if randomed_index_list.size() >= get_song_count():
		randomed_index_list.clear();
	var last_indexes = range(0, get_song_count()).filter(func(i):
		return !randomed_index_list.has(i);
	);
	if !last_indexes.is_empty():
		var index = last_indexes.pick_random();
		randomed_index_list.append(index);
		select_song(index);
		scroll_to(index);

func _unhandled_input(event: InputEvent):
	if event is InputEventKey:
		if event.physical_keycode == KEY_R && event.pressed:
			select_song_random();
