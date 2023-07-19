extends Panel

@onready var playground :PlaygroundControl = $".." as PlaygroundControl;

@onready var labelRating := $HBox/VBoxL/TextureBg/LabelRating;
@onready var textureBg := $HBox/VBoxL/TextureBg;

@onready var labelScore := $HBox/VBoxL/VBoxDetail/HBoxScore/Label;
@onready var labelCombo := $HBox/VBoxL/VBoxDetail/HBoxCombo/Label;
@onready var labelAcc := $HBox/VBoxL/VBoxDetail/HBoxAcc/Label;

@onready var labelTitle := $HBox/VBoxR/ScrollInfo/VBox/LabelTitle;
@onready var labelAuthor := $HBox/VBoxR/ScrollInfo/VBox/LabelAuthor;
@onready var labelMapName := $HBox/VBoxR/ScrollInfo/VBox/LabelMapName;
@onready var labelMapper := $HBox/VBoxR/ScrollInfo/VBox/LabelMapper;

@onready var buttonReplay := $HBox/VBoxR/VBoxButton/ButtonReplay;
@onready var buttonRestart := $HBox/VBoxR/VBoxButton/ButtonRestart;
@onready var buttonExit := $HBox/VBoxR/VBoxButton/ButtonExit;

func _ready():
	buttonRestart.pressed.connect(func():
		visible = false;
		playground.restart();
	);
	buttonExit.pressed.connect(func():
		visible = false;
		playground.quit();
	);

func show_anim():
	
	set_value();
	
	visible = true;
	var tween = create_tween();
	tween.tween_property(self, "modulate:a", 1.0, 1.0
		).from(0.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
	tween.tween_property(self, "modulate:v", 1.0, 1.0
		).from(1.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
	await get_tree().create_timer(1).timeout;
	var player := Global.play_sound(preload("res://audio/dicolo!theme.wav"),0,1,"Music");
	Global.remove_child(player);
	add_child(player);

func set_value():
	var map := playground.beatmap;
	textureBg.texture = playground.background.texture;
	labelScore.text = str(floori(roundi(playground.score*10)/10.0));
	labelCombo.text = str(playground.max_combo);
	labelAcc.text = ("%.2f" % (playground.acc*100.0)).replace('.', ',');
	labelTitle.text = map.title;
	labelAuthor.text = map.author;
	labelMapName.text = map.map_name;
	labelMapper.text = map.mapper;
