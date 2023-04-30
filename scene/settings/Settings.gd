extends Control

var setting_shown :bool = false;

@onready var button_FullScreen := $Panel/Scroll/List/Video/FullScreen/Button;
@onready var option_FullScreenMode := $Panel/Scroll/List/Video/FullScreenMode/Option;
enum FullScreenMode {FullScreen, BorderLess};
@onready var input_FPS := $Panel/Scroll/List/Video/FPS/Input;
@onready var button_VSync := $Panel/Scroll/List/Video/VSync/Button;

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

func _input(event: InputEvent):
	if visible && event is InputEventMouseButton:
		if !$Panel.get_rect().has_point(event.position):
			accept_event();
			if event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
				visible = false;
	elif event.is_action_pressed("full_screen"):
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else 
			DisplayServer.WINDOW_MODE_WINDOWED
		);
