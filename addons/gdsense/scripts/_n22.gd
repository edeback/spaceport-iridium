@tool
class_name _m71
extends RefCounted
class _m35:
	var exchanges: Array  
	var timestamp: String  
	var is_favorite: bool
	var custom_name: String
	var session_id: String  
	var last_updated: String  
	var pinned_open_scripts: Dictionary
	var pinned_open_script_order: Array[String]
	var _n25: String  
	func _init(_u77: String = "", _k39: bool = false, name: String = ""):
		exchanges = []
		timestamp = Time.get_datetime_string_from_system()
		last_updated = timestamp
		is_favorite = _k39
		custom_name = name
		session_id = _u77 if not _u77.is_empty() else _o82()
		pinned_open_scripts = {}
		pinned_open_script_order = []
		_n25 = ""
	func _o82() -> String:
		return "local_%d" % Time.get_ticks_msec()
	static func _e24(message: String) -> String:
		if not message.begins_with("# Context Information"):
			return message  
		var _r81 = "\n\n# User Request\n\n"
		var _t17 = message.find(_r81)
		if _t17 != -1:
			var _f68 = message.substr(_t17 + _r81.length())
			if not _f68.is_empty():
				return _f68.strip_edges()
		var _p83 = "\n---\n\n"
		_t17 = message.find(_p83)
		if _t17 != -1:
			var _b83 = message.substr(_t17 + _p83.length())
			if _b83.begins_with("# User Request\n\n"):
				_b83 = _b83.substr("# User Request\n\n".length())
			if not _b83.is_empty():
				return _b83.strip_edges()
		return message
	func _d22(_p23: String, _z73: String, _d6: String = "", _y21: String = "", model: String = ""):
		var _c85 = {
			"user_message": _p23,
			"ai_response": _z73
		}
		_c85["enhanced_user_message"] = _y21 if not _y21.is_empty() else _p23
		if not _d6.is_empty():
			_c85["thought_signature"] = _d6
		exchanges.append(_c85)
		last_updated = Time.get_datetime_string_from_system()
		if _n25.is_empty() and not model.is_empty():
			_n25 = model
	func _v7() -> String:
		return "%s" % timestamp.substr(0, 19).replace("T", " ")
	func _c59(_t83: int = 50) -> String:
		if not custom_name.is_empty():
			return custom_name
		if exchanges.is_empty():
			return "(Empty session)"
		var _v45 = exchanges[0]
		var _o20 = _m35._e24(_v45["user_message"]).strip_edges()
		if _o20.length() > _t83:
			return _o20.substr(0, _t83) + "..."
		return _o20
	func _y97() -> String:
		if not custom_name.is_empty():
			return custom_name
		return _c59(40)
	func _t1() -> int:
		return exchanges.size()
	func _x19() -> String:
		if exchanges.is_empty():
			return ""
		return _m35._e24(exchanges[0]["user_message"])
	func _b29() -> String:
		if exchanges.is_empty():
			return ""
		return exchanges[0]["ai_response"]
	func _h64() -> String:
		var text = ""
		for i in range(exchanges.size()):
			var _c85 = exchanges[i]
			text += "Turn %d:\n" % (i + 1)
			text += "User: %s\n" % _m35._e24(_c85["user_message"])
			text += "AI: %s\n\n" % _c85["ai_response"]
		return text
	func _r1(_e76: Dictionary, _f49: Array[String]) -> void:
		pinned_open_scripts = _e76.duplicate(true)
		var _z47: Array[String] = []
		_z47.assign(_f49)
		pinned_open_script_order = _z47
	func _k19() -> Dictionary:
		return pinned_open_scripts.duplicate(true)
	func _q20() -> Array[String]:
		var _e21: Array[String] = []
		_e21.assign(pinned_open_script_order)
		return _e21
const _f95 = 15
const _o21 = 100
var _d79: Array[_m35] = []
var _y92: Array[_m35] = []
var _l35: _m35 = null  
var _f86: Dictionary = {}
var _i87: Array[String] = []
func _o78(user_message: String, ai_response: String, session_id: String = "", _j43: String = "", _u30: String = "", _n25: String = "") -> _m35:
	if user_message.is_empty() or ai_response.is_empty():
		return null
	if not _l35 or (not session_id.is_empty() and _l35.session_id != session_id):
		_y78(session_id)
	_l35._d22(user_message, ai_response, _j43, _u30, _n25)
	return _l35
func _e60(_e76: Dictionary, _f49: Array[String]) -> void:
	_f86 = _e76.duplicate(true)
	var _z47: Array[String] = []
	_z47.assign(_f49)
	_i87 = _z47
	if _l35:
		_l35._r1(_f86, _i87)
func _w35() -> Dictionary:
	if _l35:
		return _l35._k19()
	return _f86.duplicate(true)
func _e32() -> Array[String]:
	if _l35:
		return _l35._q20()
	var _e21: Array[String] = []
	_e21.assign(_i87)
	return _e21
func _y78(session_id: String = "") -> _m35:
	if _l35:
		_r74()
	_l35 = _m35.new(session_id)
	if not _f86.is_empty() or not _i87.is_empty():
		_l35._r1(_f86, _i87)
	return _l35
func _r74():
	if not _l35 or _l35._t1() == 0:
		_l35 = null
		return
	_d79.push_front(_l35)
	while _d79.size() > _f95:
		var removed = _d79.pop_back()
	_l35 = null
func _t91() -> _m35:
	return _l35
func _n5() -> Array[_m35]:
	return _d79.duplicate()
func _n61() -> Array[_m35]:
	return _y92.duplicate()
func _u62(timestamp: String) -> bool:
	for i in range(_d79.size()):
		var _r10 = _d79[i]
		if _r10.timestamp == timestamp:
			if _y92.size() >= _o21:
				return false
			_r10.is_favorite = true
			_y92.push_front(_r10)
			_d79.remove_at(i)
			_d97()
			return true
	return false
func _v62(timestamp: String) -> bool:
	for i in range(_y92.size()):
		var _r10 = _y92[i]
		if _r10.timestamp == timestamp:
			_r10.is_favorite = false
			_y92.remove_at(i)
			_d79.push_front(_r10)
			while _d79.size() > _f95:
				_d79.pop_back()
			_d97()
			return true
	return false
func _b75(timestamp: String, _y39: String) -> bool:
	if _y39.length() > 100:
		return false
	for _r10 in _d79:
		if _r10.timestamp == timestamp:
			_r10.custom_name = _y39
			_d97()
			return true
	for _r10 in _y92:
		if _r10.timestamp == timestamp:
			_r10.custom_name = _y39
			_d97()
			return true
	return false
func _t97(timestamp: String) -> bool:
	for i in range(_d79.size()):
		if _d79[i].timestamp == timestamp:
			_d79.remove_at(i)
			_d97()
			return true
	for i in range(_y92.size()):
		if _y92[i].timestamp == timestamp:
			_y92.remove_at(i)
			_d97()
			return true
	return false
func _b36(timestamp: String) -> _m35:
	for _r10 in _d79:
		if _r10.timestamp == timestamp:
			return _r10
	for _r10 in _y92:
		if _r10.timestamp == timestamp:
			return _r10
	return null
func _y35() -> void:
	_d79.clear()
func _y25() -> void:
	_y92.clear()
func _v46() -> void:
	_d79.clear()
	_y92.clear()
func _d19() -> int:
	return _d79.size() + _y92.size()
const _d55 = "user://chat_history.json"
const _n26 = "user://chat_history_backup.json"
func _d97() -> void:
	var _b55 = {
		"recent_chats": [],
		"favorite_chats": []
	}
	for _r10 in _d79:
		if _s59(_r10):
			_b55["recent_chats"].append(_w83(_r10))
		else:
			pass
	for _r10 in _y92:
		if _s59(_r10):
			_b55["favorite_chats"].append(_w83(_r10))
		else:
			pass
	_f37()
	var file = FileAccess.open(_d55, FileAccess.WRITE)
	if file:
		var _f74 = JSON.stringify(_b55, "\t")
		if _f74 and not _f74.is_empty():
			file.store_string(_f74)
			file.close()
		else:
			file.close()
			push_error("[ChatHistory] Failed to serialize chat data")
			_k43()
	else:
		push_error("[ChatHistory] Failed to save chat history to disk")
		_k43()
func _v97() -> void:
	var file = FileAccess.open(_d55, FileAccess.READ)
	if not file:
		return
	var _f74 = file.get_as_text()
	file.close()
	var json = JSON.new()
	var _n76 = json.parse(_f74)
	if _n76 != OK:
		push_error("[ChatHistory] Failed to parse history file: %s" % json.get_error_message())
		_k43()
		return
	var _b55 = json.data
	if not _b55 is Dictionary:
		push_error("[ChatHistory] Invalid history data format")
		_k43()
		return
	_d79.clear()
	_y92.clear()
	if _b55.has("recent_chats") and _b55["recent_chats"] is Array:
		for _m84 in _b55["recent_chats"]:
			if _m84 is Dictionary:
				var _r10 = _q90(_m84)
				if _r10 and _s59(_r10):
					_d79.append(_r10)
	if _b55.has("favorite_chats") and _b55["favorite_chats"] is Array:
		for _m84 in _b55["favorite_chats"]:
			if _m84 is Dictionary:
				var _r10 = _q90(_m84)
				if _r10 and _s59(_r10):
					_r10.is_favorite = true
					_y92.append(_r10)
func _s59(_r10: _m35) -> bool:
	if not _r10:
		return false
	if not _r10.pinned_open_scripts is Dictionary:
		_r10.pinned_open_scripts = {}
	if not _r10.pinned_open_script_order is Array:
		_r10.pinned_open_script_order = _r10.pinned_open_scripts.keys()
	if _r10.timestamp.is_empty():
		return false
	if _r10.exchanges.is_empty():
		return false
	for _c85 in _r10.exchanges:
		if not _c85 is Dictionary:
			return false
		if not _c85.has("user_message") or not _c85.has("ai_response"):
			return false
		if _c85["user_message"].is_empty() or _c85["ai_response"].is_empty():
			return false
		if _c85["user_message"].length() > 100000 or _c85["ai_response"].length() > 500000:
			return false
		if _c85.has("enhanced_user_message") and _c85["enhanced_user_message"].length() > 200000:
			return false
	return true
func _w83(_r10: _m35) -> Dictionary:
	return {
		"exchanges": _r10.exchanges,
		"timestamp": _r10.timestamp,
		"last_updated": _r10.last_updated,
		"is_favorite": _r10.is_favorite,
		"custom_name": _r10.custom_name,
		"session_id": _r10.session_id,
		"pinned_open_scripts": _r10.pinned_open_scripts,
		"pinned_open_script_order": _r10.pinned_open_script_order,
		"model_used": _r10._n25
	}
func _q90(data: Dictionary) -> _m35:
	if not data.has("exchanges") or not data.has("timestamp"):
		return null
	var session_id = data.get("session_id", "")
	var _r10 = _m35.new(session_id, data.get("is_favorite", false), data.get("custom_name", ""))
	_r10.exchanges = data.get("exchanges", [])
	_r10.timestamp = data.get("timestamp", "")
	_r10.last_updated = data.get("last_updated", _r10.timestamp)
	_r10.pinned_open_scripts = data.get("pinned_open_scripts", {})
	if not _r10.pinned_open_scripts is Dictionary:
		_r10.pinned_open_scripts = {}
	var _z51 = data.get("pinned_open_script_order", [])
	var _z47: Array[String] = []
	if _z51 is Array:
		for _d48 in _z51:
			if _d48 is String:
				_z47.append(_d48)
	else:
		for _i19 in _r10.pinned_open_scripts.keys():
			if _i19 is String:
				_z47.append(_i19)
	_r10.pinned_open_script_order = _z47
	_r10._n25 = data.get("model_used", "")
	return _r10
func _f37() -> void:
	if FileAccess.file_exists(_d55):
		var source = FileAccess.open(_d55, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()
			var _o38 = FileAccess.open(_n26, FileAccess.WRITE)
			if _o38:
				_o38.store_string(content)
				_o38.close()
func _k43() -> void:
	if not FileAccess.file_exists(_n26):
		return
	var _o38 = FileAccess.open(_n26, FileAccess.READ)
	if _o38:
		var content = _o38.get_as_text()
		_o38.close()
		var _b14 = FileAccess.open(_d55, FileAccess.WRITE)
		if _b14:
			_b14.store_string(content)
			_b14.close()
			_v97()
func _n13() -> String:
	var _s83 = "ChatHistory Debug Info:\n"
	_s83 += "Recent chats: %d\n" % _d79.size()
	_s83 += "Favorite chats: %d\n" % _y92.size()
	_s83 += "Total chats: %d\n" % _d19()
	_s83 += "\nRecent Chats:\n"
	for _r10 in _d79:
		_s83 += "  - %s (%s)\n" % [_r10._y97(), _r10._v7()]
	_s83 += "\nFavorite Chats:\n"
	for _r10 in _y92:
		_s83 += "  - %s (%s)\n" % [_r10._y97(), _r10._v7()]
	return _s83
