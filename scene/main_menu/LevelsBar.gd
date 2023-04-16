extends Control

@onready var container := $Container;

@export_range(0.0,1.0) var no_select_alpha = 0.45;

var last_select_click :Vector2;
var selected_label :Label;

func _ready() -> void:
	for level_label in container.get_children():
		level_label_init(level_label);
	child_entered_tree.connect(level_label_init.bind());

func level_label_init(level_label: Label):
	level_label.mouse_filter = Control.MOUSE_FILTER_PASS;
	level_label.modulate.a = no_select_alpha;
	# 点击事件 -> 选择level
	level_label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					last_select_click = event.global_position;
				else:
					if get_global_mouse_position().distance_to(last_select_click) < 10:
						select_label(level_label);
	);

func select_label(label :Label):
	print("Select level: " + label.text);
	if selected_label != null:
		selected_label.modulate.a = no_select_alpha;
	selected_label = label;
	selected_label.modulate.a = 1.0;
