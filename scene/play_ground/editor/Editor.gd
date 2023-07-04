class_name Editor
extends Control

## 制谱器

@onready var playground :PlaygroundControl = $PlaygroundControl as PlaygroundControl;
@onready var scroll :HScrollBar = $FlowBox/Scroll as HScrollBar;
@onready var flowBox :Control = $FlowBox as Control;
@onready var flow :EditorFlow = $FlowBox/FlowPanel as EditorFlow;
@onready var note_choose := $Edit/VBox/NoteChoose;

@onready var buttonPlay := $Edit/VBox/HBoxPlayback/ButtonPlay;
@onready var buttonMenu := $Edit/VBox/HBoxPlayback/ButtonMenu;

var edit_note_type :BeatMap.EVENT_TYPE;

## 列出音符类型的array
var event_types :Array = BeatMap.EVENT_TYPE.keys();

signal loaded;
var has_loaded := false;

func _ready():
	# 禁用 virtualJoystic
	playground.enable_virtualJoystick = false;
	playground.manuButton.visible = false;
	# 设定模式
	playground.play_mode = playground.PLAY_MODE.EDIT;
	# 修正大小
	if Global.data_has_loaded_setting: currect_scaling();
	else: Global.data_loaded_setting.connect(currect_scaling);
	
	# 测试用 加载map
	load_map("res://map/HareHareYukai/map_normal.txt");
	
	playground.play_end.connect(func():
		buttonPlay.button_pressed = false;
	);
	playground.play_jump.connect(func(time):
		buttonPlay.button_pressed = false;
	);
	buttonPlay.toggled.connect(func(pressed:bool):
		if !playground.started:
			playground.start();
		elif !playground.paused:
			playground.pause();
		else:
			playground.resume();
	);
	
	playground.bgpanel_mask.color.a = 0.6;

## 修正大小
func currect_scaling():
	playground.video_player.scale = Vector2(0.91, 0.91);
	#playground.scale /= Global.stretch_scale;


## 加载铺面
func load_map(map_file_path: String):
	
	print("[Editor] loading map: ", map_file_path);
	
	playground.load_map(map_file_path, false);
	
	has_loaded = true;
	loaded.emit();
	print("[Editor] loaded.");
	
	var length = flow.get_length_in_flow(playground.get_audio_length());
	flow.size.x = length;
	scroll.page = flowBox.size.x;
	scroll.max_value = length + scroll.page;
	scroll.value_changed.connect(func(value):
		flow.offset = value;
		playground.jump(flow.get_time_by_length(value));
	);
	
	playground.play_restart.connect(func():
		scroll.value = 0;
	);
	
	note_choose.get_child(0).button_group.pressed.connect(func(button):
		print("[Editor] Choose ", String(button.name));
		edit_note_type = event_types.find(String(button.name));
	);
	
	# 加载铺面到编辑器
	for event in playground.beatmap.events:
		flow.add_note(
			event.event_type,
			Vector2(
				flow.get_length_in_flow(event.time),
				flow.get_note_pos_y(event.side)
			),
			Vector2(
				10,
				flow.size.y/2 - flow.note_margin_vertical * 2
			)
		);
	
	#for key in BeatMap.EVENT_TYPE.keys():
	#	NOTE_TYPE_MAP[key] = BeatMap.EVENT_TYPE[key];

func _process(_delta: float) -> void:
	if playground.started && !playground.ended && !playground.paused:
		var x = flow.get_length_in_flow(playground.play_time)
		scroll.set_value_no_signal(x);
		scroll.queue_redraw();
		flow.offset = x;

func choose_note_type(type :BeatMap.EVENT_TYPE):
	(note_choose.find_child(BeatMap.EVENT_TYPE.find_key(type)) as Button).button_pressed = true;
	edit_note_type = type;

func _input(event: InputEvent):
	if event.is_action_pressed("play"):
		accept_event();
		buttonPlay.button_pressed = !buttonPlay.button_pressed;

func _unhandled_input(event):
	if !visible: return;
	match event.get_class():
		"InputEventMouseButton":
			event = event as InputEventMouseButton;
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					scroll.value -= 10;
					accept_event();
				MOUSE_BUTTON_WHEEL_DOWN:
					scroll.value += 10;
					accept_event();
