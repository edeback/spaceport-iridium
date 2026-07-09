@tool
class_name _v64
extends RefCounted
class _f57:
	var exchanges: Array  
	var timestamp: String  
	var is_favorite: bool
	var custom_name: String
	var session_id: String  
	var last_updated: String  
	var pinned_open_scripts: Dictionary
	var pinned_open_script_order: Array[String]
	var _k82: String  
	func _init(_d85: String = "", _k24: bool = false, name: String = ""):
		exchanges = []
		timestamp = Time.get_datetime_string_from_system()
		last_updated = timestamp
		is_favorite = _k24
		custom_name = name
		session_id = _d85 if not _d85.is_empty() else _v69()
		pinned_open_scripts = {}
		pinned_open_script_order = []
		_k82 = ""
	func _v69() -> String:
		return "local_%d" % Time.get_ticks_msec()
	static func _e88(message: String) -> String:
		if not message.begins_with("# Context Information"):
			return message  
		var _e57 = "\n\n# User Request\n\n"
		var _n89 = message.find(_e57)
		if _n89 != -1:
			var _b52 = message.substr(_n89 + _e57.length())
			if not _b52.is_empty():
				return _b52.strip_edges()
		var _p79 = "\n---\n\n"
		_n89 = message.find(_p79)
		if _n89 != -1:
			var _v76 = message.substr(_n89 + _p79.length())
			if _v76.begins_with("# User Request\n\n"):
				_v76 = _v76.substr("# User Request\n\n".length())
			if not _v76.is_empty():
				return _v76.strip_edges()
		return message
	func _j94(_h35: String, _i84: String, _l57: String = "", _f73: String = "", model: String = ""):
		var _t47 = {
			"user_message": _h35,
			"ai_response": _i84
		}
		_t47["enhanced_user_message"] = _f73 if not _f73.is_empty() else _h35
		if not _l57.is_empty():
			_t47["thought_signature"] = _l57
		exchanges.append(_t47)
		last_updated = Time.get_datetime_string_from_system()
		if _k82.is_empty() and not model.is_empty():
			_k82 = model
	func _q22() -> String:
		return "%s" % timestamp.substr(0, 19).replace("T", " ")
	func _i49(_m80: int = 50) -> String:
		if not custom_name.is_empty():
			return custom_name
		if exchanges.is_empty():
			return "(Empty session)"
		var _t64 = exchanges[0]
		var _o60 = _f57._e88(_t64["user_message"]).strip_edges()
		if _o60.length() > _m80:
			return _o60.substr(0, _m80) + "..."
		return _o60
	func _v74() -> String:
		if not custom_name.is_empty():
			return custom_name
		return _i49(40)
	func _r13() -> int:
		return exchanges.size()
	func _j6() -> String:
		if exchanges.is_empty():
			return ""
		return _f57._e88(exchanges[0]["user_message"])
	func _o1() -> String:
		if exchanges.is_empty():
			return ""
		return exchanges[0]["ai_response"]
	func _v11() -> String:
		var text = ""
		for i in range(exchanges.size()):
			var _t47 = exchanges[i]
			text += "Turn %d:\n" % (i + 1)
			text += "User: %s\n" % _f57._e88(_t47["user_message"])
			text += "AI: %s\n\n" % _t47["ai_response"]
		return text
	func _t13(_s36: Dictionary, _k5: Array[String]) -> void:
		pinned_open_scripts = _s36.duplicate(true)
		var _d50: Array[String] = []
		_d50.assign(_k5)
		pinned_open_script_order = _d50
	func _e98() -> Dictionary:
		return pinned_open_scripts.duplicate(true)
	func _n78() -> Array[String]:
		var _s61: Array[String] = []
		_s61.assign(pinned_open_script_order)
		return _s61
const _r27 = 15
const _i85 = 100
var _r7: Array[_f57] = []
var _n64: Array[_f57] = []
var _r68: _f57 = null  
var _n96: Dictionary = {}
var _p40: Array[String] = []
func _m11(user_message: String, ai_response: String, session_id: String = "", _d96: String = "", _u90: String = "", _k82: String = "") -> _f57:
	if user_message.is_empty() or ai_response.is_empty():
		return null
	if not _r68 or (not session_id.is_empty() and _r68.session_id != session_id):
		_b59(session_id)
	_r68._j94(user_message, ai_response, _d96, _u90, _k82)
	return _r68
func _f3(_s36: Dictionary, _k5: Array[String]) -> void:
	_n96 = _s36.duplicate(true)
	var _d50: Array[String] = []
	_d50.assign(_k5)
	_p40 = _d50
	if _r68:
		_r68._t13(_n96, _p40)
func _q90() -> Dictionary:
	if _r68:
		return _r68._e98()
	return _n96.duplicate(true)
func _o48() -> Array[String]:
	if _r68:
		return _r68._n78()
	var _s61: Array[String] = []
	_s61.assign(_p40)
	return _s61
func _b59(session_id: String = "") -> _f57:
	if _r68:
		_y76()
	_r68 = _f57.new(session_id)
	if not _n96.is_empty() or not _p40.is_empty():
		_r68._t13(_n96, _p40)
	return _r68
func _y76():
	if not _r68 or _r68._r13() == 0:
		_r68 = null
		return
	_r7.push_front(_r68)
	while _r7.size() > _r27:
		var removed = _r7.pop_back()
	_r68 = null
func _t69() -> _f57:
	return _r68
func _d27() -> Array[_f57]:
	return _r7.duplicate()
func _b31() -> Array[_f57]:
	return _n64.duplicate()
func _v51(timestamp: String) -> bool:
	for i in range(_r7.size()):
		var _y92 = _r7[i]
		if _y92.timestamp == timestamp:
			if _n64.size() >= _i85:
				return false
			_y92.is_favorite = true
			_n64.push_front(_y92)
			_r7.remove_at(i)
			_j92()
			return true
	return false
func _p78(timestamp: String) -> bool:
	for i in range(_n64.size()):
		var _y92 = _n64[i]
		if _y92.timestamp == timestamp:
			_y92.is_favorite = false
			_n64.remove_at(i)
			_r7.push_front(_y92)
			while _r7.size() > _r27:
				_r7.pop_back()
			_j92()
			return true
	return false
func _t83(timestamp: String, _w72: String) -> bool:
	if _w72.length() > 100:
		return false
	for _y92 in _r7:
		if _y92.timestamp == timestamp:
			_y92.custom_name = _w72
			_j92()
			return true
	for _y92 in _n64:
		if _y92.timestamp == timestamp:
			_y92.custom_name = _w72
			_j92()
			return true
	return false
func _k3(timestamp: String) -> bool:
	for i in range(_r7.size()):
		if _r7[i].timestamp == timestamp:
			_r7.remove_at(i)
			_j92()
			return true
	for i in range(_n64.size()):
		if _n64[i].timestamp == timestamp:
			_n64.remove_at(i)
			_j92()
			return true
	return false
func _n48(timestamp: String) -> _f57:
	for _y92 in _r7:
		if _y92.timestamp == timestamp:
			return _y92
	for _y92 in _n64:
		if _y92.timestamp == timestamp:
			return _y92
	return null
func _u70() -> void:
	_r7.clear()
func _l81() -> void:
	_n64.clear()
func _a31() -> void:
	_r7.clear()
	_n64.clear()
func _z65() -> int:
	return _r7.size() + _n64.size()
const _g80 = "user://chat_history.json"
const _m84 = "user://chat_history_backup.json"
func _j92() -> void:
	var _y94 = {
		"recent_chats": [],
		"favorite_chats": []
	}
	for _y92 in _r7:
		if _l32(_y92):
			_y94["recent_chats"].append(_q92(_y92))
		else:
			pass
	for _y92 in _n64:
		if _l32(_y92):
			_y94["favorite_chats"].append(_q92(_y92))
		else:
			pass
	_e97()
	var file = FileAccess.open(_g80, FileAccess.WRITE)
	if file:
		var _y80 = JSON.stringify(_y94, "\t")
		if _y80 and not _y80.is_empty():
			file.store_string(_y80)
			file.close()
		else:
			file.close()
			push_error("[ChatHistory] Failed to serialize chat data")
			_y88()
	else:
		push_error("[ChatHistory] Failed to save chat history to disk")
		_y88()
func _z60() -> void:
	var file = FileAccess.open(_g80, FileAccess.READ)
	if not file:
		return
	var _y80 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _v96 = json.parse(_y80)
	if _v96 != OK:
		push_error("[ChatHistory] Failed to parse history file: %s" % json.get_error_message())
		_y88()
		return
	var _y94 = json.data
	if not _y94 is Dictionary:
		push_error("[ChatHistory] Invalid history data format")
		_y88()
		return
	_r7.clear()
	_n64.clear()
	if _y94.has("recent_chats") and _y94["recent_chats"] is Array:
		for _j51 in _y94["recent_chats"]:
			if _j51 is Dictionary:
				var _y92 = _s80(_j51)
				if _y92 and _l32(_y92):
					_r7.append(_y92)
	if _y94.has("favorite_chats") and _y94["favorite_chats"] is Array:
		for _j51 in _y94["favorite_chats"]:
			if _j51 is Dictionary:
				var _y92 = _s80(_j51)
				if _y92 and _l32(_y92):
					_y92.is_favorite = true
					_n64.append(_y92)
func _l32(_y92: _f57) -> bool:
	if not _y92:
		return false
	if not _y92.pinned_open_scripts is Dictionary:
		_y92.pinned_open_scripts = {}
	if not _y92.pinned_open_script_order is Array:
		_y92.pinned_open_script_order = _y92.pinned_open_scripts.keys()
	if _y92.timestamp.is_empty():
		return false
	if _y92.exchanges.is_empty():
		return false
	for _t47 in _y92.exchanges:
		if not _t47 is Dictionary:
			return false
		if not _t47.has("user_message") or not _t47.has("ai_response"):
			return false
		if _t47["user_message"].is_empty() or _t47["ai_response"].is_empty():
			return false
		if _t47["user_message"].length() > 100000 or _t47["ai_response"].length() > 500000:
			return false
		if _t47.has("enhanced_user_message") and _t47["enhanced_user_message"].length() > 200000:
			return false
	return true
func _q92(_y92: _f57) -> Dictionary:
	return {
		"exchanges": _y92.exchanges,
		"timestamp": _y92.timestamp,
		"last_updated": _y92.last_updated,
		"is_favorite": _y92.is_favorite,
		"custom_name": _y92.custom_name,
		"session_id": _y92.session_id,
		"pinned_open_scripts": _y92.pinned_open_scripts,
		"pinned_open_script_order": _y92.pinned_open_script_order,
		"model_used": _y92._k82
	}
func _s80(data: Dictionary) -> _f57:
	if not data.has("exchanges") or not data.has("timestamp"):
		return null
	var session_id = data.get("session_id", "")
	var _y92 = _f57.new(session_id, data.get("is_favorite", false), data.get("custom_name", ""))
	_y92.exchanges = data.get("exchanges", [])
	_y92.timestamp = data.get("timestamp", "")
	_y92.last_updated = data.get("last_updated", _y92.timestamp)
	_y92.pinned_open_scripts = data.get("pinned_open_scripts", {})
	if not _y92.pinned_open_scripts is Dictionary:
		_y92.pinned_open_scripts = {}
	var _f100 = data.get("pinned_open_script_order", [])
	var _d50: Array[String] = []
	if _f100 is Array:
		for _s38 in _f100:
			if _s38 is String:
				_d50.append(_s38)
	else:
		for _y40 in _y92.pinned_open_scripts.keys():
			if _y40 is String:
				_d50.append(_y40)
	_y92.pinned_open_script_order = _d50
	_y92._k82 = data.get("model_used", "")
	return _y92
func _e97() -> void:
	if FileAccess.file_exists(_g80):
		var source = FileAccess.open(_g80, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			var _r66 = FileAccess.open(_m84, FileAccess.WRITE)
			if _r66:
				_r66.store_string(content)
				_r66.close()
func _y88() -> void:
	if not FileAccess.file_exists(_m84):
		return
	var _r66 = FileAccess.open(_m84, FileAccess.READ)
	if _r66:
		var content = _r66.get_as_text()
		_r66.close()
		var _s21 = FileAccess.open(_g80, FileAccess.WRITE)
		if _s21:
			_s21.store_string(content)
			_s21.close()
			_z60()
func _t99() -> String:
	var _k73 = "ChatHistory Debug Info:\n"
	_k73 += "Recent chats: %d\n" % _r7.size()
	_k73 += "Favorite chats: %d\n" % _n64.size()
	_k73 += "Total chats: %d\n" % _z65()
	_k73 += "\nRecent Chats:\n"
	for _y92 in _r7:
		_k73 += "  - %s (%s)\n" % [_y92._v74(), _y92._q22()]
	_k73 += "\nFavorite Chats:\n"
	for _y92 in _n64:
		_k73 += "  - %s (%s)\n" % [_y92._v74(), _y92._q22()]
	return _k73
