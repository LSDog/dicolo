class_name MusicPlayer
extends Panel

var texture_play := load("res://visual/ui_icon/play-button.svg");
var texture_pause := load("res://visual/ui_icon/pause-button.svg");

@onready var audio_player :AudioStreamPlayer = $AudioPlayer;
@onready var progress_bar :ProgressBar = $ProgressBar;

# 让界面随着音乐律动起来！
## 音乐第一排的时间
var start_beat := 0.0;
## 音乐的bpm
var bpm := 0.0;
## 上一拍
var last_beat :int = 0;

## 每一拍发射一次信号
signal beat();

## 音乐播放结束信号，loop为true时不会触发
signal audio_end();

@export var play := true:
	set(value):
		if play == value: return;
		play = value;
		audio_player.stream_paused = !play;
		if play && !audio_player.playing: audio_player.playing = true;
		$Buttons/Play.texture_normal = texture_pause if play else texture_play;
		
@export var loop := true:
	set(value):
		if loop == value: return;
		loop = value;
		$Buttons/Loop.modulate.a = 1.0 if loop else 0.5;
		if !data_loading:
			DataManager.data_setting["MusicPlayer.Loop"] = value;
			DataManager.save_data(DataManager.DATA_TYPE.SETTING);

var data_loading = true;

func _ready():
	
	# 加载设置
	loop = DataManager.data_setting.get("MusicPlayer.Loop", loop);
	data_loading = false;
	
	# 绑按钮
	loop = $Buttons/Loop.button_pressed;
	$Buttons/Loop.toggled.connect(func(flag: bool): loop = flag);
	play = $Buttons/Play.button_pressed;
	$Buttons/Play.toggled.connect(func(flag: bool): play = flag);
	
	# 音频
	audio_player.finished.connect(func():
		if loop: audio_player.play();
		else:
			play = false;
			audio_end.emit();
	);
	


func _process(_delta: float):
	if audio_player.playing:
		# 设置进度条
		progress_bar.ratio = audio_player.get_playback_position() / audio_player.stream.get_length();
		# 发射beat信号
		var current_pos = audio_player.get_playback_position();
		if current_pos >= start_beat:
			var beat_num = ceili((audio_player.get_playback_position()-start_beat)/60.0*bpm);
			if last_beat != beat_num:
				#print("[beat] start%.2f-beat %d" % [current_pos, start_beat, beat_num])
				last_beat = beat_num;
				beat.emit();
				create_tween().tween_property(self, "scale", Vector2(1.0,1.0), 60.0/bpm
					).from(Vector2(1.02, 1.02)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);

## 播放音乐
func play_music(stream: AudioStream, song_string: String, song_start_beat: float = 0.0, song_bpm: float = 0.0):
	start_beat = song_start_beat;
	bpm = song_bpm;
	$InfoLabel.text = "] Playing: " + song_string;
	if audio_player.stream != stream:
		audio_player.stream = stream;
		if !audio_player.playing: audio_player.play();
		play = true;
		$Buttons/Play.button_pressed = true;
		$Buttons/Play.pressed.emit();

## 帮你震一下
func beat_node_scale(node: Control):
	node.create_tween().tween_property(node, "scale", Vector2(1.0,1.0), 60/bpm
		).from(Vector2(1.02, 1.02)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);
