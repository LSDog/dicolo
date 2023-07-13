extends Control

var setting_shown :bool = false;

const COLOR_NORMAL := Color.WHITE;
const COLOR_WAITING := Color("e098ff");
const COLOR_CHANGED := Color("ffdd00");

# Player #
@onready var textureAvatar := $Panel/Scroll/Margin/List/Player/Profile/TextureAvatar;
@onready var lineEditName := $Panel/Scroll/Margin/List/Player/Profile/LineEditName;
# Video #
@onready var buttonFullScreen := $Panel/Scroll/Margin/List/Video/FullScreen/Button;
@onready var optionFullScreenMode := $Panel/Scroll/Margin/List/Video/FullScreenMode/Option;
var optionFullScreenMode_items = [DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN];
@onready var inputFPS := $Panel/Scroll/Margin/List/Video/FPS/Input;
@onready var checkVSync := $Panel/Scroll/Margin/List/Video/VSync/CheckButton;
@onready var labelScale := $Panel/Scroll/Margin/List/Video/Scale/Label;
@onready var sliderScale := $Panel/Scroll/Margin/List/Video/Scale/HSlider;
# Audio #
@onready var sliderVolumeMaster := $Panel/Scroll/Margin/List/Audio/VolumeMaster/HSlider;
@onready var sliderVolumeMusic := $Panel/Scroll/Margin/List/Audio/VolumeMusic/HSlider;
@onready var sliderVolumeEffect := $Panel/Scroll/Margin/List/Audio/VolumeEffect/HSlider;
@onready var sliderVolumeVoice := $Panel/Scroll/Margin/List/Audio/VolumeVoice/HSlider;
# Device #
@onready var labelGamepad := $Panel/Scroll/Margin/List/Device/Gamepad/Label;
@onready var optionGamepad := $Panel/Scroll/Margin/List/Device/Gamepad/Option;
# GamePlay #
var audio_offset :int = 0;
@onready var labelAudioOffset := $Panel/Scroll/Margin/List/Gameplay/AudioOffset/LabelOffset;
@onready var buttonAudioOffsetAdd := $Panel/Scroll/Margin/List/Gameplay/AudioOffset/ButtonAdd;
@onready var buttonAudioOffsetSub := $Panel/Scroll/Margin/List/Gameplay/AudioOffset/ButtonSub;
# Misc #
@onready var checkDebugInfo := $Panel/Scroll/Margin/List/Misc/DebugInfo/CheckButton;
@onready var buttonReloadMap := $Panel/Scroll/Margin/List/Misc/ButtonReloadMap;

var loading_data := true;

func _ready():
	
	# 将vScroll放到左侧
	var scrollContainer := $Panel/Scroll as ScrollContainer;
	var vScroll := scrollContainer.get_v_scroll_bar();
	vScroll.layout_direction = Control.LAYOUT_DIRECTION_RTL;
	
	bind_gui_action();
	
	set_setting_from_data();
	

## 绑定gui与设置变化
func bind_gui_action():
	textureAvatar.gui_input.connect(func(input_event):
		if input_event is InputEventMouseButton:
			if input_event.pressed || input_event.button_index > MOUSE_BUTTON_MIDDLE: return;
			var fileDialog = FileDialog.new();
			fileDialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE;
			fileDialog.access = FileDialog.ACCESS_FILESYSTEM;
			fileDialog.filters = ["*.png, *.jpg, *.jpeg, *.svg, *.webp, *.bmp", "Image"];
			add_child(fileDialog);
			fileDialog.size = Vector2i(1024, 512);
			fileDialog.popup_centered()
			fileDialog.canceled.connect(func():
				remove_child(fileDialog);
				fileDialog.queue_free();
			);
			fileDialog.file_selected.connect(func(path):
				DataManager.data_player.set_avatar(path);
				var texture := DataManager.data_player.get_avatar();
				textureAvatar.texture = texture;
				Global.mainMenu.downPanel.textureAvatar.texture = texture;
				DataManager.save_data_player();
			);
	);
	lineEditName.text_changed.connect(func(text):
		DataManager.data_player.name = text;
		if loading_data: return;
		DataManager.save_data_player();
	);
	buttonFullScreen.toggled.connect(func(pressed):
		var id = optionFullScreenMode.get_selected_id();
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
			if !pressed else
			optionFullScreenMode_items[id]
		);
		save_data("FullScreen", pressed);
	);
	optionFullScreenMode.item_selected.connect(func(index: int):
		if buttonFullScreen.button_pressed:
			DisplayServer.window_set_mode(optionFullScreenMode_items[index]);
		save_data("FullScreenMode", index);
	);
	inputFPS.text_changed.connect(func(_text: String):
		inputFPS.modulate = COLOR_WAITING;
	);
	inputFPS.text_submitted.connect(func(text: String):
		if text.is_valid_int():
			var fps = text.to_int();
			Engine.max_fps = 0 if fps < 0 else fps;
			inputFPS.modulate = COLOR_NORMAL;
			# 给初始化加载数据用的
			if inputFPS.text != text:
				inputFPS.text = text;
			save_data("FPS", text);
	);
	checkVSync.toggled.connect(func(pressed: bool):
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
			if pressed else
			DisplayServer.VSYNC_DISABLED
		);
		save_data("VSync", pressed);
	);
	sliderScale.value_changed.connect(func(value: float):
		get_tree().root.content_scale_factor = value;
		Global.stretch_scale = value;
		var event := InputEventMouseButton.new();
		event.set_button_index(MOUSE_BUTTON_LEFT);
		event.set_pressed(false);
		Input.parse_input_event(event);
		save_data("Scale", value);
	);
	sliderVolumeMaster.value_changed.connect(func(value: float):
		set_audio_bus_Volume("Master", value);
		save_data("Volume.Master", value);
	);
	sliderVolumeMusic.value_changed.connect(func(value: float):
		set_audio_bus_Volume("Music", value);
		save_data("Volume.Music", value);
	);
	sliderVolumeEffect.value_changed.connect(func(value: float):
		set_audio_bus_Volume("Effect", value);
		save_data("Volume.Effect", value);
	);
	sliderVolumeVoice.value_changed.connect(func(value: float):
		set_audio_bus_Volume("Voice", value);
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
	optionGamepad.item_selected.connect(func(id):
		Global.gamepad_id = id;
		update_labelGamepad();
	);
	if Global.mainMenu != null:
		var musicPlayer = Global.mainMenu.musicPlayer;
		musicPlayer.beat.connect(func():
			labelAudioOffset.create_tween().tween_property(
				labelAudioOffset, "modulate:a", 1.0, 60.0/musicPlayer.bpm
			).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
		);
	buttonAudioOffsetAdd.pressed.connect(func():
		set_audio_offset(audio_offset + 1);
		save_data("AudioOffset", audio_offset);
	);
	buttonAudioOffsetSub.pressed.connect(func():
		set_audio_offset(audio_offset - 1);
		save_data("AudioOffset", audio_offset);
	);
	checkDebugInfo.toggled.connect(func(flag: bool):
		Global.debugInfo.visible = flag;
		save_data("DebugInfo", flag);
	);
	buttonReloadMap.pressed.connect(func():
		Notifier.notif_popup("Reloding all the map and song...");
		Global.mainMenu.songList.clear_maps();
		Global.mainMenu.songList.load_maps();
		Global.mainMenu.songList.select_song_random();
		Notifier.notif_popup("Reloded!", Notifier.COLOR_OK);
	);

func set_setting_from_data():
	
	var data_player := DataManager.data_player as PlayerData;
	textureAvatar.texture = data_player.get_avatar();
	lineEditName.text = data_player.name;
	
	optionFullScreenMode.selected = get_data("FullScreenMode", optionFullScreenMode.selected);
	buttonFullScreen.button_pressed = get_data("FullScreen", buttonFullScreen.button_pressed);
	inputFPS.text_submitted.emit(get_data("FPS", 60));
	checkVSync.button_pressed = get_data("VSync", checkVSync.button_pressed);
	sliderScale.value = get_data("Scale", sliderScale.value);
	
	sliderVolumeMaster.value = get_data("Volume.Master", sliderVolumeMaster.value);
	sliderVolumeMusic.value = get_data("Volume.Music", sliderVolumeMusic.value);
	sliderVolumeEffect.value = get_data("Volume.Effect", sliderVolumeEffect.value);
	sliderVolumeVoice.value = get_data("Volume.Voice", sliderVolumeVoice.value);
	
	set_audio_offset(get_data("AudioOffset", 0));
	
	checkDebugInfo.button_pressed = get_data("DebugInfo", checkDebugInfo.button_pressed);
	
	loading_data = false;
	Global.data_loaded_setting.emit();
	

func update_gamepad_select():
	optionGamepad.clear();
	for i in Input.get_connected_joypads():
		optionGamepad.add_item(Input.get_joy_name(i)+" ("+Input.get_joy_guid(i)+")", i);
	if optionGamepad.item_count == 0:
		Global.gamepad_id = -1;
	elif Global.gamepad_id == -1:
		var id = Input.get_connected_joypads()[0]
		Global.gamepad_id = id;
	Global.gamepad_count = Input.get_connected_joypads().size();
	update_labelGamepad();

func update_labelGamepad():
	labelGamepad.text = "Gamepad: " + str(Global.gamepad_id+1) + "/" + str(Global.gamepad_count);

func set_audio_bus_Volume(bus: String, Volume_db: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), Volume_db);

func get_audio_offset() -> int:
	return audio_offset;

func set_audio_offset(offset: int):
	if offset < 0: offset = 0;
	audio_offset = offset;
	labelAudioOffset.text = ("+" if offset >= 0 else "") + str(offset) + " ms";
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
		buttonFullScreen.button_pressed = !buttonFullScreen.button_pressed;

func _gui_input(event: InputEvent):
	if event.is_action_pressed("esc"):
		anim_hide();

func anim_show():
	visible = true;
	var tween = create_tween();
	tween.tween_property(self, "offset_left", 0, 0.15
		).from(-size.x).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);

func anim_hide():
	var tween = create_tween();
	tween.tween_property(self, "offset_left", -size.x, 0.15
		).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
	tween.finished.connect(func(): visible = false);
	
## 保存数据到配置文件
func save_data(key: String, value):
	if loading_data: return;
	DataManager.data_setting[key] = value;
	DataManager.save_data_setting();

## 获取配置
func get_data(key: String, default = null):
	var value = DataManager.data_setting.get(key);
	return default if value == null else value;
