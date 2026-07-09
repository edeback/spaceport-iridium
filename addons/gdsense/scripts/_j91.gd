@tool
class_name _k100
extends RefCounted
signal _r45(session_id: String)
signal _h96(status: Dictionary)
signal _l92(_i6: Array)  
signal _o9(message: String)
signal _a44(error: String)
signal _i57()
signal _d69(session_id: String, message: String)
signal _k43(message: String, _x58: String)  
signal _q1(text: String)  
var _g2: String = ""
var _is_active: bool = false
var _g23: String = ""
var _z70: Timer
var _v92: int = 0
var _m94: float = 1.0
var _m53: HTTPRequest
var _e24: Node
var _r78: _r91  
var _u1: Array = []  
var _z23: Array = []  
var _p86: bool = false  
var _c12: int = 0  
var _m49: Dictionary = {}  
var _r72: int = 0
var _z67: Timer
const _w57: float = 4.0  
const _c52: float = 0.5  
const _e14: int = 8  
const _j32: float = 10.0
const _s89: float = 15.0
const _y20: float = 10.0
func initialize(parent: Node, _a82: _r91) -> void:
	_e24 = parent
	_r78 = _a82
	_z70 = Timer.new()
	_z70.one_shot = false
	_z70.timeout.connect(_n35)
	parent.add_child(_z70)
	_m53 = HTTPRequest.new()
	parent.add_child(_m53)
func _z35(_h1: String, _s45: Dictionary = {}, model: String = "") -> void:
	if _is_active:
		push_error("[AgentModeManager] Agent session already active")
		return
	if not _e24 or not is_instance_valid(_e24):
		_a44.emit("Parent node is not valid")
		return
	var _j85 = _s45.duplicate()
	_j85["file_tree"] = _k40()
	_j85["godot_version"] = Engine.get_version_info()["string"]
	var _x89 = {
		"task_description": _h1,
		"project_context": _j85
	}
	if not model.is_empty():
		_x89["model"] = model
	var _m62 = _t67()
	if _m62.is_empty():
		_a44.emit("No API key configured")
		return
	var _z38 = [
		"Content-Type: application/json",
		"X-API-Key: " + _m62
	]
	if _m53.request_completed.is_connected(_j98):
		_m53.request_completed.disconnect(_j98)
	_m53.request_completed.connect(_j98, CONNECT_ONE_SHOT)
	var _w79 = _b92() + "/agent/start"
	var error = _m53.request(_w79, _z38, HTTPClient.METHOD_POST, JSON.stringify(_x89))
	if error != OK:
		_a44.emit("Failed to start agent session: HTTP request error " + str(error))
func _j98(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray) -> void:
	if _s61 != HTTPRequest.RESULT_SUCCESS:
		_a44.emit("Network error starting agent session")
		return
	var _u18 = _x89.get_string_from_utf8()
	if _j71 == 200:
		var json = JSON.parse_string(_u18)
		if json and json is Dictionary:
			_g2 = json.get("session_id", "")
			if _g2.is_empty():
				_a44.emit("Invalid response: missing session_id")
				return
			_is_active = true
			_p86 = false  
			_v92 = 0
			_m94 = _c52
			_z70.wait_time = _m94
			_z70.start()
			_b16()  
			_r45.emit(_g2)
		else:
			_a44.emit("Invalid JSON response from server")
	elif _j71 == 403:
		var _x73 = "Agent feature requires Pro tier"
		var json = JSON.parse_string(_u18)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_x73 = str(messages[0])
		_a44.emit(_x73)
	elif _j71 == 401:
		_a44.emit("Invalid API key")
	elif _j71 == 429:
		_a44.emit("Rate limit exceeded. Please try again later.")
	else:
		var _x73 = "Failed to start agent: HTTP " + str(_j71)
		var json = JSON.parse_string(_u18)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_x73 = str(messages[0])
		_a44.emit(_x73)
func _n35() -> void:
	if not _is_active or _g2.is_empty():
		return
	if not _e24 or not is_instance_valid(_e24):
		_g60()
		return
	var _m62 = _t67()
	if _m62.is_empty():
		return
	var _z38 = [
		"X-API-Key: " + _m62
	]
	var _p59 = _u75(_j32)
	_p59.request_completed.connect(_v89.bind(_p59))
	var _w79 = _b92() + "/agent/" + _g2 + "/status"
	var error = _p59.request(_w79, _z38, HTTPClient.METHOD_GET)
	if error != OK:
		_p80(_p59)
func _v89(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray, _p59: HTTPRequest) -> void:
	_p80(_p59)
	if _s61 != HTTPRequest.RESULT_SUCCESS or _j71 != 200:
		return
	var _u18 = _x89.get_string_from_utf8()
	var json = JSON.parse_string(_u18)
	if not json or not json is Dictionary:
		return
	_v92 += 1
	if json.has("next_poll_interval_ms"):
		var _n63 = json.get("next_poll_interval_ms", 1000) / 1000.0
		_m94 = clamp(_n63, _c52, _w57)
		_z70.wait_time = _m94
	elif _v92 > _e14:
		_m94 = min(_m94 * 1.2, _w57)
		_z70.wait_time = _m94
	if json.has("quota_warning") and json.get("quota_warning") != null:
		var _h9 = json.get("quota_warning")
		if _h9 is Dictionary and _r78 and is_instance_valid(_r78):
			var _h18 = _h48(_h9.get("severity", "notice"))
			var _y21 = _h9.get("model_group", "credits")
			var _n33 = _h9.get("usage_percentage", 0.0)
			var _x76 = "%s_%s_%d" % [_y21, _h18, int(_n33 / 5) * 5]
			if not _m49.has(_x76):
				_m49[_x76] = true
				_r78._i10.emit(_h18, _y21, _n33, "")
	if json.get("truncation_warning") == true:
		if _r78 and is_instance_valid(_r78):
			if not _m49.has("truncation"):
				_m49["truncation"] = true
				_r78._l16.emit("Response was truncated due to token limit. The output may be incomplete.")
	_h96.emit(json)
	var _m92 = json.get("assistant_message", "")
	if _m92 == null:
		_m92 = ""
	var _s60 = json.get("assistant_reasoning", "")
	if _s60 == null:
		_s60 = ""
	if not _m92.is_empty() or not _s60.is_empty():
		var _f45 = (_m92 + _s60).hash()
		if _f45 != _c12:
			_c12 = _f45
			_k43.emit(_m92, _s60)
	var status = json.get("status", "")
	match status:
		"THINKING", "EXECUTING":
			_u1.clear()
			_z23.clear()
			_m49.erase("truncation")
		"WAITING_TOOL", "WAITING_APPROVAL":
			var _g18: Array = []
			if json.has("pending_tool_calls") and json.get("pending_tool_calls") != null:
				var _j38 = json.get("pending_tool_calls")
				if _j38 is Array:
					for _r19 in _j38:
						if _r19 is Dictionary:
							var _t51 = _r19.get("tool_call_id", "")
							if not _t51.is_empty() and _t51 not in _u1:
								_g18.append(_r19)
								_u1.append(_t51)
			elif json.has("pending_tool_call") and json.get("pending_tool_call") != null:
				var _i65 = json.get("pending_tool_call")
				if _i65 is Dictionary:
					var _t51 = _i65.get("tool_call_id", "")
					if not _t51.is_empty() and _t51 not in _u1:
						_g18.append(_i65)
						_u1.append(_t51)
			if _g18.size() > 0:
				_l92.emit(_g18)
				_v92 = 0
				_m94 = _c52
				_z70.wait_time = _m94
		"COMPLETE":
			if _p86:
				return
			_p86 = true
			_g60()
			_o9.emit("Task completed")
		"FAILED":
			if _p86:
				return
			_p86 = true
			var _x69 = json.get("status_message", "Agent failed") if json.has("status_message") else "Agent failed"
			if _x69 == null:
				_x69 = "Agent failed"
			var _e30 = _g2
			_g60()
			if json.get("can_continue", false):
				_g23 = _e30
				_d69.emit(_e30, _x69)
			else:
				_a44.emit(_x69)
		"CANCELLED":
			if _p86:
				return
			_p86 = true
			_g60()
			_i57.emit()
func _r88(_t51: String, _w53: bool, _s61: Dictionary = {}, _z11: String = "") -> void:
	if not _is_active or _g2.is_empty():
		push_error("[AgentModeManager] Cannot submit tool output: no active session")
		return
	if not _e24 or not is_instance_valid(_e24):
		return
	if _t51 not in _z23:
		_z23.append(_t51)
	var _x89 = {
		"tool_call_id": _t51,
		"approved": _w53,
		"result": _s61,
		"rejection_reason": _z11
	}
	var _m62 = _t67()
	if _m62.is_empty():
		return
	var _z38 = [
		"Content-Type: application/json",
		"X-API-Key: " + _m62
	]
	var _p59 = _u75(_s89)
	_p59.request_completed.connect(_a36.bind(_p59, _t51))
	var _w79 = _b92() + "/agent/" + _g2 + "/tool-output"
	var error = _p59.request(_w79, _z38, HTTPClient.METHOD_POST, JSON.stringify(_x89))
	if error != OK:
		_p80(_p59)
		_z23.erase(_t51)
		_u1.erase(_t51)
func _a36(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray, _p59: HTTPRequest, _t51: String) -> void:
	_p80(_p59)
	if _s61 != HTTPRequest.RESULT_SUCCESS or _j71 != 200:
		_z23.erase(_t51)
		_u1.erase(_t51)
		return
func _x32() -> void:
	if not _is_active or _g2.is_empty():
		return
	if _p86:
		return
	_p86 = true
	if not _e24 or not is_instance_valid(_e24):
		_g60()
		_i57.emit()
		return
	var _m62 = _t67()
	if _m62.is_empty():
		_g60()
		_i57.emit()
		return
	var _z38 = [
		"Content-Type: application/json",
		"X-API-Key: " + _m62
	]
	var _p59 = _u75(_y20)
	_p59.request_completed.connect(func(r, _i11, h, b):
		_p80(_p59)
	)
	var _w79 = _b92() + "/agent/" + _g2 + "/cancel"
	_p59.request(_w79, _z38, HTTPClient.METHOD_POST)
	_g60()
	_i57.emit()
func _m87() -> void:
	if _is_active:
		push_error("[AgentModeManager] Cannot continue - session already active")
		return
	if _g23.is_empty():
		push_error("[AgentModeManager] No continuable session available")
		return
	if not _e24 or not is_instance_valid(_e24):
		_a44.emit("Parent node is not valid")
		return
	var _m62 = _t67()
	if _m62.is_empty():
		_a44.emit("No API key configured")
		return
	var _z38 = [
		"Content-Type: application/json",
		"X-API-Key: " + _m62
	]
	var _p59 = _u75(_j32)
	_p59.request_completed.connect(_a58.bind(_p59))
	var _w79 = _b92() + "/agent/" + _g23 + "/continue"
	var error = _p59.request(_w79, _z38, HTTPClient.METHOD_POST)
	if error != OK:
		_p80(_p59)
		_a44.emit("Failed to continue session: HTTP request error " + str(error))
func _a58(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray, _p59: HTTPRequest) -> void:
	_p80(_p59)
	if _s61 != HTTPRequest.RESULT_SUCCESS:
		_a44.emit("Network error continuing session")
		return
	var _u18 = _x89.get_string_from_utf8()
	if _j71 == 200:
		var json = JSON.parse_string(_u18)
		if json and json is Dictionary:
			var session_id = json.get("session_id", "")
			if session_id.is_empty():
				_a44.emit("Invalid response: missing session_id")
				return
			_g2 = session_id
			_g23 = ""
			_is_active = true
			_p86 = false
			_v92 = 0
			_m94 = _c52
			_z70.wait_time = _m94
			_z70.start()
			_b16()  
			_r45.emit(_g2)
		else:
			_a44.emit("Invalid JSON response from server")
	else:
		var _x73 = "Failed to continue session: HTTP " + str(_j71)
		var json = JSON.parse_string(_u18)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_x73 = str(messages[0])
		_a44.emit(_x73)
func _k45() -> bool:
	return not _g23.is_empty()
func _p91() -> void:
	_g23 = ""
func _g60() -> void:
	if _z70 and is_instance_valid(_z70):
		_z70.stop()
	_g45()  
	_is_active = false
	_g2 = ""
	_v92 = 0
	_m94 = _c52
	_u1.clear()  
	_z23.clear()
	_c12 = 0  
func is_active() -> bool:
	return _is_active
func _f86() -> String:
	return _g2
func _q5() -> int:
	return _v92
func _t67() -> String:
	if _r78 and is_instance_valid(_r78):
		return _r78._a37()
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", "production", config.get_value("plugin", "api_key", ""))
	return ""
func _b92() -> String:
	if _r78 and is_instance_valid(_r78):
		return _r78._p53()
	return "https://api.gdsense.com/api/v1"
func _u75(_a1: float) -> HTTPRequest:
	var _p59 = HTTPRequest.new()
	_e24.add_child(_p59)
	var _r41 = Timer.new()
	_r41.wait_time = _a1
	_r41.one_shot = true
	_r41.timeout.connect(func():
		if is_instance_valid(_p59):
			_p59.cancel_request()
			_p59.queue_free()
		if is_instance_valid(_r41):
			_r41.queue_free()
	)
	_e24.add_child(_r41)
	_r41.start()
	_p59.set_meta("timeout_timer", _r41)
	return _p59
func _p80(_p59: HTTPRequest) -> void:
	if not is_instance_valid(_p59):
		return
	if _p59.has_meta("timeout_timer"):
		var _q65 = _p59.get_meta("timeout_timer")
		if is_instance_valid(_q65):
			_q65.stop()
			_q65.queue_free()
	_p59.queue_free()
func _k40() -> String:
	var _e22: Array = ["Project Structure:", "res://"]
	_y24("res://", _e22, 1, 3)
	return "\n".join(_e22)
func _u44(_y38: String, _h5: int) -> bool:
	if _y38.begins_with("."):
		return false
	if _y38 == "addons":
		return false
	return true
func _y24(path: String, _t70: Array, depth: int, _m42: int) -> void:
	if depth > _m42:
		return
	var _d5 = DirAccess.open(path)
	if _d5 == null:
		return
	_d5.list_dir_begin()
	var _y38 = _d5.get_next()
	var indent = "  ".repeat(depth)
	var _h63: Array = []
	var _s82: Array = []
	while _y38 != "":
		if _u44(_y38, depth):
			if _d5.current_is_dir():
				_h63.append(_y38)
			else:
				if _z15(_y38):
					_s82.append(_y38)
		_y38 = _d5.get_next()
	_d5.list_dir_end()
	_h63.sort()
	_s82.sort()
	for _p60 in _h63:
		_t70.append(indent + "|-- " + _p60 + "/")
		var full_path = path.path_join(_p60)
		_y24(full_path, _t70, depth + 1, _m42)
	for file in _s82:
		_t70.append(indent + "|-- " + file)
func _z15(_y38: String) -> bool:
	var _b62 = _y38.get_extension().to_lower()
	var _a71 = ["gd", "tscn", "tres", "cfg", "gdshader", "json", "txt", "md"]
	return _b62 in _a71
func _h48(_i73: String) -> String:
	match _i73.to_lower():
		"notice":
			return "medium"
		"warning":
			return "high"
		"critical", "limit_reached":
			return "critical"
		_:
			return "medium"
func _o36() -> void:
	_g60()
	_g45()
	if _z70 and is_instance_valid(_z70):
		_z70.queue_free()
		_z70 = null
	if _m53 and is_instance_valid(_m53):
		_m53.queue_free()
		_m53 = null
	_e24 = null
	_r78 = null
func _b16() -> void:
	if _z67 and is_instance_valid(_z67):
		return  
	if not _e24 or not is_instance_valid(_e24):
		return
	_r72 = 0
	_z67 = Timer.new()
	_z67.wait_time = 0.5
	_z67.one_shot = false
	_z67.timeout.connect(_a62)
	_e24.add_child(_z67)
	_z67.start()
	_g92()
func _a62() -> void:
	_r72 = (_r72 + 1) % 4
	_g92()
func _g92() -> void:
	var _g53 = _r72 if _r72 > 0 else 1
	var _q88 = ".".repeat(_g53)
	_q1.emit("Thinking" + _q88)
func _g45() -> void:
	if _z67 and is_instance_valid(_z67):
		_z67.stop()
		_z67.queue_free()
		_z67 = null
	_r72 = 0
