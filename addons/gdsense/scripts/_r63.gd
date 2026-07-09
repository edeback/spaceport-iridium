@tool
class_name _x57
extends RefCounted

class _n41:
	var exchanges: Array  
	var timestamp: String  
	var is_favorite: bool
	var custom_name: String
	var session_id: String  
	var last_updated: String  
	var pinned_open_scripts: Dictionary
	var pinned_open_script_order: Array[String]
	var _v88: String  

	func _init(_q6: String = "", _h13: bool = false, name: String = ""):
		exchanges = []
		timestamp = Time.get_datetime_string_from_system()
		last_updated = timestamp
		is_favorite = _h13
		custom_name = name
		session_id = _q6 if not _q6.is_empty() else _f41()
		pinned_open_scripts = {}
		pinned_open_script_order = []
		_v88 = ""

	func _f41() -> String:
		return "local_%d" % Time.get_ticks_msec()

	static func _y69(message: String) -> String:
		if not message.begins_with("# Context Information"):
			return message  

		var _w55 = "\n\n# User Request\n\n"
		var _y84 = message.find(_w55)
		if _y84 != -1:
			var _t2 = message.substr(_y84 + _w55.length())
			if not _t2.is_empty():
				return _t2.strip_edges()

		var _m10 = "\n---\n\n"
		_y84 = message.find(_m10)
		if _y84 != -1:
			var _e49 = message.substr(_y84 + _m10.length())
			if _e49.begins_with("# User Request\n\n"):
				_e49 = _e49.substr("# User Request\n\n".length())
			if not _e49.is_empty():
				return _e49.strip_edges()

		return message

	func _v11(_r41: String, _u25: String, _d30: String = "", _e40: String = "", model: String = ""):
		var _t11 = {
			"user_message": _r41,
			"ai_response": _u25
		}

		_t11["enhanced_user_message"] = _e40 if not _e40.is_empty() else _r41

		if not _d30.is_empty():
			_t11["thought_signature"] = _d30
		exchanges.append(_t11)
		last_updated = Time.get_datetime_string_from_system()

		if _v88.is_empty() and not model.is_empty():
			_v88 = model

	func _l34() -> String:
		return "%s" % timestamp.substr(0, 19).replace("T", " ")

	func _e45(_j35: int = 50) -> String:
		if not custom_name.is_empty():
			return custom_name

		if exchanges.is_empty():
			return "(Empty session)"

		var _w11 = exchanges[0]

		var _l44 = _n41._y69(_w11["user_message"]).strip_edges()
		if _l44.length() > _j35:
			return _l44.substr(0, _j35) + "..."
		return _l44

	func _x63() -> String:
		if not custom_name.is_empty():
			return custom_name
		return _e45(40)

	func _i44() -> int:
		return exchanges.size()

	func _e64() -> String:
		if exchanges.is_empty():
			return ""

		return _n41._y69(exchanges[0]["user_message"])

	func _f45() -> String:
		if exchanges.is_empty():
			return ""
		return exchanges[0]["ai_response"]

	func _d34() -> String:
		var text = ""
		for i in range(exchanges.size()):
			var _t11 = exchanges[i]
			text += "Turn %d:\n" % (i + 1)

			text += "User: %s\n" % _n41._y69(_t11["user_message"])
			text += "AI: %s\n\n" % _t11["ai_response"]
		return text

	func _u73(_i72: Dictionary, _z71: Array[String]) -> void:
		pinned_open_scripts = _i72.duplicate(true)

		var _c54: Array[String] = []
		_c54.assign(_z71)
		pinned_open_script_order = _c54

	func _h26() -> Dictionary:
		return pinned_open_scripts.duplicate(true)

	func _u21() -> Array[String]:
		var _x97: Array[String] = []
		_x97.assign(pinned_open_script_order)
		return _x97

const _b62 = 15

const _y96 = 100

var _o90: Array[_n41] = []
var _s58: Array[_n41] = []
var _f78: _n41 = null  
var _q72: Dictionary = {}
var _i85: Array[String] = []

func _s89(user_message: String, ai_response: String, session_id: String = "", _c83: String = "", _w37: String = "", _v88: String = "") -> _n41:
	if user_message.is_empty() or ai_response.is_empty():
		return null

	if not _f78 or (not session_id.is_empty() and _f78.session_id != session_id):
		_u45(session_id)

	_f78._v11(user_message, ai_response, _c83, _w37, _v88)

	return _f78

func _q100(_i72: Dictionary, _z71: Array[String]) -> void:
	_q72 = _i72.duplicate(true)

	var _c54: Array[String] = []
	_c54.assign(_z71)
	_i85 = _c54
	if _f78:
		_f78._u73(_q72, _i85)

func _z61() -> Dictionary:
	if _f78:
		return _f78._h26()
	return _q72.duplicate(true)

func _j41() -> Array[String]:
	if _f78:
		return _f78._u21()

	var _x97: Array[String] = []
	_x97.assign(_i85)
	return _x97

func _u45(session_id: String = "") -> _n41:
	if _f78:
		_l97()

	_f78 = _n41.new(session_id)
	if not _q72.is_empty() or not _i85.is_empty():
		_f78._u73(_q72, _i85)

	return _f78

func _l97():
	if not _f78 or _f78._i44() == 0:
		_f78 = null
		return

	_o90.push_front(_f78)

	while _o90.size() > _b62:
		var removed = _o90.pop_back()
	_f78 = null

func _r18() -> _n41:
	return _f78

func _p89() -> Array[_n41]:
	return _o90.duplicate()

func _k52() -> Array[_n41]:
	return _s58.duplicate()

func _v56(timestamp: String) -> bool:
	for i in range(_o90.size()):
		var _h5 = _o90[i]
		if _h5.timestamp == timestamp:
			if _s58.size() >= _y96:
				return false

			_h5.is_favorite = true
			_s58.push_front(_h5)
			_o90.remove_at(i)

			_s19()
			return true

	return false

func _m93(timestamp: String) -> bool:
	for i in range(_s58.size()):
		var _h5 = _s58[i]
		if _h5.timestamp == timestamp:
			_h5.is_favorite = false
			_s58.remove_at(i)

			_o90.push_front(_h5)
			while _o90.size() > _b62:
				_o90.pop_back()

			_s19()
			return true

	return false

func _n85(timestamp: String, _o77: String) -> bool:
	if _o77.length() > 100:
		return false

	for _h5 in _o90:
		if _h5.timestamp == timestamp:
			_h5.custom_name = _o77
			_s19()
			return true

	for _h5 in _s58:
		if _h5.timestamp == timestamp:
			_h5.custom_name = _o77
			_s19()
			return true

	return false

func _d13(timestamp: String) -> bool:
	for i in range(_o90.size()):
		if _o90[i].timestamp == timestamp:
			_o90.remove_at(i)
			_s19()
			return true

	for i in range(_s58.size()):
		if _s58[i].timestamp == timestamp:
			_s58.remove_at(i)
			_s19()
			return true

	return false

func _e67(timestamp: String) -> _n41:
	for _h5 in _o90:
		if _h5.timestamp == timestamp:
			return _h5

	for _h5 in _s58:
		if _h5.timestamp == timestamp:
			return _h5

	return null

func _g92() -> void:
	_o90.clear()
func _m51() -> void:
	_s58.clear()
func _v65() -> void:
	_o90.clear()
	_s58.clear()
func _q12() -> int:
	return _o90.size() + _s58.size()

const _f34 = "user://chat_history.json"
const _x47 = "user://chat_history_backup.json"

func _s19() -> void:
	var _m54 = {
		"recent_chats": [],
		"favorite_chats": []
	}

	for _h5 in _o90:
		if _m19(_h5):
			_m54["recent_chats"].append(_y22(_h5))
		else:
			pass

	for _h5 in _s58:
		if _m19(_h5):
			_m54["favorite_chats"].append(_y22(_h5))
		else:
			pass

	_d9()

	var file = FileAccess.open(_f34, FileAccess.WRITE)
	if file:
		var _j32 = JSON.stringify(_m54, "\t")
		if _j32 and not _j32.is_empty():
			file.store_string(_j32)
			file.close()

		else:
			file.close()
			push_error("[ChatHistory] Failed to serialize chat data")
			_u95()
	else:
		push_error("[ChatHistory] Failed to save chat history to disk")
		_u95()

func _m47() -> void:
	var file = FileAccess.open(_f34, FileAccess.READ)
	if not file:
		return

	var _j32 = file.get_as_text()
	file.close()

	var json = JSON.new()
	var _o36 = json.parse(_j32)

	if _o36 != OK:
		push_error("[ChatHistory] Failed to parse history file: %s" % json.get_error_message())
		_u95()
		return

	var _m54 = json.data
	if not _m54 is Dictionary:
		push_error("[ChatHistory] Invalid history data format")
		_u95()
		return

	_o90.clear()
	_s58.clear()

	if _m54.has("recent_chats") and _m54["recent_chats"] is Array:
		for _t85 in _m54["recent_chats"]:
			if _t85 is Dictionary:
				var _h5 = _x8(_t85)
				if _h5 and _m19(_h5):
					_o90.append(_h5)

	if _m54.has("favorite_chats") and _m54["favorite_chats"] is Array:
		for _t85 in _m54["favorite_chats"]:
			if _t85 is Dictionary:
				var _h5 = _x8(_t85)
				if _h5 and _m19(_h5):
					_h5.is_favorite = true
					_s58.append(_h5)

func _m19(_h5: _n41) -> bool:
	if not _h5:
		return false

	if not _h5.pinned_open_scripts is Dictionary:
		_h5.pinned_open_scripts = {}
	if not _h5.pinned_open_script_order is Array:
		_h5.pinned_open_script_order = _h5.pinned_open_scripts.keys()

	if _h5.timestamp.is_empty():
		return false

	if _h5.exchanges.is_empty():
		return false

	for _t11 in _h5.exchanges:
		if not _t11 is Dictionary:
			return false
		if not _t11.has("user_message") or not _t11.has("ai_response"):
			return false
		if _t11["user_message"].is_empty() or _t11["ai_response"].is_empty():
			return false

		if _t11["user_message"].length() > 100000 or _t11["ai_response"].length() > 500000:
			return false

		if _t11.has("enhanced_user_message") and _t11["enhanced_user_message"].length() > 200000:
			return false

	return true

func _y22(_h5: _n41) -> Dictionary:
	return {
		"exchanges": _h5.exchanges,
		"timestamp": _h5.timestamp,
		"last_updated": _h5.last_updated,
		"is_favorite": _h5.is_favorite,
		"custom_name": _h5.custom_name,
		"session_id": _h5.session_id,
		"pinned_open_scripts": _h5.pinned_open_scripts,
		"pinned_open_script_order": _h5.pinned_open_script_order,
		"model_used": _h5._v88
	}

func _x8(data: Dictionary) -> _n41:
	if not data.has("exchanges") or not data.has("timestamp"):
		return null

	var session_id = data.get("session_id", "")
	var _h5 = _n41.new(session_id, data.get("is_favorite", false), data.get("custom_name", ""))

	_h5.exchanges = data.get("exchanges", [])

	_h5.timestamp = data.get("timestamp", "")
	_h5.last_updated = data.get("last_updated", _h5.timestamp)
	_h5.pinned_open_scripts = data.get("pinned_open_scripts", {})
	if not _h5.pinned_open_scripts is Dictionary:
		_h5.pinned_open_scripts = {}

	var _d44 = data.get("pinned_open_script_order", [])
	var _c54: Array[String] = []
	if _d44 is Array:
		for _y98 in _d44:
			if _y98 is String:
				_c54.append(_y98)
	else:
		for _t90 in _h5.pinned_open_scripts.keys():
			if _t90 is String:
				_c54.append(_t90)
	_h5.pinned_open_script_order = _c54

	_h5._v88 = data.get("model_used", "")

	return _h5

func _d9() -> void:
	if FileAccess.file_exists(_f34):
		var source = FileAccess.open(_f34, FileAccess.READ)
		if source:
			var content = source.get_as_text()
			source.close()

			var _s91 = FileAccess.open(_x47, FileAccess.WRITE)
			if _s91:
				_s91.store_string(content)
				_s91.close()
func _u95() -> void:
	if not FileAccess.file_exists(_x47):
		return

	var _s91 = FileAccess.open(_x47, FileAccess.READ)
	if _s91:
		var content = _s91.get_as_text()
		_s91.close()

		var _b93 = FileAccess.open(_f34, FileAccess.WRITE)
		if _b93:
			_b93.store_string(content)
			_b93.close()

			_m47()

func _t33() -> String:
	var _z1 = "ChatHistory Debug Info:\n"
	_z1 += "Recent chats: %d\n" % _o90.size()
	_z1 += "Favorite chats: %d\n" % _s58.size()
	_z1 += "Total chats: %d\n" % _q12()

	_z1 += "\nRecent Chats:\n"
	for _h5 in _o90:
		_z1 += "  - %s (%s)\n" % [_h5._x63(), _h5._l34()]

	_z1 += "\nFavorite Chats:\n"
	for _h5 in _s58:
		_z1 += "  - %s (%s)\n" % [_h5._x63(), _h5._l34()]

	return _z1

