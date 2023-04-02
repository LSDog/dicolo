@tool
extends Panel

@onready var editor :Control = get_parent();
@onready var note_crash_stylebox :StyleBox = preload("res://scene/play_ground/editor/note_crash.stylebox");
@onready var note_slide_stylebox :StyleBox = preload("res://scene/play_ground/editor/note_slide.stylebox");

@export var outline_color := Color.LIGHT_YELLOW;
@export var barline_color := Color.LIGHT_BLUE;
@export var beatline_color := Color(0.372549, 0.619608, 0.627451, 0.2);
@export var note_margin_vertical := 4;

signal flow_changed;

@export var bar_space := 120.0:
	set(value):
		bar_space = value;
		flow_changed.emit();
@export_range(1,8) var beat_count :int = 4:
	set(value):
		beat_count = value;
		flow_changed.emit();

var beat_space :float = bar_space/beat_count;

@export_range(0, 4096) var offset := 0.0:
	set(value):
		offset = value;
		position.x = -offset;
		queue_redraw();

var mouse_offset := 0.0;
var holding_note :Control;
var holding_note_type ;#:editor.NOTE_TYPE
var barrier_touched :bool = false;
var barrier_note_pos :Vector2;
var note_map :Dictionary = {};

func _ready():
	flow_changed.connect(func():
		beat_space = bar_space/beat_count;
		queue_redraw();
	);
	pass

func _process(delta):
	pass

func _draw():
	
	# 绘制边框
	var visible_rect := editor.get_rect().intersection(get_rect());
	visible_rect.position.x = -position.x;
	visible_rect.position.y = 0;
	var middle_line_start := Vector2(visible_rect.position.x, visible_rect.size.y/2);
	var middle_line_end := Vector2(visible_rect.position.x+visible_rect.size.x, middle_line_start.y);
	draw_rect(visible_rect, outline_color, false, 3);
	draw_line(middle_line_start, middle_line_end, outline_color, 3)
	
	# 绘制节拍线
	var h := visible_rect.size.y;
	var d_offset := fmod(-offset, -bar_space);
	var d_now := -position.x;
	var d_end := visible_rect.size.x - position.x;
	while d_now <= d_end + bar_space: # 多画一小节
		draw_line(
			Vector2(d_now + d_offset, 0),
			Vector2(d_now + d_offset, h),
			barline_color, 1.5, true
		);
		var beat_space_current := 0.0;
		while beat_space_current <= bar_space:
			draw_line(
				Vector2(d_now + beat_space_current + d_offset, 0),
				Vector2(d_now + beat_space_current + d_offset, h),
				beatline_color, 1, true
			);
			beat_space_current += beat_space;
		d_now += bar_space;



func _gui_input(event):
	
	match event.get_class():
		
		"InputEventMouseButton":
			if event.button_index != MOUSE_BUTTON_LEFT: return;
			if event.pressed:
				
				var note_pos = get_note_pos(event.position);
				if rect_overlapped_note(Rect2(note_pos, Vector2.ZERO)): return; # 当前位置存在note则忽略
				#if note_map.has(note_pos): return;
				
				holding_note_type = editor.edit_note_type;
				
				var panel_note := Panel.new();
				panel_note.name = 'n' + str(holding_note_type);
				panel_note.position = note_pos;
				panel_note.size = Vector2(10, size.y/2 - note_margin_vertical*2);
				
				match holding_note_type:
					editor.NOTE_TYPE.CRASH:
						panel_note.add_theme_stylebox_override("panel", note_crash_stylebox);
					editor.NOTE_TYPE.SLIDE:
						panel_note.add_theme_stylebox_override("panel", note_slide_stylebox);
				
				add_note(panel_note, holding_note_type);
				
				holding_note = panel_note;
				
			else:
				
				holding_note = null;
				mouse_offset = 0;
		
		"InputEventMouseMotion":
			event = event as InputEventMouseMotion;
			
			var note_pos = get_note_pos(event.position);
			
			if event.button_mask == MOUSE_BUTTON_MASK_RIGHT: # 右键划过删除
				if note_map.has(note_pos):
					var rm_note = note_map.get(note_pos);
					if rm_note != null: remove_note(rm_note);
					return;
			
			if holding_note == null: return;
			
			# 移动持有的note
			match holding_note_type:
				editor.NOTE_TYPE.CRASH:
					if !note_overlapped(holding_note, note_pos):
						move_note(holding_note, note_pos);
				editor.NOTE_TYPE.SLIDE:
					if editor.edit_note_type == editor.NOTE_TYPE.SLIDE:
						note_pos = get_note_pos(event.position, false);
						var size_x = note_pos.x - holding_note.position.x;
						if size_x < 0: return;
						holding_note.size.x = 10 + size_x;
						mouse_offset -= event.relative.x;
					else:
						note_pos.x += mouse_offset;
						move_note(holding_note, note_pos);


func _unhandled_input(event):
	match event.get_class():
		"InputEventKey":
			event = event as InputEventKey;
			match event.keycode:
				KEY_TAB:
					editor.choose_note_type(editor.NOTE_TYPE.SLIDE);
					accept_event();
				_:
					if editor.edit_note_type != editor.NOTE_TYPE.CRASH:
						editor.choose_note_type(editor.NOTE_TYPE.CRASH);

func get_note_pos(mouse_pos :Vector2, allow_cross :bool = true) -> Vector2:
	var y = clampf(floor_multiple(mouse_pos.y, size.y/2), 0, size.y/2) + note_margin_vertical;
	if allow_cross:
		return Vector2(floor_multiple(mouse_pos.x, beat_space), y);
	else:
		pass;
		var last_x = size.x;
		var have_last_x = false;
		for pos in note_map.keys():
			if pos.y == holding_note.position.y && pos.x < last_x && pos.x > holding_note.position.x:
				have_last_x = true;
				last_x = pos.x;
		return Vector2(floor_multiple(last_x - beat_space if have_last_x && mouse_pos.x >= last_x else mouse_pos.x, beat_space), y);

func move_flow(p_offset :float):
	if p_offset < 0: p_offset = 0;
	offset = p_offset;
	queue_redraw();

func add_note(note: Control, note_type): # editor.NOTE_TYPE
	
	add_child(note);
	
	note.gui_input.connect(func(event):
		
		match event.get_class():
			
			"InputEventMouseButton":
				event = event as InputEventMouseButton;
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						if event.pressed:
							holding_note = note;
							holding_note_type = note_type;
							if holding_note_type == editor.NOTE_TYPE.SLIDE:
								mouse_offset = - event.position.x;
						else:
							holding_note = null;
					MOUSE_BUTTON_RIGHT:
						if event.pressed:
							remove_note(note);
			
			"InputEventMouseMotion": # 移动持有的note
				event = event as InputEventMouseMotion;
				
				if holding_note == null || holding_note != note: return;
				var note_pos = get_note_pos(event.global_position);
				note_pos.x += offset;
				move_child(note, 0);
				match holding_note_type:
					editor.NOTE_TYPE.CRASH:
						if !note_overlapped(note, note_pos):
							move_note(note, note_pos);
					editor.NOTE_TYPE.SLIDE:
						note_pos.x += 10 + mouse_offset;
						note_pos = get_note_pos(note_pos);
						if note_overlapped(note, note_pos): return;
						move_note(note, note_pos);
	);
	note_map[note.position] = note;

func note_overlapped(note :Control, pos :Vector2 = note.get_position()) -> bool:
	var rect = note.get_rect();
	rect.position = pos;
	for map_note in note_map.values():
		if note != map_note && rect.intersects(map_note.get_rect(), true): return true;
	return false;

func rect_overlapped_note(rect :Rect2) -> bool:
	for map_note in note_map.values():
		if rect.intersects(map_note.get_rect(), true): return true;
	return false;

func move_note(note :Control, pos :Vector2):
	note_map.erase(note.position);
	note.position = pos;
	note_map[pos] = note;

func remove_note(note :Control):
	if !note_map.has(note.position): return;
	note_map.erase(note.position);
	remove_child(note);
	note = null;

func round_multiple(value :float, round :float) -> float:
	return roundf(value/round) * round;

func floor_multiple(value :float, round :float) -> float:
	return floorf(value/round) * round;
