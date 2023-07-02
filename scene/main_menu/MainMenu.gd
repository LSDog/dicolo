class_name MainMenu
extends Control

@onready var background :TextureRect = $Background;
@onready var songList :SongList = $SongList as SongList;
@onready var musicPlayer :MusicPlayer = $LeftPanel/MusicPlayer;
@onready var leftPanel :Control = $LeftPanel;
@onready var bgLbael :Label = $BgPanel/Label;
@onready var bgPanel :Panel = $BgPanel;
@onready var songMenu :Control = $SongMenu;
@onready var animation_control :Control = $Animations;
@onready var animation_player :AnimationPlayer = $Animations/AnimationPlayer;

var debug_label_last_report = 0;

@onready var bgPanel_stylebox := bgPanel.get_theme_stylebox("panel") as StyleBoxFlat;

@onready var default_backgrounds :Array[Texture2D] = [
	preload("res://visual/background/dicolo_icon_light_bubbles.png"),
];

func _ready():
	
	Global.scene_MainMenu = self;
	
	animation_control.visible = true;
	Global.data_loaded_setting.connect(func():
		# 设定加载完成（确定界面大小）后播放开始动画
		$Animations/Control.scale /= Global.stretch_scale;
		$Animations/Control.global_position = (
				$Animations.size-$Animations/Control.size/Global.stretch_scale
			)/2.0*Global.stretch_scale;
		animation_player.play("start");
	);
	
	# 跟音乐动
	musicPlayer.beat.connect(func():
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);
		tween.set_parallel(true);
		tween.tween_property(bgPanel_stylebox, "border_width_left", 0.0, 60/musicPlayer.bpm).from(250.0);
		tween.tween_property(bgPanel_stylebox, "border_width_right", 0.0, 60/musicPlayer.bpm).from(250.0);
	);
	
	musicPlayer.audio_end.connect(func():
		await get_tree().create_timer(1.0).timeout;
		if !musicPlayer.play:
			songList.select_song_random();
	);

func select_map(song_name: String, map_name: String):
	print("select map: ", song_name, " -- ", map_name);

func play_map(map_path: String):
	print("play song: ", map_path);
	var play_ground_scene := preload("res://scene/play_ground/Playground.tscn") as PackedScene;
	var play_ground := play_ground_scene.instantiate() as PlaygroundControl;
	get_tree().root.add_child(play_ground);
	get_tree().current_scene = play_ground;
	Global.freeze(self);
	play_ground.load_map(map_path, true);
