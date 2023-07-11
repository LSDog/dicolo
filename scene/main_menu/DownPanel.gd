extends Panel

var last_info_update := 0.0;

@onready var mainMenu := get_parent() as MainMenu;
@onready var textureAvatar := $Avatar;
@onready var label_player_info := $VBox/PlayerInfoVBox/Label;
@onready var label_player_text_template :String = label_player_info.text;
@onready var label_device_info := $VBox/DeviceInfoVBox/Label;
@onready var label_device_text_template :String = label_device_info.text;
@onready var buttonEdit := $VBox/ButtonEdit;
@onready var editMenu := $VBox/ButtonEdit/PanelMenu;
@onready var buttonEditNew := $VBox/ButtonEdit/PanelMenu/VBox/ButtonNew;
@onready var buttonEditEdit := $VBox/ButtonEdit/PanelMenu/VBox/ButtonEdit;
@onready var buttonEditCopy := $VBox/ButtonEdit/PanelMenu/VBox/ButtonCopy;
@onready var buttonEditDeleteMap := $VBox/ButtonEdit/PanelMenu/VBox/ButtonDeleteMap;
@onready var buttonEditDeleteSong := $VBox/ButtonEdit/PanelMenu/VBox/ButtonDeleteSong;
@onready var buttonMod := $VBox/ButtonMod;
@onready var buttonDraw := $VBox/ButtonDraw;


func _ready():
	last_info_update = Global.now_time() + 1 - fmod(Global.now_time(), 1.0);
	_ready_later.call_deferred();

func _ready_later():
	textureAvatar.texture = DataManager.data_player.get_avatar();
	apply_button_hover_sound(self);
	buttonEdit.pressed.connect(func():
		play_click_sound();
		editMenu.visible = !editMenu.visible;
	);
	buttonEditNew.pressed.connect(func():pass);
	buttonEditEdit.pressed.connect(func():
		play_click_sound();
		var path = mainMenu.songList.get_selected_map_path();
		if !path.is_empty(): mainMenu.edit_map(path);
	);
	buttonEditCopy.pressed.connect(func():pass);
	buttonEditDeleteMap.pressed.connect(func():pass);
	buttonEditDeleteSong.pressed.connect(func():pass);
	buttonMod.pressed.connect(func():
		play_click_sound();
		Notifier.notif_popup("Comming soon!", Notifier.COLOR_BLUE);
	);
	buttonDraw.pressed.connect(func():
		play_click_sound();
		mainMenu.songList.select_song_random();
	);

func apply_button_hover_sound(parent_node: Node):
	for node in parent_node.get_children():
		if node is BaseButton:
			node.mouse_entered.connect(play_hover_sound);
		if node.get_child_count() > 0: apply_button_hover_sound(node);

func play_hover_sound():
	Global.play_sound(preload("res://audio/ui/click_hat.wav"), -10, 1, "Effect");

func play_click_sound():
	Global.play_sound(preload("res://audio/ui/click_glass.wav"), -10, 1, "Effect");

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if editMenu.visible && !editMenu.get_viewport_rect().has_point(event.global_position
			) && event.button_index <= MOUSE_BUTTON_MIDDLE:
			accept_event();
			editMenu.visible = false;

func _process(_delta: float):
	var now = Global.now_time();
	if now - last_info_update < 0.1: return;
	var username = DataManager.data_player.name;
	var level = DataManager.data_player.level;
	label_player_info.text = label_player_text_template % [username, level, "alive lol"];
	label_device_info.text = label_device_text_template % [Time.get_time_string_from_system(), Time.get_date_string_from_system()];
	last_info_update = now;
