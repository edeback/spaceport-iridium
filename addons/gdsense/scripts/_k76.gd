@tool
class_name _g31
extends RefCounted

class _x82:
	var exchanges: Array  
	var timestamp: String  
	var is_favorite: bool
	var custom_name: String
	var session_id: String  
	var last_updated: String  
	var pinned_open_scripts: Dictionary
	var pinned_open_script_order: Array[String]
	var _o96: String  

	func _init(_f97: String = "", _n64: bool = false, name: String = ""):
		exchanges = []
		timestamp = Time.get_datetime_string_from_system()
		last_updated = timestamp
		is_favorite = _n64
		custom_name = name
		session_id = _f97 if not _f97.is_empty() else _t19()
		pinned_open_scripts = {}
		pinned_open_script_order = []
		_o96 = ""

	func _t19() -> String:
		return "local_%d" % Time.get_ticks_msec()

	static func _h30(message: String) -> String:
		if not message.begins_with("# Context Information"):
			return message  

		var _x25 = "\n\n# User Request\n\n"
		var _j2 = message.find(_x25)
		if _j2 != -1:
			var _r5 = message.substr(_j2 + _x25.length())
			if not _r5.is_empty():
				return _r5.strip_edges()

		var _v40 = "\n---\n\n"
		_j2 = message.find(_v40)
		if _j2 != -1:
			var _u94 = message.substr(_j2 + _v40.length())
			if _u94.begins_with("# User Request\n\n"):
				_u94 = _u94.substr("# User Request\n\n".length())
			if not _u94.is_empty():
				return _u94.strip_edges()

		return message

	func _i76(_o62: String, _q14: String, _e54: String = "", _w52: String = "", model: String = ""):
		var _k17 = {
			"user_message": _o62,
			"ai_response": _q14
		}

		_k17["enhanced_user_message"] = _w52 if not _w52.is_empty() else _o62

		if not _e54.is_empty():
			_k17["thought_signature"] = _e54
		exchanges.append(_k17)
		last_updated = Time.get_datetime_string_from_system()

		if _o96.is_empty() and not model.is_empty():
			_o96 = model

	func _c45() -> String:
		return "%s" % timestamp.substr(0, 19).replace("T", " ")

	func _k12(_m71: int = 50) -> String:
		if not custom_name.is_empty():
			return custom_name

		if exchanges.is_empty():
			return "(Empty session)"

		var _t61 = exchanges[0]

		var _q83 = _x82._h30(_t61["user_message"]).strip_edges()
		if _q83.length() > _m71:
			return _q83.substr(0, _m71) + "..."
		return _q83

	func _e86() -> String:
		if not custom_name.is_empty():
			return custom_name
		return _k12(40)

	func _u22() -> int:
		return exchanges.size()

	func _q9() -> String:
		if exchanges.is_empty():
			return ""

		return _x82._h30(exchanges[0]["user_message"])

	func _b44() -> String:
		if exchanges.is_empty():
			return ""
		return exchanges[0]["ai_response"]

	func _p64() -> String:
		var text = ""
		for i in range(exchanges.size()):
			var _k17 = exchanges[i]
			text += "Turn %d:\n" % (i + 1)

			text += "User: %s\n" % _x82._h30(_k17["user_message"])
			text += "AI: %s\n\n" % _k17["ai_response"]
		return text

	func _r16(_k99: Dictionary, _q20: Array[String]) -> void:
		pinned_open_scripts = _k99.duplicate(true)

		var _f39: Array[String] = []
		_f39.assign(_q20)
		pinned_open_script_order = _f39

	func _x46() -> Dictionary:
		return pinned_open_scripts.duplicate(true)

	func _d17() -> Array[String]:
		var _v42: Array[String] = []
		_v42.assign(pinned_open_script_order)
		return _v42

const _p82 = 15

const _o26 = 100

var _b79: Array[_x82] = []
var _i75: Array[_x82] = []
var _c8: _x82 = null  
var _o27: Dictionary = {}
var _c44: Array[String] = []

func _j12(user_message: String, ai_response: String, session_id: String = "", _n80: String = "", _v96: String = "", _o96: String = "") -> _x82:
	if user_message.is_empty() or ai_response.is_empty():
		return null

	if not _c8 or (not session_id.is_empty() and _c8.session_id != session_id):
		_s36(session_id)

	_c8._i76(user_message, ai_response, _n80, _v96, _o96)

	return _c8

func _t63(_k99: Dictionary, _q20: Array[String]) -> void:
	_o27 = _k99.duplicate(true)

	var _f39: Array[String] = []
	_f39.assign(_q20)
	_c44 = _f39
	if _c8:
		_c8._r16(_o27, _c44)

func _n27() -> Dictionary:
	if _c8:
		return _c8._x46()
	return _o27.duplicate(true)

func _u39() -> Array[String]:
	if _c8:
		return _c8._d17()

	var _v42: Array[String] = []
	_v42.assign(_c44)
	return _v42

func _s36(session_id: String = "") -> _x82:
	if _c8:
		_x48()

	_c8 = _x82.new(session_id)
	if not _o27.is_empty() or not _c44.is_empty():
		_c8._r16(_o27, _c44)

	return _c8

func _x48():
	if not _c8 or _c8._u22() == 0:
		_c8 = null
		return

	_b79.push_front(_c8)

	while _b79.size() > _p82:
		var removed = _b79.pop_back()
	_c8 = null

func _p84() -> _x82:
	return _c8

func _s28() -> Array[_x82]:
	return _b79.duplicate()

func _l96() -> Array[_x82]:
	return _i75.duplicate()

func _t25(timestamp: String) -> bool:
	for i in range(_b79.size()):
		var _w90 = _b79[i]
		if _w90.timestamp == timestamp:
			if _i75.size() >= _o26:
				return false

			_w90.is_favorite = true
			_i75.push_front(_w90)
			_b79.remove_at(i)

			_g15()
			return true

	return false

func _z90(timestamp: String) -> bool:
	for i in range(_i75.size()):
		var _w90 = _i75[i]
		if _w90.timestamp == timestamp:
			_w90.is_favorite = false
			_i75.remove_at(i)

			_b79.push_front(_w90)
			while _b79.size() > _p82:
				_b79.pop_back()

			_g15()
			return true

	return false

func _i58(timestamp: String, _x55: String) -> bool:
	if _x55.length() > 100:
		return false

	for _w90 in _b79:
		if _w90.timestamp == timestamp:
			_w90.custom_name = _x55
			_g15()
			return true

	for _w90 in _i75:
		if _w90.timestamp == timestamp:
			_w90.custom_name = _x55
			_g15()
			return true

	return false

func _j20(timestamp: String) -> bool:
	for i in range(_b79.size()):
		if _b79[i].timestamp == timestamp:
			_b79.remove_at(i)
			_g15()
			return true

	for i in range(_i75.size()):
		if _i75[i].timestamp == timestamp:
			_i75.remove_at(i)
			_g15()
			return true

	return false

func _c32(timestamp: String) -> _x82:
	for _w90 in _b79:
		if _w90.timestamp == timestamp:
			return _w90

	for _w90 in _i75:
		if _w90.timestamp == timestamp:
			return _w90

	return null

func _o59() -> void:
	_b79.clear()
func _m11() -> void:
	_i75.clear()
func _e45() -> void:
	_b79.clear()
	_i75.clear()
func _v65() -> int:
	return _b79.size() + _i75.size()

const _k91 = "user://chat_history.json"
const _y73 = "user://chat_history_backup.json"

func _g15() -> void:
	var _u72 = {
		"recent_chats": [],
		"favorite_chats": []
	}

	for _w90 in _b79:
		if _l62(_w90):
			_u72["recent_chats"].append(_d22(_w90))
		else:
			pass

	for _w90 in _i75:
		if _l62(_w90):
			_u72["favorite_chats"].append(_d22(_w90))
		else:
			pass

	_y9()

	var file = FileAccess.open(_k91, FileAccess.WRITE)
	if file:
		var _w7 = JSON.stringify(_u72, "\t")
		if _w7 and not _w7.is_empty():
			file.store_string(_w7)
			file.close()

		else:
			file.close()
			push_error("[ChatHistory] Failed to serialize chat data")
			_x11()
	else:
		push_error("[ChatHistory] Failed to save chat history to disk")
		_x11()

func _x5() -> void:
	var file = FileAccess.open(_k91, FileAccess.READ)
	if not file:
		return

	var _w7 = file.get_as_text()
	file.close()

	var json = JSON.new()
	var _q58 = json.parse(_w7)

	if _q58 != OK:
		push_error("[ChatHistory] Failed to parse history file: %s" % json.get_error_message())
		_x11()
		return

	var _u72 = json.data
	if not _u72 is Dictionary:
		push_error("[ChatHistory] Invalid history data format")
		_x11()
		return

	_b79.clear()
	_i75.clear()

	if _u72.has("recent_chats") and _u72["recent_chats"] is Array:
		for _u25 in _u72["recent_chats"]:
			if _u25 is Dictionary:
				var _w90 = _m100(_u25)
				if _w90 and _l62(_w90):
					_b79.append(_w90)

	if _u72.has("favorite_chats") and _u72["favorite_chats"] is Array:
		for _u25 in _u72["favorite_chats"]:
			if _u25 is Dictionary:
				var _w90 = _m100(_u25)
				if _w90 and _l62(_w90):
					_w90.is_favorite = true
					_i75.append(_w90)

func _l62(_w90: _x82) -> bool:
	if not _w90:
		return false

	if not _w90.pinned_open_scripts is Dictionary:
		_w90.pinned_open_scripts = {}
	if not _w90.pinned_open_script_order is Array:
		_w90.pinned_open_script_order = _w90.pinned_open_scripts.keys()

	if _w90.timestamp.is_empty():
		return false

	if _w90.exchanges.is_empty():
		return false

	for _k17 in _w90.exchanges:
		if not _k17 is Dictionary:
			return false
		if not _k17.has("user_message") or not _k17.has("ai_response"):
			return false
		if _k17["user_message"].is_empty() or _k17["ai_response"].is_empty():
			return false

		if _k17["user_message"].length() > 100000 or _k17["ai_response"].length() > 500000:
			return false

		if _k17.has("enhanced_user_message") and _k17["enhanced_user_message"].length() > 200000:
			return false

	return true

func _d22(_w90: _x82) -> Dictionary:
	return {
		"exchanges": _w90.exchanges,
		"timestamp": _w90.timestamp,
		"last_updated": _w90.last_updated,
		"is_favorite": _w90.is_favorite,
		"custom_name": _w90.custom_name,
		"session_id": _w90.session_id,
		"pinned_open_scripts": _w90.pinned_open_scripts,
		"pinned_open_script_order": _w90.pinned_open_script_order,
		"model_used": _w90._o96
	}

func _m100(data: Dictionary) -> _x82:
	if not data.has("exchanges") or not data.has("timestamp"):
		return null

	var session_id = data.get("session_id", "")
	var _w90 = _x82.new(session_id, data.get("is_favorite", false), data.get("custom_name", ""))

	_w90.exchanges = data.get("exchanges", [])

	_w90.timestamp = data.get("timestamp", "")
	_w90.last_updated = data.get("last_updated", _w90.timestamp)
	_w90.pinned_open_scripts = data.get("pinned_open_scripts", {})
	if not _w90.pinned_open_scripts is Dictionary:
		_w90.pinned_open_scripts = {}

	var _m25 = data.get("pinned_open_script_order", [])
	var _f39: Array[String] = []
	if _m25 is Array:
		for _o32 in _m25:
			if _o32 is String:
				_f39.append(_o32)
	else:
		for _m15 in _w90.pinned_open_scripts.keys():
			if _m15 is String:
				_f39.append(_m15)
	_w90.pinned_open_script_order = _f39

	_w90._o96 = data.get("model_used", "")

	return _w90

func _y9() -> void:
	if FileAccess.file_exists(_k91):
		var source = FileAccess.open(_k91, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()

			var _y3 = FileAccess.open(_y73, FileAccess.WRITE)
			if _y3:
				_y3.store_string(content)
				_y3.close()
func _x11() -> void:
	if not FileAccess.file_exists(_y73):
		return

	var _y3 = FileAccess.open(_y73, FileAccess.READ)
	if _y3:
		var content = _y3.get_as_text()
		_y3.close()

		var _c55 = FileAccess.open(_k91, FileAccess.WRITE)
		if _c55:
			_c55.store_string(content)
			_c55.close()

			_x5()

func _z48() -> String:
	var _x17 = "ChatHistory Debug Info:\n"
	_x17 += "Recent chats: %d\n" % _b79.size()
	_x17 += "Favorite chats: %d\n" % _i75.size()
	_x17 += "Total chats: %d\n" % _v65()

	_x17 += "\nRecent Chats:\n"
	for _w90 in _b79:
		_x17 += "  - %s (%s)\n" % [_w90._e86(), _w90._c45()]

	_x17 += "\nFavorite Chats:\n"
	for _w90 in _i75:
		_x17 += "  - %s (%s)\n" % [_w90._e86(), _w90._c45()]

	return _x17

