@tool
class_name _r100
extends RefCounted

signal _z89(session_id: String)
signal _t76(status: Dictionary)
signal _p61(_n46: Array)  
signal _x69(message: String)
signal _l88(error: String)
signal _r83()
signal _s92(session_id: String, message: String)
signal _h40(message: String, _k49: String)  
signal _i94(text: String)  

var _o90: String = ""
var _is_active: bool = false
var _o47: String = ""
var _s18: Timer
var _h84: int = 0
var _c100: float = 1.0
var _q76: HTTPRequest
var _u61: Node
var _a12: _w70  
var _h21: Array = []  
var _v43: Array = []  
var _n82: bool = false  
var _r37: int = 0  
var _v90: Dictionary = {}  

var _x55: int = 0
var _e67: Timer

const _m18: float = 4.0  
const _l75: float = 0.5  
const _u33: int = 8  

const _q59: float = 10.0
const _i44: float = 15.0
const _l83: float = 10.0

func initialize(parent: Node, _b4: _w70) -> void:
	_u61 = parent
	_a12 = _b4

	_s18 = Timer.new()
	_s18.one_shot = false
	_s18.timeout.connect(_y44)
	parent.add_child(_s18)

	_q76 = HTTPRequest.new()
	parent.add_child(_q76)

func _b100(_r74: String, _e76: Dictionary = {}, model: String = "") -> void:
	if _is_active:
		push_error("[AgentModeManager] Agent session already active")
		return

	if not _u61 or not is_instance_valid(_u61):
		_l88.emit("Parent node is not valid")
		return

	var _v15 = _e76.duplicate()
	_v15["file_tree"] = _p9()
	_v15["godot_version"] = Engine.get_version_info()["string"]

	var _r16 = {
		"task_description": _r74,
		"project_context": _v15
	}

	if not model.is_empty():
		_r16["model"] = model

	var _t56 = _w44()
	if _t56.is_empty():
		_l88.emit("No API key configured")
		return

	var _n38 = [
		"Content-Type: application/json",
		"X-API-Key: " + _t56
	]

	if _q76.request_completed.is_connected(_w97):
		_q76.request_completed.disconnect(_w97)
	_q76.request_completed.connect(_w97, CONNECT_ONE_SHOT)

	var _p12 = _i62() + "/agent/start"
	var error = _q76.request(_p12, _n38, HTTPClient.METHOD_POST, JSON.stringify(_r16))

	if error != OK:
		_l88.emit("Failed to start agent session: HTTP request error " + str(error))

func _w97(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray) -> void:
	if _k3 != HTTPRequest.RESULT_SUCCESS:
		_l88.emit("Network error starting agent session")
		return

	var _s93 = _r16.get_string_from_utf8()

	if _s65 == 200:
		var json = JSON.parse_string(_s93)
		if json and json is Dictionary:
			_o90 = json.get("session_id", "")
			if _o90.is_empty():
				_l88.emit("Invalid response: missing session_id")
				return

			_is_active = true
			_n82 = false  
			_h84 = 0
			_c100 = _l75
			_s18.wait_time = _c100
			_s18.start()
			_v83()  
			_z89.emit(_o90)

		else:
			_l88.emit("Invalid JSON response from server")
	elif _s65 == 403:
		var _p59 = "Agent feature requires Pro tier"
		var json = JSON.parse_string(_s93)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_p59 = str(messages[0])
		_l88.emit(_p59)
	elif _s65 == 401:
		_l88.emit("Invalid API key")
	elif _s65 == 429:
		_l88.emit("Rate limit exceeded. Please try again later.")
	else:
		var _p59 = "Failed to start agent: HTTP " + str(_s65)
		var json = JSON.parse_string(_s93)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_p59 = str(messages[0])
		_l88.emit(_p59)

func _y44() -> void:
	if not _is_active or _o90.is_empty():
		return

	if not _u61 or not is_instance_valid(_u61):
		_p85()
		return

	var _t56 = _w44()
	if _t56.is_empty():
		return

	var _n38 = [
		"X-API-Key: " + _t56
	]

	var _z83 = _y88(_q59)
	_z83.request_completed.connect(_j46.bind(_z83))

	var _p12 = _i62() + "/agent/" + _o90 + "/status"
	var error = _z83.request(_p12, _n38, HTTPClient.METHOD_GET)

	if error != OK:
		_x56(_z83)
func _j46(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray, _z83: HTTPRequest) -> void:
	_x56(_z83)

	if _k3 != HTTPRequest.RESULT_SUCCESS or _s65 != 200:
		return

	var _s93 = _r16.get_string_from_utf8()
	var json = JSON.parse_string(_s93)

	if not json or not json is Dictionary:
		return

	_h84 += 1

	if json.has("next_poll_interval_ms"):
		var _s54 = json.get("next_poll_interval_ms", 1000) / 1000.0
		_c100 = clamp(_s54, _l75, _m18)
		_s18.wait_time = _c100
	elif _h84 > _u33:
		_c100 = min(_c100 * 1.2, _m18)
		_s18.wait_time = _c100

	if json.has("quota_warning") and json.get("quota_warning") != null:
		var _m74 = json.get("quota_warning")
		if _m74 is Dictionary and _a12 and is_instance_valid(_a12):
			var _i90 = _g100(_m74.get("severity", "notice"))
			var _n75 = _m74.get("model_group", "credits")
			var _i73 = _m74.get("usage_percentage", 0.0)

			var _p87 = "%s_%s_%d" % [_n75, _i90, int(_i73 / 5) * 5]
			if not _v90.has(_p87):
				_v90[_p87] = true
				_a12._n43.emit(_i90, _n75, _i73, "")

	if json.get("truncation_warning") == true:
		if _a12 and is_instance_valid(_a12):
			if not _v90.has("truncation"):
				_v90["truncation"] = true
				_a12._f5.emit("Response was truncated due to token limit. The output may be incomplete.")

	_t76.emit(json)

	var _k22 = json.get("assistant_message", "")
	if _k22 == null:
		_k22 = ""
	var _d56 = json.get("assistant_reasoning", "")
	if _d56 == null:
		_d56 = ""

	if not _k22.is_empty() or not _d56.is_empty():
		var _b64 = (_k22 + _d56).hash()
		if _b64 != _r37:
			_r37 = _b64
			_h40.emit(_k22, _d56)

	var status = json.get("status", "")
	match status:
		"THINKING", "EXECUTING":
			_h21.clear()
			_v43.clear()

			_v90.erase("truncation")

		"WAITING_TOOL", "WAITING_APPROVAL":
			var _t73: Array = []

			if json.has("pending_tool_calls") and json.get("pending_tool_calls") != null:
				var _a35 = json.get("pending_tool_calls")
				if _a35 is Array:
					for _c33 in _a35:
						if _c33 is Dictionary:
							var _x7 = _c33.get("tool_call_id", "")

							if not _x7.is_empty() and _x7 not in _h21:
								_t73.append(_c33)
								_h21.append(_x7)
			elif json.has("pending_tool_call") and json.get("pending_tool_call") != null:
				var _r71 = json.get("pending_tool_call")
				if _r71 is Dictionary:
					var _x7 = _r71.get("tool_call_id", "")
					if not _x7.is_empty() and _x7 not in _h21:
						_t73.append(_r71)
						_h21.append(_x7)

			if _t73.size() > 0:
				_p61.emit(_t73)

				_h84 = 0
				_c100 = _l75
				_s18.wait_time = _c100

		"COMPLETE":
			if _n82:
				return
			_n82 = true

			_p85()
			_x69.emit("Task completed")

		"FAILED":
			if _n82:
				return
			_n82 = true
			var _d100 = json.get("status_message", "Agent failed") if json.has("status_message") else "Agent failed"

			if _d100 == null:
				_d100 = "Agent failed"

			var _u81 = _o90
			_p85()

			if json.get("can_continue", false):
				_o47 = _u81
				_s92.emit(_u81, _d100)
			else:
				_l88.emit(_d100)

		"CANCELLED":
			if _n82:
				return
			_n82 = true
			_p85()
			_r83.emit()

func _p7(_x7: String, _a66: bool, _k3: Dictionary = {}, _d80: String = "") -> void:
	if not _is_active or _o90.is_empty():
		push_error("[AgentModeManager] Cannot submit tool output: no active session")
		return

	if not _u61 or not is_instance_valid(_u61):
		return

	if _x7 not in _v43:
		_v43.append(_x7)

	var _r16 = {
		"tool_call_id": _x7,
		"approved": _a66,
		"result": _k3,
		"rejection_reason": _d80
	}

	var _t56 = _w44()
	if _t56.is_empty():
		return

	var _n38 = [
		"Content-Type: application/json",
		"X-API-Key: " + _t56
	]

	var _z83 = _y88(_i44)
	_z83.request_completed.connect(_b58.bind(_z83, _x7))

	var _p12 = _i62() + "/agent/" + _o90 + "/tool-output"
	var error = _z83.request(_p12, _n38, HTTPClient.METHOD_POST, JSON.stringify(_r16))

	if error != OK:
		_x56(_z83)

		_v43.erase(_x7)
		_h21.erase(_x7)
func _b58(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray, _z83: HTTPRequest, _x7: String) -> void:
	_x56(_z83)

	if _k3 != HTTPRequest.RESULT_SUCCESS or _s65 != 200:
		_v43.erase(_x7)
		_h21.erase(_x7)
		return

func _h68() -> void:
	if not _is_active or _o90.is_empty():
		return

	if _n82:
		return
	_n82 = true

	if not _u61 or not is_instance_valid(_u61):
		_p85()
		_r83.emit()
		return

	var _t56 = _w44()
	if _t56.is_empty():
		_p85()
		_r83.emit()
		return

	var _n38 = [
		"Content-Type: application/json",
		"X-API-Key: " + _t56
	]

	var _z83 = _y88(_l83)
	_z83.request_completed.connect(func(r, _x2, h, b):
		_x56(_z83)
	)

	var _p12 = _i62() + "/agent/" + _o90 + "/cancel"
	_z83.request(_p12, _n38, HTTPClient.METHOD_POST)

	_p85()
	_r83.emit()

func _b46() -> void:
	if _is_active:
		push_error("[AgentModeManager] Cannot continue - session already active")
		return

	if _o47.is_empty():
		push_error("[AgentModeManager] No continuable session available")
		return

	if not _u61 or not is_instance_valid(_u61):
		_l88.emit("Parent node is not valid")
		return

	var _t56 = _w44()
	if _t56.is_empty():
		_l88.emit("No API key configured")
		return

	var _n38 = [
		"Content-Type: application/json",
		"X-API-Key: " + _t56
	]

	var _z83 = _y88(_q59)
	_z83.request_completed.connect(_w29.bind(_z83))

	var _p12 = _i62() + "/agent/" + _o47 + "/continue"
	var error = _z83.request(_p12, _n38, HTTPClient.METHOD_POST)
	if error != OK:
		_x56(_z83)
		_l88.emit("Failed to continue session: HTTP request error " + str(error))

func _w29(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray, _z83: HTTPRequest) -> void:
	_x56(_z83)

	if _k3 != HTTPRequest.RESULT_SUCCESS:
		_l88.emit("Network error continuing session")
		return

	var _s93 = _r16.get_string_from_utf8()

	if _s65 == 200:
		var json = JSON.parse_string(_s93)
		if json and json is Dictionary:
			var session_id = json.get("session_id", "")
			if session_id.is_empty():
				_l88.emit("Invalid response: missing session_id")
				return

			_o90 = session_id
			_o47 = ""
			_is_active = true
			_n82 = false
			_h84 = 0
			_c100 = _l75
			_s18.wait_time = _c100
			_s18.start()
			_v83()  
			_z89.emit(_o90)

		else:
			_l88.emit("Invalid JSON response from server")
	else:
		var _p59 = "Failed to continue session: HTTP " + str(_s65)
		var json = JSON.parse_string(_s93)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_p59 = str(messages[0])
		_l88.emit(_p59)

func _t88() -> bool:
	return not _o47.is_empty()

func _u88() -> void:
	_o47 = ""

func _p85() -> void:
	if _s18 and is_instance_valid(_s18):
		_s18.stop()
	_l39()  
	_is_active = false
	_o90 = ""
	_h84 = 0
	_c100 = _l75
	_h21.clear()  
	_v43.clear()
	_r37 = 0  

func is_active() -> bool:
	return _is_active

func _k48() -> String:
	return _o90

func _m54() -> int:
	return _h84

func _w44() -> String:
	if _a12 and is_instance_valid(_a12):
		return _a12._m83()

	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", "production", config.get_value("plugin", "api_key", ""))

	return ""

func _i62() -> String:
	if _a12 and is_instance_valid(_a12):
		return _a12._n87()

	return "https://api.gdsense.com/api/v1"

func _y88(_n61: float) -> HTTPRequest:
	var _z83 = HTTPRequest.new()
	_u61.add_child(_z83)

	var _d8 = Timer.new()
	_d8.wait_time = _n61
	_d8.one_shot = true
	_d8.timeout.connect(func():
		if is_instance_valid(_z83):
			_z83.cancel_request()
			_z83.queue_free()
		if is_instance_valid(_d8):
			_d8.queue_free()
	)
	_u61.add_child(_d8)
	_d8.start()

	_z83.set_meta("timeout_timer", _d8)

	return _z83

func _x56(_z83: HTTPRequest) -> void:
	if not is_instance_valid(_z83):
		return

	if _z83.has_meta("timeout_timer"):
		var _x64 = _z83.get_meta("timeout_timer")
		if is_instance_valid(_x64):
			_x64.stop()
			_x64.queue_free()

	_z83.queue_free()

func _p9() -> String:
	var _c32: Array = ["Project Structure:", "res://"]
	_u16("res://", _c32, 1, 3)
	return "\n".join(_c32)

func _i21(_m48: String, _s68: int) -> bool:
	if _m48.begins_with("."):
		return false

	if _m48 == "addons":
		return false
	return true

func _u16(path: String, _m12: Array, depth: int, _w19: int) -> void:
	if depth > _w19:
		return

	var _d30 = DirAccess.open(path)
	if _d30 == null:
		return

	_d30.list_dir_begin()
	var _m48 = _d30.get_next()
	var indent = "  ".repeat(depth)

	var _k57: Array = []
	var _i67: Array = []

	while _m48 != "":
		if _i21(_m48, depth):
			if _d30.current_is_dir():
				_k57.append(_m48)
			else:
				if _w82(_m48):
					_i67.append(_m48)
		_m48 = _d30.get_next()

	_d30.list_dir_end()

	_k57.sort()
	_i67.sort()

	for _s45 in _k57:
		_m12.append(indent + "|-- " + _s45 + "/")
		var full_path = path.path_join(_s45)
		_u16(full_path, _m12, depth + 1, _w19)

	for file in _i67:
		_m12.append(indent + "|-- " + file)

func _w82(_m48: String) -> bool:
	var _s83 = _m48.get_extension().to_lower()
	var _d55 = ["gd", "tscn", "tres", "cfg", "gdshader", "json", "txt", "md"]
	return _s83 in _d55

func _g100(_p98: String) -> String:
	match _p98.to_lower():
		"notice":
			return "medium"
		"warning":
			return "high"
		"critical", "limit_reached":
			return "critical"
		_:
			return "medium"

func _k63() -> void:
	_p85()
	_l39()

	if _s18 and is_instance_valid(_s18):
		_s18.queue_free()
		_s18 = null

	if _q76 and is_instance_valid(_q76):
		_q76.queue_free()
		_q76 = null

	_u61 = null
	_a12 = null

func _v83() -> void:
	if _e67 and is_instance_valid(_e67):
		return  

	if not _u61 or not is_instance_valid(_u61):
		return

	_x55 = 0
	_e67 = Timer.new()
	_e67.wait_time = 0.5
	_e67.one_shot = false
	_e67.timeout.connect(_i78)
	_u61.add_child(_e67)
	_e67.start()
	_f21()

func _i78() -> void:
	_x55 = (_x55 + 1) % 4
	_f21()

func _f21() -> void:
	var _j56 = _x55 if _x55 > 0 else 1
	var _a1 = ".".repeat(_j56)
	_i94.emit("Thinking" + _a1)

func _l39() -> void:
	if _e67 and is_instance_valid(_e67):
		_e67.stop()
		_e67.queue_free()
		_e67 = null
	_x55 = 0

