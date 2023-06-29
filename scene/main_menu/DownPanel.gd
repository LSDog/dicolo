extends Panel

var last_info_update := 0.0;

@onready var main_menu := get_parent() as MainMenu;
@onready var label_player_info := $VBox/PlayerInfoVBox/Label;
@onready var label_player_text_template :String = label_player_info.text;
@onready var label_device_info := $VBox/DeviceInfoVBox/Label;
@onready var label_device_text_template :String = label_device_info.text;

func _ready():
	last_info_update = Global.now_time() + 1 - fmod(Global.now_time(), 1.0);
	_ready_later.call_deferred();

func _enter_tree() -> void:
	pass

func _ready_later():
	var setting_init_x = Global.scene_Setting.position.x;
	$VBox/ButtonSetting.mouse_entered.connect(play_hover_sound);
	$VBox/ButtonSetting.pressed.connect(func():
		play_click_sound();
		var setting := Global.scene_Setting;
		if !setting.visible:
			setting.anim_show();
		else:
			setting.anim_hide();
	);
	$VBox/ButtonCloud.mouse_entered.connect(play_hover_sound);
	$VBox/ButtonMod.mouse_entered.connect(play_hover_sound);
	$VBox/ButtonRandom.mouse_entered.connect(play_hover_sound);
	$VBox/ButtonRandom.pressed.connect(func():
		play_click_sound();
		main_menu.songList.select_song_random();
	);

func play_hover_sound():
	Global.play_sound(preload("res://audio/ui/click_hat.wav"), -10, 1, "Effect");

func play_click_sound():
	Global.play_sound(preload("res://audio/ui/click_glass.wav"), -10, 1, "Effect");

func _process(_delta: float):
	var now = Global.now_time();
	if now - last_info_update < 0.1: return;
	var username = OS.get_environment("USERNAME") if OS.has_environment("USERNAME") else "Player";
	label_player_info.text = label_player_text_template % [username, -255, "ALIVE"];
	label_device_info.text = label_device_text_template % [Time.get_time_string_from_system(), Time.get_date_string_from_system()];
	last_info_update = now;
