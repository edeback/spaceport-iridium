@tool
class_name _d25
extends RefCounted
class _g63:
	var exchanges: Array  
	var timestamp: String  
	var is_favorite: bool
	var custom_name: String
	var session_id: String  
	var last_updated: String  
	var pinned_open_scripts: Dictionary
	var pinned_open_script_order: Array[String]
	var _r14: String  
	func _init(_x30: String = "", _h52: bool = false, name: String = ""):
		exchanges = []
		timestamp = Time.get_datetime_string_from_system()
		last_updated = timestamp
		is_favorite = _h52
		custom_name = name
		session_id = _x30 if not _x30.is_empty() else _q44()
		pinned_open_scripts = {}
		pinned_open_script_order = []
		_r14 = ""
	func _q44() -> String:
		return "local_%d" % Time.get_ticks_msec()
	static func _u46(message: String) -> String:
		if not message.begins_with("# Context Information"):
			return message  
		var _e2 = "\n\n# User Request\n\n"
		var _k79 = message.find(_e2)
		if _k79 != -1:
			var _o28 = message.substr(_k79 + _e2.length())
			if not _o28.is_empty():
				return _o28.strip_edges()
		var _m25 = "\n---\n\n"
		_k79 = message.find(_m25)
		if _k79 != -1:
			var _s57 = message.substr(_k79 + _m25.length())
			if _s57.begins_with("# User Request\n\n"):
				_s57 = _s57.substr("# User Request\n\n".length())
			if not _s57.is_empty():
				return _s57.strip_edges()
		return message
	func _j12(_r63: String, _x28: String, _s29: String = "", _p67: String = "", model: String = ""):
		var _f43 = {
			"user_message": _r63,
			"ai_response": _x28
		}
		_f43["enhanced_user_message"] = _p67 if not _p67.is_empty() else _r63
		if not _s29.is_empty():
			_f43["thought_signature"] = _s29
		exchanges.append(_f43)
		last_updated = Time.get_datetime_string_from_system()
		if _r14.is_empty() and not model.is_empty():
			_r14 = model
	func _s30() -> String:
		return "%s" % timestamp.substr(0, 19).replace("T", " ")
	func _x69(_v10: int = 50) -> String:
		if not custom_name.is_empty():
			return custom_name
		if exchanges.is_empty():
			return "(Empty session)"
		var _u58 = exchanges[0]
		var _i97 = _g63._u46(_u58["user_message"]).strip_edges()
		if _i97.length() > _v10:
			return _i97.substr(0, _v10) + "..."
		return _i97
	func _i10() -> String:
		if not custom_name.is_empty():
			return custom_name
		return _x69(40)
	func _c53() -> int:
		return exchanges.size()
	func _t50() -> String:
		if exchanges.is_empty():
			return ""
		return _g63._u46(exchanges[0]["user_message"])
	func _g2() -> String:
		if exchanges.is_empty():
			return ""
		return exchanges[0]["ai_response"]
	func _x53() -> String:
		var text = ""
		for i in range(exchanges.size()):
			var _f43 = exchanges[i]
			text += "Turn %d:\n" % (i + 1)
			text += "User: %s\n" % _g63._u46(_f43["user_message"])
			text += "AI: %s\n\n" % _f43["ai_response"]
		return text
	func _l46(_v88: Dictionary, _e25: Array[String]) -> void:
		pinned_open_scripts = _v88.duplicate(true)
		var _r10: Array[String] = []
		_r10.assign(_e25)
		pinned_open_script_order = _r10
	func _k67() -> Dictionary:
		return pinned_open_scripts.duplicate(true)
	func _v35() -> Array[String]:
		var _x97: Array[String] = []
		_x97.assign(pinned_open_script_order)
		return _x97
const _w16 = 15
const _q35 = 100
var _b58: Array[_g63] = []
var _v12: Array[_g63] = []
var _q37: _g63 = null  
var _g52: Dictionary = {}
var _g27: Array[String] = []
func _j40(user_message: String, ai_response: String, session_id: String = "", _x6: String = "", _c87: String = "", _r14: String = "") -> _g63:
	if user_message.is_empty() or ai_response.is_empty():
		return null
	if not _q37 or (not session_id.is_empty() and _q37.session_id != session_id):
		_s19(session_id)
	_q37._j12(user_message, ai_response, _x6, _c87, _r14)
	return _q37
func _m22(_v88: Dictionary, _e25: Array[String]) -> void:
	_g52 = _v88.duplicate(true)
	var _r10: Array[String] = []
	_r10.assign(_e25)
	_g27 = _r10
	if _q37:
		_q37._l46(_g52, _g27)
func _r35() -> Dictionary:
	if _q37:
		return _q37._k67()
	return _g52.duplicate(true)
func _p70() -> Array[String]:
	if _q37:
		return _q37._v35()
	var _x97: Array[String] = []
	_x97.assign(_g27)
	return _x97
func _s19(session_id: String = "") -> _g63:
	if _q37:
		_i87()
	_q37 = _g63.new(session_id)
	if not _g52.is_empty() or not _g27.is_empty():
		_q37._l46(_g52, _g27)
	return _q37
func _i87():
	if not _q37 or _q37._c53() == 0:
		_q37 = null
		return
	_b58.push_front(_q37)
	while _b58.size() > _w16:
		var removed = _b58.pop_back()
	_q37 = null
func _h48() -> _g63:
	return _q37
func _u93() -> Array[_g63]:
	return _b58.duplicate()
func _c60() -> Array[_g63]:
	return _v12.duplicate()
func _z42(timestamp: String) -> bool:
	for i in range(_b58.size()):
		var _p42 = _b58[i]
		if _p42.timestamp == timestamp:
			if _v12.size() >= _q35:
				return false
			_p42.is_favorite = true
			_v12.push_front(_p42)
			_b58.remove_at(i)
			_w10()
			return true
	return false
func _j29(timestamp: String) -> bool:
	for i in range(_v12.size()):
		var _p42 = _v12[i]
		if _p42.timestamp == timestamp:
			_p42.is_favorite = false
			_v12.remove_at(i)
			_b58.push_front(_p42)
			while _b58.size() > _w16:
				_b58.pop_back()
			_w10()
			return true
	return false
func _m78(timestamp: String, _y60: String) -> bool:
	if _y60.length() > 100:
		return false
	for _p42 in _b58:
		if _p42.timestamp == timestamp:
			_p42.custom_name = _y60
			_w10()
			return true
	for _p42 in _v12:
		if _p42.timestamp == timestamp:
			_p42.custom_name = _y60
			_w10()
			return true
	return false
func _v77(timestamp: String) -> bool:
	for i in range(_b58.size()):
		if _b58[i].timestamp == timestamp:
			_b58.remove_at(i)
			_w10()
			return true
	for i in range(_v12.size()):
		if _v12[i].timestamp == timestamp:
			_v12.remove_at(i)
			_w10()
			return true
	return false
func _i66(timestamp: String) -> _g63:
	for _p42 in _b58:
		if _p42.timestamp == timestamp:
			return _p42
	for _p42 in _v12:
		if _p42.timestamp == timestamp:
			return _p42
	return null
func _s63() -> void:
	_b58.clear()
func _i85() -> void:
	_v12.clear()
func _j56() -> void:
	_b58.clear()
	_v12.clear()
func _x95() -> int:
	return _b58.size() + _v12.size()
const _a97 = "user://chat_history.json"
const _i53 = "user://chat_history_backup.json"
func _w10() -> void:
	var _x8 = {
		"recent_chats": [],
		"favorite_chats": []
	}
	for _p42 in _b58:
		if _l63(_p42):
			_x8["recent_chats"].append(_n23(_p42))
		else:
			pass
	for _p42 in _v12:
		if _l63(_p42):
			_x8["favorite_chats"].append(_n23(_p42))
		else:
			pass
	_m45()
	var file = FileAccess.open(_a97, FileAccess.WRITE)
	if file:
		var _t31 = JSON.stringify(_x8, "\t")
		if _t31 and not _t31.is_empty():
			file.store_string(_t31)
			file.close()
		else:
			file.close()
			push_error("[ChatHistory] Failed to serialize chat data")
			_h59()
	else:
		push_error("[ChatHistory] Failed to save chat history to disk")
		_h59()
func _m53() -> void:
	var file = FileAccess.open(_a97, FileAccess.READ)
	if not file:
		return
	var _t31 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _v55 = json.parse(_t31)
	if _v55 != OK:
		push_error("[ChatHistory] Failed to parse history file: %s" % json.get_error_message())
		_h59()
		return
	var _x8 = json.data
	if not _x8 is Dictionary:
		push_error("[ChatHistory] Invalid history data format")
		_h59()
		return
	_b58.clear()
	_v12.clear()
	if _x8.has("recent_chats") and _x8["recent_chats"] is Array:
		for _x47 in _x8["recent_chats"]:
			if _x47 is Dictionary:
				var _p42 = _y29(_x47)
				if _p42 and _l63(_p42):
					_b58.append(_p42)
	if _x8.has("favorite_chats") and _x8["favorite_chats"] is Array:
		for _x47 in _x8["favorite_chats"]:
			if _x47 is Dictionary:
				var _p42 = _y29(_x47)
				if _p42 and _l63(_p42):
					_p42.is_favorite = true
					_v12.append(_p42)
func _l63(_p42: _g63) -> bool:
	if not _p42:
		return false
	if not _p42.pinned_open_scripts is Dictionary:
		_p42.pinned_open_scripts = {}
	if not _p42.pinned_open_script_order is Array:
		_p42.pinned_open_script_order = _p42.pinned_open_scripts.keys()
	if _p42.timestamp.is_empty():
		return false
	if _p42.exchanges.is_empty():
		return false
	for _f43 in _p42.exchanges:
		if not _f43 is Dictionary:
			return false
		if not _f43.has("user_message") or not _f43.has("ai_response"):
			return false
		if _f43["user_message"].is_empty() or _f43["ai_response"].is_empty():
			return false
		if _f43["user_message"].length() > 100000 or _f43["ai_response"].length() > 500000:
			return false
		if _f43.has("enhanced_user_message") and _f43["enhanced_user_message"].length() > 200000:
			return false
	return true
func _n23(_p42: _g63) -> Dictionary:
	return {
		"exchanges": _p42.exchanges,
		"timestamp": _p42.timestamp,
		"last_updated": _p42.last_updated,
		"is_favorite": _p42.is_favorite,
		"custom_name": _p42.custom_name,
		"session_id": _p42.session_id,
		"pinned_open_scripts": _p42.pinned_open_scripts,
		"pinned_open_script_order": _p42.pinned_open_script_order,
		"model_used": _p42._r14
	}
func _y29(data: Dictionary) -> _g63:
	if not data.has("exchanges") or not data.has("timestamp"):
		return null
	var session_id = data.get("session_id", "")
	var _p42 = _g63.new(session_id, data.get("is_favorite", false), data.get("custom_name", ""))
	_p42.exchanges = data.get("exchanges", [])
	_p42.timestamp = data.get("timestamp", "")
	_p42.last_updated = data.get("last_updated", _p42.timestamp)
	_p42.pinned_open_scripts = data.get("pinned_open_scripts", {})
	if not _p42.pinned_open_scripts is Dictionary:
		_p42.pinned_open_scripts = {}
	var _z86 = data.get("pinned_open_script_order", [])
	var _r10: Array[String] = []
	if _z86 is Array:
		for _v92 in _z86:
			if _v92 is String:
				_r10.append(_v92)
	else:
		for _j26 in _p42.pinned_open_scripts.keys():
			if _j26 is String:
				_r10.append(_j26)
	_p42.pinned_open_script_order = _r10
	_p42._r14 = data.get("model_used", "")
	return _p42
func _m45() -> void:
	if FileAccess.file_exists(_a97):
		var source = FileAccess.open(_a97, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			var _c81 = FileAccess.open(_i53, FileAccess.WRITE)
			if _c81:
				_c81.store_string(content)
				_c81.close()
func _h59() -> void:
	if not FileAccess.file_exists(_i53):
		return
	var _c81 = FileAccess.open(_i53, FileAccess.READ)
	if _c81:
		var content = _c81.get_as_text()
		_c81.close()
		var _t13 = FileAccess.open(_a97, FileAccess.WRITE)
		if _t13:
			_t13.store_string(content)
			_t13.close()
			_m53()
func _g5() -> String:
	var _p29 = "ChatHistory Debug Info:\n"
	_p29 += "Recent chats: %d\n" % _b58.size()
	_p29 += "Favorite chats: %d\n" % _v12.size()
	_p29 += "Total chats: %d\n" % _x95()
	_p29 += "\nRecent Chats:\n"
	for _p42 in _b58:
		_p29 += "  - %s (%s)\n" % [_p42._i10(), _p42._s30()]
	_p29 += "\nFavorite Chats:\n"
	for _p42 in _v12:
		_p29 += "  - %s (%s)\n" % [_p42._i10(), _p42._s30()]
	return _p29
