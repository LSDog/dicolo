extends Control

var setting_shown :bool = false;

@onready var button_FullScreen := $Panel/Scroll/List/Video/FullScreen/Button;
@onready var option_FullScreenMode := $Panel/Scroll/List/Video/FullScreenMode/Option;
enum FullScreenMode {FullScreen, BorderLess};
@onready var input_FPS := $Panel/Scroll/List/Video/FPS/Input;
@onready var button_VSync := $Panel/Scroll/List/Video/VSync/Button;
@onready var label_Scale := $Panel/Scroll/List/Video/Scale/Label;
@onready var slider_Scale := $Panel/Scroll/List/Video/Scale/HSlider;
@onready var label_Gamepad := $Panel/Scroll/List/Control/Gamepad/Label;
@onready var option_Gamepad := $Panel/Scroll/List/Control/Gamepad/Option;

func _ready():
	button_FullScreen.toggled.connect(func(pressed):
		var id = option_FullScreenMode.get_selected_id();
		print("full screen -> ", option_FullScreenMode.get_item_text(id), " ", pressed);
		match id:
			FullScreenMode.FullScreen:
				DisplayServer.window_set_mode(
					DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
					if pressed else 
					DisplayServer.WINDOW_MODE_WINDOWED
				);
			FullScreenMode.BorderLess:
				DisplayServer.window_set_mode(
					DisplayServer.WINDOW_MODE_FULLSCREEN
					if pressed else 
					DisplayServer.WINDOW_MODE_WINDOWED
				);
				
	);
	input_FPS.text_submitted.connect(func(text: String):
		if text.is_valid_int():
			var fps = text.to_int();
			Engine.max_fps = 0 if fps < 0 else fps;
	);
	button_VSync.toggled.connect(func(pressed: bool):
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED
			if pressed else
			DisplayServer.VSYNC_DISABLED
		);
	);
	slider_Scale.value_changed.connect(func(value: float):
		get_tree().root.content_scale_factor = value;
		var event := InputEventMouseButton.new();
		event.set_button_index(1);
		event.set_pressed(false);
		Input.parse_input_event(event);
	);
	update_gamepad_select();
	Input.joy_connection_changed.connect(func(device: int, connected: bool):
		print("[Setting] gamepad changed: ",device,"\tconnected: ",connected);
		Notifier.notif_popup(
			"A gamepad was [b]" + ("inserted" if connected else "pulled out") + "[/b].",
			Notifier.COLOR_OK if connected else Notifier.COLOR_BAD
		);
		update_gamepad_select();
		if connected: Global.gamepad_id = device;
	);
	option_Gamepad.item_selected.connect(func(id):
		Global.gamepad_id = id;
		update_label_Gamepad();
	)

func update_gamepad_select():
	var joys = [];
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
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else 
			DisplayServer.WINDOW_MODE_WINDOWED
		);
