@tool
class_name _p75
extends RefCounted
signal _c27(session_id: String)
signal _o43(status: Dictionary)
signal _y48(_t12: Array)  
signal _u69(message: String)
signal _f97(error: String)
signal _k49()
signal _f50(session_id: String, message: String)
signal _d90(message: String, _g2: String)  
signal _v57(text: String)  
var _y3: String = ""
var _is_active: bool = false
var _e80: String = ""
var _q23: Timer
var _d33: int = 0
var _t62: float = 1.0
var _x95: HTTPRequest
var _d21: Node
var _i24: _a99  
var _e41: Array = []  
var _v61: Array = []  
var _k67: bool = false  
var _j37: int = 0  
var _u36: Dictionary = {}  
var _o46: int = 0
var _z20: Timer
const _u1: float = 4.0  
const _z39: float = 0.5  
const _u32: int = 8  
const _x40: float = 10.0
const _y27: float = 15.0
const _k42: float = 10.0
func initialize(parent: Node, _d19: _a99) -> void:
	_d21 = parent
	_i24 = _d19
	_q23 = Timer.new()
	_q23.one_shot = false
	_q23.timeout.connect(_w34)
	parent.add_child(_q23)
	_x95 = HTTPRequest.new()
	parent.add_child(_x95)
func _h22(_y88: String, _r97: Dictionary = {}, model: String = "") -> void:
	if _is_active:
		push_error("[AgentModeManager] Agent session already active")
		return
	if not _d21 or not is_instance_valid(_d21):
		_f97.emit("Parent node is not valid")
		return
	var _v9 = _r97.duplicate()
	_v9["file_tree"] = _f16()
	_v9["godot_version"] = Engine.get_version_info()["string"]
	var _v73 = {
		"task_description": _y88,
		"project_context": _v9
	}
	if not model.is_empty():
		_v73["model"] = model
	var _w88 = _x39()
	if _w88.is_empty():
		_f97.emit("No API key configured")
		return
	var _p18 = [
		"Content-Type: application/json",
		"X-API-Key: " + _w88
	]
	if _x95.request_completed.is_connected(_f42):
		_x95.request_completed.disconnect(_f42)
	_x95.request_completed.connect(_f42, CONNECT_ONE_SHOT)
	var _f56 = _u55() + "/agent/start"
	var error = _x95.request(_f56, _p18, HTTPClient.METHOD_POST, JSON.stringify(_v73))
	if error != OK:
		_f97.emit("Failed to start agent session: HTTP request error " + str(error))
func _f42(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray) -> void:
	if _n37 != HTTPRequest.RESULT_SUCCESS:
		_f97.emit("Network error starting agent session")
		return
	var _p100 = _v73.get_string_from_utf8()
	if _a6 == 200:
		var json = JSON.parse_string(_p100)
		if json and json is Dictionary:
			_y3 = json.get("session_id", "")
			if _y3.is_empty():
				_f97.emit("Invalid response: missing session_id")
				return
			_is_active = true
			_k67 = false  
			_d33 = 0
			_t62 = _z39
			_q23.wait_time = _t62
			_q23.start()
			_q88()  
			_c27.emit(_y3)
		else:
			_f97.emit("Invalid JSON response from server")
	elif _a6 == 403:
		var _w11 = "Agent feature requires Pro tier"
		var json = JSON.parse_string(_p100)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_w11 = str(messages[0])
		_f97.emit(_w11)
	elif _a6 == 401:
		_f97.emit("Invalid API key")
	elif _a6 == 429:
		_f97.emit("Rate limit exceeded. Please try again later.")
	else:
		var _w11 = "Failed to start agent: HTTP " + str(_a6)
		var json = JSON.parse_string(_p100)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_w11 = str(messages[0])
		_f97.emit(_w11)
func _w34() -> void:
	if not _is_active or _y3.is_empty():
		return
	if not _d21 or not is_instance_valid(_d21):
		_d84()
		return
	var _w88 = _x39()
	if _w88.is_empty():
		return
	var _p18 = [
		"X-API-Key: " + _w88
	]
	var _b25 = _r49(_x40)
	_b25.request_completed.connect(_l60.bind(_b25))
	var _f56 = _u55() + "/agent/" + _y3 + "/status"
	var error = _b25.request(_f56, _p18, HTTPClient.METHOD_GET)
	if error != OK:
		_t32(_b25)
func _l60(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray, _b25: HTTPRequest) -> void:
	_t32(_b25)
	if _n37 != HTTPRequest.RESULT_SUCCESS or _a6 != 200:
		return
	var _p100 = _v73.get_string_from_utf8()
	var json = JSON.parse_string(_p100)
	if not json or not json is Dictionary:
		return
	_d33 += 1
	if json.has("next_poll_interval_ms"):
		var _j17 = json.get("next_poll_interval_ms", 1000) / 1000.0
		_t62 = clamp(_j17, _z39, _u1)
		_q23.wait_time = _t62
	elif _d33 > _u32:
		_t62 = min(_t62 * 1.2, _u1)
		_q23.wait_time = _t62
	if json.has("quota_warning") and json.get("quota_warning") != null:
		var _h33 = json.get("quota_warning")
		if _h33 is Dictionary and _i24 and is_instance_valid(_i24):
			var _l66 = _q83(_h33.get("severity", "notice"))
			var _r94 = _h33.get("model_group", "credits")
			var _p85 = _h33.get("usage_percentage", 0.0)
			var _x98 = "%s_%s_%d" % [_r94, _l66, int(_p85 / 5) * 5]
			if not _u36.has(_x98):
				_u36[_x98] = true
				_i24._f67.emit(_l66, _r94, _p85, "")
	if json.get("truncation_warning") == true:
		if _i24 and is_instance_valid(_i24):
			if not _u36.has("truncation"):
				_u36["truncation"] = true
				_i24._c79.emit("Response was truncated due to token limit. The output may be incomplete.")
	_o43.emit(json)
	var _v66 = json.get("assistant_message", "")
	if _v66 == null:
		_v66 = ""
	var _c30 = json.get("assistant_reasoning", "")
	if _c30 == null:
		_c30 = ""
	if not _v66.is_empty() or not _c30.is_empty():
		var _z35 = (_v66 + _c30).hash()
		if _z35 != _j37:
			_j37 = _z35
			_d90.emit(_v66, _c30)
	var status = json.get("status", "")
	match status:
		"THINKING", "EXECUTING":
			_e41.clear()
			_v61.clear()
			_u36.erase("truncation")
		"WAITING_TOOL", "WAITING_APPROVAL":
			var _f70: Array = []
			if json.has("pending_tool_calls") and json.get("pending_tool_calls") != null:
				var _q15 = json.get("pending_tool_calls")
				if _q15 is Array:
					for _r61 in _q15:
						if _r61 is Dictionary:
							var _k66 = _r61.get("tool_call_id", "")
							if not _k66.is_empty() and _k66 not in _e41:
								_f70.append(_r61)
								_e41.append(_k66)
			elif json.has("pending_tool_call") and json.get("pending_tool_call") != null:
				var _n66 = json.get("pending_tool_call")
				if _n66 is Dictionary:
					var _k66 = _n66.get("tool_call_id", "")
					if not _k66.is_empty() and _k66 not in _e41:
						_f70.append(_n66)
						_e41.append(_k66)
			if _f70.size() > 0:
				_y48.emit(_f70)
				_d33 = 0
				_t62 = _z39
				_q23.wait_time = _t62
		"COMPLETE":
			if _k67:
				return
			_k67 = true
			_d84()
			_u69.emit("Task completed")
		"FAILED":
			if _k67:
				return
			_k67 = true
			var _y94 = json.get("status_message", "Agent failed") if json.has("status_message") else "Agent failed"
			if _y94 == null:
				_y94 = "Agent failed"
			var _a44 = _y3
			_d84()
			if json.get("can_continue", false):
				_e80 = _a44
				_f50.emit(_a44, _y94)
			else:
				_f97.emit(_y94)
		"CANCELLED":
			if _k67:
				return
			_k67 = true
			_d84()
			_k49.emit()
func _g26(_k66: String, _l43: bool, _n37: Dictionary = {}, _q32: String = "") -> void:
	if not _is_active or _y3.is_empty():
		push_error("[AgentModeManager] Cannot submit tool output: no active session")
		return
	if not _d21 or not is_instance_valid(_d21):
		return
	if _k66 not in _v61:
		_v61.append(_k66)
	var _v73 = {
		"tool_call_id": _k66,
		"approved": _l43,
		"result": _n37,
		"rejection_reason": _q32
	}
	var _w88 = _x39()
	if _w88.is_empty():
		return
	var _p18 = [
		"Content-Type: application/json",
		"X-API-Key: " + _w88
	]
	var _b25 = _r49(_y27)
	_b25.request_completed.connect(_f25.bind(_b25, _k66))
	var _f56 = _u55() + "/agent/" + _y3 + "/tool-output"
	var error = _b25.request(_f56, _p18, HTTPClient.METHOD_POST, JSON.stringify(_v73))
	if error != OK:
		_t32(_b25)
		_v61.erase(_k66)
		_e41.erase(_k66)
func _f25(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray, _b25: HTTPRequest, _k66: String) -> void:
	_t32(_b25)
	if _n37 != HTTPRequest.RESULT_SUCCESS or _a6 != 200:
		_v61.erase(_k66)
		_e41.erase(_k66)
		return
func _k45() -> void:
	if not _is_active or _y3.is_empty():
		return
	if _k67:
		return
	_k67 = true
	if not _d21 or not is_instance_valid(_d21):
		_d84()
		_k49.emit()
		return
	var _w88 = _x39()
	if _w88.is_empty():
		_d84()
		_k49.emit()
		return
	var _p18 = [
		"Content-Type: application/json",
		"X-API-Key: " + _w88
	]
	var _b25 = _r49(_k42)
	_b25.request_completed.connect(func(r, _j67, h, b):
		_t32(_b25)
	)
	var _f56 = _u55() + "/agent/" + _y3 + "/cancel"
	_b25.request(_f56, _p18, HTTPClient.METHOD_POST)
	_d84()
	_k49.emit()
func _v8() -> void:
	if _is_active:
		push_error("[AgentModeManager] Cannot continue - session already active")
		return
	if _e80.is_empty():
		push_error("[AgentModeManager] No continuable session available")
		return
	if not _d21 or not is_instance_valid(_d21):
		_f97.emit("Parent node is not valid")
		return
	var _w88 = _x39()
	if _w88.is_empty():
		_f97.emit("No API key configured")
		return
	var _p18 = [
		"Content-Type: application/json",
		"X-API-Key: " + _w88
	]
	var _b25 = _r49(_x40)
	_b25.request_completed.connect(_r3.bind(_b25))
	var _f56 = _u55() + "/agent/" + _e80 + "/continue"
	var error = _b25.request(_f56, _p18, HTTPClient.METHOD_POST)
	if error != OK:
		_t32(_b25)
		_f97.emit("Failed to continue session: HTTP request error " + str(error))
func _r3(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray, _b25: HTTPRequest) -> void:
	_t32(_b25)
	if _n37 != HTTPRequest.RESULT_SUCCESS:
		_f97.emit("Network error continuing session")
		return
	var _p100 = _v73.get_string_from_utf8()
	if _a6 == 200:
		var json = JSON.parse_string(_p100)
		if json and json is Dictionary:
			var session_id = json.get("session_id", "")
			if session_id.is_empty():
				_f97.emit("Invalid response: missing session_id")
				return
			_y3 = session_id
			_e80 = ""
			_is_active = true
			_k67 = false
			_d33 = 0
			_t62 = _z39
			_q23.wait_time = _t62
			_q23.start()
			_q88()  
			_c27.emit(_y3)
		else:
			_f97.emit("Invalid JSON response from server")
	else:
		var _w11 = "Failed to continue session: HTTP " + str(_a6)
		var json = JSON.parse_string(_p100)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_w11 = str(messages[0])
		_f97.emit(_w11)
func _u47() -> bool:
	return not _e80.is_empty()
func _i96() -> void:
	_e80 = ""
func _d84() -> void:
	if _q23 and is_instance_valid(_q23):
		_q23.stop()
	_e50()  
	_is_active = false
	_y3 = ""
	_d33 = 0
	_t62 = _z39
	_e41.clear()  
	_v61.clear()
	_j37 = 0  
func is_active() -> bool:
	return _is_active
func _k70() -> String:
	return _y3
func _z62() -> int:
	return _d33
func _x39() -> String:
	if _i24 and is_instance_valid(_i24):
		return _i24._a82()
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", "production", config.get_value("plugin", "api_key", ""))
	return ""
func _u55() -> String:
	if _i24 and is_instance_valid(_i24):
		return _i24._r18()
	return "https://api.gdsense.com/api/v1"
func _r49(_p79: float) -> HTTPRequest:
	var _b25 = HTTPRequest.new()
	_d21.add_child(_b25)
	var _j71 = Timer.new()
	_j71.wait_time = _p79
	_j71.one_shot = true
	_j71.timeout.connect(func():
		if is_instance_valid(_b25):
			_b25.cancel_request()
			_b25.queue_free()
		if is_instance_valid(_j71):
			_j71.queue_free()
	)
	_d21.add_child(_j71)
	_j71.start()
	_b25.set_meta("timeout_timer", _j71)
	return _b25
func _t32(_b25: HTTPRequest) -> void:
	if not is_instance_valid(_b25):
		return
	if _b25.has_meta("timeout_timer"):
		var _h63 = _b25.get_meta("timeout_timer")
		if is_instance_valid(_h63):
			_h63.stop()
			_h63.queue_free()
	_b25.queue_free()
func _f16() -> String:
	var _t30: Array = ["Project Structure:", "res://"]
	_y62("res://", _t30, 1, 3)
	return "\n".join(_t30)
func _n96(_s80: String, _m59: int) -> bool:
	if _s80.begins_with("."):
		return false
	if _s80 == "addons":
		return false
	return true
func _y62(path: String, _a62: Array, depth: int, _y43: int) -> void:
	if depth > _y43:
		return
	var _e23 = DirAccess.open(path)
	if _e23 == null:
		return
	_e23.list_dir_begin()
	var _s80 = _e23.get_next()
	var indent = "  ".repeat(depth)
	var _f98: Array = []
	var _u72: Array = []
	while _s80 != "":
		if _n96(_s80, depth):
			if _e23.current_is_dir():
				_f98.append(_s80)
			else:
				if _d82(_s80):
					_u72.append(_s80)
		_s80 = _e23.get_next()
	_e23.list_dir_end()
	_f98.sort()
	_u72.sort()
	for _o81 in _f98:
		_a62.append(indent + "|-- " + _o81 + "/")
		var full_path = path.path_join(_o81)
		_y62(full_path, _a62, depth + 1, _y43)
	for file in _u72:
		_a62.append(indent + "|-- " + file)
func _d82(_s80: String) -> bool:
	var _p58 = _s80.get_extension().to_lower()
	var _k40 = ["gd", "tscn", "tres", "cfg", "gdshader", "json", "txt", "md"]
	return _p58 in _k40
func _q83(_r71: String) -> String:
	match _r71.to_lower():
		"notice":
			return "medium"
		"warning":
			return "high"
		"critical", "limit_reached":
			return "critical"
		_:
			return "medium"
func _h41() -> void:
	_d84()
	_e50()
	if _q23 and is_instance_valid(_q23):
		_q23.queue_free()
		_q23 = null
	if _x95 and is_instance_valid(_x95):
		_x95.queue_free()
		_x95 = null
	_d21 = null
	_i24 = null
func _q88() -> void:
	if _z20 and is_instance_valid(_z20):
		return  
	if not _d21 or not is_instance_valid(_d21):
		return
	_o46 = 0
	_z20 = Timer.new()
	_z20.wait_time = 0.5
	_z20.one_shot = false
	_z20.timeout.connect(_e77)
	_d21.add_child(_z20)
	_z20.start()
	_c86()
func _e77() -> void:
	_o46 = (_o46 + 1) % 4
	_c86()
func _c86() -> void:
	var _w50 = _o46 if _o46 > 0 else 1
	var _u21 = ".".repeat(_w50)
	_v57.emit("Thinking" + _u21)
func _e50() -> void:
	if _z20 and is_instance_valid(_z20):
		_z20.stop()
		_z20.queue_free()
		_z20 = null
	_o46 = 0
