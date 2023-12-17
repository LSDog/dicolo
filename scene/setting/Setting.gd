extends Control

var setting_shown :bool = false;

const COLOR_NORMAL := Color.WHITE;
const COLOR_WAITING := Color("e098ff");
const COLOR_CHANGED := Color("ffdd00");

# Player #
@onready var textureAvatar :TextureRect = $Panel/Scroll/Margin/List/Player/Profile/TextureAvatar;
@onready var lineEditName :LineEdit = $Panel/Scroll/Margin/List/Player/Profile/LineEditName;
# GamePlay #
var audio_offset :int = 0;
@onready var buttonInputGamepad: Button = $Panel/Scroll/Margin/List/Gameplay/InputMode/Gamepad;
@onready var buttonInputVJoy: Button = $Panel/Scroll/Margin/List/Gameplay/InputMode/VirtualJoystick;
@onready var buttonInputTouch: Button = $Panel/Scroll/Margin/List/Gameplay/InputMode/Touch;
@onready var labelAudioOffset :Label = $Panel/Scroll/Margin/List/Gameplay/AudioOffset/LabelOffset;
@onready var buttonAudioOffsetAdd :Button = $Panel/Scroll/Margin/List/Gameplay/AudioOffset/ButtonAdd;
@onready var buttonAudioOffsetSub :Button = $Panel/Scroll/Margin/List/Gameplay/AudioOffset/ButtonSub;
# Video #
@onready var buttonFullScreen :Button = $Panel/Scroll/Margin/List/Video/FullScreen/Button;
@onready var optionFullScreenMode :OptionButton = $Panel/Scroll/Margin/List/Video/FullScreenMode/Option;
var optionFullScreenMode_items :Array[DisplayServer.WindowMode] = [DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN];
@onready var inputFPS :LineEdit = $Panel/Scroll/Margin/List/Video/FPS/Input;
@onready var checkVSync :CheckButton = $Panel/Scroll/Margin/List/Video/VSync/CheckButton;
@onready var labelScale :Label = $Panel/Scroll/Margin/List/Video/Scale/Label;
@onready var sliderScale :HSlider = $Panel/Scroll/Margin/List/Video/Scale/HSlider;
# Audio #
@onready var sliderVolumeMaster :HSlider = $Panel/Scroll/Margin/List/Audio/VolumeMaster/HSlider;
@onready var sliderVolumeMusic :HSlider = $Panel/Scroll/Margin/List/Audio/VolumeMusic/HSlider;
@onready var sliderVolumeEffect :HSlider = $Panel/Scroll/Margin/List/Audio/VolumeEffect/HSlider;
@onready var sliderVolumeVoice :HSlider = $Panel/Scroll/Margin/List/Audio/VolumeVoice/HSlider;
# Device #
@onready var labelGamepad :Label = $Panel/Scroll/Margin/List/Device/Gamepad/Label;
@onready var optionGamepad :OptionButton = $Panel/Scroll/Margin/List/Device/Gamepad/Option;
# Misc #
@onready var checkDebugInfo :CheckButton = $Panel/Scroll/Margin/List/Misc/DebugInfo/CheckButton;
@onready var storageLocation :Button = $Panel/Scroll/Margin/List/Misc/StorageLoation/Button;
@onready var buttonReloadMap :Button = $Panel/Scroll/Margin/List/Misc/ButtonReloadMap;

var loading_data := true;

func _ready():
	
	# 将vScroll放到左侧
	var scrollContainer := $Panel/Scroll as ScrollContainer;
	var vScroll := scrollContainer.get_v_scroll_bar();
	vScroll.layout_direction = Control.LAYOUT_DIRECTION_RTL;
	
	bind_gui_action();
	
	if DataManager.all_data_has_loaded:
		set_setting_from_data();
	else:
		DataManager.data_loaded.connect(set_setting_from_data);



## 绑定gui与设置变化
func bind_gui_action():
	
	textureAvatar.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.pressed || event.button_index > MOUSE_BUTTON_MIDDLE: return;
			var fileDialog := Global.get_file_dialog(
				FileDialog.FILE_MODE_OPEN_FILE, FileDialog.ACCESS_FILESYSTEM,"",
				["*.png, *.jpg, *.jpeg, *.svg, *.webp, *.bmp", "Image"],
			);
			add_child(fileDialog);
			fileDialog.popup_centered();
			fileDialog.canceled.connect(func():
				remove_child(fileDialog);
				fileDialog.queue_free();
			);
			fileDialog.file_selected.connect(func(path: String):
				DataManager.data_player.set_avatar(path);
				var texture := DataManager.data_player.get_avatar();
				textureAvatar.texture = texture;
				Global.mainMenu.downPanel.textureAvatar.texture = texture;
				if !loading_data: DataManager.save_data_player();
			);
	);
	lineEditName.text_changed.connect(func(text: String):
		DataManager.data_player.name = text;
		if !loading_data: DataManager.save_data_player();
	);
	buttonInputGamepad.pressed.connect(func():
		Notifier.notif_popup("Now using Gamepad for rolling!", Notifier.COLOR_BLUE);
		get_setting().input_mode = DataSetting.INPUT_MODE.JOYSTICK;
		save_setting();
	);
	buttonInputVJoy.pressed.connect(func():
		Notifier.notif_popup("Now using Virtual Joystick for rolling!", Notifier.COLOR_BLUE);
		get_setting().input_mode = DataSetting.INPUT_MODE.V_JOYSTICK;
		save_setting();
	);
	buttonInputTouch.pressed.connect(func():
		Notifier.notif_popup("Now using finger for tapping!", Notifier.COLOR_BLUE);
		get_setting().input_mode = DataSetting.INPUT_MODE.TOUCH;
		save_setting();
	);
	buttonFullScreen.toggled.connect(func(pressed: bool):
		var id = optionFullScreenMode.get_selected_id();
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
			if !pressed else
			optionFullScreenMode_items[id]
		);
		get_setting().full_screen = pressed;
		save_setting();
	);
	optionFullScreenMode.item_selected.connect(func(index: int):
		if buttonFullScreen.button_pressed:
			DisplayServer.window_set_mode(optionFullScreenMode_items[index]);
		get_setting().full_screen_mode = index;
		save_setting();
	);
	inputFPS.text_changed.connect(func(_text: String):
		inputFPS.modulate = COLOR_WAITING;
	);
	inputFPS.text_submitted.connect(func(text: String):
		if text.is_valid_int():
			var fps := text.to_int();
			Engine.max_fps = 0 if fps < 0 else fps;
			inputFPS.modulate = COLOR_NORMAL;
			# 给初始化加载数据用的
			if inputFPS.text != text:
				inputFPS.text = text;
			get_setting().fps = text.to_int();
			save_setting();
		else:
			Notifier.notif_popup("You should input a integer for fps!", Notifier.COLOR_BAD);
	);
	checkVSync.toggled.connect(func(pressed: bool):
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
			if pressed else
			DisplayServer.VSYNC_DISABLED
		);
		get_setting().v_sync = pressed;
		save_setting();
	);
	sliderScale.value_changed.connect(func(value: float):
		get_tree().root.content_scale_factor = value;
		Global.stretch_scale = value;
		var event := InputEventMouseButton.new();
		event.set_button_index(MOUSE_BUTTON_LEFT);
		event.set_pressed(false);
		Input.parse_input_event(event);
		get_setting().scale = value;
		save_setting();
	);
	sliderVolumeMaster.value_changed.connect(func(value: float):
		set_audio_bus_Volume("Master", value);
		get_setting().volume_master = value; save_setting();
	);
	sliderVolumeMusic.value_changed.connect(func(value: float):
		set_audio_bus_Volume("Music", value);
		get_setting().volume_music = value; save_setting();
	);
	sliderVolumeEffect.value_changed.connect(func(value: float):
		set_audio_bus_Volume("Effect", value);
		get_setting().volume_effect = value; save_setting();
	);
	sliderVolumeVoice.value_changed.connect(func(value: float):
		set_audio_bus_Volume("Voice", value);
		get_setting().volume_voice = value; save_setting();
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
	optionGamepad.item_selected.connect(func(id: int):
		Global.gamepad_id = id;
		update_labelGamepad();
	);
	if Global.mainMenu != null:
		var musicPlayer := Global.mainMenu.musicPlayer;
		musicPlayer.beat.connect(func():
			labelAudioOffset.create_tween().tween_property(
				labelAudioOffset, "modulate:a", 1.0, 60.0/musicPlayer.bpm
			).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
		);
	buttonAudioOffsetAdd.pressed.connect(func():
		set_audio_offset(audio_offset + 1);
		get_setting().audio_offset = audio_offset; save_setting();
	);
	buttonAudioOffsetSub.pressed.connect(func():
		set_audio_offset(audio_offset - 1);
		get_setting().audio_offset = audio_offset; save_setting();
	);
	checkDebugInfo.toggled.connect(func(flag: bool):
		Global.debugInfo.visible = flag;
		get_setting().debug_info = flag;
		save_setting();
	);
	buttonReloadMap.pressed.connect(func():
		Notifier.notif_popup("Reloding all the map and song...");
		Global.mainMenu.songList.clear_maps();
		Global.mainMenu.songList.load_maps();
		Global.mainMenu.songList.select_song_random();
		Notifier.notif_popup("Reloded!", Notifier.COLOR_OK);
	);
	storageLocation.pressed.connect(func():
		var fileDialog := Global.get_file_dialog(
			FileDialog.FILE_MODE_OPEN_DIR, FileDialog.ACCESS_FILESYSTEM
		);
		add_child(fileDialog);
		fileDialog.popup_centered();
		fileDialog.canceled.connect(func():fileDialog.queue_free());
		fileDialog.dir_selected.connect(func(path: String):
			var storage_location_file := FileAccess.open("user://storage_location", FileAccess.WRITE_READ);
			var err := FileAccess.get_open_error();
			if storage_location_file != null && err == OK:
				storage_location_file.store_string(path);
				storage_location_file.flush();
				storage_location_file.close();
			else: Global.pop_text(
					"Unable to change the storage location!
					error: " + error_string(err)
				); return;
			print("ready to move files to new storage location: " + path);
			Notifier.notif_popup("Moving files!", Notifier.COLOR_WARN, Notifier.default_icon, false);
			Global.move_file(Global.storage_path, path, ["logs", "shader_cache"], ["storage_location"]);
			var dialog := Global.pop_text(
				"Changing storage location to %s
				dicolo! has already moved your file
				~ Please restart the game ~" % path
			, true);
		);
	)

func get_setting() -> DataSetting:
	return DataManager.get_data_setting();

func save_setting():
	if loading_data: return;
	DataManager.save_data_setting();

func set_setting_from_data():
	
	print("set_setting_from_data...");
	
	var data_player := DataManager.data_player as DataPlayer;
	textureAvatar.texture = data_player.get_avatar();
	lineEditName.text = data_player.name;
	
	var setting := get_setting();
	
	match setting.input_mode:
		DataSetting.INPUT_MODE.JOYSTICK:
			buttonInputGamepad.button_pressed = true;
		DataSetting.INPUT_MODE.V_JOYSTICK:
			buttonInputVJoy.button_pressed = true;
		DataSetting.INPUT_MODE.TOUCH:
			buttonInputTouch.button_pressed = true;
	
	optionFullScreenMode.selected = setting.full_screen_mode;
	buttonFullScreen.button_pressed = setting.full_screen;
	inputFPS.text = str(setting.fps);
	checkVSync.button_pressed = setting.v_sync;
	sliderScale.value = setting.scale;
	
	sliderVolumeMaster.value = setting.volume_master;
	sliderVolumeMusic.value = setting.volume_music;
	sliderVolumeEffect.value = setting.volume_effect;
	sliderVolumeVoice.value = setting.volume_voice;
	
	set_audio_offset(setting.audio_offset);
	
	checkDebugInfo.button_pressed = setting.debug_info;
	
	
	if Global.storage_path != "user://":
		storageLocation.text = Global.storage_path;
	
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
	var tween := create_tween();
	tween.tween_property(self, "offset_left", 0, 0.15
		).from(-size.x).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);

func anim_hide():
	var tween := create_tween();
	tween.tween_property(self, "offset_left", -size.x, 0.15
		).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
	tween.finished.connect(func(): visible = false);
