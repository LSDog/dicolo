class_name MainMenu
extends Control

@onready var background :TextureRect = $Background;
@onready var songList :SongList = $SongList as SongList;
@onready var musicPlayer :MusicPlayer = $LeftPanel/MusicPlayer;
@onready var leftPanel :Control = $LeftPanel;
@onready var downPanel :Control = $DownPanel;
@onready var bgLbael :Label = $BgPanel/Label;
@onready var bgPanel :Panel = $BgPanel;
@onready var animation_control :Control = $Animations;
@onready var animation_player :AnimationPlayer = $Animations/AnimationPlayer;

var debug_label_last_report := 0.0;

@onready var bgPanel_stylebox := bgPanel.get_theme_stylebox("panel") as StyleBoxFlat;

@onready var default_backgrounds :Array[Texture2D] = [
	preload("res://visual/background/dicolo_icon_light_bubbles.png"),
];

@export var parallax_bg_scale := 1.015:
	set(value):
		parallax_bg_scale = value;
		background.scale.x = parallax_bg_scale;
		background.scale.y = parallax_bg_scale;
		background.pivot_offset = background.size/2.0;

func _ready():
	
	Global.mainMenu = self;
	
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
	
	background.scale.x = parallax_bg_scale;
	background.scale.y = parallax_bg_scale;
	background.pivot_offset = background.size/2.0;

func _process(delta: float):
	# 视差背景
	var mouse_position = get_local_mouse_position();
	mouse_position.clamp(Vector2.ZERO, size);
	background.position = (
		mouse_position.clamp(Vector2.ZERO, size) - size/2.0) * (1-parallax_bg_scale)/2.0;

func select_map(song_name: String, map_name: String):
	print("select map: ", song_name, " -- ", map_name);

func play_map(map_path: String):
	print("play song: ", map_path);
	var playground_scene := preload("res://scene/playground/Playground.tscn") as PackedScene;
	var playground := playground_scene.instantiate() as PlaygroundControl;
	get_tree().root.add_child(playground);
	get_tree().current_scene = playground;
	Global.freeze(self);
	playground.load_map(map_path, true);

func edit_map(map_path: String):
	print("edit map: ", map_path);
	var editor_scene := preload("res://scene/editor/Editor.tscn") as PackedScene;
	var editor := editor_scene.instantiate() as Editor;
	get_tree().root.add_child(editor);
	get_tree().current_scene = editor;
	Global.freeze(self);
	editor.load_map(map_path);
