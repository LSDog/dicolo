extends Control

@export_category("Setting")
## 允许控制
@export var enable_control := true;
## 铺/音/画不同步的调整阈值
@export var max_delay :float = 0.05;

@export_category("Timing")
## 预处理时间，相当于“音符在击打前多久开始出现动画”
@export var event_before_time :float = 0.5;
## 音符在多久后消失(包含淡出等动画时间)
@export var note_after_time :float = 0.35;

@export_category("Judge")
## Fine
@export var judge_before :float = 0.1;

var play_mode;
enum PLAY_MODE {PLAY, EDIT};


## 铺面
var beatmap :BeatMap;
## 事件索引（包括音符等...）
var event_index :int = 0;
## 在场的（等待判定）的音符和相关canvas结点。结构 [codeblock] 
## {8:[Note,[PathFollow2D]], 9:[Note,[PathFollow2D, Line2D, PathFollow2D]} [/codeblock]
var waiting_notes := {};

## 游戏是否开始，开始前不允许暂停
var started := false;
## 演奏是否中途暂停
var paused := false;
## 演奏是否已结束
var ended := false;
## 是否有背景视频
var has_video := false;

## 当前音乐(若有视频则为视频)播放的时间（秒）
var stream_time := 0.0;
## 开始时间
var start_time := 0.0;
## 演奏时间
var play_time := 0.0;

# 左侧准心
var ctl :RigidBody2D;
var ctl_move_pos :Vector2 = Vector2.ZERO;

# 右侧准星
var ctr :RigidBody2D;
var ctr_move_pos :Vector2 = Vector2.ZERO;

## 左侧轨道
var trackl :StaticBody2D;
var trackl_mesh :MeshInstance2D;
var trackl_center :Vector2;
var trackl_path :Path2D;
## 右侧轨道
var trackr :StaticBody2D;
var trackr_mesh :MeshInstance2D;
var trackr_center :Vector2;
var trackr_path :Path2D;

@onready var audio_player := $Panel/AudioPlayer;
@onready var video_player := $Panel/VideoPlayer;
@onready var background := $Panel/Background;
var texture_crash = preload("res://image/texture/crash.svg");
var texture_follow = preload("res://image/texture/follow.svg");
var tecture_line_crash = preload("res://image/texture/crash_line.svg");
var tecture_slide = preload("res://image/texture/slide_line.svg");

var countdown_word := ["①","②","⑨"];

## 铺面加载完毕
signal loaded;

func _ready():
	
	print("[PlayGround] opening map files..")
	var map_file = FileAccess.open("res://map/HareHareYukai/map_normal.txt", FileAccess.READ);
	print("[PlayGround] result: ", map_file, ": ", error_string(FileAccess.get_open_error()));
	beatmap = BeatMap.new("res://map/HareHareYukai", map_file);
	print("[PlayGround] loaded: ", beatmap);
	map_file = null;
	
	audio_player.stream = load(beatmap.audio_path);
	video_player.stream = load(beatmap.video_path);
	background.texture = beatmap.bg_image;
	$Panel/DebugLabel.text = "debug text..."
	
	has_video = false if video_player.stream == null else true;
	
	$MenuButton.pressed.connect(func():
		if !paused: pause();
		else: resume();
	)
	
	# 暂停菜单
	$Pause/Content/Quit.pressed.connect(func():
		var playGroundScene = get_tree().current_scene;
		Global.unfreeze(Global.scene_MainMenu);
		Global.scene_MainMenu.visible = true;
		#get_tree().root.add_child(Global.scene_MainMenu);
		#get_tree().root.move_child(Global.scene_MainMenu, get_tree().root.get_child_count()-1);
		get_tree().current_scene = Global.scene_MainMenu;
		get_tree().root.remove_child(playGroundScene);
		playGroundScene.queue_free();
	)
	$Pause/Content/Back.pressed.connect(resume);
	$Pause/Content/Retry.pressed.connect(retry);
	
	# 初始化控制柄
	ctl = $PlayGround/CtL as RigidBody2D;
	ctr = $PlayGround/CtR as RigidBody2D;
	trackl = $PlayGround/TrackL as StaticBody2D;
	trackl_mesh = $PlayGround/TrackL/Mesh;
	trackl_path = $PlayGround/TrackL/Path;
	trackr = $PlayGround/TrackR as StaticBody2D;
	trackr_mesh = $PlayGround/TrackR/Mesh;
	trackr_path = $PlayGround/TrackR/Path;
	
	audio_player.finished.connect(end);# 音乐结束之后进入end
	video_player.finished.connect(end);# 或者视频结束之后进入end
	
	loaded.emit();
	
	pre_start.call_deferred();
	# ▼▼▼ 这里初始化结束进入 pre_start

func pre_start():
	
	#$Animation.play("pre_start");
	
	trackl_center = trackl.position;
	trackr_center = trackr.position;
	
	# 倒数
	#var timer := Timer.new();
	#add_child(timer);
	#timer.start(1)
	#var time_left := 3;
	#
	#while time_left > 0:
	#	
	#	time_left -= 1;
	#	print(time_left)
	#	$Panel/CountDownText.text = countdown_word[time_left]
	#	var text_tween = create_tween();
	#	text_tween.tween_property($Panel/CountDownText, "modulate:a8", 0, 1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC);
	#	if time_left > 0: text_tween.tween_callback(func(): $Panel/CountDownText.modulate.a8 = 150)
	#	
	#	await timer.timeout;
	#timer.stop();
	
	await get_tree().create_timer(1).timeout;
	
	# 遮罩变暗
	#var bg_dark_tween = $Panel/Mask.create_tween();
	create_tween().tween_property($Panel/Mask, "color:a", 0.25, 1.5).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	
	# Track旋转
	var trackl_start_tween = trackl.create_tween();
	trackl_start_tween.tween_property(trackl, "rotation", 0.0, 1.5).from(1.0
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	var trackr_start_tween = trackr.create_tween();
	trackr_start_tween.tween_property(trackr, "rotation", 0.0, 1.5).from(-1.0
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	
	# Ct移动
	var playground_size = $PlayGround.size;
	var ctl_start_tween = ctl.create_tween();
	ctl_start_tween.tween_property(ctl, "position", Vector2(playground_size.x/3.0*1.0, playground_size.y/2.0), 1.5
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	var ctr_start_tween = ctr.create_tween();
	ctr_start_tween.tween_property(ctr, "position", Vector2(playground_size.x/3.0*2.0, playground_size.y/2.0), 1.5
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	ctr_start_tween.finished.connect(start);
	# ▼▼▼ 这里动画结束进入 start

func start():
	if has_video:
		# 背景变更黑
		create_tween().tween_property(background, "modulate:v", 0.3, 2).from_current().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD);
		# 开始视频
		video_player.play();
		# 淡入视频
		create_tween().tween_property(video_player, "modulate:a", 1.0, 1).from(0.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD);
	# 开始音频
	audio_player.play();
	started = true;
	start_time = Time.get_unix_time_from_system();

func pause():
	if !started: return;
	paused = true;
	video_player.paused = true;
	audio_player.stream_paused = true;
	$Pause.visible = true;

func resume():
	$Pause.visible = false;
	video_player.paused = false;
	audio_player.stream_paused = false;
	paused = false;

func retry():
	$Pause.visible = false;
	started = false;
	paused = false;
	audio_player.stop();
	audio_player.seek(0);
	video_player.stop();
	audio_player.stream_paused = false;
	video_player.paused = false;
	stream_time = 0;
	start_time = 0.0;
	play_time = 0.0;
	event_index = 0;
	for item in trackl_path.get_children():
		trackl_path.remove_child(item);
		item.free();
	for item in trackr_path.get_children():
		trackr_path.remove_child(item);
		item.free();
	pre_start();

func end():
	if ended: return;
	print("ended")
	ended = true;
	audio_player.stop();
	video_player.stop();

func _unhandled_input(event):
	if event is InputEvent:
		event = event as InputEvent;
		if event.is_action_pressed("esc"):
			if !paused: pause();
			else: resume();
			accept_event();

func _process(delta):
	
	var can_control = false;
	
	if !ended: # 未结束
		
		var audio_pos = audio_player.get_playback_position();
		var video_pos = video_player.stream_position;
		
		stream_time = video_pos if has_video else audio_pos;
		
		if !paused: # 未暂停
			
			can_control = false;
			
			if started: # 游戏已开始
				
				can_control = true;
				play_time += delta;
				
				# 音频 <- 视频流校准
				if has_video:
					var audio_delay = audio_pos - video_pos;
					if abs(audio_delay) > max_delay: # 音视频延迟超过校准时间就回调音频
						# 更新 audio_pos
						audio_pos = audio_pos-audio_delay;
						audio_player.seek(audio_pos);
						print("[audio] delay", audio_delay, " > ",max_delay," --> reset-audio=",video_pos);
				
				# 演奏总时间 <- 音频流校准
				var play_time_delay = play_time - audio_pos;
				if abs(play_time_delay) > max_delay:
					play_time = play_time - play_time_delay;
					print("[play] delay",play_time_delay," > ",max_delay," --> reset-play_time=",audio_pos);
				
				# 预处理event
				while event_index < beatmap.events.size():
					# 这种方法永远会多获取一个event，然后才在发现时机未到后break出循环，可缓存优化
					var event :BeatMap.Event = beatmap.events[event_index];
					if play_time + event_before_time >= event.time:
						# 判断Event是否为Note
						if event is BeatMap.Event.Note:
							# 场景里生成note
							var canvasItems = generate_note(event);
							# 塞到待判定音符里
							waiting_notes[event_index] = [event, canvasItems];
						event_index += 1;
					else:
						break;
				
				# 处理event
				for wait_index in waiting_notes:
					var event = waiting_notes[wait_index][0];
					if play_time > event.time + event.keep_time:
						if event is BeatMap.Event.Note:
							remove_note(wait_index);
						else:
							handle_event(event);
				
				$Panel/DebugLabel.text = "Play: %.2f || Audio: %.2f || Video: %.2f" % [play_time,audio_pos,video_pos];
	
	else: # 游戏已结束
		
		can_control = true;
	
	if enable_control && can_control:
	
		# 控制
		var joyl :Vector2 = $VirtualJoystick.joy_l if Global.joypad_id == -1 else Global.get_joy_left();
		var joyr :Vector2 = $VirtualJoystick.joy_r if Global.joypad_id == -1 else Global.get_joy_right();
		
		# 手柄坐标越界则归一
		if joyl.length_squared() > 1: joyl = joyl.normalized();
		if joyr.length_squared() > 1: joyr = joyr.normalized();
		
		trackl.position = trackl_center + joyl * 10;
		trackr.position = trackr_center + joyr * 10;
		
		ctl.position = trackl.position + joyl*trackl_mesh.mesh.size/2;
		ctr.position = trackr.position + joyr*trackr_mesh.mesh.size/2;

## 处理音符以外的事件
func handle_event(event :RefCounted):
	event = event as BeatMap.Event;
	match event.event_type:
		"Start":
			print("Notes start!");

func get_track(note :RefCounted) -> CanvasItem:
	return trackl if note.side == note.SIDE.LEFT else (
		trackr if note.side == note.SIDE.RIGHT else null);

## 生成音符并返回相关的CanvasItem节点数组，如 [PathFollow2D] 或 [PathFollow2D, Path2D, PathFollow2D]
func generate_note(note :RefCounted) -> Array:
	#note = note as BeatMap.Event.Note;
	print(note.event_type, play_time);
	var track = get_track(note);
	var path :Path2D = track.get_child(0) as Path2D; # 获取 path2D 记得放在第一位
	match note.event_type:
		"Crash":
			var follow := PathFollow2D.new();
			path.add_child(follow);
			follow.progress_ratio = note.deg/360.0;
			var crash := Sprite2D.new();
			crash.texture = texture_crash;
			crash.scale.x = 0.2;
			crash.scale.y = 0.2;
			follow.add_child(crash);
			show_animation(follow);
			return [follow];
		"LineCrash":
			var follow_start := PathFollow2D.new();
			var follow_end := PathFollow2D.new();
			path.add_child(follow_start);
			path.add_child(follow_end);
			follow_start.progress_ratio = note.deg/360.0;
			follow_end.progress_ratio = note.deg_end/360.0;
			var crash := Sprite2D.new();
			crash.texture = texture_crash;
			crash.scale.x = 0.2;
			crash.scale.y = 0.2;
			follow_start.add_child(crash);
			follow_end.add_child(crash.duplicate());
			var line := Line2D.new();
			var points = get_points_from_curve(
				trackl_path.curve if note.side == note.SIDE.LEFT else trackr_path.curve, 
				note.deg/360.0, note.deg_end/360.0
			);
			line.points = points;
			line.width = 14;
			line.texture = tecture_line_crash;
			line.texture_mode = Line2D.LINE_TEXTURE_TILE;
			line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED;
			path.add_child(line);
			show_animation(follow_start);
			show_animation(follow_end);
			show_animation(line);
			return [follow_start, line, follow_end];
		"Slide":
			var follow_start := PathFollow2D.new();
			var follow_end := PathFollow2D.new();
			path.add_child(follow_start);
			path.add_child(follow_end);
			follow_start.progress_ratio = note.deg/360.0;
			follow_end.progress_ratio = note.deg_end/360.0;
			var crash := Sprite2D.new();
			crash.texture = texture_crash;
			crash.scale.x = 0.2;
			crash.scale.y = 0.2;
			follow_start.add_child(crash);
			follow_end.add_child(crash.duplicate());
			var line := Line2D.new();
			var points = get_points_from_curve(
				trackl_path.curve if note.side == note.SIDE.LEFT else trackr_path.curve, 
				note.deg/360.0, note.deg_end/360.0
			);
			line.points = points;
			line.width = 37;
			line.texture = tecture_slide;
			line.texture_mode = Line2D.LINE_TEXTURE_TILE;
			line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED;
			path.add_child(line);
			show_animation(follow_start);
			show_animation(follow_end);
			show_animation(line);
			return [follow_start, line, follow_end];
	return [];

func show_animation(node :Node):
	node.create_tween().tween_property(node, "modulate:a", 1.0, event_before_time/3.0).from(0.0
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);
	var hint_node := node.duplicate();
	hint_node.position = Vector2.ZERO;
	hint_node.rotation = 0;
	node.get_parent().add_child(hint_node);
	hint_node.modulate.a = 0.2;
	hint_node.modulate.v = 0.5;
	hint_node.modulate.s = 1;
	#hint_node.z_index = -1;
	var tween = hint_node.create_tween();
	tween.finished.connect(func():
		hint_node.queue_free();
	);
	tween.tween_property(hint_node, "scale", Vector2(1.0,1.0), event_before_time).from(Vector2(3.0,3.0));

## 删掉waiting_note[index]的全部玩意儿
func remove_note(wait_index :int) :
	
	var array :Array = waiting_notes[wait_index];
	if array == null || array.is_empty(): return;
	
	var note = array[0];
	var canvas_items = array[1];
	
	var track = get_track(note);
	var path = track.get_child(0);
	
	# 删掉所有 canvasItem
	for item in canvas_items:
		var tween := create_tween().bind_node(item);
		tween.finished.connect(func():
			item.queue_free();
		);
		tween.tween_property(item, "modulate:a", 0.0, note_after_time
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD);
	
	waiting_notes.erase(wait_index);

func get_points_from_curve(curve :Curve2D, start_ratio :float = 0, end_ratio :float = 1):
	while start_ratio < 0: start_ratio += 1;
	while end_ratio < 0: end_ratio += 1;
	var curve_points = curve.get_baked_points();
	var point_count = curve_points.size();
	var start = (start_ratio if start_ratio < end_ratio else end_ratio) * point_count;
	var end = (start_ratio if start_ratio > end_ratio else end_ratio) * point_count;
	return curve_points.slice(ceili(start), floori(end));
