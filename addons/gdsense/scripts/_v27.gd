@tool
class_name _i29
extends RefCounted
signal _f56(session_id: String)
signal _m28(status: Dictionary)
signal _p31(_j5: Array)  
signal _w3(message: String)
signal _q47(error: String)
signal _n32()
signal _y89(session_id: String, message: String)
signal _x100(message: String, _r80: String)  
signal _s4(text: String)  
var _c25: String = ""
var _is_active: bool = false
var _y37: String = ""
var _s18: Timer
var _y94: int = 0
var _u14: float = 1.0
var _g99: HTTPRequest
var _d19: Node
var _k26: _y57  
var _g32: Array = []  
var _j19: Array = []  
var _p62: bool = false  
var _e91: int = 0  
var _l96: Dictionary = {}  
var _v32: int = 0
var _o10: Timer
const _e37: float = 4.0  
const _f75: float = 0.5  
const _b46: int = 8  
const _j31: float = 10.0
const _j76: float = 15.0
const _m89: float = 10.0
func initialize(parent: Node, _b44: _y57) -> void:
	_d19 = parent
	_k26 = _b44
	_s18 = Timer.new()
	_s18.one_shot = false
	_s18.timeout.connect(_f30)
	parent.add_child(_s18)
	_g99 = HTTPRequest.new()
	parent.add_child(_g99)
func _q77(_u53: String, _u87: Dictionary = {}, model: String = "") -> void:
	if _is_active:
		push_error("[AgentModeManager] Agent session already active")
		return
	if not _d19 or not is_instance_valid(_d19):
		_q47.emit("Parent node is not valid")
		return
	var _j22 = _u87.duplicate()
	_j22["file_tree"] = _c99()
	_j22["godot_version"] = Engine.get_version_info()["string"]
	var _h62 = {
		"task_description": _u53,
		"project_context": _j22
	}
	if not model.is_empty():
		_h62["model"] = model
	var _a62 = _f85()
	if _a62.is_empty():
		_q47.emit("No API key configured")
		return
	var _l42 = [
		"Content-Type: application/json",
		"X-API-Key: " + _a62
	]
	if _g99.request_completed.is_connected(_m59):
		_g99.request_completed.disconnect(_m59)
	_g99.request_completed.connect(_m59, CONNECT_ONE_SHOT)
	var _a28 = _p38() + "/agent/start"
	var error = _g99.request(_a28, _l42, HTTPClient.METHOD_POST, JSON.stringify(_h62))
	if error != OK:
		_q47.emit("Failed to start agent session: HTTP request error " + str(error))
func _m59(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_q47.emit("Network error starting agent session")
		return
	var _w83 = _h62.get_string_from_utf8()
	if _g51 == 200:
		var json = JSON.parse_string(_w83)
		if json and json is Dictionary:
			_c25 = json.get("session_id", "")
			if _c25.is_empty():
				_q47.emit("Invalid response: missing session_id")
				return
			_is_active = true
			_p62 = false  
			_y94 = 0
			_u14 = _f75
			_s18.wait_time = _u14
			_s18.start()
			_r100()  
			_f56.emit(_c25)
		else:
			_q47.emit("Invalid JSON response from server")
	elif _g51 == 403:
		var _q22 = "Agent feature requires Pro tier"
		var json = JSON.parse_string(_w83)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_q22 = str(messages[0])
		_q47.emit(_q22)
	elif _g51 == 401:
		_q47.emit("Invalid API key")
	elif _g51 == 429:
		_q47.emit("Rate limit exceeded. Please try again later.")
	else:
		var _q22 = "Failed to start agent: HTTP " + str(_g51)
		var json = JSON.parse_string(_w83)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_q22 = str(messages[0])
		_q47.emit(_q22)
func _f30() -> void:
	if not _is_active or _c25.is_empty():
		return
	if not _d19 or not is_instance_valid(_d19):
		_g93()
		return
	var _a62 = _f85()
	if _a62.is_empty():
		return
	var _l42 = [
		"X-API-Key: " + _a62
	]
	var _q17 = _r37(_j31)
	_q17.request_completed.connect(_v13.bind(_q17))
	var _a28 = _p38() + "/agent/" + _c25 + "/status"
	var error = _q17.request(_a28, _l42, HTTPClient.METHOD_GET)
	if error != OK:
		_n12(_q17)
func _v13(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray, _q17: HTTPRequest) -> void:
	_n12(_q17)
	if _x97 != HTTPRequest.RESULT_SUCCESS or _g51 != 200:
		return
	var _w83 = _h62.get_string_from_utf8()
	var json = JSON.parse_string(_w83)
	if not json or not json is Dictionary:
		return
	_y94 += 1
	if json.has("next_poll_interval_ms"):
		var _l26 = json.get("next_poll_interval_ms", 1000) / 1000.0
		_u14 = clamp(_l26, _f75, _e37)
		_s18.wait_time = _u14
	elif _y94 > _b46:
		_u14 = min(_u14 * 1.2, _e37)
		_s18.wait_time = _u14
	if json.has("quota_warning") and json.get("quota_warning") != null:
		var _k64 = json.get("quota_warning")
		if _k64 is Dictionary and _k26 and is_instance_valid(_k26):
			var _w39 = _i30(_k64.get("severity", "notice"))
			var _y88 = _k64.get("model_group", "credits")
			var _r27 = _k64.get("usage_percentage", 0.0)
			var _z48 = "%s_%s_%d" % [_y88, _w39, int(_r27 / 5) * 5]
			if not _l96.has(_z48):
				_l96[_z48] = true
				_k26._r2.emit(_w39, _y88, _r27, "")
	if json.get("truncation_warning") == true:
		if _k26 and is_instance_valid(_k26):
			if not _l96.has("truncation"):
				_l96["truncation"] = true
				_k26._j20.emit("Response was truncated due to token limit. The output may be incomplete.")
	_m28.emit(json)
	var _k98 = json.get("assistant_message", "")
	if _k98 == null:
		_k98 = ""
	var _s45 = json.get("assistant_reasoning", "")
	if _s45 == null:
		_s45 = ""
	if not _k98.is_empty() or not _s45.is_empty():
		var _e42 = (_k98 + _s45).hash()
		if _e42 != _e91:
			_e91 = _e42
			_x100.emit(_k98, _s45)
	var status = json.get("status", "")
	match status:
		"THINKING", "EXECUTING":
			_g32.clear()
			_j19.clear()
			_l96.erase("truncation")
		"WAITING_TOOL", "WAITING_APPROVAL":
			var _t67: Array = []
			if json.has("pending_tool_calls") and json.get("pending_tool_calls") != null:
				var _t14 = json.get("pending_tool_calls")
				if _t14 is Array:
					for _q89 in _t14:
						if _q89 is Dictionary:
							var _n3 = _q89.get("tool_call_id", "")
							if not _n3.is_empty() and _n3 not in _g32:
								_t67.append(_q89)
								_g32.append(_n3)
			elif json.has("pending_tool_call") and json.get("pending_tool_call") != null:
				var _o5 = json.get("pending_tool_call")
				if _o5 is Dictionary:
					var _n3 = _o5.get("tool_call_id", "")
					if not _n3.is_empty() and _n3 not in _g32:
						_t67.append(_o5)
						_g32.append(_n3)
			if _t67.size() > 0:
				_p31.emit(_t67)
				_y94 = 0
				_u14 = _f75
				_s18.wait_time = _u14
		"COMPLETE":
			if _p62:
				return
			_p62 = true
			_g93()
			_w3.emit("Task completed")
		"FAILED":
			if _p62:
				return
			_p62 = true
			var _b96 = json.get("status_message", "Agent failed") if json.has("status_message") else "Agent failed"
			if _b96 == null:
				_b96 = "Agent failed"
			var _h27 = _c25
			_g93()
			if json.get("can_continue", false):
				_y37 = _h27
				_y89.emit(_h27, _b96)
			else:
				_q47.emit(_b96)
		"CANCELLED":
			if _p62:
				return
			_p62 = true
			_g93()
			_n32.emit()
func _e59(_n3: String, _d45: bool, _x97: Dictionary = {}, _v97: String = "") -> void:
	if not _is_active or _c25.is_empty():
		push_error("[AgentModeManager] Cannot submit tool output: no active session")
		return
	if not _d19 or not is_instance_valid(_d19):
		return
	if _n3 not in _j19:
		_j19.append(_n3)
	var _h62 = {
		"tool_call_id": _n3,
		"approved": _d45,
		"result": _x97,
		"rejection_reason": _v97
	}
	var _a62 = _f85()
	if _a62.is_empty():
		return
	var _l42 = [
		"Content-Type: application/json",
		"X-API-Key: " + _a62
	]
	var _q17 = _r37(_j76)
	_q17.request_completed.connect(_s41.bind(_q17, _n3))
	var _a28 = _p38() + "/agent/" + _c25 + "/tool-output"
	var error = _q17.request(_a28, _l42, HTTPClient.METHOD_POST, JSON.stringify(_h62))
	if error != OK:
		_n12(_q17)
		_j19.erase(_n3)
		_g32.erase(_n3)
func _s41(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray, _q17: HTTPRequest, _n3: String) -> void:
	_n12(_q17)
	if _x97 != HTTPRequest.RESULT_SUCCESS or _g51 != 200:
		_j19.erase(_n3)
		_g32.erase(_n3)
		return
func _o16() -> void:
	if not _is_active or _c25.is_empty():
		return
	if _p62:
		return
	_p62 = true
	if not _d19 or not is_instance_valid(_d19):
		_g93()
		_n32.emit()
		return
	var _a62 = _f85()
	if _a62.is_empty():
		_g93()
		_n32.emit()
		return
	var _l42 = [
		"Content-Type: application/json",
		"X-API-Key: " + _a62
	]
	var _q17 = _r37(_m89)
	_q17.request_completed.connect(func(r, _r78, h, b):
		_n12(_q17)
	)
	var _a28 = _p38() + "/agent/" + _c25 + "/cancel"
	_q17.request(_a28, _l42, HTTPClient.METHOD_POST)
	_g93()
	_n32.emit()
func _r70() -> void:
	if _is_active:
		push_error("[AgentModeManager] Cannot continue - session already active")
		return
	if _y37.is_empty():
		push_error("[AgentModeManager] No continuable session available")
		return
	if not _d19 or not is_instance_valid(_d19):
		_q47.emit("Parent node is not valid")
		return
	var _a62 = _f85()
	if _a62.is_empty():
		_q47.emit("No API key configured")
		return
	var _l42 = [
		"Content-Type: application/json",
		"X-API-Key: " + _a62
	]
	var _q17 = _r37(_j31)
	_q17.request_completed.connect(_u17.bind(_q17))
	var _a28 = _p38() + "/agent/" + _y37 + "/continue"
	var error = _q17.request(_a28, _l42, HTTPClient.METHOD_POST)
	if error != OK:
		_n12(_q17)
		_q47.emit("Failed to continue session: HTTP request error " + str(error))
func _u17(_x97: int, _g51: int, _l42: PackedStringArray, _h62: PackedByteArray, _q17: HTTPRequest) -> void:
	_n12(_q17)
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_q47.emit("Network error continuing session")
		return
	var _w83 = _h62.get_string_from_utf8()
	if _g51 == 200:
		var json = JSON.parse_string(_w83)
		if json and json is Dictionary:
			var session_id = json.get("session_id", "")
			if session_id.is_empty():
				_q47.emit("Invalid response: missing session_id")
				return
			_c25 = session_id
			_y37 = ""
			_is_active = true
			_p62 = false
			_y94 = 0
			_u14 = _f75
			_s18.wait_time = _u14
			_s18.start()
			_r100()  
			_f56.emit(_c25)
		else:
			_q47.emit("Invalid JSON response from server")
	else:
		var _q22 = "Failed to continue session: HTTP " + str(_g51)
		var json = JSON.parse_string(_w83)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_q22 = str(messages[0])
		_q47.emit(_q22)
func _v24() -> bool:
	return not _y37.is_empty()
func _a51() -> void:
	_y37 = ""
func _g93() -> void:
	if _s18 and is_instance_valid(_s18):
		_s18.stop()
	_p37()  
	_is_active = false
	_c25 = ""
	_y94 = 0
	_u14 = _f75
	_g32.clear()  
	_j19.clear()
	_e91 = 0  
func is_active() -> bool:
	return _is_active
func _b71() -> String:
	return _c25
func _m93() -> int:
	return _y94
func _f85() -> String:
	if _k26 and is_instance_valid(_k26):
		return _k26._e21()
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", "production", config.get_value("plugin", "api_key", ""))
	return ""
func _p38() -> String:
	if _k26 and is_instance_valid(_k26):
		return _k26._h10()
	return "https://api.gdsense.com/api/v1"
func _r37(_t81: float) -> HTTPRequest:
	var _q17 = HTTPRequest.new()
	_d19.add_child(_q17)
	var _f50 = Timer.new()
	_f50.wait_time = _t81
	_f50.one_shot = true
	_f50.timeout.connect(func():
		if is_instance_valid(_q17):
			_q17.cancel_request()
			_q17.queue_free()
		if is_instance_valid(_f50):
			_f50.queue_free()
	)
	_d19.add_child(_f50)
	_f50.start()
	_q17.set_meta("timeout_timer", _f50)
	return _q17
func _n12(_q17: HTTPRequest) -> void:
	if not is_instance_valid(_q17):
		return
	if _q17.has_meta("timeout_timer"):
		var _e63 = _q17.get_meta("timeout_timer")
		if is_instance_valid(_e63):
			_e63.stop()
			_e63.queue_free()
	_q17.queue_free()
func _c99() -> String:
	var _j11: Array = ["Project Structure:", "res://"]
	_i38("res://", _j11, 1, 3)
	return "\n".join(_j11)
func _b35(_f63: String, _w91: int) -> bool:
	if _f63.begins_with("."):
		return false
	if _f63 == "addons":
		return false
	return true
func _i38(path: String, _j90: Array, depth: int, _z62: int) -> void:
	if depth > _z62:
		return
	var _v15 = DirAccess.open(path)
	if _v15 == null:
		return
	_v15.list_dir_begin()
	var _f63 = _v15.get_next()
	var indent = "  ".repeat(depth)
	var _e20: Array = []
	var _w56: Array = []
	while _f63 != "":
		if _b35(_f63, depth):
			if _v15.current_is_dir():
				_e20.append(_f63)
			else:
				if _r26(_f63):
					_w56.append(_f63)
		_f63 = _v15.get_next()
	_v15.list_dir_end()
	_e20.sort()
	_w56.sort()
	for _b49 in _e20:
		_j90.append(indent + "|-- " + _b49 + "/")
		var full_path = path.path_join(_b49)
		_i38(full_path, _j90, depth + 1, _z62)
	for file in _w56:
		_j90.append(indent + "|-- " + file)
func _r26(_f63: String) -> bool:
	var _h79 = _f63.get_extension().to_lower()
	var _i24 = ["gd", "tscn", "tres", "cfg", "gdshader", "json", "txt", "md"]
	return _h79 in _i24
func _i30(_i56: String) -> String:
	match _i56.to_lower():
		"notice":
			return "medium"
		"warning":
			return "high"
		"critical", "limit_reached":
			return "critical"
		_:
			return "medium"
func _q60() -> void:
	_g93()
	_p37()
	if _s18 and is_instance_valid(_s18):
		_s18.queue_free()
		_s18 = null
	if _g99 and is_instance_valid(_g99):
		_g99.queue_free()
		_g99 = null
	_d19 = null
	_k26 = null
func _r100() -> void:
	if _o10 and is_instance_valid(_o10):
		return  
	if not _d19 or not is_instance_valid(_d19):
		return
	_v32 = 0
	_o10 = Timer.new()
	_o10.wait_time = 0.5
	_o10.one_shot = false
	_o10.timeout.connect(_s71)
	_d19.add_child(_o10)
	_o10.start()
	_e38()
func _s71() -> void:
	_v32 = (_v32 + 1) % 4
	_e38()
func _e38() -> void:
	var _a95 = _v32 if _v32 > 0 else 1
	var _s40 = ".".repeat(_a95)
	_s4.emit("Thinking" + _s40)
func _p37() -> void:
	if _o10 and is_instance_valid(_o10):
		_o10.stop()
		_o10.queue_free()
		_o10 = null
	_v32 = 0
