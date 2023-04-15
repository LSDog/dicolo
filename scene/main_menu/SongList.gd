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
var selected_card; # 选中的卡片

var is_mouse_entered := false;
var center_song_index :int = 0; # 当前在屏幕“中间”的歌曲位数
var center_song_index_float :float = 0.0; # 当前在屏幕“中间”的歌曲位数的小数形式
var dragging_index := [];

var song_card_tscn = preload("res://scene/main_menu/song_card.tscn");

func _ready():
	
	mouse_entered.connect(func(): is_mouse_entered = true);
	mouse_exited.connect(func(): is_mouse_entered = false);
	
	_ready_later.call_deferred();

func _ready_later():
	
	print("Loading maps ...")
	load_maps();
	for node in $VBoxContainer.get_children():
		node = node as SongCard;
		node.song_selected.connect(handle_song_select.bind(node));
		node.song_play_request.connect(handle_song_play_request.bind(node));
		

func _process(delta):
	
	# 速度过小设零
	if abs(scroll_speed * delta) < 0.5: scroll_speed = 0;
	# 触底减速
	if (scroll_speed < 0 && scroll_vertical <= 0) || \
		(scroll_speed > 0 && scroll_vertical + size.y >= $VBoxContainer.size.y):
		Global.stick_edge(lerpf(scroll_speed, 0, 0.95));
	
	if scroll_speed != 0:
		
		# 丝滑滚动
		scroll_vertical += scroll_speed * delta;
		if scroll_speed > 0:
			scroll_speed = max(scroll_speed - friction*scroll_speed, 0.0);
		else:
			scroll_speed = min(scroll_speed - friction*scroll_speed, 0.0);
		
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
	center_song_index_float = $VBoxContainer.get_child_count() * ratio if !is_nan(ratio) else $VBoxContainer.get_child_count()/2.0;
	center_song_index = roundi(center_song_index_float);
	
	# 让靠近屏幕中间的歌曲形成向外的弧线
	var i = 0;
	var wide = 4 / (Global.stretch_scale); # 弧线的长度
	for song_card in $VBoxContainer.get_children():
		#song_card = song_card as ColorRect;
		var distance = abs(i-center_song_index_float+0.5);
		if (!song_card.is_mouse_entered):
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

## 处理选中歌曲
func handle_song_select(song_card: SongCard):
	print("selected song: ", song_card.example_beatmap.title);
	touch_scroll_speed = 0;
	scroll_speed = 0;
	var main_menu := get_parent() as MainMenu;
	main_menu.background.texture = load(song_card.example_beatmap.bg_image_path);
	main_menu.music_player.play_music(
		load(song_card.example_beatmap.audio_path),
		song_card.example_beatmap.title+" - "+song_card.example_beatmap.singer
	);

## 处理开始歌曲
func handle_song_play_request(song_card: SongCard):
	print("play song: ", song_card.example_beatmap.title)
	pass;

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
	var readme;
	
	for file_name in dir.get_files():
		if !file_name.ends_with(".txt"): continue;
		
		if file_name.to_lower() == "readme.txt":
			readme = Global.get_sub_file(dir, file_name, FileAccess.READ).get_as_text();
		elif beatmap == null:
			var temp_beatmap := BeatMap.new(dir, Global.get_sub_file(dir, file_name, FileAccess.READ));
			if temp_beatmap != null && temp_beatmap.loaded:
				beatmap = temp_beatmap;
				break;
	
	if beatmap != null:
		print(beatmap.file_path);
		add_song(beatmap, readme if readme != null else "");
		print("   ↑ Loaded: " + beatmap.title);

## 添加一首歌
func add_song(beatmap: BeatMap, readme: String = ""):
	var song_card :SongCard = song_card_tscn.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as SongCard;
	container.add_child(song_card);
	song_card.example_beatmap = beatmap;
	song_card.readme = readme;
