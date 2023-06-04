extends Node

var container :Control;
var base_point :Control;
var vbox :VBoxContainer;

@onready var scene_notif = preload("res://scene/notif_box.tscn");
@onready var notif_box_copy = scene_notif.instantiate() as PanelContainer;
@onready var notif_stylebox :StyleBoxFlat;
@onready var default_icon = preload("res://image/ui_icon/info.svg");

var show_time :float = 0.25;
var keep_time :float = 5;
var exit_time :float = 0.5;

const COLOR_NORAML = Color(0.4,0.4,0.4);
const COLOR_OK = Color.LIME_GREEN;
const COLOR_WARN = Color.ORANGE;
const COLOR_BAD = Color.RED;


func _ready() -> void:
	notif_stylebox = notif_box_copy.get_theme_stylebox("panel").duplicate(true);
	container = Control.new();
	base_point = Control.new();
	vbox = VBoxContainer.new();
	_ready_later.call_deferred();

func _ready_later():
	container.name = "Notification";
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	container.set_anchors_preset(Control.PRESET_FULL_RECT);
	# 注意 Notif 和其他要置顶的的排序在 Global.gd里 这里注释掉
	#container.z_index = 13;
	
	base_point.name = "BasePoint";
	base_point.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	base_point.set_anchors_preset(Control.PRESET_TOP_RIGHT);
	base_point.grow_horizontal = Control.GROW_DIRECTION_BEGIN;
	
	vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT);
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN;
	vbox.add_theme_constant_override("separation", 0);
	
	get_tree().root.add_child(container);
	container.add_child(base_point);
	base_point.add_child(vbox);

## 弹出一个通知
func notif_popup(text: String, border_color: Color = COLOR_NORAML, icon: Texture2D = default_icon):
	var notif_box := notif_box_copy.duplicate() as PanelContainer;
	var stylebox = notif_stylebox.duplicate(true);
	stylebox.border_color = border_color;
	notif_box.mouse_filter = Control.MOUSE_FILTER_IGNORE;
	notif_box.get_child(0).find_child("Text").text = text;
	notif_box.add_theme_stylebox_override("panel", stylebox);
	vbox.add_child(notif_box);
	vbox.move_child(notif_box, 0);
	var tween = notif_box.create_tween().set_parallel(true);
	tween.finished.connect(func(): notif_box.queue_free());
	tween.tween_property(notif_box, "modulate:a", 1.0, show_time).from(0.0);
	tween.tween_property(notif_box, "position:x", 0, show_time).from(notif_box.size.x
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO);
	tween.chain().tween_property(stylebox, "bg_color:v", 0.15, keep_time);
	tween.chain().tween_property(notif_box, "modulate:a", 0.0, exit_time
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO);
