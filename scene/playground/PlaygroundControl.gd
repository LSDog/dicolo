class_name PlaygroundControl
extends Control

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
@onready var audioPlayer := $BGPanel/AudioPlayer;
@onready var videoPlayer := $BGPanel/VideoContainer/VideoPlayer;
@onready var background := $BGPanel/Background;
@onready var playground := $PlayGround;
@onready var progress := $BGPanel/Progress;
@onready var labelScore := $BGPanel/LabelScore;
@onready var labelAcc := $BGPanel/LabelAcc;
@onready var labelCombo := $BGPanel/LabelCombo;
@onready var progressAcc := $BGPanel/ProgressAcc;
@onready var lyricsLabel :=  $BGPanel/LyricLabel;
@onready var virtualJoystick := $VirtualJoystick;
@onready var buttonMenu := $ButtonMenu;
@onready var panelScore := $PanelScore;

@export_category("Setting")
@export var enable_control :bool = true; ## 允许控制

@export var enable_virtualJoystick :bool = false: ## 是否使用虚拟摇杆
	set(value):
		enable_virtualJoystick = value;
		virtualJoystick.visible = value;
		virtualJoystick.mouse_filter = MOUSE_FILTER_STOP if value else MOUSE_FILTER_IGNORE;
		virtualJoystick.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED;
## 铺/音/画不同步的调整阈值
@export var max_delay :float = 0.05;

@export_category("Timing")
## 预处理拍数，相当于“音符在击打前多久开始出现动画”
var event_before_beat :float = 4;
var note_after_time :float = 0.25; ## 音符动画时间

@export_category("Judge")
@export var judge_best :float = 0.1; ## 判定 best 的时间
@export var acc_best :float = 1.0; ## best 的准确度
@export var judge_good :float = 0.25; ## 判定 good 的时间
@export var acc_good :float = 0.5; ## good 的准确度
@export var acc_miss :float = 0.0; ## miss 的准确度
var judge_bound_radius :float = 10; ## bound 回弹的最大判定半径
var judge_bound_speed :float = 100; ## bound 回弹的最小速度

var texture_hit_fx = preload("res://visual/texture/hit_fx.svg");
var texture_slide = preload("res://visual/texture/slide.svg");
var texture_slide_hint_ring = preload("res://visual/texture/ring.svg");
var texture_slide_hint_point = preload("res://visual/texture/slide_hint.svg");
var texture_bound = preload("res://visual/texture/bound.svg");
var texture_follow = preload("res://visual/texture/follow.svg");

var sound_hit = preload("res://audio/map/note_hihat.wav");
var sound_cross = preload("res://audio/map/note_snarehat.wav");
var sound_slide = preload("res://audio/map/note_hihatclosed.wav");
var sound_bound = preload("res://audio/map/note_floortom.wav");

## 游玩模式
var play_mode := PLAY_MODE.PLAY;
enum PLAY_MODE {PLAY, EDIT}; ## 游玩模式的枚举
## 输入模式: 摇杆/虚拟摇杆/触控
var input_mode := INPUT_MODE.TOUCH;
enum INPUT_MODE {JOYSTICK,V_JOYSTICK,TOUCH} ## 输入模式的枚举
## 判定的枚举
enum JUDGEMENT { BEST, GOOD, MISS }

## 判定的代表色
const JUDGE_COLOR :Array[Color] = [Color(0.95, 0.9, 0.55), Color(0.55, 0.95, 0.9), Color.WHITE];
const COLOR_BEST = JUDGE_COLOR[0];
const COLOR_GOOD = JUDGE_COLOR[1];
const COLOR_MISS = JUDGE_COLOR[2];

## 铺面
var beatmap :BeatMap;
## 事件索引（包括音符等...）
var event_index :int = 0;
## 在场的（等待判定）的音符和相关canvas结点。结构 [codeblock] 
## {8:[Note,[PathFollow2D]], 9:[Note,[PathFollow2D, Line2D, PathFollow2D]]} [/codeblock]
var waiting_notes := {};
## 已进行判定的音符和相关canvas结点。结构同 waiting_notes
var judged_notes := {};
var bpm :float; ## 当前bpm
var anim_tweens :Array[Tween] = []; ## 动画的tween们

## 触控点，index为事件中的index，结构为
## [ [[l_pos, l_deg, dis], [r_pos, r_deg, dis], vec, vec_deg], ... ]
##   [[左track相对位置,度数,距离], [右track...], 速度, 速度的角度]
var touch_points :Array = [];
## 上一帧的触控点，结构为
## [ [l_pos, r_pos], ... ]
var prev_touch_points :Array = [];
var touch_just :int = 0; ## 每一位(右到左)1/0表示touch_points中index是否为新的点击
var touch_used :int = 0; ## 同上，按位表示touch_points中index是否已经用于作为判定了

## 歌词
var lyrics :LyricsFile;
var lrc_index :int = 0; ## 歌词到哪句了

# 状态
var started := false; ## 游戏是否开始，开始前不允许暂停
var paused := false; ## 演奏是否中途暂停
var ended := false; ## 演奏是否已结束
var has_video := false; ## 是否有背景视频
var has_lyrics := false; ## 是否有歌词
var jumped := false; ## 是否为跳转后状态

var stream_time := 0.0; ## 当前音乐(若有视频则为视频)播放的时间（秒）
var start_time := 0.0; ## 开始时间戳
var play_time := 0.0; ## 演奏总时间

var score :float = 0.0; ## 总分
var combo :int = 0; ## 当前combo
var max_combo :int = 0; ## 最大Combo
var acc :float = -1; ## 准确度，-1为等待第一次输入
var judge_counts :Array[int] = [];

# 信号
signal map_loaded; ## 铺面加载完毕
var map_has_loaded :bool = false; ## map是否加载
signal play_start; ## 开始播放
signal play_pause; ## 暂停
signal play_resume; ## 恢复
signal play_jump(time:float); ## 跳转
signal play_restart; ## 重开
signal play_end; ## 结束

func _ready():
	
	match input_mode:
		INPUT_MODE.TOUCH:
			enable_virtualJoystick = false;
		INPUT_MODE.JOYSTICK:
			enable_virtualJoystick = false;
	
	correct_size();
	judge_counts.resize(JUDGEMENT.size());
	touch_points.resize(20);
	prev_touch_points.resize(20);
	
	buttonMenu.pressed.connect(func():
		if !paused: pause();
		else: resume();
	)
	
	# 暂停菜单
	$Pause/Content/Quit.pressed.connect(quit);
	$Pause/Content/Back.pressed.connect(resume);
	$Pause/Content/Restart.pressed.connect(restart);
	
	# 音乐结束之后进入end
	audioPlayer.finished.connect(end);

func quit():
	var playgroundScene = get_tree().current_scene;
	Global.unfreeze(Global.mainMenu);
	Global.mainMenu.visible = true;
	Global.mainMenu.back_to_mainMenu();
	get_tree().current_scene = Global.mainMenu;
	get_tree().root.remove_child(playgroundScene);
	playgroundScene.queue_free();

## 修正大小
func correct_size():
	# 保证 stretch scale 更改后 track 大小不变
	var keep_scale = Vector2(1.0/Global.stretch_scale, 1.0/Global.stretch_scale);
	$VirtualJoystick/LOut.scale = Vector2.ONE * 0.2 * keep_scale;
	$VirtualJoystick/ROut.scale = Vector2.ONE * 0.2 * keep_scale;
	progress.scale = keep_scale;
	buttonMenu.scale = keep_scale;
	playground.scale = keep_scale;
	videoPlayer.get_stream_name()


## 载入铺面并开始游戏
func load_map(map_file_path: String, auto_start: bool = false):
	
	print("[PlayGround] opening map files..")
	var map_file = FileAccess.open(map_file_path, FileAccess.READ);
	print("[PlayGround] result: ", map_file, ": ", error_string(FileAccess.get_open_error()));
	beatmap = BeatMap.new(map_file_path.get_base_dir(), map_file);
	print("[PlayGround] map_loaded: ", beatmap);
	map_file = null;
	
	load_bg_image();
	load_audio();
	load_video();
	$BGPanel/DebugLabel.text = "debug text..."
	
	bpm = beatmap.bpm;
	print("Default bpm = ", bpm);
	print("One Beat = ", get_beat_time(), "s");
	print("Event counts = ", beatmap.event_counts);
	print("Note Scores = ", beatmap.note_scores);
	if beatmap.lrc_path != "":
		var lrcfile = LyricsFile.new(FileAccess.open(beatmap.get_lrc_path(), FileAccess.READ));
		if lrcfile.loaded:
			lyrics = lrcfile;
			has_lyrics = true;
	
	map_has_loaded = true;
	map_loaded.emit();
	
	if auto_start:
		pre_start.call_deferred();
		# ▼▼▼ 这里初始化结束进入 pre_start

func load_bg_image():
	background.texture = ExternLoader.load_image(beatmap.get_bg_image_path()
		) if beatmap.bg_image_path != "" else Global.mainMenu.default_backgrounds.pick_random();

func load_audio():
	audioPlayer.stream = ExternLoader.load_audio(beatmap.get_audio_path());

func load_video():
	has_video = beatmap.video_path != "";
	if has_video: videoPlayer.stream = load(beatmap.get_video_path());
	has_video = false if videoPlayer.stream == null else true;

## 准备开始游戏
func pre_start():
	
	# 数据还原/设零
	set_combo(0);
	set_score(0);
	reset_acc();
	judge_counts.fill(0);
	
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
	
	# Progress 归零
	create_anim_tween(progress).tween_property(progress, "value", 0.0, 1.5
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART);
	
	# ▼▼▼ 这里动画结束进入 start

## 开始游戏
func start():
	if has_video:
		# 背景变更黑
		create_anim_tween().tween_property(background, "modulate:v", 0.3, 2).from_current().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD);
		# 开始视频
		videoPlayer.play();
		# 淡入视频
		create_anim_tween().tween_property(videoPlayer, "modulate:a", 1.0, 1).from(0.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD);
	# 开始音频
	audioPlayer.play();
	started = true;
	start_time = Time.get_unix_time_from_system();
	
	play_start.emit();

## 暂停
func pause():
	if !started: return;
	
	paused = true;
	videoPlayer.paused = true;
	audioPlayer.stream_paused = true;
	if play_mode == PLAY_MODE.PLAY: $Pause.visible = true;
	pause_anim_tweens();
	
	play_pause.emit();

## 取消暂停
func resume():
	
	$Pause.visible = false;
	videoPlayer.paused = false;
	audioPlayer.stream_paused = false;
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
		audioPlayer.play(time);
		audioPlayer.stream_paused = true;
	else:
		audioPlayer.seek(time);
	play_time = time;
	print("[Play] Jump to: ", time, " index = ", last_index);
	
	# 跳转视频(只能暂停或回到第一帧开始)
	videoPlayer.stop();
	if time == 0.0:
		videoPlayer.stop();
		videoPlayer.play();
		videoPlayer.paused = true;
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
	_process(1/100.0);
	pause();
	
	#print(anim_tweens)
	
	play_jump.emit(time);

## 重开游戏
func restart():
	
	$Pause.visible = false;
	ended = false;
	started = false;
	paused = false;
	audioPlayer.stop();
	audioPlayer.seek(0);
	videoPlayer.stop();
	audioPlayer.stream_paused = false;
	videoPlayer.paused = false;
	stream_time = 0;
	start_time = 0.0;
	play_time = 0.0;
	event_index = 0;
	waiting_notes.clear();
	judged_notes.clear();
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
	audioPlayer.stop();
	videoPlayer.stop();
	
	play_end.emit();
	panelScore.set_value();
	panelScore.show_anim();

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

func _gui_input(event: InputEvent) -> void:
	## 触控输入
	if input_mode != INPUT_MODE.TOUCH: return;
	if event is InputEventScreenTouch:
		if event.pressed:
			var pos :Vector2 = event.position - playground.global_position;
			var l_pos := pos-trackl_center;
			var r_pos := pos-trackr_center;
			touch_points[event.index] = [
				[l_pos, get_degree_in_track(l_pos), l_pos.length()],
				[r_pos, get_degree_in_track(r_pos), r_pos.length()],
				0, 0
			];
			touch_just |= 1 << event.index;
		else:
			touch_used &= 0 << event.index;
			touch_points.remove_at(event.index);
			if touch_points.is_empty(): touch_points.resize(20);
		print(event);
		accept_event();
	elif event is InputEventScreenDrag:
		var touch :Array = touch_points[event.index];
		var pos :Vector2 = event.position - playground.global_position;
		var l_pos := pos-trackl_center;
		var r_pos := pos-trackr_center;
		touch[0] = [l_pos, get_degree_in_track(l_pos), l_pos.length()];
		touch[1] = [r_pos, get_degree_in_track(r_pos), r_pos.length()];
		touch[2] = event.velocity;
		touch[3] = get_degree_in_track(event.velocity);
		accept_event();

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("esc"):
		if !paused: pause();
		else: resume();
		accept_event();

func _process(delta):
	
	if !map_has_loaded: return;
	
	var can_control = false;
	
	var audio_pos :float = audioPlayer.get_playback_position();
	var audio_length := get_audio_length();
	
	progress.value = audio_pos/audio_length;
	
	# 通过播放进度判断是否end
	if !ended && audio_pos >= audio_length:
		end();
	
	if !ended: # 未结束
		
		var video_pos = videoPlayer.stream_position;
		
		stream_time = video_pos if has_video else audio_pos;
		
		if !paused: # 未暂停
			
			can_control = false;
			
			if started: # 游戏已开始
				
				can_control = true;
				play_time += delta;
				
				# 音频 <- 视频流校准
				if videoPlayer.is_playing() && !videoPlayer.paused && !jumped && has_video:
					var audio_delay = audio_pos - video_pos;
					if abs(audio_delay) > max_delay: # 音视频延迟超过校准时间就回调音频
						# 更新 audio_pos
						audio_pos = audio_pos-audio_delay;
						audioPlayer.seek(audio_pos);
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
						else:
							waiting_notes[event_index] = [event];
						event_index += 1;
					else:
						break;
				
				
				# 计算俩个 Ct 的值
				if input_mode == INPUT_MODE.JOYSTICK || input_mode == INPUT_MODE.V_JOYSTICK:
					update_ct(ctl);
					update_ct(ctr);
				
				
				# 处理等待中的event
				for wait_index in waiting_notes:
					var event_array = waiting_notes[wait_index];
					var event = event_array[0];
					if event is BeatMap.Event.Note:
						# 这里判定Note
						judge_note(wait_index, event_array);
					elif play_time >= event.time:
						# 这里处理事件
						handle_other_event(wait_index);
				
				if input_mode == INPUT_MODE.TOUCH:
					# 清除此帧“刚点击”的按钮
					if touch_just != 0: touch_just = 0;
					# 搞“上一帧的触控点”
					prev_touch_points.fill([]);
					for i in touch_points.size():
						var touch = touch_points[i];
						if touch == null || touch.is_empty(): return;
						if prev_touch_points[i].is_empty():
							prev_touch_points[i].resize(2);
						prev_touch_points[i][0] = touch[0][0];
						prev_touch_points[i][1] = touch[1][0];
				
				# All best / Full Combo 指示(在acc圈的颜色上)
				var best_judge := (
					JUDGEMENT.MISS if judge_counts[JUDGEMENT.MISS] != 0 else
					JUDGEMENT.BEST if judge_counts[JUDGEMENT.GOOD] == 0 else
					JUDGEMENT.GOOD
				);
				progressAcc.tint_progress = JUDGE_COLOR[best_judge];
				
				
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
func handle_other_event(wait_index: int):
	var event :BeatMap.Event = waiting_notes[wait_index][0];
	print("handle event: ", event);
	match event.type:
		BeatMap.EVENT_TYPE.Start:
			print("[Event] -- Start!");
		BeatMap.EVENT_TYPE.End:
			end();
			print("[Event] -- End!")
		BeatMap.EVENT_TYPE.Bpm:
			bpm = event.bpm;
			print("[Event] -- Bpm changed: ", event.bpm);
	waiting_notes.erase(wait_index);

## 通过note获取相应的轨道
func get_track(note :BeatMap.Event.Note) -> CanvasItem:
	return trackl if note.side == note.SIDE.LEFT else (
		trackr if note.side == note.SIDE.RIGHT else null);

## 生成音符并返回相关的CanvasItem节点数组，如 [PathFollow2D] 或 [PathFollow2D, Path2D, PathFollow2D]
## offset: 与预生成时间点的差值
func generate_note(note :BeatMap.Event.Note, before_time: float, offset :float = 0.0) -> Array:
	#print("[Event] ", BeatMap.EVENT_TYPE.find_key(note.type), " ", play_time);
	var track = get_track(note);
	var path :Path2D = track.get_child(0) as Path2D; # 获取 path2D 记得放在第一位
	
	match note.type:
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
		BeatMap.EVENT_TYPE.Cross:
			var radius = trackl_diam/2.0 if track == trackl else trackr_diam/2.0;
			var start_pos = get_point_on_track(note.deg, radius);
			var end_pos = get_point_on_track(note.deg_end, radius);
			var line := Line2D.new();
			line.width = 10;
			line.points = [start_pos, start_pos];
			line.default_color = Color(246, 227, 242, 0.5);
			path.add_child(line);
			var hint_line := Line2D.new();
			hint_line.points = [start_pos, end_pos];
			hint_line.default_color = Color(1,1,1,0);
			hint_line.begin_cap_mode = Line2D.LINE_CAP_ROUND;
			hint_line.end_cap_mode = Line2D.LINE_CAP_ROUND;
			path.add_child(hint_line);
			var tween = create_anim_tween(line);
			tween.parallel().tween_method((func(pos): line.points[1] = pos),
				start_pos, end_pos, event_before_beat*get_beat_time()
				).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			tween.parallel().tween_property(hint_line, "default_color:a", 0.5, event_before_beat*get_beat_time()
				).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC);
			tween.parallel().tween_property(hint_line, "width", line.width, event_before_beat*get_beat_time()
				).from(96).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC);
			tween_step(tween, offset);
			return [line, hint_line];
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
		BeatMap.EVENT_TYPE.Bound:
			var bound = Sprite2D.new();
			bound.texture = texture_bound;
			path.add_child(bound);
			bound.show_behind_parent = true;
			var tween = create_anim_tween(bound);
			tween.parallel().tween_property(bound, "modulate:a", 1.0, event_before_beat*get_beat_time()
				).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART);
			tween.parallel().tween_property(bound, "rotation_degrees", 0.0, event_before_beat*get_beat_time()
				).from(-180.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			tween.parallel().tween_property(bound, "scale", Vector2(0.4,0.4), event_before_beat*get_beat_time()
				).from(Vector2(1,1)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
			tween_step(tween, offset);
			return [bound];
	return [];

## 让一个tween跳到delta秒后
func tween_step(tween: Tween, delta: float, kill_if_finish: bool = true):
	if !tween.custom_step(delta) && kill_if_finish:
		print("kill ", tween);
		tween.kill();
		anim_tweens.erase(tween);

## 判定note
func judge_note(wait_index :int, note_array = null):
	if judged_notes.has(wait_index):
		return; # 此音符已判定 忽略
	if note_array == null: note_array = waiting_notes[wait_index];
	var note :BeatMap.Event.Note = note_array[0];
	var offset = play_time - note.time;
	if offset < -judge_good: return; # 还早着呢
	
	var judge;
	var note_item_array :Array = note_array[1];
	
	# miss 判定与动画
	if offset > judge_good:
		judge = JUDGEMENT.MISS;
		judge_counts[judge] += 1;
		judged_notes[wait_index] = note_array;
		set_combo(0);
		update_acc(acc_miss);
		match note.type:
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
			BeatMap.EVENT_TYPE.Cross:
				var line :Line2D = note_item_array[0];
				var hint_line :Line2D = note_item_array[1];
				var tween = create_anim_tween(hint_line);
				tween.set_ease(Tween.EASE_OUT);
				tween.set_trans(Tween.TRANS_LINEAR);
				tween.parallel().tween_property(line, "modulate", Color(1,0,0,0), note_after_time);
				tween.parallel().tween_property(hint_line, "modulate", Color(1,0,0,0), note_after_time);
			BeatMap.EVENT_TYPE.Bound:
				var bound :Sprite2D = note_item_array[0];
				var tween = create_anim_tween(bound);
				tween.finished.connect(func(): if bound != null: bound.queue_free());
				tween.set_ease(Tween.EASE_OUT);
				tween.set_trans(Tween.TRANS_LINEAR);
				tween.parallel().tween_property(bound, "modulate", Color(1,0,0,0), note_after_time);
		remove_note(wait_index, true);
		return;
	
	# 非 miss 的判定与动画
	
	var edit_mode :bool = play_mode == PLAY_MODE.EDIT;
	# 编辑模式下精准击中
	if edit_mode && offset < 0: return;
	
	if offset >= -judge_best && offset <= judge_best:
		judge = JUDGEMENT.BEST;
	else:
		judge = JUDGEMENT.GOOD;
	
	var track := get_track(note);
	var radius := trackl_diam/2.0 if track == trackl else trackr_diam/2.0;
	var ct := ctl if note.side == note.SIDE.LEFT else ctr;
	
	var is_judged := false;
	
	# 判断碰没碰上 然后搞特效 让判定完的东西消失啥的
	match note.type:
		
		BeatMap.EVENT_TYPE.Hit:
			note = note as BeatMap.Event.Note.Hit;
			var reached := false;
			if input_mode == INPUT_MODE.JOYSTICK || input_mode == INPUT_MODE.V_JOYSTICK:
				# 摇杆输入, 通过ct判断
				reached = (
					# ct 距离 track边缘 5px 内
					ct.distance >= radius - 5 &&
					# 在角度内
					is_in_degree(ct.degree, note.deg, note.deg_end) &&
					# 撞击角度 最大容许偏差45°(一共90°)
					is_in_degree(
						get_degree_in_track(ct.velocity),
						ct.degree - 45, ct.degree + 45
					) &&
					# 速度大于256px/s
					ct.velocity.length() >= 256
				);
			elif input_mode == INPUT_MODE.TOUCH:
				# 触控输入
				for i in touch_points.size():
					if (touch_just>>i)&1 != 1 || (touch_used>>i)&1 != 0: continue;
					var touch = touch_points[i];
					if touch == null || touch.is_empty(): continue;
					var point = touch[0 if note.side == BeatMap.Event.SIDE.LEFT else 1];
					if point == null || point.is_empty(): continue;
					# 点击距离track边缘最大128px (共256px)
					reached = (
						# 触控角度可偏差±10
						is_in_degree(point[1], note.deg, note.deg_end, 10) &&
						radius - 128 <= point[2] && point[2] <= radius + 128
					);
					if reached:
						touch_used |= 1 << i;
						break;
			if edit_mode || reached:
				is_judged = true;
				anim_track_flash(note.side, JUDGE_COLOR[judge]);
				var line :Line2D = note_item_array[0];
				#var polygon :Polygon2D = note_item_array[1];
				line.default_color = JUDGE_COLOR[judge];
				line.queue_redraw();
				play_sound(sound_hit);
				# 特效
				var line_fx := line.duplicate() as Line2D;
				line_fx.default_color.a = 0.3;
				track.add_child(line_fx);
				var tween = create_anim_tween(line_fx);
				tween.parallel().tween_property(line_fx, "width", 140.0, note_after_time
					).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
				tween.parallel().tween_property(line_fx, "modulate:a", 0.0, note_after_time
					).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD);
				note_item_array.append(line_fx);
				
				note_array[1] = note_item_array; ## 新Node得加进去
				judged_notes[wait_index] = note_array;
				remove_note(wait_index, true);
		
		BeatMap.EVENT_TYPE.Slide:
			note = note as BeatMap.Event.Note.Slide;
			var reached := false;
			if input_mode == INPUT_MODE.JOYSTICK || input_mode == INPUT_MODE.V_JOYSTICK:
				reached = (
					ct.distance >= radius - 5 &&
					is_in_degree(ct.degree, note.deg, note.deg, 4)
				);
			elif input_mode == INPUT_MODE.TOUCH:
				for i in touch_points.size():
					var touch = touch_points[i];
					if touch == null || touch.is_empty(): continue;
					var point = touch[0 if note.side == BeatMap.Event.SIDE.LEFT else 1];
					if point == null || point.is_empty(): continue;
					reached = (
						is_in_degree(point[1], note.deg, note.deg, 10) &&
						radius - 128 <= point[2] && point[2] <= radius + 128
					);
					if reached: break;
			if edit_mode || reached:
				is_judged = true;
				anim_track_flash(note.side, JUDGE_COLOR[judge]);
				var path_follow := note_item_array[0] as PathFollow2D;
				#var slide :Sprite2D = path_follow.get_child(0);
				var ring := path_follow.get_child(1) as Sprite2D;
				ring.modulate = COLOR_BEST;
				ring.queue_redraw();
				play_sound(sound_slide);
				var tween = create_anim_tween(ring);
				tween.parallel().tween_property(ring, "scale", Vector2(1,1), note_after_time
					).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
				tween.parallel().tween_property(ring, "modulate:a", 0.0, note_after_time*2
					).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
				
				judged_notes[wait_index] = note_array;
				remove_note(wait_index, true);
		
		BeatMap.EVENT_TYPE.Cross:
			note = note as BeatMap.Event.Note.Cross;
			var start_pos = get_point_on_track(note.deg, radius);
			var end_pos = get_point_on_track(note.deg_end, radius);
			var crossed := false;
			if input_mode == INPUT_MODE.JOYSTICK || input_mode == INPUT_MODE.V_JOYSTICK:
				crossed = has_crossed_line(start_pos, end_pos, ct.pos, ct.prev_pos);
			elif input_mode == INPUT_MODE.TOUCH:
				var side_index := 0 if note.side == BeatMap.Event.SIDE.LEFT else 1;
				for i in touch_points.size():
					var prev_point = prev_touch_points[i];
					if prev_point == null || prev_point.is_empty(): continue;
					var touch = touch_points[i];
					if touch == null || touch.is_empty(): continue;
					var point = touch[side_index];
					if point == null || point.is_empty(): continue;
					# 点击距离track边缘最大128px (共256px)
					crossed = has_crossed_line(start_pos, end_pos, prev_point[side_index], point[0]);
					if crossed:
						touch_used |= 1 << i;
						break;
			if edit_mode || crossed:
				is_judged = true;
				anim_track_flash(note.side, JUDGE_COLOR[judge]);
				judged_notes[wait_index] = note_array;
				var line :Line2D = note_item_array[0];
				var hint_line :Line2D = note_item_array[1];
				var extend_start := hint_line.points[0]*2 - hint_line.points[1];
				var extend_end := hint_line.points[1]*2 - hint_line.points[0];
				hint_line.begin_cap_mode = Line2D.LINE_CAP_BOX;
				hint_line.end_cap_mode = Line2D.LINE_CAP_BOX;
				hint_line.modulate = JUDGE_COLOR[judge];
				hint_line.queue_redraw();
				play_sound(sound_cross);
				var tween = create_anim_tween(hint_line);
				tween.parallel().tween_property(line, "modulate:a", 0.0, note_after_time
					).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
				tween.parallel().tween_method(
					func(pos:Vector2): hint_line.set_point_position(0, pos),
					hint_line.points[0], extend_start, note_after_time
				).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
				tween.parallel().tween_method(
					func(pos:Vector2): hint_line.points[1] = pos,
					hint_line.points[1], extend_end, note_after_time
				).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
				tween.parallel().tween_property(hint_line, "modulate:a", 0.0, note_after_time/2.0
					).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
				
				judged_notes[wait_index] = note_array;
				remove_note(wait_index, true);
		
		BeatMap.EVENT_TYPE.Bound:
			note = note as BeatMap.Event.Note.Bound;
			var reached := false;
			if input_mode == INPUT_MODE.JOYSTICK || input_mode == INPUT_MODE.V_JOYSTICK:
				reached = ct.distance <= 10 && ct.velocity.length_squared() >= 5000**2
			elif input_mode == INPUT_MODE.TOUCH:
				for i in touch_points.size():
					if (touch_just>>i)&1 != 1 || (touch_used>>i)&1 != 0: continue;
					var point = touch_points[i][0 if note.side == BeatMap.Event.SIDE.LEFT else 1];
					if point == null || point.is_empty(): continue;
					reached = point[2] <= 128;
					if reached:
						touch_used |= 1 << i;
						break;
			if edit_mode || reached:
				is_judged = true;
				anim_track_flash(note.side, JUDGE_COLOR[judge]);
				judged_notes[wait_index] = note_array;
				var bound := note_item_array[0] as Sprite2D;
				bound.modulate = JUDGE_COLOR[judge];
				bound.queue_redraw();
				play_sound(sound_bound);
				var tween = create_anim_tween(bound);
				tween.parallel().tween_property(bound, "scale", Vector2(1.5, 1.5), note_after_time
					).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
				tween.parallel().tween_property(bound, "modulate:a", 0.0, note_after_time*2
					).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
				
				remove_note(wait_index, true)
	
	if is_judged:
		set_combo(combo + 1);
		update_acc(acc_best if judge == JUDGEMENT.BEST else acc_good);
		set_score(score + get_score(note.type, judge, offset));
		judge_counts[judge] += 1;

func anim_track_flash(side: BeatMap.Event.SIDE, color: Color = COLOR_MISS):
	if side == null || side == BeatMap.Event.SIDE.NONE: return;
	var track_circle = trackl_circle if side == BeatMap.Event.SIDE.LEFT else trackr_circle;
	color.a = 0.5;
	track_circle.create_tween().tween_property(track_circle, "modulate", trackl_circle.modulate, 0.1
		).from(color).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);

const E :float = 2.718281828459045;

func get_score(note_type: BeatMap.EVENT_TYPE, judge: JUDGEMENT, offset: float = 0) -> float:
	var base_score = beatmap.note_scores[note_type];
	match judge:
		JUDGEMENT.BEST: return base_score;
		JUDGEMENT.GOOD: return base_score*(
			(pow(E,-40*offset+10)+401.4287934927351)/804.8575869854702);
		# GOOD's curve -> (e^(-40*offset + 10) + e^(6) - 2)/(2*e^(6) - 2)
		_,JUDGEMENT.MISS: return 0;

func set_score(value: float):
	score = value;
	labelScore.text = "%07d" % floori(roundi(score*10)/10.0);
	# round四舍五入小数第二位，解决分数满分总和变成999999

func set_combo(value: int):
	combo = value;
	if combo > max_combo: max_combo = combo;
	labelCombo.text = str(combo);
	labelCombo.create_tween().tween_property(labelCombo, "scale", Vector2.ONE, 0.1
		).from(Vector2.ONE*1.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);

func update_acc(new_acc: float):
	acc = new_acc if acc == -1 else (acc+new_acc)/2.0;
	labelAcc.text = ("%.2f" % (acc*100.0)).replace('.', ',') + "%";
	progressAcc.value = acc;

func reset_acc():
	acc = -1;
	labelAcc.text = "00,00%";

## 更新ct的数值
func update_ct(ct: Ct):
	ct.prev_pos = ct.pos;
	ct.pos = get_ct_position(ct);
	ct.distance = ct.pos.length();
	ct.degree = get_degree_in_track(ct.pos);
	ct.velocity_degree = (
		0.0 if ct.velocity == Vector2.ZERO else get_degree_in_track(ct.velocity)
	);

## 获取 Ct 在 track 中的相对位置
func get_ct_position(ct: Ct) -> Vector2:
	return ct.position - (trackl.position if ct == ctl else trackr.position);

## 通过与 track中心 的相对位置获取度数（顺时针，正上0°）
func get_degree_in_track(vec: Vector2) -> float:
	return (
		0 if vec == Vector2.ZERO else
		abs(fposmod((float(atan2(-vec.y , vec.x)/PI)*180.0-90), -360))
	);

## 判断此度数x是否在min~max里, offset 可以让两边范围增加(2*offset)
func is_in_degree(x: float, min_val: float, max_val: float, offset: float = 0) -> bool:
	if min_val > max_val:
		var temp_min := min_val;
		min_val = max_val;
		max_val = temp_min;
	min_val -= offset;
	max_val += offset;
	if min_val < 0 && max_val > 0:
		# 跨 0° 的判断方法: 拆成 前面~0° 以及 0°~后面
		return is_in_degree(x, min_val, 0) || is_in_degree(x, 0, max_val);
	x = fposmod(x, 360) + 360 * floorf(min_val/360.0);
	return min_val <= x && x <= max_val;

## 检查先后两点是否穿过了一条线，包括prev点在线上的情况
func has_crossed_line(
	line_start: Vector2, line_end: Vector2,
	pos_now: Vector2, pos_prev: Vector2) -> bool:
	if pos_prev == pos_now: return false;
	if line_start.y == line_end.y: ## 横线
		return pos_prev.x <= line_start.x && pos_now.x >= line_start.x;
	elif line_start.x == line_end.x: ## 竖线
		return pos_prev.y <= line_start.y && pos_now.y >= line_start.y;
	else: ## 斜线，通过与在线上同x的点的y值比较
		var delta_y = line_end.y - line_start.y;
		var delta_x = line_end.x - line_start.x;
		var y_del_prev = (pos_prev.x - line_start.x)/delta_x*delta_y - pos_prev.y;
		var y_del_now = (pos_now.x - line_start.x)/delta_x*delta_y - pos_now.y;
		#print("    >> has_crossed_line : (%.1f,%.1f)"%[y_del_prev, y_del_now])
		return y_del_prev <= 0 && y_del_now > 0 || y_del_prev >= 0 && y_del_now < 0;

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
			if play_mode == PLAY_MODE.EDIT: item.free();
			else: item.queue_free();
		else:
			var tween := create_anim_tween();
			tween.finished.connect(func():
				if item != null: item.queue_free();
			);
			tween.tween_property(item, "modulate:a", 0.0, note_after_time
			).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
	judged_notes.erase(wait_index);
	waiting_notes.erase(wait_index);

## 返回轨道上的度数对应的相对位置，相对位置
func get_point_on_track(deg: float, radius: float = 1.0) -> Vector2:
	var rad := deg_to_rad(deg-90);
	return (Vector2(cos(rad),sin(rad)) * radius);

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
	return audioPlayer.stream.get_length();

func get_play_length() -> float:
	return beatmap.start_time

func round_multiple(value :float, round_float :float) -> float:
	return roundf(value/round_float) * round_float;
