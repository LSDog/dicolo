## 包含一张图所有信息的类
class_name BeatMap
extends Resource

## 音符类型
enum EVENT_TYPE {None, Note, Hit, Slide, Bounce, Start, Bpm, End};

## 是否加载完毕
var loaded :bool = false;

## 铺面文件夹路径
var dir_path :String;
## 铺面文件路径
var file_path :String;

## 歌曲标题
var title :String;
## 演唱者
var singer :String;
## 作图者
var mapper :String;
## 难度
var level: float;
## 难度名称
var levelname :String;
## 音频文件路径
var audio_path :String;
## 视频文件路径
var video_path :String;
## 默认Bpm
var bpm: float;
## 背景图片路径
var bg_image_path :String;
## 背景图片
#var bg_image :Texture2D;
## 歌词路径
var lrc_path :String;
## 音符/事件等
var events :Array[Event] = [];
## 开始时间（来自第一个event的时间）
var start_time: float;

## 构造器。需要当前铺面目录和已经打开的 [FileAccess] ([method FileAccess.open])
func _init(dir_access :DirAccess, file :FileAccess):
	resource_name = "BeatMap";
	if file == null || !file.is_open(): return;
	dir_path = dir_access.get_current_dir();
	file_path = file.get_path();
	# 获取第一行的标识内容并检验
	var head_line = file.get_line();
	if head_line != "!dicolo_map_v1":
		file.close();
		return;
	var dir = dir_access.get_current_dir() + '/';
	var key :String = "";
	var value :String = "";
	var in_event :bool = false;
	var line :String;
	while file.get_position() < file.get_length():
		# 获取下一行
		line = file.get_line();
		# 去掉注释
		line = line.substr(0, line.find("//"));
		if line.is_empty(): continue;
		if in_event:
			# 读取event时
			add_event(line);
		else:
			# 读取其他单行键值
			var array := line.split(':', true, 2);
			if array.size() < 2: continue;
			key = array[0];
			value = array[1];
			match key:
				"title": title = value;
				"singer": singer = value;
				"mapper": mapper = value;
				"level": level = -1 if !value.is_valid_float() else value.to_float();
				"levelname": levelname = value;
				"audio":
					audio_path = dir+value;
				"video":
					video_path = dir+value;
				"bpm": bpm = 0 if !value.is_valid_float() else value.to_float();
				"bg":
					bg_image_path = dir+value;
					#bg_image = ResourceLoader.load(dir+value, "Texture2D");
				"lrc":
					lrc_path = dir+value;
				"events":
					in_event = true;
	file.close();
	start_time = 0.0 if events.is_empty() else events[0].time;
	loaded = true;

## 接受1行带时间的event形式，如 "0.6 _start" 或 "1.93 c/l/-135 c/r/-90"
func add_event(event_str :String):
	if event_str == null || event_str.is_empty(): return;
	var event_split := event_str.split(" ", false);
	if event_split.size() < 2: return;
	if !event_split[0].is_valid_float(): return;
	var time := event_split[0].to_float();
	if event_split[1].begins_with("_"):
		# 其他事件
		match event_split[1]:
			"_start":
				events.append(Event.Start.new(time));
	else:
		# 音符
		for i in range(1, event_split.size()):
			add_note(time, event_split[i]);

## 接受单个音符形式，如 c/r/135
func add_note(time: float, note_string :String):
	if note_string.is_empty(): return;
	var note_split = note_string.split('/');
	match note_split[0]:
		"h": # hit
			events.append(Event.Note.Hit.new(
				time, \
				Event.SIDE.LEFT if note_split[1]=="l" else Event.SIDE.RIGHT, \
				0.0 if !note_split[2].is_valid_float() else note_split[2].to_float(), \
				0.0 if !note_split[3].is_valid_float() else note_split[3].to_float()
			));
		"s": # slide
			events.append(Event.Note.Slide.new(
				time, \
				Event.SIDE.LEFT if note_split[1]=="l" else Event.SIDE.RIGHT, \
				0.0 if !note_split[2].is_valid_float() else note_split[2].to_float(),
			));
		"b": # bounce
			events.append(Event.Note.Bounce.new(
				time, \
				Event.SIDE.LEFT if note_split[1]=="l" else Event.SIDE.RIGHT
			));

## 输出为格式化的String
func to_file_string() -> String:
	var values :PackedStringArray = [];
	append_no_empty(values, ["!dicolo_map_v1"]);
	append_no_empty(values, ["title: ", title]);
	append_no_empty(values, ["singer: ", singer]);
	append_no_empty(values, ["mapper: ", mapper]);
	append_no_empty(values, ["level: ", str(level)]);
	append_no_empty(values, ["levelname: ", levelname]);
	append_no_empty(values, ["audio: ", audio_path]);
	append_no_empty(values, ["video: ", video_path]);
	append_no_empty(values, ["bpm: ", str(bpm)]);
	append_no_empty(values, ["bg: ", bg_image_path]);
	append_no_empty(values, ["lrc: ", lrc_path]);
	
	var event_array :PackedStringArray = [];
	for event in events:
		event_array.append(event.to_string());
	values.append("events:\n" + "\n".join(event_array));
	
	return "\n".join(values);

func append_no_empty(array: PackedStringArray, str_array: Array):
	if str_array != null && !array.is_empty() && !str_array.has(null) && !str_array.has(""):
		array.append("".join(str_array));

class Event:
	
	# Event 类型（get_class不能用）
	var event_type = EVENT_TYPE.None;
	
	## 执行的时间(s)
	var time: float;
	
	## 所在track的位置
	var side :int;
	## 位置常量
	enum SIDE {OTHER=-1, LEFT=0, RIGHT=1}
	
	func _init(p_time: float, p_side: int = SIDE.OTHER):
		self.time = p_time;
		self.side = p_side;
	
	func _to_string() -> String:
		return "{} event" % time;
	
	## 音符
	class Note:
		extends Event;
		
		func _init(p_time: float, p_side: int):
			super._init(p_time, p_side);
			self.event_type = EVENT_TYPE.Note;
		
		class Hit:
			extends Note;
			
			var deg: float;
			var deg_end: float;
			
			func _init(p_time: float, p_side: int, p_deg: float, p_deg_end: float):
				super._init(p_time, p_side);
				self.deg = p_deg;
				self.deg_end = p_deg_end;
				self.event_type = EVENT_TYPE.Hit;
		
		class Slide:
			extends Note;
			
			var deg: float;
			
			func _init(p_time: float, p_side: int, p_deg: float):
				super._init(p_time, p_side);
				self.deg = p_deg;
				self.event_type = EVENT_TYPE.Slide;
		
		class Bounce:
			extends Note;
			
			func _init(p_time: float, p_side: int):
				super._init(p_time, p_side);
				self.event_type = EVENT_TYPE.Bounce;
	
	## 开始
	class Start:
		extends Event;
		func _init(p_time: float):
			super._init(p_time, SIDE.OTHER);
			event_type = EVENT_TYPE.Start;
	
	## bpm更改
	class Bpm:
		extends Event;
		
		var bpm: float;
		
		func _init(p_time: float, p_bpm: float):
			super._init(p_time, SIDE.OTHER);
			self.bpm = p_bpm;
			event_type = EVENT_TYPE.Bpm;
	
