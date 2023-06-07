class_name MainMenu
extends Control

@onready var background :TextureRect = $Background;
@onready var song_list :SongList = $SongList as SongList;
@onready var music_player :MusicPlayer = $LeftPanel/MusicPlayer as MusicPlayer;
@onready var readme_label :RichTextLabel = $LeftPanel/Readme/Label;
@onready var levels_bar :Control = $LeftPanel/LevelsBar;
@onready var bg_label :Label = $Bg_Label;
@onready var bg_panel :Panel = $Bg_Panel;
@onready var animation_control :Control = $Animations;
@onready var animation_player :AnimationPlayer = $Animations/AnimationPlayer;

var debug_label_last_report = 0;

@onready var bg_panel_stylebox := bg_panel.get_theme_stylebox("panel") as StyleBoxFlat;

@onready var default_backgrounds :Array[Texture2D] = [
	preload("res://image/background/dicolo_icon_light_bubbles.png"),
];

func _ready():
	
	Global.scene_MainMenu = self;
	
	## 设定加载完成（确定界面大小）后播放开始动画
	Global.data_loaded_setting.connect(func():
		
		#animation_control.pivot_offset = get_tree().root.size/2;
		animation_control.scale /= Global.stretch_scale;
		#animation_control.position = Vector2.ZERO;
		animation_player.play("start");
	);
	
	# 跟音乐动
	music_player.beat.connect(func():
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);
		tween.set_parallel(true);
		tween.tween_property(bg_panel_stylebox, "border_width_left", 0.0, 60/music_player.bpm).from(250.0);
		tween.tween_property(bg_panel_stylebox, "border_width_right", 0.0, 60/music_player.bpm).from(250.0);
	);
	
	music_player.audio_end.connect(func():
		await get_tree().create_timer(1.0).timeout;
		if !music_player.play:
			song_list.choose_song_random();
	);
