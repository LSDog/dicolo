extends Control

@onready var click_circle = preload("res://visual/texture/ring.svg");

@onready var panelLightPad = $PanelLightPad;
var left_touch_count :int = 0;
var right_touch_count :int = 0;
var panelLightPad_gradient :Gradient;
var panelLightPad_tween :Array[Tween] = [null,null,null];

var touch_index_object :Dictionary = {};
var touch_index_velocity :Dictionary = {};

func _ready():
	panelLightPad_gradient = (panelLightPad.texture as GradientTexture1D).gradient;

func _input(event: InputEvent):
	
	var middle_x :float = panelLightPad.global_position.x + panelLightPad.size.x/2.0;
	
	if event is InputEventScreenTouch:
		
		var side := 0 if event.position.x < middle_x else 1;
		
		if event.pressed:
			# circle
			var objects = anim_click_circle(event.position);
			touch_index_object[event.index] = objects;
			# pad
			add_touch_count(side);
			anim_panelLightPad_press(side);
			
		else:
			#circle
			var objects;
			var vel = touch_index_velocity.get(event.index);
			if (vel != null):
				objects = anim_click_release(event.position, vel);
				touch_index_velocity.erase(event.index);
			else:
				objects = anim_click_release(event.position);
			# pad
			add_touch_count(side, -1);
			if get_touch_count(side) <= 0:
				anim_panelLightPad_release(side);
	
	elif event is InputEventScreenDrag:
		
		var side := 0 if event.position.x < middle_x else 1;
		
		# circle
		var objects :Array = touch_index_object.get(event.index) as Array;
		if objects != null:
			objects.all(func(object):
				if object != null && object is CanvasItem:
					object.position += event.relative;
			)
		touch_index_velocity[event.index] = event.velocity;
		# pad
		var side_before = 0 if event.position.x-event.relative.x < middle_x else 1;
		if side_before != side:
			add_touch_count(side_before, -1);
			add_touch_count(side);
			anim_panelLightPad_release(side_before);
			anim_panelLightPad_press(side);

func anim_panelLightPad_press(side: int):
	anim_panelLightPad_stop_tween(side);
	panelLightPad_gradient.colors[2 if side else 0].a = 1.0;

func anim_panelLightPad_release(side: int):
	anim_panelLightPad_stop_tween(side);
	var tween := create_tween();
	tween.tween_method(func(a): panelLightPad_gradient.colors[2 if side else 0].a = a, 1.0, 0.0, 0.4);
	panelLightPad_tween[side] = tween;

func anim_panelLightPad_stop_tween(side: int):
	var prev_tween = panelLightPad_tween[side];
	if prev_tween != null:
		prev_tween.stop();

func get_touch_count(side: int):
	return left_touch_count if side == 0 else right_touch_count;

func add_touch_count(side: int, count: int = 1):
	if side == 0:
		left_touch_count = max(left_touch_count+count, 0);
	else:
		right_touch_count = max(right_touch_count+count, 0);

func anim_click_circle(pos: Vector2) -> Array:
	var circle = Sprite2D.new();
	add_child(circle);
	circle.global_position = pos;
	circle.texture = click_circle;
	circle.scale = Vector2.ZERO;
	circle.modulate.a = 0.8;
	var tween = create_tween();
	tween.parallel().tween_property(circle, "scale", Vector2.ONE*randf_range(0.5,0.8), 0.4
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
	tween.parallel().tween_property(circle, "modulate:a", 0, 0.4
		).set_trans(Tween.TRANS_LINEAR);
	tween.finished.connect(func(): circle.queue_free());
	return [circle];

func anim_click_release(pos: Vector2, velocity: Vector2 = Vector2.ZERO) -> Array:
	var circle = Sprite2D.new();
	add_child(circle);
	circle.global_position = pos;
	circle.texture = click_circle;
	circle.scale = Vector2.ZERO;
	circle.modulate.a = 0.3;
	var tween = create_tween();
	tween.parallel().tween_property(circle, "scale", Vector2.ZERO, 1
		).from(Vector2.ONE*randf_range(0.4,0.6)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC);
	tween.parallel().tween_property(circle, "modulate:a", 0, 0.2
		).set_trans(Tween.TRANS_LINEAR);
	velocity.limit_length(100);
	tween.parallel().tween_property(circle, "position", velocity*0.2, 0.2).as_relative();
	tween.finished.connect(func(): circle.queue_free());
	return [circle];
	
