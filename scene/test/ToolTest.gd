@tool
extends EditorScript

func _run():
	var array := [9,9,9,9];
	for i in array.size():
		print(i)

## int 转换为二进制形式的字符串
func int2bin(value: int, min_digit: int = 1) -> String:
	if value <= 0: return "0".repeat(min_digit);
	var out = "";
	var digit = 0;
	while value > 0:
		out = ("1" if value & 1 else "0") + out;
		value >>= 1;
		digit += 1;
	if digit < min_digit:
		out = "0".repeat(min_digit - digit) + out;
	return out;
