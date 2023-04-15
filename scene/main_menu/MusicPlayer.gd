class_name MusicPlayer
extends Panel

var texture_play := load("res://image/ui_icon/play-button.svg");
var texture_pause := load("res://image/ui_icon/pause-button.svg");

@onready var audio_player :AudioStreamPlayer = $AudioPlayer;
@onready var progress_bar :ProgressBar = $ProgressBar;

@export var play := true:
	set(value):
		if play == value: return;
		play = value;
		audio_player.playing = play;
		$Buttons/Play.texture_normal = texture_pause if play else texture_play;
		
@export var loop := true:
	set(value):
		if loop == value: return;
		loop = value;
		$Buttons/Loop.modulate.a = 1.0 if loop else 0.3;

func _ready():
	
	# 绑按钮组
	$Buttons/Loop.toggled.connect(func(flag: bool): loop = flag);
	$Buttons/Play.toggled.connect(func(flag: bool): play = flag);
	
	# 音频
	audio_player.finished.connect(func():
		if loop: audio_player.play();
	);


func _process(delta: float):
	if audio_player.playing:
		progress_bar.ratio = audio_player.get_playback_position() / audio_player.stream.get_length();

## 播放音乐
func play_music(stream: AudioStream, song_string :String):
	$InfoLabel.text = "] Playing: " + song_string;
	if audio_player.stream != stream:
		audio_player.stream = stream;
		if play: audio_player.play();
