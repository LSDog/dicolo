class_name PlayGroundControl
extends Control

@export_category("Setting")
## 允许控制
@export var enable_control := true;
## 铺/音/画不同步的调整阈值
@export var max_delay :float = 0.05;

@export_category("Timing")
## 预处理拍数，相当于“音符在击打前多久开始出现动画”
@export var event_before_beat :float = 4;
## 音符动画时间
@export var note_after_time :float = 0.25;

@export_category("Judge")
enum JUDGEMENT { JUST, GOOD, MISS }
@export var judge_just :float = 0.1;
@export var judge_good :float = 0.2;
## 判定时最大容许的准星与轨道半径的差值
@export var judge_radius_offset :float = 10;
## slide可判定的的度数
@export var judge_slide_deg :float = 6;
## hit 最小速度
@export var judge_hit_speed :float = 10;
## hit 最大容许的撞击角度偏差
@export var judge_hit_deg_offset :float = 45;

## 游玩模式
var play_mode;
enum PLAY_MODE {PLAY, EDIT};

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
## 歌词到哪了
var lrc_index :int = 0;

## 游戏是否开始，开始前不允许暂停
var started := false;
## 演奏是否中途暂停
var paused := false;
## 演奏是否已结束
var ended := false;
## 是否有音乐（?
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
var ctl :Ct;
## 右侧准星
var ctr :Ct;

## 左侧轨道
var trackl :Sprite2D;
var trackl_diam := 512.0;
var trackl_line :Sprite2D;
var trackl_center :Vector2;
var trackl_path :Path2D;
## 右侧轨道
var trackr :Sprite2D;
var trackr_diam := 512.0;
var trackr_line :Sprite2D;
var trackr_center :Vector2;
var trackr_path :Path2D;

@onready var bgpanel := $BGPanel;
@onready var audio_player := $BGPanel/AudioPlayer;
@onready var video_player := $BGPanel/VideoPlayer;
@onready var background := $BGPanel/Background;
@onready var playground := $PlayGround;
@onready var lyrics_label :=  $BGPanel/LyricLabel;

var texture_slide = preload("res://image/texture/slide.svg");
var texture_slide_hint_gradient = preload("res://image/texture/slide_hint_line_gradient.tres");
var texture_bounce = preload("res://image/texture/bounce.svg");
var texture_crash = preload("res://image/texture/crash.svg");
var texture_follow = preload("res://image/texture/follow.svg");

var texture_hit_fx = preload("res://image/texture/hit_fx.svg");

var sound_hit = preload("res://sound/note_hihat.wav");

## 铺面加载完毕
signal map_loaded;
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
	
	# 初始化控制柄
	ctl = $PlayGround/CtL;
	ctr = $PlayGround/CtR;
	trackl = $PlayGround/TrackL;
	trackl_line = $PlayGround/TrackL/Mesh;
	trackl_path = $PlayGround/TrackL/Path;
	trackr = $PlayGround/TrackR;
	trackr_line = $PlayGround/TrackR/Mesh;
	trackr_path = $PlayGround/TrackR/Path;
	
	audio_player.finished.connect(end);# 音乐结束之后进入end
	
	
## 载入铺面并开始游戏
func play(map_file_path: String):
	
	print("[PlayGround] opening map files..")
	var map_file = FileAccess.open(map_file_path, FileAccess.READ);
	print("[PlayGround] result: ", map_file, ": ", error_string(FileAccess.get_open_error()));
	var dir := DirAccess.open(map_file_path.substr(0, map_file_path.rfind("/")));
	beatmap = BeatMap.new(dir, map_file);
	print("[PlayGround] map_loaded: ", beatmap);
	map_file = null;
	
	background.texture = load(beatmap.bg_image_path);
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
	
	map_loaded.emit();
	
	pre_start.call_deferred();
	# ▼▼▼ 这里初始化结束进入 pre_start

## 初始化游戏
func pre_start():
	
	trackl_center = trackl.position;
	trackr_center = trackr.position;
	
	# 为了演示加的延迟 记得删
	await get_tree().create_timer(1).timeout;
	
	# 遮罩变暗
	create_anim_tween().tween_property($BGPanel/Mask, "color:a", 0.4, 1.5).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	
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
	var playground_size = $PlayGround.size;
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
	$Pause.visible = true;
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
func jump(time :float):
	
	if ended: ended = false;
	
	pause();
	
	for i in waiting_notes.keys():
		remove_note(i);
	
	# 获取跳转到的下一个event
	var last_index := 0;
	for event in beatmap.events:
		if event.time >= play_time: break;
		last_index += 1;
	event_index = last_index;
	
	# 跳转音乐
	if paused:
		audio_player.play(time);
		audio_player.stream_paused = true;
	else:
		audio_player.seek(time);
	play_time = time;
	print("[Play] Jump to: ", time, " index = ", last_index);
	
	video_player.stop();
	if time == 0.0:
		video_player.play();
		video_player.stop();
		#video_player.paused = true;
		jumped = false;
	else:
		# 无法跳转视频播放，故暂停
		jumped = true;
	
	stream_time = time;
	start_time = Time.get_unix_time_from_system() - time;
	play_time = time;
	
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
	anim_tweens.push_back(tween);
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
				if !jumped && has_video:
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
					if play_time + event_before_beat*get_beat_time() >= event.time:
						# 判断Event是否为Note
						if event is BeatMap.Event.Note:
							# 场景里生成note
							var canvasItems = generate_note(event);
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
						lyrics_label.text = line;
						lyrics_label.create_tween().tween_property(lyrics_label, "modulate:a", 1.0, 0.1).from(0.0);
				
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
		
		var joyl :Vector2 = $VirtualJoystick.joy_l if Global.joypad_id == -1 else Global.get_joy_left();
		var joyr :Vector2 = $VirtualJoystick.joy_r if Global.joypad_id == -1 else Global.get_joy_right();
		
		# 手柄坐标越界则归一
		if joyl.length_squared() > 1: joyl = joyl.normalized();
		if joyr.length_squared() > 1: joyr = joyr.normalized();
		
		trackl.position = trackl_center + joyl * 10;
		trackr.position = trackr_center + joyr * 10;
		
		ctl.position = trackl.position + joyl*trackl_line.texture.get_size()/2;
		ctr.position = trackr.position + joyr*trackr_line.texture.get_size()/2;

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
func generate_note(note :BeatMap.Event.Note) -> Array:
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
				).from(7.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART);
			# 引导轨道（扇形）
			var polygon = Polygon2D.new();
			var polygon_points = [Vector2.ZERO];
			polygon_points.append_array(points);
			polygon_points.append(Vector2.ZERO);
			polygon.color = Color.WHITE;
			polygon.polygon = polygon_points;
			path.add_child(polygon);
			create_anim_tween(polygon).tween_property(polygon, "modulate:a", 0.1, event_before_beat*get_beat_time()
				).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);
			return [line, polygon];
		BeatMap.EVENT_TYPE.Slide:
			var path_follow := PathFollow2D.new();
			path.add_child(path_follow);
			path_follow.progress_ratio = note.deg/360.0;
			var slide := Sprite2D.new();
			slide.texture = texture_slide;
			slide.scale.x = 0.15;
			slide.scale.y = 0.15;
			# 提示线
			var line := Line2D.new();
			line.width = 4;
			line.points = [Vector2.ZERO, Vector2.ZERO];
			line.default_color = Color8(255,255,255,32);
			line.gradient = texture_slide_hint_gradient;
			path.add_child(line);
			# 动画效果
			create_anim_tween(line).tween_method(
				func(ratio: float):
					line.set_point_position(1, path_follow.position * ratio),
				0.0, 1.0, event_before_beat * get_beat_time()
			).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART);
			path_follow.add_child(slide);
			create_anim_tween(slide).tween_property(slide, "modulate:a", 1.0, event_before_beat*get_beat_time()
				).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART);
			return [path_follow, line];
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
			tween.parallel().tween_property(bounce, "scale", Vector2(0.5,0.5), event_before_beat*get_beat_time()
				).from(Vector2(1,1)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			return [bounce];
	return [];

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
	
	if offset > judge_good:
		# miss
		judge = JUDGEMENT.MISS;
		judged_notes[wait_index] = note_array;
		match note.event_type:
			BeatMap.EVENT_TYPE.Hit:
				var line :Line2D = note_item_array[0];
				var polygon :Polygon2D = note_item_array[1];
				#polygon.color.r = 1;
				var tween = create_anim_tween(polygon);
				tween.finished.connect(func(): if polygon != null: polygon.queue_free());
				tween.set_ease(Tween.EASE_OUT);
				tween.set_trans(Tween.TRANS_LINEAR);
				tween.parallel().tween_property(polygon, "modulate", Color(0.9,0.4,0.4,0), note_after_time);
			BeatMap.EVENT_TYPE.Slide:
				var slide_path_follow :PathFollow2D = note_item_array[0];
				var line :Line2D = note_item_array[1];
				#line.color.r = 1;
				var tween = create_anim_tween(line);
				tween.finished.connect(func(): if line != null: line.queue_free());
				tween.set_ease(Tween.EASE_OUT);
				tween.set_trans(Tween.TRANS_LINEAR);
				tween.parallel().tween_property(slide_path_follow, "modulate", Color(1,0,0,0), note_after_time);
				tween.parallel().tween_property(line, "modulate", Color(1,0,0,0), note_after_time);
			BeatMap.EVENT_TYPE.Bounce:
				var bounce :Sprite2D = note_item_array[0];
				var tween = create_anim_tween(bounce);
				tween.finished.connect(func(): if bounce != null: bounce.queue_free());
				tween.set_ease(Tween.EASE_OUT);
				tween.set_trans(Tween.TRANS_LINEAR);
				tween.parallel().tween_property(bounce, "modulate", Color(1,0,0,0), note_after_time);
		remove_note(wait_index);
		return;
	
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
	
	# 判断碰没碰上
	match note.event_type:
		BeatMap.EVENT_TYPE.Hit:
			note = note as BeatMap.Event.Note.Hit;
			touched = (
				ct.distance >= radius - judge_radius_offset &&
				is_in_degree(ct.degree, note.deg, note.deg_end)
			);
			hit = is_in_degree(
				get_degree_in_track(ct.velocity, true),
				note.deg - judge_hit_deg_offset,
				note.deg_end + judge_hit_deg_offset
			);
			#print("touched %s\thit %s" % [touched, hit]);
			if ct.velocity.length() >= judge_hit_speed && touched && hit:
				# 速度足够而且碰上了!!
				judged_notes[wait_index] = note_array;
				var line :Line2D = note_item_array[0];
				var polygon :Polygon2D = note_item_array[1];
				line.default_color = Color(0.95, 0.9, 0.55) if judge == JUDGEMENT.JUST else Color(0.95, 0.9, 0.75);
				line.queue_redraw();
				play_sound(sound_hit);
				# 特效
				var line_fx := line.duplicate() as Line2D;
				line_fx.default_color.a = 0.3;
				track.add_child(line_fx);
				var tween = create_anim_tween(line_fx);
				tween.parallel().tween_property(line_fx, "width", 140, note_after_time
					).from(1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
				#tween.parallel().tween_property(line_fx, "scale", Vector2(1.2,1.2), note_after_time
				#	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
				tween.parallel().tween_property(line_fx, "modulate:a", 0, note_after_time*2
					).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD);
				note_item_array.append(line_fx);
				
				remove_note(wait_index);

## 更新ct的数值
func update_ct(ct: Ct):
	ct.pos = get_ct_position(ct);
	ct.distance = ct.pos.length();
	ct.degree = get_degree_in_track(ct.pos, true);
	ct.velocity_degree = (
		0 if ct.velocity == Vector2.ZERO else get_degree_in_track(ct.velocity, true)
	);

## 获取 Ct 在 track 中的相对位置
func get_ct_position(ct: Ct) -> Vector2:
	return ct.position - (trackl.position if ct == ctl else trackr.position);

## 通过与 track中心 的相对位置获取度数（顺时针，正上0°）
func get_degree_in_track(vec: Vector2, negative_y :bool = false) -> float:
	return abs(fposmod((float(atan2(vec.y if !negative_y else -vec.y , vec.x)/PI)*180.0-90), -360));

## 判断此度数x是否在min~max里
func is_in_degree(x: float, min: float, max: float) -> bool:
	if min > max:
		var temp_min = min;
		min = max;
		max = temp_min;
	x = fposmod(x, 360) + 360 * floor(min/360.0);
	#print("min %.1f\tct %.1f\tmax %.1f" % [min, x ,max]);
	return min <= x && x <= max;

func play_sound(stream: AudioStream, volume: float = 0, pitch: float = 1, bus: String = "Master"):	
	var audio_player = AudioStreamPlayer.new();
	add_child(audio_player);
	audio_player.stream = stream;
	audio_player.volume_db = volume
	audio_player.pitch_scale = pitch;
	audio_player.bus = bus;
	audio_player.finished.connect(func(): audio_player.queue_free());
	audio_player.play();

## 删掉waiting_note[index]的全部玩意儿
func remove_note(wait_index :int):
	
	var array = waiting_notes.get(wait_index);
	if array == null || array.is_empty(): return;
	
	var canvas_items = array[1];

	# 删掉所有 canvasItem
	for item in canvas_items:
		if item == null: continue;
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
