extends ColorRect


@onready var background = $Background;

var hide_anim_playing :bool = false;

func _ready():
	background.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT && !event.pressed:
				hide_anim();
	);


func _gui_input(event: InputEvent):
	if event.is_action_released("esc"):
		hide_anim();

func switch_show_hide():
	if visible:
		hide_anim();
	else:
		show_anim();

func show_anim():
	visible = true;
	var tween = create_tween();
	tween.tween_property(self, "modulate:a", 1.0, 0.3
		).from(0.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);

func hide_anim():
	if hide_anim_playing: return;
	hide_anim_playing = true;
	var tween = create_tween();
	tween.tween_property(self, "modulate:a", 0.0, 0.1
		).from(1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
	tween.finished.connect(func():
		visible = false;
		hide_anim_playing = false;
	);
