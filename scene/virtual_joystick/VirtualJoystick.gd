extends Control

var enable_control = true;

# [ LPos, RPos ]
var touches := [null, null];
var touch_index := [null, null];
var out_pos := [null, null];
var tweens := [null, null];

var joy_l = Vector2.ZERO;
var joy_r = Vector2.ZERO;

func _ready():
	
	$LOut.visible = false;
	$ROut.visible = false;

func _process(_delta):
	update();

func update():
	
	if $LOut.visible:
		var left_joy_pos :Vector2 = (touches[0] - $LOut.position)/$LOut.scale.x;
		var length = left_joy_pos.length();
		var out_radius = $LOut.texture.get_size().x/2;
		if length > out_radius: left_joy_pos = left_joy_pos * (out_radius / length);
		joy_l = left_joy_pos / out_radius;
		$LOut/Stick.position = left_joy_pos;
	else:
		joy_l = Vector2.ZERO;
	
	if $ROut.visible:
		var right_joy_pos :Vector2 = (touches[1] - $ROut.position)/$ROut.scale.x;
		var length = right_joy_pos.length();
		var out_radius = $ROut.texture.get_size().x/2;
		if length > out_radius: right_joy_pos = right_joy_pos * (out_radius / length);
		joy_r = right_joy_pos / out_radius;
		$ROut/Stick.position = right_joy_pos;
	else:
		joy_r = Vector2.ZERO;

func _gui_input(event):
	match event.get_class():
		"InputEventScreenTouch":
			#event = event as InputEventScreenTouch;
			# side: 0左 1右
			var side :int = touch_index.find(event.index);
			if side == -1:
				side = 0 if event.position.x <= size.x/2.0 else 1;
			if event.pressed:
				if touch_index[side] == null:
					touch_index[side] = event.index;
					touches[side] = event.position;
					play_show(side);
					update();
			else:
				touch_index[side] = null;
				play_hide(side);
			accept_event();
		"InputEventScreenDrag":
			#event = event as InputEventScreenDrag;
			if touch_index.has(event.index):
				var side = touch_index.find(event.index);
				touches[side] = event.position;
			accept_event();

func play_show(side: int):
	
	var node = $LOut if side == 0 else $ROut;
	node.position = touches[side];
	node.visible = true;
	
	if tweens[side] != null:
		tweens[side].kill();
	
	var tween = node.create_tween().set_parallel(true);
	tweens[side] = tween;
	tween.tween_property(node, "modulate:v", 1.0, 0.2).from(2.0).set_trans(Tween.TRANS_EXPO);
	tween.tween_property(node, "modulate:a", 1.0, 0.045).from(0.0);

func play_hide(side: int):
	
	var node = $LOut if side == 0 else $ROut;
	var tween = node.create_tween().set_parallel(true);
	tweens[side] = tween;
	tween.tween_property(node, "modulate:a", 0.0, 0.1).from_current();
	var stick = node.get_child(1);
	tween.tween_property(stick, "position", Vector2.ZERO, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD);
	tween.tween_callback(func():
		node.visible = false;
	).set_delay(0.1);
