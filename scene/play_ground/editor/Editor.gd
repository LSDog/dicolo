extends Control

@onready var playground :Control = get_parent();
@onready var scroll := $Scroll;
@onready var flow := $Flow;
@onready var note_choose := $NoteChoose;

enum NOTE_TYPE {CRASH, SLIDE};
var NOTE_TYPE_MAP :Dictionary;
var edit_note_type :NOTE_TYPE;

func _ready():
	playground.loaded.connect(loaded);
	for key in NOTE_TYPE.keys():
		NOTE_TYPE_MAP[key] = NOTE_TYPE[key];

func loaded():
	flow.size.x = flow.beat_space * playground.audio_player.stream.get_length() / 60 * playground.beatmap.bpm;
	scroll.max_value = flow.size.x;
	scroll.page = get_viewport_rect().size.x;
	scroll.value_changed.connect(func(value):
		flow.offset = value;
	);
	note_choose.get_child(0).button_group.pressed.connect(func(button):
		edit_note_type = NOTE_TYPE_MAP.get(button.name);
	);

func choose_note_type(type :NOTE_TYPE):
	(note_choose.find_child(NOTE_TYPE.find_key(type)) as Button).button_pressed = true;
	edit_note_type = type;

func _unhandled_input(event):
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
