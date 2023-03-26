extends Control

var float_bar_rect :Rect2;
var float_bar_shown :bool = false;
var setting_shown :bool = false;

func _ready():
	$FloatBar.gui_input.connect(float_bar_input);
	$Panel/Animation.animation_finished.connect(func(anim_name):
		match anim_name:
			"hide":
				setting_shown = false;
	);

func _process(_delta):
	float_bar_rect = $FloatBar.get_global_rect();
	var mouse_pos := get_global_mouse_position();
	if mouse_pos.y < 5.0 && mouse_pos.x >= float_bar_rect.position.x && mouse_pos.x <= float_bar_rect.position.x + float_bar_rect.size.x:
		if !float_bar_shown:
			float_bar_shown = true;
			$FloatBar/Animation.play("show");
	else:
		if float_bar_shown && !setting_shown && !float_bar_rect.has_point(mouse_pos):
			float_bar_shown = false;
			$FloatBar/Animation.play("hide");

func _input(event):
	# 显示设置面板时拦截其他事件
	if setting_shown:
		var event_name :String = event.get_class();
		#if event is InputEventMouse || event is InputEventScreenTouch || event is InputEventScreenDrag:
		if (event_name.contains("InputEventMouse") && event.button_mask <= 2
		) || event_name.contains("InputEventScreen"):
			accept_event();
			if event.is_pressed() && !$Panel.get_global_rect().has_point(event.position):
				$Panel/Animation.play("hide");

func float_bar_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT && event.is_pressed():
			if !setting_shown:
				setting_shown = true;
				$Panel/Animation.play("show");
			else:
				$Panel/Animation.play("hide");
