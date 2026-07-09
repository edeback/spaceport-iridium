@tool
class_name _q76
extends RefCounted

signal _x16(session_id: String)
signal _i54(status: Dictionary)
signal _u5(_n95: Array)  
signal _h98(message: String)
signal _r8(error: String)
signal _n26()
signal _c18(session_id: String, message: String)
signal _f31(message: String, _t80: String)  
signal _m95(text: String)  

var _c71: String = ""
var _is_active: bool = false
var _f8: String = ""
var _o58: Timer
var _f52: int = 0
var _u64: float = 1.0
var _w70: HTTPRequest
var _d89: Node
var _k87: _y82  
var _d5: Array = []  
var _w76: Array = []  
var _h81: bool = false  
var _e85: int = 0  
var _k6: Dictionary = {}  

var _u17: int = 0
var _x94: Timer

const _s96: float = 4.0  
const _q63: float = 0.5  
const _v58: int = 8  

const _w43: float = 10.0
const _p19: float = 15.0
const _l66: float = 10.0

func initialize(parent: Node, _h31: _y82) -> void:
	_d89 = parent
	_k87 = _h31

	_o58 = Timer.new()
	_o58.one_shot = false
	_o58.timeout.connect(_d100)
	parent.add_child(_o58)

	_w70 = HTTPRequest.new()
	parent.add_child(_w70)

func _i88(_w100: String, _g97: Dictionary = {}, model: String = "") -> void:
	if _is_active:
		push_error("[AgentModeManager] Agent session already active")
		return

	if not _d89 or not is_instance_valid(_d89):
		_r8.emit("Parent node is not valid")
		return

	var _k49 = _g97.duplicate()
	_k49["file_tree"] = _s84()
	_k49["godot_version"] = Engine.get_version_info()["string"]

	var _k5 = {
		"task_description": _w100,
		"project_context": _k49
	}

	if not model.is_empty():
		_k5["model"] = model

	var _s45 = _o83()
	if _s45.is_empty():
		_r8.emit("No API key configured")
		return

	var _e88 = [
		"Content-Type: application/json",
		"X-API-Key: " + _s45
	]

	if _w70.request_completed.is_connected(_m58):
		_w70.request_completed.disconnect(_m58)
	_w70.request_completed.connect(_m58, CONNECT_ONE_SHOT)

	var _o41 = _e27() + "/agent/start"
	var error = _w70.request(_o41, _e88, HTTPClient.METHOD_POST, JSON.stringify(_k5))

	if error != OK:
		_r8.emit("Failed to start agent session: HTTP request error " + str(error))

func _m58(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_r8.emit("Network error starting agent session")
		return

	var _s33 = _k5.get_string_from_utf8()

	if _u67 == 200:
		var json = JSON.parse_string(_s33)
		if json and json is Dictionary:
			_c71 = json.get("session_id", "")
			if _c71.is_empty():
				_r8.emit("Invalid response: missing session_id")
				return

			_is_active = true
			_h81 = false  
			_f52 = 0
			_u64 = _q63
			_o58.wait_time = _u64
			_o58.start()
			_b9()  
			_x16.emit(_c71)

		else:
			_r8.emit("Invalid JSON response from server")
	elif _u67 == 403:
		var _e22 = "Agent feature requires Pro tier"
		var json = JSON.parse_string(_s33)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_e22 = str(messages[0])
		_r8.emit(_e22)
	elif _u67 == 401:
		_r8.emit("Invalid API key")
	elif _u67 == 429:
		_r8.emit("Rate limit exceeded. Please try again later.")
	else:
		var _e22 = "Failed to start agent: HTTP " + str(_u67)
		var json = JSON.parse_string(_s33)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_e22 = str(messages[0])
		_r8.emit(_e22)

func _d100() -> void:
	if not _is_active or _c71.is_empty():
		return

	if not _d89 or not is_instance_valid(_d89):
		_r75()
		return

	var _s45 = _o83()
	if _s45.is_empty():
		return

	var _e88 = [
		"X-API-Key: " + _s45
	]

	var _h34 = _e72(_w43)
	_h34.request_completed.connect(_e30.bind(_h34))

	var _o41 = _e27() + "/agent/" + _c71 + "/status"
	var error = _h34.request(_o41, _e88, HTTPClient.METHOD_GET)

	if error != OK:
		_g86(_h34)
func _e30(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray, _h34: HTTPRequest) -> void:
	_g86(_h34)

	if _x97 != HTTPRequest.RESULT_SUCCESS or _u67 != 200:
		return

	var _s33 = _k5.get_string_from_utf8()
	var json = JSON.parse_string(_s33)

	if not json or not json is Dictionary:
		return

	_f52 += 1

	if json.has("next_poll_interval_ms"):
		var _n24 = json.get("next_poll_interval_ms", 1000) / 1000.0
		_u64 = clamp(_n24, _q63, _s96)
		_o58.wait_time = _u64
	elif _f52 > _v58:
		_u64 = min(_u64 * 1.2, _s96)
		_o58.wait_time = _u64

	if json.has("quota_warning") and json.get("quota_warning") != null:
		var _x86 = json.get("quota_warning")
		if _x86 is Dictionary and _k87 and is_instance_valid(_k87):
			var _m90 = _c55(_x86.get("severity", "notice"))
			var _q4 = _x86.get("model_group", "credits")
			var _p96 = _x86.get("usage_percentage", 0.0)

			var _v22 = "%s_%s_%d" % [_q4, _m90, int(_p96 / 5) * 5]
			if not _k6.has(_v22):
				_k6[_v22] = true
				_k87._z93.emit(_m90, _q4, _p96, "")

	if json.get("truncation_warning") == true:
		if _k87 and is_instance_valid(_k87):
			if not _k6.has("truncation"):
				_k6["truncation"] = true
				_k87._o37.emit("Response was truncated due to token limit. The output may be incomplete.")

	_i54.emit(json)

	var _v19 = json.get("assistant_message", "")
	if _v19 == null:
		_v19 = ""
	var _j30 = json.get("assistant_reasoning", "")
	if _j30 == null:
		_j30 = ""

	if not _v19.is_empty() or not _j30.is_empty():
		var _s21 = (_v19 + _j30).hash()
		if _s21 != _e85:
			_e85 = _s21
			_f31.emit(_v19, _j30)

	var status = json.get("status", "")
	match status:
		"THINKING", "EXECUTING":
			_d5.clear()
			_w76.clear()

			_k6.erase("truncation")

		"WAITING_TOOL", "WAITING_APPROVAL":
			var _j4: Array = []

			if json.has("pending_tool_calls") and json.get("pending_tool_calls") != null:
				var _z79 = json.get("pending_tool_calls")
				if _z79 is Array:
					for _h74 in _z79:
						if _h74 is Dictionary:
							var _b80 = _h74.get("tool_call_id", "")

							if not _b80.is_empty() and _b80 not in _d5:
								_j4.append(_h74)
								_d5.append(_b80)
			elif json.has("pending_tool_call") and json.get("pending_tool_call") != null:
				var _t28 = json.get("pending_tool_call")
				if _t28 is Dictionary:
					var _b80 = _t28.get("tool_call_id", "")
					if not _b80.is_empty() and _b80 not in _d5:
						_j4.append(_t28)
						_d5.append(_b80)

			if _j4.size() > 0:
				_u5.emit(_j4)

				_f52 = 0
				_u64 = _q63
				_o58.wait_time = _u64

		"COMPLETE":
			if _h81:
				return
			_h81 = true

			_r75()
			_h98.emit("Task completed")

		"FAILED":
			if _h81:
				return
			_h81 = true
			var _s12 = json.get("status_message", "Agent failed") if json.has("status_message") else "Agent failed"

			if _s12 == null:
				_s12 = "Agent failed"

			var _a91 = _c71
			_r75()

			if json.get("can_continue", false):
				_f8 = _a91
				_c18.emit(_a91, _s12)
			else:
				_r8.emit(_s12)

		"CANCELLED":
			if _h81:
				return
			_h81 = true
			_r75()
			_n26.emit()

func _d72(_b80: String, _s25: bool, _x97: Dictionary = {}, _x98: String = "") -> void:
	if not _is_active or _c71.is_empty():
		push_error("[AgentModeManager] Cannot submit tool output: no active session")
		return

	if not _d89 or not is_instance_valid(_d89):
		return

	if _b80 not in _w76:
		_w76.append(_b80)

	var _k5 = {
		"tool_call_id": _b80,
		"approved": _s25,
		"result": _x97,
		"rejection_reason": _x98
	}

	var _s45 = _o83()
	if _s45.is_empty():
		return

	var _e88 = [
		"Content-Type: application/json",
		"X-API-Key: " + _s45
	]

	var _h34 = _e72(_p19)
	_h34.request_completed.connect(_q45.bind(_h34, _b80))

	var _o41 = _e27() + "/agent/" + _c71 + "/tool-output"
	var error = _h34.request(_o41, _e88, HTTPClient.METHOD_POST, JSON.stringify(_k5))

	if error != OK:
		_g86(_h34)

		_w76.erase(_b80)
		_d5.erase(_b80)
func _q45(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray, _h34: HTTPRequest, _b80: String) -> void:
	_g86(_h34)

	if _x97 != HTTPRequest.RESULT_SUCCESS or _u67 != 200:
		_w76.erase(_b80)
		_d5.erase(_b80)
		return

func _l96() -> void:
	if not _is_active or _c71.is_empty():
		return

	if _h81:
		return
	_h81 = true

	if not _d89 or not is_instance_valid(_d89):
		_r75()
		_n26.emit()
		return

	var _s45 = _o83()
	if _s45.is_empty():
		_r75()
		_n26.emit()
		return

	var _e88 = [
		"Content-Type: application/json",
		"X-API-Key: " + _s45
	]

	var _h34 = _e72(_l66)
	_h34.request_completed.connect(func(r, _b48, h, b):
		_g86(_h34)
	)

	var _o41 = _e27() + "/agent/" + _c71 + "/cancel"
	_h34.request(_o41, _e88, HTTPClient.METHOD_POST)

	_r75()
	_n26.emit()

func _p32() -> void:
	if _is_active:
		push_error("[AgentModeManager] Cannot continue - session already active")
		return

	if _f8.is_empty():
		push_error("[AgentModeManager] No continuable session available")
		return

	if not _d89 or not is_instance_valid(_d89):
		_r8.emit("Parent node is not valid")
		return

	var _s45 = _o83()
	if _s45.is_empty():
		_r8.emit("No API key configured")
		return

	var _e88 = [
		"Content-Type: application/json",
		"X-API-Key: " + _s45
	]

	var _h34 = _e72(_w43)
	_h34.request_completed.connect(_d35.bind(_h34))

	var _o41 = _e27() + "/agent/" + _f8 + "/continue"
	var error = _h34.request(_o41, _e88, HTTPClient.METHOD_POST)
	if error != OK:
		_g86(_h34)
		_r8.emit("Failed to continue session: HTTP request error " + str(error))

func _d35(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray, _h34: HTTPRequest) -> void:
	_g86(_h34)

	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_r8.emit("Network error continuing session")
		return

	var _s33 = _k5.get_string_from_utf8()

	if _u67 == 200:
		var json = JSON.parse_string(_s33)
		if json and json is Dictionary:
			var session_id = json.get("session_id", "")
			if session_id.is_empty():
				_r8.emit("Invalid response: missing session_id")
				return

			_c71 = session_id
			_f8 = ""
			_is_active = true
			_h81 = false
			_f52 = 0
			_u64 = _q63
			_o58.wait_time = _u64
			_o58.start()
			_b9()  
			_x16.emit(_c71)

		else:
			_r8.emit("Invalid JSON response from server")
	else:
		var _e22 = "Failed to continue session: HTTP " + str(_u67)
		var json = JSON.parse_string(_s33)
		if json and json is Dictionary:
			if json.has("messages"):
				var messages = json.get("messages", [])
				if messages is Array and messages.size() > 0:
					_e22 = str(messages[0])
		_r8.emit(_e22)

func _t75() -> bool:
	return not _f8.is_empty()

func _z42() -> void:
	_f8 = ""

func _r75() -> void:
	if _o58 and is_instance_valid(_o58):
		_o58.stop()
	_j64()  
	_is_active = false
	_c71 = ""
	_f52 = 0
	_u64 = _q63
	_d5.clear()  
	_w76.clear()
	_e85 = 0  

func is_active() -> bool:
	return _is_active

func _r78() -> String:
	return _c71

func _a39() -> int:
	return _f52

func _o83() -> String:
	if _k87 and is_instance_valid(_k87):
		return _k87._x42()

	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", "production", config.get_value("plugin", "api_key", ""))

	return ""

func _e27() -> String:
	if _k87 and is_instance_valid(_k87):
		return _k87._w6()

	return "https://api.gdsense.com/api/v1"

func _e72(_k85: float) -> HTTPRequest:
	var _h34 = HTTPRequest.new()
	_d89.add_child(_h34)

	var _r2 = Timer.new()
	_r2.wait_time = _k85
	_r2.one_shot = true
	_r2.timeout.connect(func():
		if is_instance_valid(_h34):
			_h34.cancel_request()
			_h34.queue_free()
		if is_instance_valid(_r2):
			_r2.queue_free()
	)
	_d89.add_child(_r2)
	_r2.start()

	_h34.set_meta("timeout_timer", _r2)

	return _h34

func _g86(_h34: HTTPRequest) -> void:
	if not is_instance_valid(_h34):
		return

	if _h34.has_meta("timeout_timer"):
		var _b2 = _h34.get_meta("timeout_timer")
		if is_instance_valid(_b2):
			_b2.stop()
			_b2.queue_free()

	_h34.queue_free()

func _s84() -> String:
	var _q16: Array = ["Project Structure:", "res://"]
	_i82("res://", _q16, 1, 3)
	return "\n".join(_q16)

func _b13(_x87: String, _q50: int) -> bool:
	if _x87.begins_with("."):
		return false

	if _x87 == "addons":
		return false
	return true

func _i82(path: String, _d41: Array, depth: int, _u72: int) -> void:
	if depth > _u72:
		return

	var _j57 = DirAccess.open(path)
	if _j57 == null:
		return

	_j57.list_dir_begin()
	var _x87 = _j57.get_next()
	var indent = "  ".repeat(depth)

	var _i43: Array = []
	var _n51: Array = []

	while _x87 != "":
		if _b13(_x87, depth):
			if _j57.current_is_dir():
				_i43.append(_x87)
			else:
				if _r9(_x87):
					_n51.append(_x87)
		_x87 = _j57.get_next()

	_j57.list_dir_end()

	_i43.sort()
	_n51.sort()

	for _x100 in _i43:
		_d41.append(indent + "|-- " + _x100 + "/")
		var full_path = path.path_join(_x100)
		_i82(full_path, _d41, depth + 1, _u72)

	for file in _n51:
		_d41.append(indent + "|-- " + file)

func _r9(_x87: String) -> bool:
	var _p39 = _x87.get_extension().to_lower()
	var _i38 = ["gd", "tscn", "tres", "cfg", "gdshader", "json", "txt", "md"]
	return _p39 in _i38

func _c55(_z29: String) -> String:
	match _z29.to_lower():
		"notice":
			return "medium"
		"warning":
			return "high"
		"critical", "limit_reached":
			return "critical"
		_:
			return "medium"

func _q17() -> void:
	_r75()
	_j64()

	if _o58 and is_instance_valid(_o58):
		_o58.queue_free()
		_o58 = null

	if _w70 and is_instance_valid(_w70):
		_w70.queue_free()
		_w70 = null

	_d89 = null
	_k87 = null

func _b9() -> void:
	if _x94 and is_instance_valid(_x94):
		return  

	if not _d89 or not is_instance_valid(_d89):
		return

	_u17 = 0
	_x94 = Timer.new()
	_x94.wait_time = 0.5
	_x94.one_shot = false
	_x94.timeout.connect(_e6)
	_d89.add_child(_x94)
	_x94.start()
	_w63()

func _e6() -> void:
	_u17 = (_u17 + 1) % 4
	_w63()

func _w63() -> void:
	var _n44 = _u17 if _u17 > 0 else 1
	var _m30 = ".".repeat(_n44)
	_m95.emit("Thinking" + _m30)

func _j64() -> void:
	if _x94 and is_instance_valid(_x94):
		_x94.stop()
		_x94.queue_free()
		_x94 = null
	_u17 = 0

