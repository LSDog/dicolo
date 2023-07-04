extends Control

var setting_shown :bool = false;

const COLOR_NORMAL := Color.WHITE;
const COLOR_WAITING := Color("e098ff");
const COLOR_CHANGED := Color("ffdd00");

# Video #
@onready var button_FullScreen := $Panel/Scroll/Margin/List/Video/FullScreen/Button;
@onready var option_FullScreenMode := $Panel/Scroll/Margin/List/Video/FullScreenMode/Option;
var option_FullScreenMode_items = [DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN];
@onready var input_FPS := $Panel/Scroll/Margin/List/Video/FPS/Input;
@onready var check_VSync := $Panel/Scroll/Margin/List/Video/VSync/CheckButton;
@onready var label_Scale := $Panel/Scroll/Margin/List/Video/Scale/Label;
@onready var slider_Scale := $Panel/Scroll/Margin/List/Video/Scale/HSlider;
# Audio #
@onready var slider_volumeMaster := $Panel/Scroll/Margin/List/Audio/VolumeMaster/HSlider;
@onready var slider_volumeMusic := $Panel/Scroll/Margin/List/Audio/VolumeMusic/HSlider;
@onready var slider_volumeEffect := $Panel/Scroll/Margin/List/Audio/VolumeEffect/HSlider;
@onready var slider_volumeVoice := $Panel/Scroll/Margin/List/Audio/VolumeVoice/HSlider;
# Device #
@onready var label_Gamepad := $Panel/Scroll/Margin/List/Device/Gamepad/Label;
@onready var option_Gamepad := $Panel/Scroll/Margin/List/Device/Gamepad/Option;
# GamePlay #
var audio_offset :int = 0;
@onready var label_AudioOffset := $Panel/Scroll/Margin/List/Gameplay/AudioOffset/LabelOffset;
@onready var button_AudioOffsetAdd := $Panel/Scroll/Margin/List/Gameplay/AudioOffset/ButtonAdd;
@onready var button_AudioOffsetSub := $Panel/Scroll/Margin/List/Gameplay/AudioOffset/ButtonSub;
# Misc #
@onready var check_DebugInfo := $Panel/Scroll/Margin/List/Misc/DebugInfo/CheckButton;

var loading_data := true;

func _ready():
	
	DataManager.load_data(DataManager.DATA_TYPE.SETTING);
	
	bind_gui_action();
	
	set_setting_from_data();
	

## 绑定gui与设置变化
func bind_gui_action():
	
	button_FullScreen.toggled.connect(func(pressed):
		var id = option_FullScreenMode.get_selected_id();
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
			if !pressed else
			option_FullScreenMode_items[id]
		);
		save_data("FullScreen", pressed);
	);
	option_FullScreenMode.item_selected.connect(func(index: int):
		if button_FullScreen.button_pressed:
			DisplayServer.window_set_mode(option_FullScreenMode_items[index]);
		save_data("FullScreenMode", index);
	);
	input_FPS.text_changed.connect(func(_text: String):
		input_FPS.modulate = COLOR_WAITING;
	);
	input_FPS.text_submitted.connect(func(text: String):
		if text.is_valid_int():
			var fps = text.to_int();
			Engine.max_fps = 0 if fps < 0 else fps;
			input_FPS.modulate = COLOR_NORMAL;
			# 给初始化加载数据用的
			if input_FPS.text != text:
				input_FPS.text = text;
			save_data("FPS", text);
	);
	check_VSync.toggled.connect(func(pressed: bool):
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
			if pressed else
			DisplayServer.VSYNC_DISABLED
		);
		save_data("VSync", pressed);
	);
	slider_Scale.value_changed.connect(func(value: float):
		get_tree().root.content_scale_factor = value;
		Global.stretch_scale = value;
		var event := InputEventMouseButton.new();
		event.set_button_index(MOUSE_BUTTON_LEFT);
		event.set_pressed(false);
		Input.parse_input_event(event);
		save_data("Scale", value);
	);
	slider_volumeMaster.value_changed.connect(func(value: float):
		set_audio_bus_volume("Master", value);
		save_data("Volume.Master", value);
	);
	slider_volumeMusic.value_changed.connect(func(value: float):
		set_audio_bus_volume("Music", value);
		save_data("Volume.Music", value);
	);
	slider_volumeEffect.value_changed.connect(func(value: float):
		set_audio_bus_volume("Effect", value);
		save_data("Volume.Effect", value);
	);
	slider_volumeVoice.value_changed.connect(func(value: float):
		set_audio_bus_volume("Voice", value);
		save_data("Volume.Voice", value);
	);
	update_gamepad_select();
	Input.joy_connection_changed.connect(func(device: int, connected: bool):
		print("[Setting] gamepad changed: ",device,"\tconnected: ",connected);
		Notifier.notif_popup(
			"A gamepad [b]" + ("connected" if connected else "disconnected") + "[/b].",
			Notifier.COLOR_OK if connected else Notifier.COLOR_BAD,
			preload("res://visual/ui_icon/gamepad.svg")
		);
		update_gamepad_select();
		if connected: Global.gamepad_id = device;
	);
	option_Gamepad.item_selected.connect(func(id):
		Global.gamepad_id = id;
		update_label_Gamepad();
	);
	if Global.scene_MainMenu != null:
		var musicPlayer = Global.scene_MainMenu.musicPlayer;
		musicPlayer.beat.connect(func():
			label_AudioOffset.create_tween().tween_property(
				label_AudioOffset, "modulate:a", 1.0, 60.0/musicPlayer.bpm
			).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
		);
	button_AudioOffsetAdd.pressed.connect(func():
		set_audio_offset(audio_offset + 1);
		save_data("AudioOffset", audio_offset);
	);
	button_AudioOffsetSub.pressed.connect(func():
		set_audio_offset(audio_offset - 1);
		save_data("AudioOffset", audio_offset);
	);
	check_DebugInfo.toggled.connect(func(flag: bool):
		Global.scene_DebugInfo.visible = flag;
		save_data("DebugInfo", flag);
	);

func set_setting_from_data():
	
	option_FullScreenMode.selected = get_data("FullScreenMode", option_FullScreenMode.selected);
	button_FullScreen.button_pressed = get_data("FullScreen", button_FullScreen.button_pressed);
	input_FPS.text_submitted.emit(get_data("FPS", 60));
	check_VSync.button_pressed = get_data("VSync", check_VSync.button_pressed);
	slider_Scale.value = get_data("Scale", slider_Scale.value);
	
	slider_volumeMaster.value = get_data("Volume.Master", slider_volumeMaster.value);
	slider_volumeMusic.value = get_data("Volume.Music", slider_volumeMusic.value);
	slider_volumeEffect.value = get_data("Volume.Effect", slider_volumeEffect.value);
	slider_volumeVoice.value = get_data("Volume.Voice", slider_volumeVoice.value);
	
	set_audio_offset(get_data("AudioOffset", 0));
	
	check_DebugInfo.button_pressed = get_data("DebugInfo", check_DebugInfo.button_pressed);
	
	loading_data = false;
	Global.data_loaded_setting.emit();
	

func update_gamepad_select():
	option_Gamepad.clear();
	for i in Input.get_connected_joypads():
		option_Gamepad.add_item(Input.get_joy_name(i)+" ("+Input.get_joy_guid(i)+")", i);
	if option_Gamepad.item_count == 0:
		Global.gamepad_id = -1;
	elif Global.gamepad_id == -1:
		var id = Input.get_connected_joypads()[0]
		Global.gamepad_id = id;
	Global.gamepad_count = Input.get_connected_joypads().size();
	update_label_Gamepad();

func update_label_Gamepad():
	label_Gamepad.text = "Gamepad: " + str(Global.gamepad_id+1) + "/" + str(Global.gamepad_count);

func set_audio_bus_volume(bus: String, volume_db: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), volume_db);

func get_audio_offset() -> int:
	return audio_offset;

func set_audio_offset(offset: int):
	if offset < 0: offset = 0;
	audio_offset = offset;
	label_AudioOffset.text = ("+" if offset >= 0 else "") + str(offset) + " ms";
	var delay := AudioServer.get_bus_effect(0, 0) as AudioEffectDelay;
	delay.tap1_delay_ms = offset;

func _input(event: InputEvent):
	if visible && event is InputEventMouseButton:
		if !get_rect().has_point(event.position):
			accept_event();
			# 点到外面就收回
			if event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
				anim_hide();
	elif event.is_action_pressed("full_screen"):
		button_FullScreen.button_pressed = !button_FullScreen.button_pressed;

func _gui_input(event: InputEvent):
	if event.is_action_pressed("esc"):
		anim_hide();

func anim_show():
	visible = true;
	var tween = create_tween();
	tween.tween_property(self, "offset_right", 0, 0.15
		).from(size.x).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);

func anim_hide():
	var tween = create_tween();
	tween.tween_property(self, "offset_right", size.x, 0.15
		).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
	tween.finished.connect(func(): visible = false);
	
## 保存数据到配置文件
func save_data(key: String, value):
	if loading_data: return;
	DataManager.data_setting[key] = value;
	DataManager.save_data(DataManager.DATA_TYPE.SETTING);

func get_data(key: String, default_value = null):
	var value = DataManager.data_setting.get(key);
	return default_value if value == null else value;
