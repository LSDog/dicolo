class_name Editor
extends Control

@onready var playground :PlayGroundControl = get_parent() as PlayGroundControl;
@onready var scroll :HScrollBar = $Scroll as HScrollBar;
@onready var flow :EditorFlow = $Flow as EditorFlow;
@onready var note_choose := $NoteChoose;

var edit_note_type :BeatMap.EVENT_TYPE;

func _ready():
	print("Editor: playground ", playground);
	playground.map_loaded.connect(func():
		loaded();
	);
	#for key in BeatMap.EVENT_TYPE.keys():
	#	NOTE_TYPE_MAP[key] = BeatMap.EVENT_TYPE[key];
	
func loaded():
	
	var scroll_page = playground.get_rect().size.x;
	flow.size.x = get_length_in_flow(playground.get_audio_length()) + scroll_page;
	scroll.max_value = flow.size.x;
	scroll.page = scroll_page;
	scroll.value_changed.connect(func(value):
		flow.offset = value;
		playground.jump(get_time_by_length(value));
	);
	
	playground.play_restart.connect(func():
		scroll.value = 0;
	);
	
	note_choose.get_child(0).button_group.pressed.connect(func(button):
		edit_note_type = BeatMap.EVENT_TYPE.find_key(String(button.name));
	);
	
	# 加载铺面到编辑器
	for event in playground.beatmap.events:
		flow.add_note(
			event.event_type,
			Vector2(
				get_length_in_flow(event.time),
				flow.get_note_pos_y(event.side)
			),
			Vector2(
				10,
				flow.size.y/2 - flow.note_margin_vertical * 2
			)
		);

func _process(delta: float) -> void:
	if playground.started && !playground.ended && !playground.paused:
		var x = get_length_in_flow(playground.play_time)
		scroll.set_value_no_signal(x);
		scroll.queue_redraw();
		flow.offset = x;

func get_length_in_flow(time :float) -> float:
	return time * playground.bpm / 60 * flow.beat_space;

func get_time_by_length(length :float) -> float:
	return length / flow.beat_space / playground.bpm * 60;

func choose_note_type(type :BeatMap.EVENT_TYPE):
	(note_choose.find_child(BeatMap.EVENT_TYPE.find_key(type)) as Button).button_pressed = true;
	edit_note_type = type;

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
