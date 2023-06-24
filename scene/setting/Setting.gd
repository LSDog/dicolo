extends Control

var setting_shown :bool = false;

const COLOR_NORMAL := Color.WHITE;
const COLOR_WAITING := Color("e098ff");
const COLOR_CHANGED := Color("ffdd00");

@onready var button_FullScreen := $Panel/Scroll/List/Video/FullScreen/Button;
@onready var option_FullScreenMode := $Panel/Scroll/List/Video/FullScreenMode/Option;
var option_FullScreenMode_items = [DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, DisplayServer.WINDOW_MODE_FULLSCREEN];
@onready var input_FPS := $Panel/Scroll/List/Video/FPS/Input;
@onready var button_VSync := $Panel/Scroll/List/Video/VSync/Button;
@onready var label_Scale := $Panel/Scroll/List/Video/Scale/Label;
@onready var slider_Scale := $Panel/Scroll/List/Video/Scale/HSlider;
@onready var label_Gamepad := $Panel/Scroll/List/Control/Gamepad/Label;
@onready var option_Gamepad := $Panel/Scroll/List/Control/Gamepad/Option;

var loading_data := true;

func _ready():
	
	DataManager.load_data(DataManager.DATA_TYPE.SETTING);
	
	set_setting_from_data();
	
	bind_gui_action();
	


func bind_gui_action():
	
	button_FullScreen.toggled.connect(func(pressed):
		var id = option_FullScreenMode.get_selected_id();
		print("FullScreen -> ", option_FullScreenMode.get_item_text(id), ": ", pressed);
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
			if !pressed else
			option_FullScreenMode_items[id]
		);
		set_data("FullScreen", pressed);
	);
	option_FullScreenMode.item_selected.connect(func(index: int):
		if button_FullScreen.button_pressed:
			print("FullScreen -> ", option_FullScreenMode.get_item_text(index), ": ", button_FullScreen.button_pressed);
			DisplayServer.window_set_mode(option_FullScreenMode_items[index]);	
		set_data("FullScreenMode", index);
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
			set_data("FPS", text);
	);
	button_VSync.toggled.connect(func(pressed: bool):
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
			if pressed else
			DisplayServer.VSYNC_DISABLED
		);
		set_data("VSync", pressed);
	);
	slider_Scale.value_changed.connect(func(value: float):
		get_tree().root.content_scale_factor = value;
		Global.stretch_scale = value;
		var event := InputEventMouseButton.new();
		event.set_button_index(MOUSE_BUTTON_LEFT);
		event.set_pressed(false);
		Input.parse_input_event(event);
		set_data("Scale", value);
	);
	update_gamepad_select();
	Input.joy_connection_changed.connect(func(device: int, connected: bool):
		print("[Setting] gamepad changed: ",device,"\tconnected: ",connected);
		Notifier.notif_popup(
			"A gamepad was [b]" + ("inserted" if connected else "pulled out") + "[/b].",
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

func set_setting_from_data():
	
	option_FullScreenMode.selected = get_data("FullScreenMode", option_FullScreenMode.selected);
	button_FullScreen.button_pressed = get_data("FullScreen", button_FullScreen.button_pressed);
	input_FPS.text_submitted.emit(get_data("FPS", 60));
	button_VSync.button_pressed = get_data("VSync", button_VSync.button_pressed);
	slider_Scale.value = get_data("Scale", slider_Scale.value);
	
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

func _input(event: InputEvent):
	if visible && event is InputEventMouseButton:
		if !get_rect().has_point(event.position):
			accept_event();
			if event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
				visible = false;
	elif event.is_action_pressed("full_screen"):
		button_FullScreen.button_pressed = !button_FullScreen.button_pressed;

func set_data(key: String, value):
	DataManager.data_setting[key] = value;
	DataManager.save_data(DataManager.DATA_TYPE.SETTING);

func get_data(key: String, default_value = null):
	var value = DataManager.data_setting.get(key);
	return default_value if value == null else value;
