class_name MainMenu
extends Control

var debug_label_last_report = 0;

@onready var background :TextureRect = $Background;
@onready var song_list :SongList = $SongList as SongList;
@onready var music_player :MusicPlayer = $LeftPanel/MusicPlayer as MusicPlayer;
@onready var readme_label :RichTextLabel = $LeftPanel/Readme/Label;
@onready var levels_bar :Control = $LeftPanel/LevelsBar;
@onready var bg_label :Label = $Bg_Label;
@onready var bg_panel :Panel = $Bg_Panel;

func _ready():
	Global.scene_MainMenu = self;
	# 跟音乐动
	music_player.beat.connect(func():
		#music_player.beat_node_scale($DownPanel/Avatar);
		var stylebox :StyleBoxFlat = bg_panel.get_theme_stylebox("panel") as StyleBoxFlat;
		var tween = bg_panel.create_tween(
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).parallel();
		tween.tween_property(stylebox, "border_width_left", 0.0, 60/music_player.bpm).from(250.0);
		tween.tween_property(stylebox, "border_width_right", 0.0, 60/music_player.bpm).from(250.0);
	);

func _process(_delta):
	
	var time = Time.get_unix_time_from_system();
	if time - debug_label_last_report >= 0.5:
		$Debugs/DebugLabel.text = "debug: [dpi]%d [fps]%d [mem]%.1f/%.1fM [acc]%s" % [
			DisplayServer.screen_get_dpi(), Engine.get_frames_per_second(),
			OS.get_static_memory_usage()/1024.0/1024.0,
			OS.get_static_memory_peak_usage()/1024.0/1024.0,
			Input.get_accelerometer()
		];
		debug_label_last_report = time;
