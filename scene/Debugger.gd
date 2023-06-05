extends Node


var time_count_dic :Dictionary = {};

func _ready():
	print("Debugger.gd enabled.");

## 记录和检测某个步骤的耗时（开始的时候执行一次，后面再执行一次）
func count_time(id :String) -> void:
	var now = Time.get_ticks_usec();
	var prev = time_count_dic.get(id);
	time_count_dic[id] = now;
	if prev == null:
		print("[Debug] TIME-COUNT: \"", id, "\" started.");
	else:
		print("[Debug] TIME-COUNT: \"", id, "\" = ", (now - prev)/1000.0, "  ms");
		time_count_dic.erase(id);
