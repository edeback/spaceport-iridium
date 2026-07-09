@tool
class_name _z35
extends RefCounted
signal _q47(session_id: String)
signal _n50(status: Dictionary)
signal _e91(_p16: Array)  
signal _f28(message: String)
signal _l70(error: String)
signal _d10()
signal _u51(session_id: String, message: String)
signal _n70(message: String, _q11: String)  
signal _g46(text: String)  
var _j16: String = ""
var _is_active: bool = false
var _o80: String = ""
var _m32: Timer
var _m64: int = 0
var _l96: float = 1.0
var _n43: HTTPRequest
var _p42: Node
var _x34: _p17  
var _h44: Array = []  
var _r78: Array = []  
var _p92: bool = false  
var _b92: int = 0  
var _c26: Dictionary = {}  
var _t89: int = 0
var _r21: Timer
const _t34: float = 4.0  
const _m45: float = 0.5  
const _v15: int = 8  
const _u94: float = 10.0
const _x68: float = 15.0
const _w41: float = 10.0
func initialize(parent: Node, _v55: _p17) -> void:
	_p42 = parent
	_x34 = _v55
	_m32 = Timer.new()
	_m32.one_shot = false
	_m32.timeout.connect(_g55)
	parent.add_child(_m32)
	_n43 = HTTPRequest.new()
	parent.add_child(_n43)
func _j52(_q65: String, _p44: Dictionary = {}, model: String = "") -> void:
	if _is_active:
		push_error("[AgentModeManager] Agent session already active")
		return
	if not _p42 or not is_instance_valid(_p42):
		_l70.emit("Parent node is not valid")
		return
	var _x95 = _p44.duplicate()
	_x95["file_tree"] = _j1()
	_x95["godot_version"] = Engine.get_version_info()["string"]
	var _r63 = {
		"task_description": _q65,
		"project_context": _x95
	}
	if not model.is_empty():
		_r63["model"] = model
	var _u10 = _r26()
	if _u10.is_empty():
		_l70.emit("No API key configured")
		return
	var _x35 = [
		"Content-Type: application/json",
		"X-API-Key: " + _u10
	]
	if _n43.request_completed.is_connected(_e36):
		_n43.request_completed.disconnect(_e36)
	_n43.request_completed.connect(_e36, CONNECT_ONE_SHOT)
	var _p8 = _s52() + "/agent/start"
	var error = _n43.request(_p8, _x35, HTTPClient.METHOD_POST, JSON.stringify(_r63))
	if error != OK:
		_l70.emit("Failed to start agent session: HTTP request error " + str(error))
func _e36(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray) -> void:
	if _e21 != HTTPRequest.RESULT_SUCCESS:
		_l70.emit("Network error starting agent session")
		return
	var _b72 = _r63.get_string_from_utf8()
	if _j100 == 200:
		var json = JSON.parse_string(_b72)
		if json and json is Dictionary:
			_j16 = json.get("session_id", "")
			if _j16.is_empty():
				_l70.emit("Invalid response: missing session_id")
				return
			_is_active = true
			_p92 = false  
			_m64 = 0
			_l96 = _m45
			_m32.wait_time = _l96
			_m32.start()
			_v79()  
			_q47.emit(_j16)
		else:
			_l70.emit("Invalid JSON response from server")
	elif _j100 == 403:
		var _u39 = "Agent feature requires Pro tier"
		var json = JSON.parse_string(_b72)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_u39 = str(messages[0])
		_l70.emit(_u39)
	elif _j100 == 401:
		_l70.emit("Invalid API key")
	elif _j100 == 429:
		_l70.emit("Rate limit exceeded. Please try again later.")
	else:
		var _u39 = "Failed to start agent: HTTP " + str(_j100)
		var json = JSON.parse_string(_b72)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_u39 = str(messages[0])
		_l70.emit(_u39)
func _g55() -> void:
	if not _is_active or _j16.is_empty():
		return
	if not _p42 or not is_instance_valid(_p42):
		_d63()
		return
	var _u10 = _r26()
	if _u10.is_empty():
		return
	var _x35 = [
		"X-API-Key: " + _u10
	]
	var _c34 = _t82(_u94)
	_c34.request_completed.connect(_h43.bind(_c34))
	var _p8 = _s52() + "/agent/" + _j16 + "/status"
	var error = _c34.request(_p8, _x35, HTTPClient.METHOD_GET)
	if error != OK:
		_t84(_c34)
func _h43(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray, _c34: HTTPRequest) -> void:
	_t84(_c34)
	if _e21 != HTTPRequest.RESULT_SUCCESS or _j100 != 200:
		return
	var _b72 = _r63.get_string_from_utf8()
	var json = JSON.parse_string(_b72)
	if not json or not json is Dictionary:
		return
	_m64 += 1
	if json.has("next_poll_interval_ms"):
		var _n37 = json.get("next_poll_interval_ms", 1000) / 1000.0
		_l96 = clamp(_n37, _m45, _t34)
		_m32.wait_time = _l96
	elif _m64 > _v15:
		_l96 = min(_l96 * 1.2, _t34)
		_m32.wait_time = _l96
	if json.has("quota_warning") and json.get("quota_warning") != null:
		var _f29 = json.get("quota_warning")
		if _f29 is Dictionary and _x34 and is_instance_valid(_x34):
			var _e30 = _f48(_f29.get("severity", "notice"))
			var _i61 = _f29.get("model_group", "credits")
			var _d51 = _f29.get("usage_percentage", 0.0)
			var _y84 = "%s_%s_%d" % [_i61, _e30, int(_d51 / 5) * 5]
			if not _c26.has(_y84):
				_c26[_y84] = true
				_x34._m5.emit(_e30, _i61, _d51, "")
	if json.get("truncation_warning") == true:
		if _x34 and is_instance_valid(_x34):
			if not _c26.has("truncation"):
				_c26["truncation"] = true
				_x34._u64.emit("Response was truncated due to token limit. The output may be incomplete.")
	_n50.emit(json)
	var _z38 = json.get("assistant_message", "")
	if _z38 == null:
		_z38 = ""
	var _h81 = json.get("assistant_reasoning", "")
	if _h81 == null:
		_h81 = ""
	if not _z38.is_empty() or not _h81.is_empty():
		var _p47 = (_z38 + _h81).hash()
		if _p47 != _b92:
			_b92 = _p47
			_n70.emit(_z38, _h81)
	var status = json.get("status", "")
	match status:
		"THINKING", "EXECUTING":
			_h44.clear()
			_r78.clear()
			_c26.erase("truncation")
		"WAITING_TOOL", "WAITING_APPROVAL":
			var _y74: Array = []
			if json.has("pending_tool_calls") and json.get("pending_tool_calls") != null:
				var _e100 = json.get("pending_tool_calls")
				if _e100 is Array:
					for _i82 in _e100:
						if _i82 is Dictionary:
							var _j74 = _i82.get("tool_call_id", "")
							if not _j74.is_empty() and _j74 not in _h44:
								_y74.append(_i82)
								_h44.append(_j74)
			elif json.has("pending_tool_call") and json.get("pending_tool_call") != null:
				var _a84 = json.get("pending_tool_call")
				if _a84 is Dictionary:
					var _j74 = _a84.get("tool_call_id", "")
					if not _j74.is_empty() and _j74 not in _h44:
						_y74.append(_a84)
						_h44.append(_j74)
			if _y74.size() > 0:
				_e91.emit(_y74)
				_m64 = 0
				_l96 = _m45
				_m32.wait_time = _l96
		"COMPLETE":
			if _p92:
				return
			_p92 = true
			_d63()
			_f28.emit("Task completed")
		"FAILED":
			if _p92:
				return
			_p92 = true
			var _t90 = json.get("status_message", "Agent failed") if json.has("status_message") else "Agent failed"
			if _t90 == null:
				_t90 = "Agent failed"
			var _q99 = _j16
			_d63()
			if json.get("can_continue", false):
				_o80 = _q99
				_u51.emit(_q99, _t90)
			else:
				_l70.emit(_t90)
		"CANCELLED":
			if _p92:
				return
			_p92 = true
			_d63()
			_d10.emit()
func _e81(_j74: String, _s24: bool, _e21: Dictionary = {}, _d29: String = "") -> void:
	if not _is_active or _j16.is_empty():
		push_error("[AgentModeManager] Cannot submit tool output: no active session")
		return
	if not _p42 or not is_instance_valid(_p42):
		return
	if _j74 not in _r78:
		_r78.append(_j74)
	var _r63 = {
		"tool_call_id": _j74,
		"approved": _s24,
		"result": _e21,
		"rejection_reason": _d29
	}
	var _u10 = _r26()
	if _u10.is_empty():
		return
	var _x35 = [
		"Content-Type: application/json",
		"X-API-Key: " + _u10
	]
	var _c34 = _t82(_x68)
	_c34.request_completed.connect(_l50.bind(_c34, _j74))
	var _p8 = _s52() + "/agent/" + _j16 + "/tool-output"
	var error = _c34.request(_p8, _x35, HTTPClient.METHOD_POST, JSON.stringify(_r63))
	if error != OK:
		_t84(_c34)
		_r78.erase(_j74)
		_h44.erase(_j74)
func _l50(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray, _c34: HTTPRequest, _j74: String) -> void:
	_t84(_c34)
	if _e21 != HTTPRequest.RESULT_SUCCESS or _j100 != 200:
		_r78.erase(_j74)
		_h44.erase(_j74)
		return
func _v44() -> void:
	if not _is_active or _j16.is_empty():
		return
	if _p92:
		return
	_p92 = true
	if not _p42 or not is_instance_valid(_p42):
		_d63()
		_d10.emit()
		return
	var _u10 = _r26()
	if _u10.is_empty():
		_d63()
		_d10.emit()
		return
	var _x35 = [
		"Content-Type: application/json",
		"X-API-Key: " + _u10
	]
	var _c34 = _t82(_w41)
	_c34.request_completed.connect(func(r, _k22, h, b):
		_t84(_c34)
	)
	var _p8 = _s52() + "/agent/" + _j16 + "/cancel"
	_c34.request(_p8, _x35, HTTPClient.METHOD_POST)
	_d63()
	_d10.emit()
func _y83() -> void:
	if _is_active:
		push_error("[AgentModeManager] Cannot continue - session already active")
		return
	if _o80.is_empty():
		push_error("[AgentModeManager] No continuable session available")
		return
	if not _p42 or not is_instance_valid(_p42):
		_l70.emit("Parent node is not valid")
		return
	var _u10 = _r26()
	if _u10.is_empty():
		_l70.emit("No API key configured")
		return
	var _x35 = [
		"Content-Type: application/json",
		"X-API-Key: " + _u10
	]
	var _c34 = _t82(_u94)
	_c34.request_completed.connect(_j22.bind(_c34))
	var _p8 = _s52() + "/agent/" + _o80 + "/continue"
	var error = _c34.request(_p8, _x35, HTTPClient.METHOD_POST)
	if error != OK:
		_t84(_c34)
		_l70.emit("Failed to continue session: HTTP request error " + str(error))
func _j22(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray, _c34: HTTPRequest) -> void:
	_t84(_c34)
	if _e21 != HTTPRequest.RESULT_SUCCESS:
		_l70.emit("Network error continuing session")
		return
	var _b72 = _r63.get_string_from_utf8()
	if _j100 == 200:
		var json = JSON.parse_string(_b72)
		if json and json is Dictionary:
			var session_id = json.get("session_id", "")
			if session_id.is_empty():
				_l70.emit("Invalid response: missing session_id")
				return
			_j16 = session_id
			_o80 = ""
			_is_active = true
			_p92 = false
			_m64 = 0
			_l96 = _m45
			_m32.wait_time = _l96
			_m32.start()
			_v79()  
			_q47.emit(_j16)
		else:
			_l70.emit("Invalid JSON response from server")
	else:
		var _u39 = "Failed to continue session: HTTP " + str(_j100)
		var json = JSON.parse_string(_b72)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_u39 = str(messages[0])
		_l70.emit(_u39)
func _d77() -> bool:
	return not _o80.is_empty()
func _o50() -> void:
	_o80 = ""
func _d63() -> void:
	if _m32 and is_instance_valid(_m32):
		_m32.stop()
	_c11()  
	_is_active = false
	_j16 = ""
	_m64 = 0
	_l96 = _m45
	_h44.clear()  
	_r78.clear()
	_b92 = 0  
func is_active() -> bool:
	return _is_active
func _s16() -> String:
	return _j16
func _r38() -> int:
	return _m64
func _r26() -> String:
	if _x34 and is_instance_valid(_x34):
		return _x34._a77()
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", "production", config.get_value("plugin", "api_key", ""))
	return ""
func _s52() -> String:
	if _x34 and is_instance_valid(_x34):
		return _x34._o51()
	return "https://api.gdsense.com/api/v1"
func _t82(_g41: float) -> HTTPRequest:
	var _c34 = HTTPRequest.new()
	_p42.add_child(_c34)
	var _u63 = Timer.new()
	_u63.wait_time = _g41
	_u63.one_shot = true
	_u63.timeout.connect(func():
		if is_instance_valid(_c34):
			_c34.cancel_request()
			_c34.queue_free()
		if is_instance_valid(_u63):
			_u63.queue_free()
	)
	_p42.add_child(_u63)
	_u63.start()
	_c34.set_meta("timeout_timer", _u63)
	return _c34
func _t84(_c34: HTTPRequest) -> void:
	if not is_instance_valid(_c34):
		return
	if _c34.has_meta("timeout_timer"):
		var _e34 = _c34.get_meta("timeout_timer")
		if is_instance_valid(_e34):
			_e34.stop()
			_e34.queue_free()
	_c34.queue_free()
func _j1() -> String:
	var _y29: Array = ["Project Structure:", "res://"]
	_o56("res://", _y29, 1, 3)
	return "\n".join(_y29)
func _k14(_g95: String, _o44: int) -> bool:
	if _g95.begins_with("."):
		return false
	if _g95 == "addons":
		return false
	return true
func _o56(path: String, _p91: Array, depth: int, _p1: int) -> void:
	if depth > _p1:
		return
	var _b57 = DirAccess.open(path)
	if _b57 == null:
		return
	_b57.list_dir_begin()
	var _g95 = _b57.get_next()
	var indent = "  ".repeat(depth)
	var _v94: Array = []
	var _q72: Array = []
	while _g95 != "":
		if _k14(_g95, depth):
			if _b57.current_is_dir():
				_v94.append(_g95)
			else:
				if _v89(_g95):
					_q72.append(_g95)
		_g95 = _b57.get_next()
	_b57.list_dir_end()
	_v94.sort()
	_q72.sort()
	for _x30 in _v94:
		_p91.append(indent + "|-- " + _x30 + "/")
		var full_path = path.path_join(_x30)
		_o56(full_path, _p91, depth + 1, _p1)
	for file in _q72:
		_p91.append(indent + "|-- " + file)
func _v89(_g95: String) -> bool:
	var _x85 = _g95.get_extension().to_lower()
	var _s73 = ["gd", "tscn", "tres", "cfg", "gdshader", "json", "txt", "md"]
	return _x85 in _s73
func _f48(_z44: String) -> String:
	match _z44.to_lower():
		"notice":
			return "medium"
		"warning":
			return "high"
		"critical", "limit_reached":
			return "critical"
		_:
			return "medium"
func _u75() -> void:
	_d63()
	_c11()
	if _m32 and is_instance_valid(_m32):
		_m32.queue_free()
		_m32 = null
	if _n43 and is_instance_valid(_n43):
		_n43.queue_free()
		_n43 = null
	_p42 = null
	_x34 = null
func _v79() -> void:
	if _r21 and is_instance_valid(_r21):
		return  
	if not _p42 or not is_instance_valid(_p42):
		return
	_t89 = 0
	_r21 = Timer.new()
	_r21.wait_time = 0.5
	_r21.one_shot = false
	_r21.timeout.connect(_w1)
	_p42.add_child(_r21)
	_r21.start()
	_x82()
func _w1() -> void:
	_t89 = (_t89 + 1) % 4
	_x82()
func _x82() -> void:
	var _m57 = _t89 if _t89 > 0 else 1
	var _z46 = ".".repeat(_m57)
	_g46.emit("Thinking" + _z46)
func _c11() -> void:
	if _r21 and is_instance_valid(_r21):
		_r21.stop()
		_r21.queue_free()
		_r21 = null
	_t89 = 0
