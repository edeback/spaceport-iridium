@tool
class_name _c24
extends RefCounted

signal _q3(session_id: String)
signal _o23(status: Dictionary)
signal _h92(_a29: Array)  
signal _c58(message: String)
signal _p86(error: String)
signal _a36()
signal _i79(session_id: String, message: String)
signal _v1(message: String, _a27: String)  
signal _l58(text: String)  

var _o100: String = ""
var _is_active: bool = false
var _h96: String = ""
var _r91: Timer
var _i87: int = 0
var _i1: float = 1.0
var _p4: HTTPRequest
var _i9: Node
var _u56: _b92  
var _e27: Array = []  
var _s88: Array = []  
var _u98: bool = false  
var _q81: int = 0  
var _a70: Dictionary = {}  

var _e43: int = 0
var _h31: Timer

const _e28: float = 4.0  
const _s43: float = 0.5  
const _w46: int = 8  

const _u12: float = 10.0
const _y25: float = 15.0
const _x41: float = 10.0

func initialize(parent: Node, _r18: _b92) -> void:
	_i9 = parent
	_u56 = _r18

	_r91 = Timer.new()
	_r91.one_shot = false
	_r91.timeout.connect(_m62)
	parent.add_child(_r91)

	_p4 = HTTPRequest.new()
	parent.add_child(_p4)

func _j59(_q74: String, _g68: Dictionary = {}, model: String = "") -> void:
	if _is_active:
		push_error("[AgentModeManager] Agent session already active")
		return

	if not _i9 or not is_instance_valid(_i9):
		_p86.emit("Parent node is not valid")
		return

	var _t52 = _g68.duplicate()
	_t52["file_tree"] = _k7()
	_t52["godot_version"] = Engine.get_version_info()["string"]

	var _v64 = {
		"task_description": _q74,
		"project_context": _t52
	}

	if not model.is_empty():
		_v64["model"] = model

	var _w95 = _y85()
	if _w95.is_empty():
		_p86.emit("No API key configured")
		return

	var _g61 = [
		"Content-Type: application/json",
		"X-API-Key: " + _w95
	]

	if _p4.request_completed.is_connected(_d16):
		_p4.request_completed.disconnect(_d16)
	_p4.request_completed.connect(_d16, CONNECT_ONE_SHOT)

	var _p33 = _i46() + "/agent/start"
	var error = _p4.request(_p33, _g61, HTTPClient.METHOD_POST, JSON.stringify(_v64))

	if error != OK:
		_p86.emit("Failed to start agent session: HTTP request error " + str(error))

func _d16(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray) -> void:
	if _v42 != HTTPRequest.RESULT_SUCCESS:
		_p86.emit("Network error starting agent session")
		return

	var _n45 = _v64.get_string_from_utf8()

	if _k63 == 200:
		var json = JSON.parse_string(_n45)
		if json and json is Dictionary:
			_o100 = json.get("session_id", "")
			if _o100.is_empty():
				_p86.emit("Invalid response: missing session_id")
				return

			_is_active = true
			_u98 = false  
			_i87 = 0
			_i1 = _s43
			_r91.wait_time = _i1
			_r91.start()
			_z18()  
			_q3.emit(_o100)

		else:
			_p86.emit("Invalid JSON response from server")
	elif _k63 == 403:
		var _s52 = "Agent feature requires Pro tier"
		var json = JSON.parse_string(_n45)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_s52 = str(messages[0])
		_p86.emit(_s52)
	elif _k63 == 401:
		_p86.emit("Invalid API key")
	elif _k63 == 429:
		_p86.emit("Rate limit exceeded. Please try again later.")
	else:
		var _s52 = "Failed to start agent: HTTP " + str(_k63)
		var json = JSON.parse_string(_n45)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_s52 = str(messages[0])
		_p86.emit(_s52)

func _m62() -> void:
	if not _is_active or _o100.is_empty():
		return

	if not _i9 or not is_instance_valid(_i9):
		_a67()
		return

	var _w95 = _y85()
	if _w95.is_empty():
		return

	var _g61 = [
		"X-API-Key: " + _w95
	]

	var _z75 = _g54(_u12)
	_z75.request_completed.connect(_d14.bind(_z75))

	var _p33 = _i46() + "/agent/" + _o100 + "/status"
	var error = _z75.request(_p33, _g61, HTTPClient.METHOD_GET)

	if error != OK:
		_o92(_z75)
func _d14(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray, _z75: HTTPRequest) -> void:
	_o92(_z75)

	if _v42 != HTTPRequest.RESULT_SUCCESS or _k63 != 200:
		return

	var _n45 = _v64.get_string_from_utf8()
	var json = JSON.parse_string(_n45)

	if not json or not json is Dictionary:
		return

	_i87 += 1

	if json.has("next_poll_interval_ms"):
		var _x9 = json.get("next_poll_interval_ms", 1000) / 1000.0
		_i1 = clamp(_x9, _s43, _e28)
		_r91.wait_time = _i1
	elif _i87 > _w46:
		_i1 = min(_i1 * 1.2, _e28)
		_r91.wait_time = _i1

	if json.has("quota_warning") and json.get("quota_warning") != null:
		var _a85 = json.get("quota_warning")
		if _a85 is Dictionary and _u56 and is_instance_valid(_u56):
			var _h18 = _i14(_a85.get("severity", "notice"))
			var _e47 = _a85.get("model_group", "credits")
			var _d75 = _a85.get("usage_percentage", 0.0)

			var _o57 = "%s_%s_%d" % [_e47, _h18, int(_d75 / 5) * 5]
			if not _a70.has(_o57):
				_a70[_o57] = true
				_u56._c79.emit(_h18, _e47, _d75, "")

	if json.get("truncation_warning") == true:
		if _u56 and is_instance_valid(_u56):
			if not _a70.has("truncation"):
				_a70["truncation"] = true
				_u56._d52.emit("Response was truncated due to token limit. The output may be incomplete.")

	_o23.emit(json)

	var _x80 = json.get("assistant_message", "")
	if _x80 == null:
		_x80 = ""
	var _k75 = json.get("assistant_reasoning", "")
	if _k75 == null:
		_k75 = ""

	if not _x80.is_empty() or not _k75.is_empty():
		var _o78 = (_x80 + _k75).hash()
		if _o78 != _q81:
			_q81 = _o78
			_v1.emit(_x80, _k75)

	var status = json.get("status", "")
	match status:
		"THINKING", "EXECUTING":
			_e27.clear()
			_s88.clear()

			_a70.erase("truncation")

		"WAITING_TOOL", "WAITING_APPROVAL":
			var _r94: Array = []

			if json.has("pending_tool_calls") and json.get("pending_tool_calls") != null:
				var _q16 = json.get("pending_tool_calls")
				if _q16 is Array:
					for _l81 in _q16:
						if _l81 is Dictionary:
							var _n77 = _l81.get("tool_call_id", "")

							if not _n77.is_empty() and _n77 not in _e27:
								_r94.append(_l81)
								_e27.append(_n77)
			elif json.has("pending_tool_call") and json.get("pending_tool_call") != null:
				var _z10 = json.get("pending_tool_call")
				if _z10 is Dictionary:
					var _n77 = _z10.get("tool_call_id", "")
					if not _n77.is_empty() and _n77 not in _e27:
						_r94.append(_z10)
						_e27.append(_n77)

			if _r94.size() > 0:
				_h92.emit(_r94)

				_i87 = 0
				_i1 = _s43
				_r91.wait_time = _i1

		"COMPLETE":
			if _u98:
				return
			_u98 = true

			_a67()
			_c58.emit("Task completed")

		"FAILED":
			if _u98:
				return
			_u98 = true
			var _s57 = json.get("status_message", "Agent failed") if json.has("status_message") else "Agent failed"

			if _s57 == null:
				_s57 = "Agent failed"

			var _k77 = _o100
			_a67()

			if json.get("can_continue", false):
				_h96 = _k77
				_i79.emit(_k77, _s57)
			else:
				_p86.emit(_s57)

		"CANCELLED":
			if _u98:
				return
			_u98 = true
			_a67()
			_a36.emit()

func _s61(_n77: String, _u32: bool, _v42: Dictionary = {}, _x51: String = "") -> void:
	if not _is_active or _o100.is_empty():
		push_error("[AgentModeManager] Cannot submit tool output: no active session")
		return

	if not _i9 or not is_instance_valid(_i9):
		return

	if _n77 not in _s88:
		_s88.append(_n77)

	var _v64 = {
		"tool_call_id": _n77,
		"approved": _u32,
		"result": _v42,
		"rejection_reason": _x51
	}

	var _w95 = _y85()
	if _w95.is_empty():
		return

	var _g61 = [
		"Content-Type: application/json",
		"X-API-Key: " + _w95
	]

	var _z75 = _g54(_y25)
	_z75.request_completed.connect(_y26.bind(_z75, _n77))

	var _p33 = _i46() + "/agent/" + _o100 + "/tool-output"
	var error = _z75.request(_p33, _g61, HTTPClient.METHOD_POST, JSON.stringify(_v64))

	if error != OK:
		_o92(_z75)

		_s88.erase(_n77)
		_e27.erase(_n77)
func _y26(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray, _z75: HTTPRequest, _n77: String) -> void:
	_o92(_z75)

	if _v42 != HTTPRequest.RESULT_SUCCESS or _k63 != 200:
		_s88.erase(_n77)
		_e27.erase(_n77)
		return

func _x83() -> void:
	if not _is_active or _o100.is_empty():
		return

	if _u98:
		return
	_u98 = true

	if not _i9 or not is_instance_valid(_i9):
		_a67()
		_a36.emit()
		return

	var _w95 = _y85()
	if _w95.is_empty():
		_a67()
		_a36.emit()
		return

	var _g61 = [
		"Content-Type: application/json",
		"X-API-Key: " + _w95
	]

	var _z75 = _g54(_x41)
	_z75.request_completed.connect(func(r, _l51, h, b):
		_o92(_z75)
	)

	var _p33 = _i46() + "/agent/" + _o100 + "/cancel"
	_z75.request(_p33, _g61, HTTPClient.METHOD_POST)

	_a67()
	_a36.emit()

func _j17() -> void:
	if _is_active:
		push_error("[AgentModeManager] Cannot continue - session already active")
		return

	if _h96.is_empty():
		push_error("[AgentModeManager] No continuable session available")
		return

	if not _i9 or not is_instance_valid(_i9):
		_p86.emit("Parent node is not valid")
		return

	var _w95 = _y85()
	if _w95.is_empty():
		_p86.emit("No API key configured")
		return

	var _g61 = [
		"Content-Type: application/json",
		"X-API-Key: " + _w95
	]

	var _z75 = _g54(_u12)
	_z75.request_completed.connect(_y36.bind(_z75))

	var _p33 = _i46() + "/agent/" + _h96 + "/continue"
	var error = _z75.request(_p33, _g61, HTTPClient.METHOD_POST)
	if error != OK:
		_o92(_z75)
		_p86.emit("Failed to continue session: HTTP request error " + str(error))

func _y36(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray, _z75: HTTPRequest) -> void:
	_o92(_z75)

	if _v42 != HTTPRequest.RESULT_SUCCESS:
		_p86.emit("Network error continuing session")
		return

	var _n45 = _v64.get_string_from_utf8()

	if _k63 == 200:
		var json = JSON.parse_string(_n45)
		if json and json is Dictionary:
			var session_id = json.get("session_id", "")
			if session_id.is_empty():
				_p86.emit("Invalid response: missing session_id")
				return

			_o100 = session_id
			_h96 = ""
			_is_active = true
			_u98 = false
			_i87 = 0
			_i1 = _s43
			_r91.wait_time = _i1
			_r91.start()
			_z18()  
			_q3.emit(_o100)

		else:
			_p86.emit("Invalid JSON response from server")
	else:
		var _s52 = "Failed to continue session: HTTP " + str(_k63)
		var json = JSON.parse_string(_n45)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_s52 = str(messages[0])
		_p86.emit(_s52)

func _v38() -> bool:
	return not _h96.is_empty()

func _k13() -> void:
	_h96 = ""

func _a67() -> void:
	if _r91 and is_instance_valid(_r91):
		_r91.stop()
	_t11()  
	_is_active = false
	_o100 = ""
	_i87 = 0
	_i1 = _s43
	_e27.clear()  
	_s88.clear()
	_q81 = 0  

func is_active() -> bool:
	return _is_active

func _w24() -> String:
	return _o100

func _o41() -> int:
	return _i87

func _y85() -> String:
	if _u56 and is_instance_valid(_u56):
		return _u56._o19()

	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", "production", config.get_value("plugin", "api_key", ""))

	return ""

func _i46() -> String:
	if _u56 and is_instance_valid(_u56):
		return _u56._d9()

	return "https://api.gdsense.com/api/v1"

func _g54(_h43: float) -> HTTPRequest:
	var _z75 = HTTPRequest.new()
	_i9.add_child(_z75)

	var _s99 = Timer.new()
	_s99.wait_time = _h43
	_s99.one_shot = true
	_s99.timeout.connect(func():
		if is_instance_valid(_z75):
			_z75.cancel_request()
			_z75.queue_free()
		if is_instance_valid(_s99):
			_s99.queue_free()
	)
	_i9.add_child(_s99)
	_s99.start()

	_z75.set_meta("timeout_timer", _s99)

	return _z75

func _o92(_z75: HTTPRequest) -> void:
	if not is_instance_valid(_z75):
		return

	if _z75.has_meta("timeout_timer"):
		var _v72 = _z75.get_meta("timeout_timer")
		if is_instance_valid(_v72):
			_v72.stop()
			_v72.queue_free()

	_z75.queue_free()

func _k7() -> String:
	var _c2: Array = ["Project Structure:", "res://"]
	_q100("res://", _c2, 1, 3)
	return "\n".join(_c2)

func _l12(_p88: String, _z62: int) -> bool:
	if _p88.begins_with("."):
		return false

	if _p88 == "addons":
		return false
	return true

func _q100(path: String, _b26: Array, depth: int, _j27: int) -> void:
	if depth > _j27:
		return

	var _g27 = DirAccess.open(path)
	if _g27 == null:
		return

	_g27.list_dir_begin()
	var _p88 = _g27.get_next()
	var indent = "  ".repeat(depth)

	var _c83: Array = []
	var _h63: Array = []

	while _p88 != "":
		if _l12(_p88, depth):
			if _g27.current_is_dir():
				_c83.append(_p88)
			else:
				if _q89(_p88):
					_h63.append(_p88)
		_p88 = _g27.get_next()

	_g27.list_dir_end()

	_c83.sort()
	_h63.sort()

	for _b3 in _c83:
		_b26.append(indent + "|-- " + _b3 + "/")
		var full_path = path.path_join(_b3)
		_q100(full_path, _b26, depth + 1, _j27)

	for file in _h63:
		_b26.append(indent + "|-- " + file)

func _q89(_p88: String) -> bool:
	var _s95 = _p88.get_extension().to_lower()
	var _f20 = ["gd", "tscn", "tres", "cfg", "gdshader", "json", "txt", "md"]
	return _s95 in _f20

func _i14(_i28: String) -> String:
	match _i28.to_lower():
		"notice":
			return "medium"
		"warning":
			return "high"
		"critical", "limit_reached":
			return "critical"
		_:
			return "medium"

func _o76() -> void:
	_a67()
	_t11()

	if _r91 and is_instance_valid(_r91):
		_r91.queue_free()
		_r91 = null

	if _p4 and is_instance_valid(_p4):
		_p4.queue_free()
		_p4 = null

	_i9 = null
	_u56 = null

func _z18() -> void:
	if _h31 and is_instance_valid(_h31):
		return  

	if not _i9 or not is_instance_valid(_i9):
		return

	_e43 = 0
	_h31 = Timer.new()
	_h31.wait_time = 0.5
	_h31.one_shot = false
	_h31.timeout.connect(_j79)
	_i9.add_child(_h31)
	_h31.start()
	_t78()

func _j79() -> void:
	_e43 = (_e43 + 1) % 4
	_t78()

func _t78() -> void:
	var _n24 = _e43 if _e43 > 0 else 1
	var _v16 = ".".repeat(_n24)
	_l58.emit("Thinking" + _v16)

func _t11() -> void:
	if _h31 and is_instance_valid(_h31):
		_h31.stop()
		_h31.queue_free()
		_h31 = null
	_e43 = 0

