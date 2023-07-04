class_name PlaygroundControl
extends Control

@export_category("Setting")
## 允许控制
@export var enable_control :bool = true;
## 使用 VirtualJoystic
@export var enable_virtualJoystick :bool = true:
	set(value):
		enable_virtualJoystick = value;
		virtualJoystick.visible = value;
		virtualJoystick.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED;
## 铺/音/画不同步的调整阈值
@export var max_delay :float = 0.05;

@export_category("Timing")
## 预处理拍数，相当于“音符在击打前多久开始出现动画”
@export var event_before_beat :float = 4;
## 音符动画时间
@export var note_after_time :float = 0.25;

@export_category("Judge")
## 判定 just 的时间
@export var judge_just :float = 0.1;
## 判定 good 的时间
@export var judge_good :float = 0.25;
## hit ct与轨道半径最远差值
@export var judge_hit_radius :float = 5;
## hit 最小速度
@export var judge_hit_speed :float = 10;
## hit 最大容许的撞击角度偏差
@export var judge_hit_deg_offset :float = 45;
## slide ct与轨道半径最远差值
@export var judge_slide_radius :float = 5;
## slide 可判定的左右度数 (左右各0.5倍)
@export var judge_slide_deg :float = 8;
## bounce 回弹的最大判定半径
@export var judge_bounce_radius :float = 10;
## bounce 回弹的最小速度
@export var judge_bounce_speed :float = 100;


## 游玩模式
var play_mode :PLAY_MODE = PLAY_MODE.PLAY;
## 游玩模式
enum PLAY_MODE {PLAY, EDIT};
## 判定
enum JUDGEMENT { JUST, GOOD, MISS }
const COLOR_GOOD = Color.WHITE;
const COLOR_JUST = Color(0.95, 0.9, 0.55);

## 铺面
var beatmap :BeatMap;
## 事件索引（包括音符等...）
var event_index :int = 0;
## 在场的（等待判定）的音符和相关canvas结点。结构 [codeblock] 
## {8:[Note,[PathFollow2D]], 9:[Note,[PathFollow2D, Line2D, PathFollow2D]]} [/codeblock]
var waiting_notes := {};
## 以判定等待特效或删除的音符和相关canvas结点。结构同 waiting_notes
var judged_notes := {};
## 已判定的
## 当前bpm
var bpm :float;
## 动画的tween们
var anim_tweens :Array[Tween] = [];

## 歌词
var lyrics :LyricsFile;
## 歌词到哪句了
var lrc_index :int = 0;

## 游戏是否开始，开始前不允许暂停
var started := false;
## 演奏是否中途暂停
var paused := false;
## 演奏是否已结束
var ended := false;
# 是否有音乐（必须有 所以不设此项
#var has_audio := false;
## 是否有背景视频
var has_video := false;
## 是否有歌词
var has_lyrics := false;
## 是否为跳转后状态
var jumped := false;

## 当前音乐(若有视频则为视频)播放的时间（秒）
var stream_time := 0.0;
## 开始时间戳
var start_time := 0.0;
## 演奏总时间
var play_time := 0.0;

## 左侧准心
@onready var ctl :Ct = $PlayGround/CtL;
## 右侧准星
@onready var ctr :Ct = $PlayGround/CtR;

## 左侧轨道
@onready var trackl :Sprite2D = $PlayGround/TrackL;
@onready var trackl_diam := 512.0;
@onready var trackl_circle :Sprite2D = $PlayGround/TrackL/Circle;
@onready var trackl_center :Vector2 = trackl.position;
@onready var trackl_path :Path2D = $PlayGround/TrackL/Path;
## 右侧轨道
@onready var trackr :Sprite2D = $PlayGround/TrackR;
@onready var trackr_diam := 512.0;
@onready var trackr_circle :Sprite2D = $PlayGround/TrackR/Circle;
@onready var trackr_center :Vector2 = trackr.position;
@onready var trackr_path :Path2D = $PlayGround/TrackR/Path;

@onready var bgpanel := $BGPanel;
@onready var bgpanel_mask := $BGPanel/Mask;
@onready var audio_player := $BGPanel/AudioPlayer;
@onready var video_player := $BGPanel/VideoPlayer;
@onready var background := $BGPanel/Background;
@onready var playground := $PlayGround;
@onready var lyricsLabel :=  $BGPanel/LyricLabel;
@onready var virtualJoystick := $VirtualJoystick;
@onready var manuButton := $MenuButton;


var texture_hit_fx = preload("res://visual/texture/hit_fx.svg");
var texture_slide = preload("res://visual/texture/slide.svg");
var texture_slide_hint_ring = preload("res://visual/texture/ring.svg");
var texture_slide_hint_point = preload("res://visual/texture/slide_hint.svg");
var texture_bounce = preload("res://visual/texture/bounce.svg");
var texture_follow = preload("res://visual/texture/follow.svg");


var sound_hit = preload("res://audio/map/note_hihat.wav");
var sound_slide = preload("res://audio/map/note_hihatclosed.wav");
var sound_bounce = preload("res://audio/map/note_floortom.wav");

## 铺面加载完毕
signal map_loaded;
## map是否加载
var map_has_loaded :bool = false;
## 开始播放
signal play_start;
## 暂停
signal play_pause;
## 恢复
signal play_resume;
## 跳转
signal play_jump(time:float);
## 重开
signal play_restart;
## 结束
signal play_end;

func _ready():
	
	correct_size();
	
	$MenuButton.pressed.connect(func():
		if !paused: pause();
		else: resume();
	)
	
	# 暂停菜单
	$Pause/Content/Quit.pressed.connect(func():
		var playGroundScene = get_tree().current_scene;
		Global.unfreeze(Global.scene_MainMenu);
		Global.scene_MainMenu.visible = true;
		get_tree().current_scene = Global.scene_MainMenu;
		get_tree().root.remove_child(playGroundScene);
		playGroundScene.queue_free();
	)
	$Pause/Content/Back.pressed.connect(resume);
	$Pause/Content/Restart.pressed.connect(restart);
	
	# 音乐结束之后进入end
	audio_player.finished.connect(end);


## 修正大小
func correct_size():
	# 保证 stretch scale 更改后 track 大小不变
	var keep_scale = Vector2(1.0/Global.stretch_scale, 1.0/Global.stretch_scale);
	var center_pos = get_tree().root.size/2;
	playground.scale = keep_scale;
	video_player.scale = keep_scale;
	video_player.pivot_offset = center_pos;


## 载入铺面并开始游戏
func load_map(map_file_path: String, auto_start: bool = false):
	
	print("[PlayGround] opening map files..")
	var map_file = FileAccess.open(map_file_path, FileAccess.READ);
	print("[PlayGround] result: ", map_file, ": ", error_string(FileAccess.get_open_error()));
	var dir := DirAccess.open(map_file_path.substr(0, map_file_path.rfind("/")));
	beatmap = BeatMap.new(dir, map_file);
	print("[PlayGround] map_loaded: ", beatmap);
	map_file = null;
	
	background.texture = load(beatmap.bg_image_path) if beatmap.bg_image_path != "" else Global.scene_MainMenu.default_backgrounds.pick_random();
	#has_audio = beatmap.audio_path != "";
	audio_player.stream = load(beatmap.audio_path);
	has_video = beatmap.video_path != "";
	if has_video: video_player.stream = load(beatmap.video_path);
	has_video = false if video_player.stream == null else true;
	$BGPanel/DebugLabel.text = "debug text..."
	
	bpm = beatmap.bpm;
	print("Default bpm = ", bpm);
	print("One Beat = ", get_beat_time(), "s");
	
	if beatmap.lrc_path != "":
		var lrcfile = LyricsFile.new(FileAccess.open(beatmap.lrc_path, FileAccess.READ));
		if lrcfile.loaded:
			lyrics = lrcfile;
			has_lyrics = true;
	
	map_has_loaded = true;
	map_loaded.emit();
	
	if auto_start:
		pre_start.call_deferred();
		# ▼▼▼ 这里初始化结束进入 pre_start
	

## 准备开始游戏
func pre_start():
	
	# 一秒延迟
	await get_tree().create_timer(1).timeout;
	
	# 遮罩变暗
	create_anim_tween().tween_property(bgpanel_mask, "color:a", 0.6, 1.5).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	
	# Track旋转+归位
	var trackl_start_tween = create_anim_tween();
	trackl_start_tween.tween_property(trackl, "rotation", 0.0, 1.5).from(1.0
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	trackl_start_tween.tween_property(trackl, "position", trackl_center, 1.5);
	var trackr_start_tween = create_anim_tween();
	trackr_start_tween.tween_property(trackr, "rotation", 0.0, 1.5).from(-1.0
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	trackr_start_tween.tween_property(trackr, "position", trackr_center, 1.5);
	
	# Ct移动
	create_anim_tween(ctl).tween_property(ctl, "position", trackl_center, 1.5
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	var ctr_start_tween = create_anim_tween(ctr);
	ctr_start_tween.tween_property(ctr, "position", trackr_center, 1.5
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	ctr_start_tween.finished.connect(start);
	# ▼▼▼ 这里动画结束进入 start

## 开始游戏
func start():
	if has_video:
		# 背景变更黑
		create_anim_tween().tween_property(background, "modulate:v", 0.3, 2).from_current().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD);
		# 开始视频
		video_player.play();
		# 淡入视频
		create_anim_tween().tween_property(video_player, "modulate:a", 1.0, 1).from(0.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD);
	# 开始音频
	audio_player.play();
	started = true;
	start_time = Time.get_unix_time_from_system();
	
	play_start.emit();

## 暂停
func pause():
	if !started: return;
	
	paused = true;
	video_player.paused = true;
	audio_player.stream_paused = true;
	if play_mode == PLAY_MODE.PLAY: $Pause.visible = true;
	pause_anim_tweens();
	
	play_pause.emit();

## 取消暂停
func resume():
	
	$Pause.visible = false;
	video_player.paused = false;
	audio_player.stream_paused = false;
	paused = false;
	resume_anim_tweens();
	
	play_resume.emit();

## 跳转到时间
func jump(time :float, do_pause :bool = true):
	
	if ended: ended = false;
	if !started: start();
	
	if do_pause: pause();
	
	# 获取跳转到的下一个event
	var last_index := 0;
	for event in beatmap.events:
		if event.time >= play_time: break;
		last_index += 1;
	event_index = last_index;
	
	# 防止超过
	var audio_length = get_audio_length();
	if time > audio_length:
		time = audio_length;
	
	# 跳转音乐
	if paused:
		audio_player.play(time);
		audio_player.stream_paused = true;
	else:
		audio_player.seek(time);
	play_time = time;
	print("[Play] Jump to: ", time, " index = ", last_index);
	
	# 跳转视频(只能暂停或回到第一帧开始)
	video_player.stop();
	if time == 0.0:
		video_player.stop();
		video_player.play();
		video_player.paused = true;
		jumped = false;
	else:
		# 无法跳转视频播放，故暂停
		jumped = true;
	
	# 设定时间
	stream_time = time;
	start_time = Time.get_unix_time_from_system() - time;
	play_time = time;
	
	# 清除场上的note
	for i in waiting_notes.keys():
		remove_note(i);
	for i in judged_notes.keys():
		remove_note(i);
	for node in trackl_path.get_children(): node.queue_free();
	for node in trackr_path.get_children(): node.queue_free();
	
	# 强制运行很短的时间来预览
	resume();
	_process(1/1000.0);
	pause();
	
	#print(anim_tweens)
	
	play_jump.emit(time);

## 重开游戏
func restart():
	
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
	
	play_restart.emit();

## 结束游戏
func end():
	if ended: return;
	
	print("[Play] end!");
	ended = true;
	audio_player.stop();
	video_player.stop();
	
	play_end.emit();

## 获取一个可以随游戏暂停而暂停的Tween
func create_anim_tween(node: Node = self) -> Tween:
	var tween = node.create_tween();
	anim_tweens.append(tween);
	tween.finished.connect(func():
		tween.kill();
		anim_tweens.erase(tween);
	);
	return tween;

## 暂停动画
func pause_anim_tweens():
	for tween in anim_tweens:
		if tween.is_valid(): tween.pause();

## 恢复动画
func resume_anim_tweens():
	for tween in anim_tweens:
		if tween.is_valid(): tween.play();

func _unhandled_input(event):
	if event is InputEvent:
		event = event as InputEvent;
		if event.is_action_pressed("esc"):
			if !paused: pause();
			else: resume();
			accept_event();

func _process(delta):
	
	if !map_has_loaded: return;
	
	var can_control = false;
	
	var audio_pos = audio_player.get_playback_position();
	
	# 通过播放进度判断是否end
	if !ended && audio_pos >= audio_player.stream.get_length():
		end();
	
	if !ended: # 未结束
		
		var video_pos = video_player.stream_position;
		
		stream_time = video_pos if has_video else audio_pos;
		
		if !paused: # 未暂停
			
			can_control = false;
			
			if started: # 游戏已开始
				
				can_control = true;
				play_time += delta;
				
				# 音频 <- 视频流校准
				if !jumped && has_video:
					var audio_delay = audio_pos - video_pos;
					if abs(audio_delay) > max_delay: # 音视频延迟超过校准时间就回调音频
						# 更新 audio_pos
						audio_pos = audio_pos-audio_delay;
						audio_player.seek(audio_pos);
						print("[audio] delay ", audio_delay, " > ",max_delay," --> reset-audio=",video_pos);
				
				# 演奏总时间 <- 音频流校准
				var play_time_delay = play_time - audio_pos;
				if abs(play_time_delay) > max_delay:
					play_time = play_time - play_time_delay;
					print("[play] delay ",play_time_delay," > ",max_delay," --> reset-play_time=",audio_pos);
				
				
				# 预处理event
				var before_time = event_before_beat*get_beat_time();
				while event_index < beatmap.events.size():
					# 这种方法永远会多获取一个event，然后才在发现时机未到后break出循环，可缓存优化
					var event :BeatMap.Event = beatmap.events[event_index];
					if play_time + before_time >= event.time:
						# 判断Event是否为Note
						if event is BeatMap.Event.Note:
							# 场景里生成note
							var canvasItems = generate_note(
								event, before_time, play_time + before_time - event.time
							);
							# 塞到待判定音符里
							waiting_notes[event_index] = [event, canvasItems];
						event_index += 1;
					else:
						break;
				
				
				# 计算俩个 Ct 的值
				update_ct(ctl);
				update_ct(ctr);
				
				
				# 处理等待中的event
				for wait_index in waiting_notes:
					var event_array = waiting_notes[wait_index];
					var event = event_array[0];
					if event is BeatMap.Event.Note:
						# 这里判定Note
						judge_note(wait_index, event_array);
					elif play_time > event.time:
						# 这里处理事件
						handle_event(event);
				
				
				# 处理歌词
				if has_lyrics:
					var line = "";
					var has_line = false;
					while lrc_index < lyrics.lyrics.size():
						var values :Array = lyrics.lyrics[lrc_index];
						if play_time >= values[0]-0.025:
							has_line = true;
							line = values[1];
							lrc_index += 1;
						else:
							break;
					if has_line:
						lyricsLabel.text = line;
						lyricsLabel.create_tween().tween_property(lyricsLabel, "modulate:a", 1.0, 0.1).from(0.0);
				
				
				# Debug
				$BGPanel/DebugLabel.text = (
					"
					Ctl: %.1f° %.1f || Ctr: %.1f° %.1f
					Play: %.2f || Audio: %.2f || Video: %.2f
					" % [
						ctl.degree,ctl.velocity.length(),
						ctr.degree,ctr.velocity.length(),
						
						play_time,audio_pos,video_pos
					]
				);
	
	else: # 游戏已结束
		
		can_control = true;
	
	if enable_control && can_control:
		
		# 控制准星
		# limit_length 防止手柄坐标越界
		var joyl :Vector2 = $VirtualJoystick.joy_l if Global.gamepad_id == -1 else Global.get_joy_left().limit_length(1.0);
		var joyr :Vector2 = $VirtualJoystick.joy_r if Global.gamepad_id == -1 else Global.get_joy_right().limit_length(1.0);
		
		trackl.position = trackl_center + joyl * 10;
		trackr.position = trackr_center + joyr * 10;
		
		ctl.position = trackl.position + joyl*trackl_diam/2;
		ctr.position = trackr.position + joyr*trackr_diam/2;
		


## 处理音符以外的各种事件
func handle_event(event :BeatMap.Event):
	match event.event_type:
		"Start":
			print("[Event] -- Start!");
		"End":
			print("[Event] -- End!")
		"Bpm":
			bpm = event.bpm;
			print("[Event] -- Bpm changed: ", event.bpm);

## 通过note获取相应的轨道
func get_track(note :BeatMap.Event.Note) -> CanvasItem:
	return trackl if note.side == note.SIDE.LEFT else (
		trackr if note.side == note.SIDE.RIGHT else null);

## 生成音符并返回相关的CanvasItem节点数组，如 [PathFollow2D] 或 [PathFollow2D, Path2D, PathFollow2D]
## offset: 与预生成时间点的差值
func generate_note(note :BeatMap.Event.Note, before_time: float, offset :float = 0.0) -> Array:
	#print("[Event] ", BeatMap.EVENT_TYPE.find_key(note.event_type), " ", play_time);
	var track = get_track(note);
	var path :Path2D = track.get_child(0) as Path2D; # 获取 path2D 记得放在第一位
	
	match note.event_type:
		BeatMap.EVENT_TYPE.Hit:
			var line := Line2D.new();
			var points = get_points_from_curve(
				trackl_path.curve if note.side == note.SIDE.LEFT else trackr_path.curve, 
				note.deg/360.0, note.deg_end/360.0
			);
			line.points = points;
			line.width = 10;
			path.add_child(line);
			# Hit 线条出现 下落(外扩)
			var tween := create_anim_tween(line);
			tween.parallel().tween_property(line, "modulate:a", 1.0, event_before_beat*get_beat_time()/3.0
				).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);
			tween.parallel().tween_property(line, "scale", Vector2(1,1), event_before_beat*get_beat_time()
				).from(Vector2(0,0)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			tween.parallel().tween_property(line, "width", 12.5, event_before_beat*get_beat_time()
				).from(7.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			# 引导轨道（扇形）
			var polygon = Polygon2D.new();
			var polygon_points = [Vector2.ZERO];
			polygon_points.append_array(points);
			polygon_points.append(Vector2.ZERO);
			polygon.color = Color.WHITE;
			polygon.polygon = polygon_points;
			path.add_child(polygon);
			tween.parallel().tween_property(polygon, "modulate:a", 0.1, event_before_beat*get_beat_time()
				).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);
			tween_step(tween, offset);
			return [line, polygon];
		BeatMap.EVENT_TYPE.Slide:
			var path_follow := PathFollow2D.new();
			path.add_child(path_follow);
			path_follow.progress_ratio = note.deg/360.0;
			var slide := Sprite2D.new();
			slide.texture = texture_slide;
			slide.scale.x = 0.2;
			slide.scale.y = 0.2;
			path_follow.add_child(slide);
			var tween := create_anim_tween(slide);
			tween.parallel().tween_property(slide, "modulate:a", 1.0, event_before_beat*get_beat_time()
				).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART);
			# 提示圈
			var ring := Sprite2D.new();
			ring.texture = texture_slide_hint_ring;
			ring.scale.x = 0.7;
			ring.scale.y = 0.7;
			path_follow.add_child(ring);
			tween.parallel().tween_property(ring, "modulate:a", 0.6, event_before_beat*get_beat_time()
				).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			tween.parallel().tween_property(ring, "scale", Vector2(0, 0), event_before_beat*get_beat_time()
				).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			# 提示点
			var point := Sprite2D.new();
			point.texture = texture_slide_hint_point;
			point.scale = Vector2(0.11, 0.11);
			path.add_child(point);
			tween.parallel().tween_property(point, "modulate:a", 0.8, event_before_beat*get_beat_time()
				).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);
			tween.parallel().tween_property(point, "position", path_follow.position, event_before_beat*get_beat_time()
				).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			tween_step(tween, offset);
			return [path_follow, point];
		BeatMap.EVENT_TYPE.Bounce:
			var bounce = Sprite2D.new();
			bounce.texture = texture_bounce;
			path.add_child(bounce);
			bounce.show_behind_parent = true;
			var tween = create_anim_tween(bounce);
			tween.parallel().tween_property(bounce, "modulate:a", 1.0, event_before_beat*get_beat_time()
				).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART);
			tween.parallel().tween_property(bounce, "rotation_degrees", 0.0, event_before_beat*get_beat_time()
				).from(-180.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			tween.parallel().tween_property(bounce, "scale", Vector2(0.4,0.4), event_before_beat*get_beat_time()
				).from(Vector2(1,1)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			tween_step(tween, offset);
			return [bounce];
	return [];

func tween_step(tween: Tween, delta: float, kill_if_finish: bool = true):
	if !tween.custom_step(delta) && kill_if_finish:
		print("kill ", tween);
		tween.kill();
		anim_tweens.erase(tween);

func judge_note(wait_index :int, note_array = null):
	if judged_notes.has(wait_index):
		return; # 此音符已判定 忽略
	if note_array == null: note_array = waiting_notes[wait_index];
	var note :BeatMap.Event.Note = note_array[0];
	# 判定
	var offset = play_time - note.time;
	if offset < -judge_good: return; # 还早着呢
	
	var judge;
	var note_item_array :Array = note_array[1];
	
	# miss 判定与动画
	if offset > judge_good:
		judge = JUDGEMENT.MISS;
		judged_notes[wait_index] = note_array;
		match note.event_type:
			BeatMap.EVENT_TYPE.Hit:
				#var line :Line2D = note_item_array[0];
				var polygon :Polygon2D = note_item_array[1];
				#polygon.color.r = 1;
				var tween = create_anim_tween(polygon);
				tween.finished.connect(func(): if polygon != null: polygon.queue_free());
				tween.set_ease(Tween.EASE_OUT);
				tween.set_trans(Tween.TRANS_LINEAR);
				tween.parallel().tween_property(polygon, "modulate", Color(0.9,0.4,0.4,0), note_after_time);
			BeatMap.EVENT_TYPE.Slide:
				var slide_path_follow :PathFollow2D = note_item_array[0];
				var hint_point :Sprite2D = note_item_array[1];
				var tween = create_anim_tween(slide_path_follow);
				tween.set_ease(Tween.EASE_OUT);
				tween.set_trans(Tween.TRANS_LINEAR);
				tween.parallel().tween_property(slide_path_follow, "modulate", Color(1,0,0,0), note_after_time);
				tween.parallel().tween_property(hint_point, "modulate", Color(1,0,0,0), note_after_time);
			BeatMap.EVENT_TYPE.Bounce:
				var bounce :Sprite2D = note_item_array[0];
				var tween = create_anim_tween(bounce);
				tween.finished.connect(func(): if bounce != null: bounce.queue_free());
				tween.set_ease(Tween.EASE_OUT);
				tween.set_trans(Tween.TRANS_LINEAR);
				tween.parallel().tween_property(bounce, "modulate", Color(1,0,0,0), note_after_time);
		remove_note(wait_index, true);
		return;
	
	# 非 miss 的判定与动画
	
	if offset > -judge_just && offset < judge_just:
		# just
		judge = JUDGEMENT.JUST;
	else:
		# good
		judge = JUDGEMENT.GOOD;
	
	var track := get_track(note);
	var radius := trackl_diam/2.0 if track == trackl else trackr_diam/2.0;
	var ct := ctl if note.side == note.SIDE.LEFT else ctr;
	
	var touched := false;
	var hit := false;
	
	# 判断碰没碰上 然后搞特效 让判定完的东西消失啥的
	match note.event_type:
		
		BeatMap.EVENT_TYPE.Hit:
			note = note as BeatMap.Event.Note.Hit;
			touched = (
				ct.distance >= radius - judge_hit_radius &&
				is_in_degree(ct.degree, note.deg, note.deg_end)
			);
			hit = is_in_degree(
				get_degree_in_track(ct.velocity, true),
				ct.degree - judge_hit_deg_offset,
				ct.degree + judge_hit_deg_offset
			);
			if ct.velocity.length() >= judge_hit_speed && touched && hit:
				judged_notes[wait_index] = note_array;
				var line :Line2D = note_item_array[0];
				#var polygon :Polygon2D = note_item_array[1];
				line.default_color = COLOR_JUST if judge == JUDGEMENT.JUST else COLOR_GOOD;
				line.queue_redraw();
				play_sound(sound_hit);
				# 特效
				var line_fx := line.duplicate() as Line2D;
				line_fx.default_color.a = 0.3;
				track.add_child(line_fx);
				var tween = create_anim_tween(line_fx);
				tween.parallel().tween_property(line_fx, "width", 140.0, note_after_time
					).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
				tween.parallel().tween_property(line_fx, "modulate:a", 0.0, note_after_time*2
					).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD);
				note_item_array.append(line_fx);
				
				remove_note(wait_index, true);
		
		BeatMap.EVENT_TYPE.Slide:
			note = note as BeatMap.Event.Note.Slide;
			touched = (
				ct.distance >= radius - judge_slide_radius &&
				is_in_degree(ct.degree, note.deg - judge_slide_deg/2.0, note.deg + judge_slide_deg/2.0)
			);
			if touched:
				judged_notes[wait_index] = note_array;
				var path_follow := note_item_array[0] as PathFollow2D;
				#var slide :Sprite2D = path_follow.get_child(0);
				var ring := path_follow.get_child(1) as Sprite2D;
				ring.modulate = COLOR_JUST;
				ring.queue_redraw();
				play_sound(sound_slide);
				var tween = create_anim_tween(ring);
				tween.parallel().tween_property(ring, "scale", Vector2(1,1), note_after_time
					).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
				tween.parallel().tween_property(ring, "modulate:a", 0.0, note_after_time*2
					).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
				
				remove_note(wait_index, true);
		
		BeatMap.EVENT_TYPE.Bounce:
			note = note as BeatMap.Event.Note.Bounce;
			touched = ct.distance <= judge_bounce_radius;
			if ct.velocity.length_squared() >= judge_bounce_speed**2 && touched:
				judged_notes[wait_index] = note_array;
				var bounce := note_item_array[0] as Sprite2D;
				bounce.modulate = COLOR_JUST if judge == JUDGEMENT.JUST else COLOR_GOOD;
				bounce.queue_redraw();
				play_sound(sound_bounce);
				var tween = create_anim_tween(bounce);
				tween.parallel().tween_property(bounce, "scale", Vector2(1.5, 1.5), note_after_time
					).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
				tween.parallel().tween_property(bounce, "modulate:a", 0.0, note_after_time*2
					).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
				
				remove_note(wait_index, true)

## 更新ct的数值
func update_ct(ct: Ct):
	ct.pos = get_ct_position(ct);
	ct.distance = ct.pos.length();
	ct.degree = get_degree_in_track(ct.pos, true);
	ct.velocity_degree = (
		0.0 if ct.velocity == Vector2.ZERO else get_degree_in_track(ct.velocity, true)
	);

## 获取 Ct 在 track 中的相对位置
func get_ct_position(ct: Ct) -> Vector2:
	return ct.position - (trackl.position if ct == ctl else trackr.position);

## 通过与 track中心 的相对位置获取度数（顺时针，正上0°）
func get_degree_in_track(vec: Vector2, negative_y :bool = false) -> float:
	return (
		0 if vec == Vector2.ZERO else
		abs(fposmod((float(atan2(vec.y if !negative_y else -vec.y , vec.x)/PI)*180.0-90), -360))
	);

## 判断此度数x是否在min~max里
func is_in_degree(x: float, min_val: float, max_val: float) -> bool:
	if min_val > max_val:
		var temp_min := min_val;
		min_val = max_val;
		max_val = temp_min;
	if min_val < 0 && max_val > 0:
		# 跨 0° 的判断方法
		return is_in_degree(x, min_val, 0) || is_in_degree(x, 0, max_val);
	x = fposmod(x, 360) + 360 * floorf(min_val/360.0);
	if min_val == -20:
		print("min_val %.1f\tct %.1f\tmax %.1f" % [min_val, x ,max_val]);
	return min_val <= x && x <= max_val;

func play_sound(stream: AudioStream, volume: float = 0, pitch: float = 1, bus: String = "Master"):	
	var player = AudioStreamPlayer.new();
	add_child(player);
	player.stream = stream;
	player.volume_db = volume
	player.pitch_scale = pitch;
	player.bus = bus;
	player.finished.connect(func(): player.queue_free());
	player.play();

## 删掉waiting_note[index]的全部玩意儿
func remove_note(wait_index :int, use_animation :float = false):
	
	var array = waiting_notes.get(wait_index);
	if array == null || array.is_empty(): return;
	
	var canvas_items = array[1];

	# 删掉所有 canvasItem
	for item in canvas_items:
		if item == null: continue;
		if !use_animation:
			item.queue_free();
		else:
			var tween := create_anim_tween();
			tween.finished.connect(func():
				if item != null: item.queue_free();
			);
			tween.tween_property(item, "modulate:a", 0.0, note_after_time
			).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
	judged_notes.erase(wait_index);
	waiting_notes.erase(wait_index);

## 获得从start“转”到end的所有点，这意味着他可以返回绕好几圈的结果
func get_points_from_curve(curve :Curve2D, start_ratio :float = 0, end_ratio :float = 1):
	
	var points :PackedVector2Array = [];
	var curve_points := curve.get_baked_points();
	var point_count := curve_points.size();
	var ratio := start_ratio;
	var d_radio := 1.0/point_count;
	
	if start_ratio < end_ratio:
		while ratio < end_ratio:
			points.append(curve_points[roundi(round_multiple(ratio, d_radio)*point_count)]);
			ratio += d_radio;
	else:
		d_radio = -d_radio;
		while ratio > end_ratio:
			points.append(curve_points[roundi(round_multiple(ratio, d_radio)*point_count)]);
			ratio += d_radio;
	return points;

func get_beat_time() -> float:
	return 60/bpm;

func get_audio_length() -> float:
	return audio_player.stream.get_length();

func round_multiple(value :float, round_float :float) -> float:
	return roundf(value/round_float) * round_float;
