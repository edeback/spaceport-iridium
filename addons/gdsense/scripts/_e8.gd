@tool
class_name _f28
extends RefCounted

class _x51:
	var exchanges: Array  
	var timestamp: String  
	var is_favorite: bool
	var custom_name: String
	var session_id: String  
	var last_updated: String  
	var pinned_open_scripts: Dictionary
	var pinned_open_script_order: Array[String]
	var _q17: String  

	func _init(_v26: String = "", _g61: bool = false, name: String = ""):
		exchanges = []
		timestamp = Time.get_datetime_string_from_system()
		last_updated = timestamp
		is_favorite = _g61
		custom_name = name
		session_id = _v26 if not _v26.is_empty() else _s69()
		pinned_open_scripts = {}
		pinned_open_script_order = []
		_q17 = ""

	func _s69() -> String:
		return "local_%d" % Time.get_ticks_msec()

	static func _h52(message: String) -> String:
		if not message.begins_with("# Context Information"):
			return message  

		var _p63 = "\n\n# User Request\n\n"
		var _u92 = message.find(_p63)
		if _u92 != -1:
			var _g34 = message.substr(_u92 + _p63.length())
			if not _g34.is_empty():
				return _g34.strip_edges()

		var _m66 = "\n---\n\n"
		_u92 = message.find(_m66)
		if _u92 != -1:
			var _l65 = message.substr(_u92 + _m66.length())
			if _l65.begins_with("# User Request\n\n"):
				_l65 = _l65.substr("# User Request\n\n".length())
			if not _l65.is_empty():
				return _l65.strip_edges()

		return message

	func _s77(_u49: String, _q34: String, _b72: String = "", _z7: String = "", model: String = ""):
		var _b29 = {
			"user_message": _u49,
			"ai_response": _q34
		}

		_b29["enhanced_user_message"] = _z7 if not _z7.is_empty() else _u49

		if not _b72.is_empty():
			_b29["thought_signature"] = _b72
		exchanges.append(_b29)
		last_updated = Time.get_datetime_string_from_system()

		if _q17.is_empty() and not model.is_empty():
			_q17 = model

	func _s57() -> String:
		return "%s" % timestamp.substr(0, 19).replace("T", " ")

	func _d86(_h92: int = 50) -> String:
		if not custom_name.is_empty():
			return custom_name

		if exchanges.is_empty():
			return "(Empty session)"

		var _f29 = exchanges[0]

		var _k21 = _x51._h52(_f29["user_message"]).strip_edges()
		if _k21.length() > _h92:
			return _k21.substr(0, _h92) + "..."
		return _k21

	func _s72() -> String:
		if not custom_name.is_empty():
			return custom_name
		return _d86(40)

	func _p47() -> int:
		return exchanges.size()

	func _p37() -> String:
		if exchanges.is_empty():
			return ""

		return _x51._h52(exchanges[0]["user_message"])

	func _q5() -> String:
		if exchanges.is_empty():
			return ""
		return exchanges[0]["ai_response"]

	func _v59() -> String:
		var text = ""
		for i in range(exchanges.size()):
			var _b29 = exchanges[i]
			text += "Turn %d:\n" % (i + 1)

			text += "User: %s\n" % _x51._h52(_b29["user_message"])
			text += "AI: %s\n\n" % _b29["ai_response"]
		return text

	func _c97(_a31: Dictionary, _v72: Array[String]) -> void:
		pinned_open_scripts = _a31.duplicate(true)

		var _l1: Array[String] = []
		_l1.assign(_v72)
		pinned_open_script_order = _l1

	func _q74() -> Dictionary:
		return pinned_open_scripts.duplicate(true)

	func _s88() -> Array[String]:
		var _k3: Array[String] = []
		_k3.assign(pinned_open_script_order)
		return _k3

const _e88 = 15

const _t71 = 100

var _x85: Array[_x51] = []
var _g65: Array[_x51] = []
var _b10: _x51 = null  
var _v56: Dictionary = {}
var _g45: Array[String] = []

func _r94(user_message: String, ai_response: String, session_id: String = "", _y8: String = "", _f1: String = "", _q17: String = "") -> _x51:
	if user_message.is_empty() or ai_response.is_empty():
		return null

	if not _b10 or (not session_id.is_empty() and _b10.session_id != session_id):
		_k69(session_id)

	_b10._s77(user_message, ai_response, _y8, _f1, _q17)

	return _b10

func _s63(_a31: Dictionary, _v72: Array[String]) -> void:
	_v56 = _a31.duplicate(true)

	var _l1: Array[String] = []
	_l1.assign(_v72)
	_g45 = _l1
	if _b10:
		_b10._c97(_v56, _g45)

func _m69() -> Dictionary:
	if _b10:
		return _b10._q74()
	return _v56.duplicate(true)

func _p58() -> Array[String]:
	if _b10:
		return _b10._s88()

	var _k3: Array[String] = []
	_k3.assign(_g45)
	return _k3

func _k69(session_id: String = "") -> _x51:
	if _b10:
		_v94()

	_b10 = _x51.new(session_id)
	if not _v56.is_empty() or not _g45.is_empty():
		_b10._c97(_v56, _g45)

	return _b10

func _v94():
	if not _b10 or _b10._p47() == 0:
		_b10 = null
		return

	_x85.push_front(_b10)

	while _x85.size() > _e88:
		var removed = _x85.pop_back()
	_b10 = null

func _i50() -> _x51:
	return _b10

func _v10() -> Array[_x51]:
	return _x85.duplicate()

func _p80() -> Array[_x51]:
	return _g65.duplicate()

func _b34(timestamp: String) -> bool:
	for i in range(_x85.size()):
		var _j91 = _x85[i]
		if _j91.timestamp == timestamp:
			if _g65.size() >= _t71:
				return false

			_j91.is_favorite = true
			_g65.push_front(_j91)
			_x85.remove_at(i)

			_p31()
			return true

	return false

func _o39(timestamp: String) -> bool:
	for i in range(_g65.size()):
		var _j91 = _g65[i]
		if _j91.timestamp == timestamp:
			_j91.is_favorite = false
			_g65.remove_at(i)

			_x85.push_front(_j91)
			while _x85.size() > _e88:
				_x85.pop_back()

			_p31()
			return true

	return false

func _u72(timestamp: String, _q21: String) -> bool:
	if _q21.length() > 100:
		return false

	for _j91 in _x85:
		if _j91.timestamp == timestamp:
			_j91.custom_name = _q21
			_p31()
			return true

	for _j91 in _g65:
		if _j91.timestamp == timestamp:
			_j91.custom_name = _q21
			_p31()
			return true

	return false

func _s48(timestamp: String) -> bool:
	for i in range(_x85.size()):
		if _x85[i].timestamp == timestamp:
			_x85.remove_at(i)
			_p31()
			return true

	for i in range(_g65.size()):
		if _g65[i].timestamp == timestamp:
			_g65.remove_at(i)
			_p31()
			return true

	return false

func _d25(timestamp: String) -> _x51:
	for _j91 in _x85:
		if _j91.timestamp == timestamp:
			return _j91

	for _j91 in _g65:
		if _j91.timestamp == timestamp:
			return _j91

	return null

func _x26() -> void:
	_x85.clear()
func _l86() -> void:
	_g65.clear()
func _m19() -> void:
	_x85.clear()
	_g65.clear()
func _j95() -> int:
	return _x85.size() + _g65.size()

const _g10 = "user://chat_history.json"
const _q44 = "user://chat_history_backup.json"

func _p31() -> void:
	var _i66 = {
		"recent_chats": [],
		"favorite_chats": []
	}

	for _j91 in _x85:
		if _f88(_j91):
			_i66["recent_chats"].append(_z4(_j91))
		else:
			pass

	for _j91 in _g65:
		if _f88(_j91):
			_i66["favorite_chats"].append(_z4(_j91))
		else:
			pass

	_t42()

	var file = FileAccess.open(_g10, FileAccess.WRITE)
	if file:
		var _r87 = JSON.stringify(_i66, "\t")
		if _r87 and not _r87.is_empty():
			file.store_string(_r87)
			file.close()

		else:
			file.close()
			push_error("[ChatHistory] Failed to serialize chat data")
			_z56()
	else:
		push_error("[ChatHistory] Failed to save chat history to disk")
		_z56()

func _z100() -> void:
	var file = FileAccess.open(_g10, FileAccess.READ)
	if not file:
		return

	var _r87 = file.get_as_text()
	file.close()

	var json = JSON.new()
	var _d58 = json.parse(_r87)

	if _d58 != OK:
		push_error("[ChatHistory] Failed to parse history file: %s" % json.get_error_message())
		_z56()
		return

	var _i66 = json.data
	if not _i66 is Dictionary:
		push_error("[ChatHistory] Invalid history data format")
		_z56()
		return

	_x85.clear()
	_g65.clear()

	if _i66.has("recent_chats") and _i66["recent_chats"] is Array:
		for _h10 in _i66["recent_chats"]:
			if _h10 is Dictionary:
				var _j91 = _r53(_h10)
				if _j91 and _f88(_j91):
					_x85.append(_j91)

	if _i66.has("favorite_chats") and _i66["favorite_chats"] is Array:
		for _h10 in _i66["favorite_chats"]:
			if _h10 is Dictionary:
				var _j91 = _r53(_h10)
				if _j91 and _f88(_j91):
					_j91.is_favorite = true
					_g65.append(_j91)

func _f88(_j91: _x51) -> bool:
	if not _j91:
		return false

	if not _j91.pinned_open_scripts is Dictionary:
		_j91.pinned_open_scripts = {}
	if not _j91.pinned_open_script_order is Array:
		_j91.pinned_open_script_order = _j91.pinned_open_scripts.keys()

	if _j91.timestamp.is_empty():
		return false

	if _j91.exchanges.is_empty():
		return false

	for _b29 in _j91.exchanges:
		if not _b29 is Dictionary:
			return false
		if not _b29.has("user_message") or not _b29.has("ai_response"):
			return false
		if _b29["user_message"].is_empty() or _b29["ai_response"].is_empty():
			return false

		if _b29["user_message"].length() > 100000 or _b29["ai_response"].length() > 500000:
			return false

		if _b29.has("enhanced_user_message") and _b29["enhanced_user_message"].length() > 200000:
			return false

	return true

func _z4(_j91: _x51) -> Dictionary:
	return {
		"exchanges": _j91.exchanges,
		"timestamp": _j91.timestamp,
		"last_updated": _j91.last_updated,
		"is_favorite": _j91.is_favorite,
		"custom_name": _j91.custom_name,
		"session_id": _j91.session_id,
		"pinned_open_scripts": _j91.pinned_open_scripts,
		"pinned_open_script_order": _j91.pinned_open_script_order,
		"model_used": _j91._q17
	}

func _r53(data: Dictionary) -> _x51:
	if not data.has("exchanges") or not data.has("timestamp"):
		return null

	var session_id = data.get("session_id", "")
	var _j91 = _x51.new(session_id, data.get("is_favorite", false), data.get("custom_name", ""))

	_j91.exchanges = data.get("exchanges", [])

	_j91.timestamp = data.get("timestamp", "")
	_j91.last_updated = data.get("last_updated", _j91.timestamp)
	_j91.pinned_open_scripts = data.get("pinned_open_scripts", {})
	if not _j91.pinned_open_scripts is Dictionary:
		_j91.pinned_open_scripts = {}

	var _l52 = data.get("pinned_open_script_order", [])
	var _l1: Array[String] = []
	if _l52 is Array:
		for _c53 in _l52:
			if _c53 is String:
				_l1.append(_c53)
	else:
		for _y48 in _j91.pinned_open_scripts.keys():
			if _y48 is String:
				_l1.append(_y48)
	_j91.pinned_open_script_order = _l1

	_j91._q17 = data.get("model_used", "")

	return _j91

func _t42() -> void:
	if FileAccess.file_exists(_g10):
		var source = FileAccess.open(_g10, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()

			var _o46 = FileAccess.open(_q44, FileAccess.WRITE)
			if _o46:
				_o46.store_string(content)
				_o46.close()
func _z56() -> void:
	if not FileAccess.file_exists(_q44):
		return

	var _o46 = FileAccess.open(_q44, FileAccess.READ)
	if _o46:
		var content = _o46.get_as_text()
		_o46.close()

		var _s25 = FileAccess.open(_g10, FileAccess.WRITE)
		if _s25:
			_s25.store_string(content)
			_s25.close()

			_z100()

func _h72() -> String:
	var _h31 = "ChatHistory Debug Info:\n"
	_h31 += "Recent chats: %d\n" % _x85.size()
	_h31 += "Favorite chats: %d\n" % _g65.size()
	_h31 += "Total chats: %d\n" % _j95()

	_h31 += "\nRecent Chats:\n"
	for _j91 in _x85:
		_h31 += "  - %s (%s)\n" % [_j91._s72(), _j91._s57()]

	_h31 += "\nFavorite Chats:\n"
	for _j91 in _g65:
		_h31 += "  - %s (%s)\n" % [_j91._s72(), _j91._s57()]

	return _h31

