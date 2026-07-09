@tool
class_name _a99
extends Node
signal _k16(_d40: String, _a79: Array, _u17: String, _e53: String)
signal _y58
signal _t37(_a6: int, _e13: String)
signal _p86
signal _z29(_h35: int, _o76: int, _r52: int)
signal _z92(_k91: String, _v88: int)
signal _t38(success: bool)
signal _w57(refactored_code: String, original_hash: String, function_name: String)
signal _s39(_r52: int, breakdown: Array, _y25: int)
signal _d6(_f58: Dictionary)
signal _f67(_l66: String, _r94: String, _p85: float, _w95: String)
signal _c79(message: String)
signal _z97(_p60: String, _e8: String)
var _x95: HTTPRequest
var _u40: HTTPRequest
var _c48: HTTPRequest
var _s10: HTTPRequest
var _p93: HTTPRequest
var _h87: HTTPRequest
var _x48: String = ""
var _p17: bool = false
var _y60: String = "https://api.gdsense.com/api/v1"
var _k78: int = 0
var _y72: String = ""
var _c68: String = ""
var _d15: Dictionary = {}  
var _u36: Dictionary = {}  
var _c83: String = ""  
const _l12 = 86400  
var _f57: String = ""
const _e60 = {
	"GROUP_FREE": [
		"openai/gpt-oss-20b",          
		"gemini-2.5-flash-lite",       
		"gpt-5-nano"                   
	],
	"GROUP_STD": [
		"openai/gpt-oss-120b",         
		"gemini-2.5-flash",            
		"gpt-5.1-codex-mini"           
	],
	"GROUP_PREM": [
		"moonshotai/kimi-k2-instruct-0905",  
		"moonshotai/kimi-k2-thinking-maas",  
		"gemini-3-flash-preview",      
		"gemini-3-pro-preview",        
		"gemini-2.5-pro",              
		"gpt-5.1-codex"                
	]
}
const _d63 = {
	"FREE": ["GROUP_FREE"],
	"STARTER": ["GROUP_FREE", "GROUP_STD"],
	"BETA_FREE": ["GROUP_FREE", "GROUP_STD"],
	"PRO": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"],
	"ULTRA": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
}
const _u76 = ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
func _enter_tree() -> void:
	_x95 = HTTPRequest.new()
	add_child(_x95)
	_x95.request_completed.connect(_q94)
	_u40 = HTTPRequest.new()
	add_child(_u40)
	_u40.request_completed.connect(_j32)
	_u40.timeout = 0.5  
	_c48 = HTTPRequest.new()
	add_child(_c48)
	_c48.request_completed.connect(_w76)
	_c48.timeout = 30.0  
	_s10 = HTTPRequest.new()
	add_child(_s10)
	_s10.request_completed.connect(_e22)
	_s10.timeout = 5.0  
	_p93 = HTTPRequest.new()
	add_child(_p93)
	_p93.request_completed.connect(_s81)
	_p93.timeout = 10.0  
	_h87 = HTTPRequest.new()
	add_child(_h87)
	_h87.request_completed.connect(_g94)
	_h87.timeout = 10.0  
	_x67()
	_y15()
	_q53()
	_p46()
	_m1()
	_s55.call_deferred()
	_k93.call_deferred()
func _q94(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray) -> void:
	if _n37 != HTTPRequest.RESULT_SUCCESS:
		_t37.emit(0, "Network error")
		return
	if _a6 != 200:
		if _a6 == 401:
			_y58.emit()
		elif _a6 == 403:
			var _w11 = "This feature/model is not available in your tier. Please upgrade."
			var json = JSON.new()
			var _a50 = json.parse(_v73.get_string_from_utf8())
			if _a50 == OK:
				var _o77 = json.get_data()
				if _o77 is Dictionary and _o77.has("message"):
					_w11 = _o77.get("message", _w11)
			_t37.emit(_a6, _w11)
		elif _a6 == 429:
			var _w11 = "You've exceeded your quota. Please wait before making more requests."
			var json = JSON.new()
			var _a50 = json.parse(_v73.get_string_from_utf8())
			if _a50 == OK:
				var _o77 = json.get_data()
				if _o77 is Dictionary:
					var _r94 = _o77.get("group", "")
					var _w95 = _o77.get("reset_date", "")
					if not _r94.is_empty():
						if not _w95.is_empty():
							_w11 = "You've exceeded your quota for %s. Resets on %s." % [_r94, _c33(_w95)]
						else:
							_w11 = "You've exceeded your quota for %s." % _r94
					elif _o77.has("message"):
						_w11 = _o77.get("message", _w11)
			_t37.emit(_a6, _w11)
		elif _a6 == 400:
			var _w11 = "Bad request"
			var json = JSON.new()
			var _a50 = json.parse(_v73.get_string_from_utf8())
			if _a50 == OK:
				var _o77 = json.get_data()
				if _o77 is Dictionary and _o77.has("message"):
					_w11 = _o77.get("message", "Bad request")
			_t37.emit(_a6, _w11)
		elif _a6 == 422:
			_t37.emit(_a6, "Request validation failed. Please check your custom rules and parameters.")
		else:
			_t37.emit(_a6, "Server returned an error")
		return
	var json = JSON.new()
	var error = json.parse(_v73.get_string_from_utf8())
	if error != OK:
		_t37.emit(_a6, "Invalid JSON response")
		return
	var _o77 = json.get_data()
	if not _o77 is Dictionary:
		_t37.emit(_a6, "JSON response is not a dictionary.")
		return
	if not _o77.has("content"):
		_t37.emit(_a6, "Response does not contain 'content' field.")
		return
	var content = _o77.get("content", "")
	var _a79 = []
	if _o77.has("documentation_sources"):
		var _h57 = _o77.get("documentation_sources", [])
		if _h57 is Array:
			for source in _h57:
				if source is Dictionary:
					_a79.append({
						"url": source.get("url", ""),
						"title": source.get("title", "Godot Documentation"),
						"priority": source.get("priority", 0.0),
						"language": source.get("language", "en")
					})
	if _o77.has("response_id"):
		_y72 = _o77.get("response_id", "")
	else:
		pass
	var _u17 = ""
	if _o77.has("thought_signature"):
		_u17 = _o77.get("thought_signature", "")
		_c83 = _u17
	else:
		_c83 = ""
	var _e53 = ""
	if _o77.has("enhanced_user_message"):
		_e53 = _o77.get("enhanced_user_message", "")
	if _o77.has("quota_warning") and _o77.get("quota_warning") is Dictionary:
		var _i33 = _o77.get("quota_warning")
		var _l66 = _i33.get("severity", "notice").to_lower()
		var _r94 = _i33.get("model_group", "")
		var _p85 = _i33.get("usage_percentage", 0.0)
		var _w95 = _i33.get("reset_date", "")
		match _l66:
			"notice":
				_l66 = "medium"
			"warning":
				_l66 = "high"
			"critical", "limit_reached":
				_l66 = "critical"
			_:
				_l66 = "medium"
		var _x98 = "%s_%s_%d" % [_r94, _l66, int(_p85 / 5) * 5]  
		if not _r94.is_empty() and not _u36.has(_x98):
			_u36[_x98] = Time.get_ticks_msec()
			_f67.emit(_l66, _r94, _p85, _w95)
	if _o77.has("truncation_warning"):
		var _q17 = _o77.get("truncation_warning", "")
		if _q17 is String and not _q17.is_empty():
			_c79.emit(_q17)
	if _o77.has("tier"):
		var _c97 = _o77.get("tier", "")
		if _c97 is String and not _c97.is_empty():
			var _r62 = _d15.get("tier", "")
			if _c97 != _r62:
				_d15["tier"] = _c97
				_d6.emit(_d15)
	for _l95 in _p18:
		if _l95.begins_with("X-Usage-Warning:"):
			var _g77 = _l95.split(": ", true, 1)[1] if _l95.contains(": ") else ""
		elif _l95.begins_with("X-Model-Group:"):
			var _u49 = _l95.split(": ", true, 1)[1] if _l95.contains(": ") else ""
	_k16.emit(content, _a79, _u17, _e53)
	if _o77.has("usage"):
		var _o68 = _o77.get("usage", {})
		var _h35 = _o68.get("prompt_tokens", 0)
		var _o76 = _o68.get("completion_tokens", 0)
		var _r52 = _o68.get("total_tokens", 0)
		_z29.emit(_h35, _o76, _r52)
func _y15() -> void:
	var _d44 := ConfigFile.new()
	var error := _d44.load("user://gdsense_api_key.cfg")
	if error == OK:
		if _p17:
			var env = _q98()
			_x48 = _d44.get_value("api_keys", env, "")
			if _x48.is_empty():
				_x48 = _d44.get_value("plugin", "api_key", "")
				if not _x48.is_empty() and env == "production":
					_d44.set_value("api_keys", "production", _x48)
					_d44.save("user://gdsense_api_key.cfg")
		else:
			_x48 = _d44.get_value("api_keys", "production", "")
			if _x48.is_empty():
				_x48 = _d44.get_value("plugin", "api_key", "")
	else:
		pass
func _l34(_b22: String) -> void:
	var _d44 := ConfigFile.new()
	_d44.load("user://gdsense_api_key.cfg")  
	if _p17:
		var env = _q98()
		_d44.set_value("api_keys", env, _b22)
	else:
		_d44.set_value("api_keys", "production", _b22)
	if not _p17 or _q98() == "production":
		_d44.set_value("plugin", "api_key", _b22)
	_d44.save("user://gdsense_api_key.cfg")
	_x48 = _b22
	_p86.emit()
	_f84.call_deferred()
func _a82() -> String:
	return _x48
func _r18() -> String:
	return _y60
func _x57() -> bool:
	return not _x48.strip_edges().is_empty()
func _p94() -> Dictionary:
	return _d15
func _n83(environment: String) -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", environment, "")
	return ""
func _j66(model: String) -> void:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
	else:
		config.set_value("plugin", "api_key", _x48)
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
func _o26() -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var model = config.get_value("settings", "selected_model", "llama-3.1-8b-instant")
		if model == "Meta-Llama-3-8B-Instruct" or model == "Meta-Llama-3.1-8B-Instruct" or model == "llama-3.1-8b-instruct":
			model = "llama-3.1-8b-instant"
			_j66(model)  
		elif model == "Meta-Llama-3-70B-Instruct" or model == "Meta-Llama-3.1-70B-Instruct":
			model = "llama-3.1-70b-instruct"
			_j66(model)  
		elif model == "gemini-2.5-flash-lite-preview-06-17":
			model = "gemini-2.5-flash-lite"
			_j66(model)  
		return model
	return "llama-3.1-8b-instant"
func _x67() -> void:
	var _e36 = FileAccess.open("res://.gdsense-dev", FileAccess.READ)
	_p17 = _e36 != null
	if _e36:
		_e36.close()
	if _p17:
		pass
func _k71() -> bool:
	return _p17
func _q53() -> void:
	if not _p17:
		_y60 = "https://api.gdsense.com/api/v1"
		return
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var env = config.get_value("developer", "api_environment", "production")
		if env == "development":
			_y60 = "http://localhost:8080/api/v1"
		else:
			_y60 = "https://api.gdsense.com/api/v1"
func _o30(environment: String) -> void:
	if not _p17:
		return
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("developer", "api_environment", environment)
	config.save("user://gdsense_api_key.cfg")
	_q53()
	_y15()
func _q98() -> String:
	if not _p17:
		return "production"
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("developer", "api_environment", "production")
	return "production"
func _r28(messages: Array, _y59: String = "", _e11: String = "", context_metadata: Dictionary = {}) -> void:
	_y15() 
	_l99()
	var _k74 := _x48.strip_edges(true, true)
	if _k74.is_empty():
		_y58.emit()
		return
	if _x95.is_processing():
		return
	var _p18: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _k74
	]
	var _w63 = _o26()
	var _d26 = {
		"messages": messages,
		"model": _w63,
		"godotVersion": _e35(),
		"chat_session_id": _c68
	}
	if not context_metadata.is_empty():
		_d26["context_metadata"] = context_metadata
	if not _y59.is_empty():
		_d26["command"] = _y59
	if not _e11.is_empty():
		_d26["function_context"] = _e11
	var _h82 = _i41()
	if _h82.size() > 0:
		_d26["custom_rules"] = _h82
	var _f41 = _a36()
	if not _f41.is_empty():
		_d26["parametersOverride"] = _f41
	var _v73: String = JSON.stringify(_d26)
	if _d26.has("custom_rules"):
		var _j56 = _d26["custom_rules"]
	else:
		pass
	var _f56 = _y60 + "/completion"
	var error = _x95.request(_f56, _p18, HTTPClient.METHOD_POST, _v73)
	if error != OK:
		_t37.emit(0, "Failed to start request.")
		return 
func _i39(context: Dictionary) -> void:
	_y15() 
	var _k74 := _x48.strip_edges(true, true)
	if _k74.is_empty():
		return
	if is_instance_valid(_u40):
		if _u40.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_u40.cancel_request()
	var _p18: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _k74
	]
	var _v73: String = JSON.stringify({
		"context": context,
		"maxTokens": 150  
	})
	_k78 = Time.get_ticks_msec()
	var _f56 = _y60 + "/autocomplete"
	var error = _u40.request(_f56, _p18, HTTPClient.METHOD_POST, _v73)
	if error != OK:
		return
func _j32(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray) -> void:
	var _v88 = Time.get_ticks_msec() - _k78
	if _n37 != HTTPRequest.RESULT_SUCCESS:
		return
	if _a6 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_v73.get_string_from_utf8())
	if error != OK:
		return
	var _o77 = json.get_data()
	if not _o77 is Dictionary:
		return
	var _k91 = _o77.get("suggestion", "")
	if _k91.is_empty():
		return
	_z92.emit(_k91, _v88)
var _y42: Dictionary = {}  
func _b85(function_name: String, _w94: String, _z10: String, file_path: String = "", model: String = "") -> void:
	_y15() 
	var _k74 := _x48.strip_edges(true, true)
	if _k74.is_empty():
		_y58.emit()
		return
	if is_instance_valid(_c48):
		if _c48.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_c48.cancel_request()
	else:
		pass
	var _p18: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _k74
	]
	var original_hash = _x83(_w94)
	_y42 = {
		"function_name": function_name,
		"original_hash": original_hash
	}
	if _c68.is_empty():
		_m1()
	var _g58 = model if not model.is_empty() else "gemini-2.5-flash"
	var _n84 = {
		"file_path": file_path if file_path else "unknown.gd",
		"language": "gdscript",
		"func_name": function_name,
		"func_code": _w94,
		"user_prompt": _z10,
		"editor_version": _e35(),
		"chat_session_id": _c68,
		"model": _g58
	}
	var _v73: String = JSON.stringify(_n84)
	var _f56 = _y60 + "/refactor"
	if not is_instance_valid(_c48):
		_c48 = HTTPRequest.new()
		add_child(_c48)
		_c48.request_completed.connect(_w76)
		_c48.timeout = 30.0
	var error = _c48.request(_f56, _p18, HTTPClient.METHOD_POST, _v73)
	if error != OK:
		_t37.emit(0, "Failed to start refactor request.")
		return
func _w76(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray) -> void:
	if _n37 != HTTPRequest.RESULT_SUCCESS:
		_t37.emit(0, "Network error during refactor")
		return
	if _a6 != 200:
		var _w11 = ""
		var json = JSON.new()
		var _a50 = json.parse(_v73.get_string_from_utf8())
		var _o77 = {}
		if _a50 == OK:
			var data = json.get_data()
			if data is Dictionary:
				_o77 = data
		if _a6 == 401:
			_y58.emit()
		elif _a6 == 403:
			_w11 = "Refactor is not available in your tier. Please upgrade."
			if _o77.has("message"):
				_w11 = _o77.get("message", _w11)
			_t37.emit(_a6, _w11)
		elif _a6 == 429:
			_w11 = "You've exceeded your refactor quota. Please wait before making more requests."
			if _o77.has("group") or _o77.has("reset_date"):
				var _r94 = _o77.get("group", "")
				var _w95 = _o77.get("reset_date", "")
				if not _r94.is_empty():
					if not _w95.is_empty():
						_w11 = "You've exceeded your quota for %s. Resets on %s." % [_r94, _c33(_w95)]
					else:
						_w11 = "You've exceeded your quota for %s." % _r94
			elif _o77.has("message"):
				_w11 = _o77.get("message", _w11)
			_t37.emit(_a6, _w11)
		elif _a6 == 400:
			_w11 = "Bad refactor request"
			if _o77.has("message"):
				_w11 = _o77.get("message", _w11)
			_t37.emit(_a6, _w11)
		elif _a6 == 422:
			_w11 = "Refactor request validation failed."
			if _o77.has("message"):
				_w11 = _o77.get("message", _w11)
			_t37.emit(_a6, _w11)
		else:
			_w11 = "Server returned an error during refactor (code: %d)" % _a6
			if _o77.has("message"):
				_w11 = _o77.get("message", _w11)
			elif _o77.has("error"):
				_w11 = _o77.get("error", _w11)
			_t37.emit(_a6, _w11)
		return
	var json = JSON.new()
	var error = json.parse(_v73.get_string_from_utf8())
	if error != OK:
		_t37.emit(_a6, "Invalid JSON response from refactor")
		return
	var _o77 = json.get_data()
	if not _o77 is Dictionary:
		_t37.emit(_a6, "Refactor response is not a dictionary")
		return
	if not _o77.has("rewritten_func"):
		_t37.emit(_a6, "Refactor response missing 'rewritten_func' field")
		return
	var refactored_code = _o77.get("rewritten_func", "")
	if refactored_code.is_empty():
		_t37.emit(_a6, "Refactor response contains empty code")
		return
	var function_name = _y42.get("function_name", "")
	var original_hash = _y42.get("original_hash", "")
	_y42.clear()
	_w57.emit(refactored_code, original_hash, function_name)
func _x83(text: String) -> String:
	var _d54 = HashingContext.new()
	_d54.start(HashingContext.HASH_SHA256)
	_d54.update(text.to_utf8_buffer())
	var _g16 = _d54.finish()
	return _g16.hex_encode()
func _e35() -> String:
	var _q72 = Engine.get_version_info()
	return "%d.%d.%d" % [_q72.major, _q72.minor, _q72.patch]
func _i41() -> PackedStringArray:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _a70 = config.get_value("custom_rules", "rules_text", "")
		if not _a70.is_empty():
			var _b99 = _a70.split("\n")
			var _t10 = PackedStringArray()
			for _o15 in _b99:
				var _f34 = _o15.strip_edges()
				if not _f34.is_empty():
					_t10.append(_f34)
			return _t10
	return PackedStringArray()
func _a36() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _l37 = {}
		var _b30 = config.get_value("parameters", "temperature_override", 0.0)
		var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
		if _b30 > 0.0:
			_l37["temperature"] = _b30
		if max_tokens > 0:
			_l37["max_tokens"] = max_tokens
		return _l37
	return {}
func _z19(_a70: String) -> Dictionary:
	var _n37 = {"valid": true, "errors": []}
	if _a70.length() > 500:
		_n37["valid"] = false
		_n37["errors"].append("Custom rules must be under 500 characters")
	var _w13 = [
		"system:", "assistant:", "user:",
		"ignore all previous", "disregard instructions",
		"forget previous", "override system"
	]
	var _h6 = _a70.to_lower()
	for _a45 in _w13:
		if _h6.find(_a45) != -1:
			_n37["valid"] = false
			_n37["errors"].append("System instruction overrides are not allowed")
			break
	return _n37
func _z32(_a70: String) -> bool:
	var _w84 = _z19(_a70)
	if not _w84.get("valid", false):
		return false
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("custom_rules", "rules_text", _a70)
	config.save("user://gdsense_settings.cfg")
	return true
func _y30(_b30: float, max_tokens: int) -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("parameters", "temperature_override", _b30)
	config.set_value("parameters", "max_tokens_override", max_tokens)
	config.save("user://gdsense_settings.cfg")
func _q56() -> String:
	return _y72
func _e70() -> String:
	var _j69 = []
	for i in range(32):
		_j69.append(randi() % 16)
	_j69[12] = 4  
	_j69[16] = (_j69[16] & 0x3) | 0x8  
	var _o91 = "0123456789abcdef"
	var _n37 = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			_n37 += "-"
		_n37 += _o91[_j69[i]]
	return _n37
func _m1() -> void:
	_c68 = _e70()
func _s22() -> String:
	return _c68
func _j94(rating: String, category: String = "", details: String = "") -> void:
	if _y72.is_empty():
		return
	var _k74 := _x48.strip_edges(true, true)
	if _k74.is_empty():
		return
	var _p18: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _k74
	]
	var _j11 = {
		"responseId": _y72,
		"rating": rating,
		"category": category,
		"details": details,
		"chat_session_id": _c68,
		"context": {
			"model": _o26(),
			"godotVersion": _e35()
		}
	}
	var _v73: String = JSON.stringify(_j11)
	var _j42 = HTTPRequest.new()
	add_child(_j42)
	_j42.request_completed.connect(_g69)
	var _f56 = _y60 + "/feedback"
	var error = _j42.request(_f56, _p18, HTTPClient.METHOD_POST, _v73)
	if error != OK:
		_j42.queue_free()
func _g69(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray) -> void:
	var _c4 = null
	for _i64 in get_children():
		if _i64 is HTTPRequest and _i64 != _x95 and _i64 != _u40:
			_c4 = _i64
			break
	if _c4:
		_c4.queue_free()
	var success = _n37 == HTTPRequest.RESULT_SUCCESS and _a6 == 200
	if success:
		pass
	else:
		pass
	_t38.emit(success)
func _p46() -> void:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		if not config.has_section_key("custom_rules", "rules_text"):
			config.set_value("custom_rules", "rules_text", "")
		if not config.has_section_key("parameters", "temperature_override"):
			config.set_value("parameters", "temperature_override", 0.0)
		if not config.has_section_key("parameters", "max_tokens_override"):
			config.set_value("parameters", "max_tokens_override", 0)
		config.save("user://gdsense_settings.cfg")
	else:
		config.set_value("custom_rules", "rules_text", "")
		config.set_value("parameters", "temperature_override", 0.0)
		config.set_value("parameters", "max_tokens_override", 0)
		config.save("user://gdsense_settings.cfg")
func _q8(messages: Array, context_metadata: Dictionary = {}) -> void:
	if _x48.is_empty():
		return
	if _s10 and _s10.is_processing():
		return
	var _p18: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _x48
	]
	var _d26 = {
		"messages": messages,
		"model": _o26(),
		"context_metadata": context_metadata
	}
	var _g5 = JSON.stringify(_d26)
	var _f56 = _y60 + "/context/estimate"
	var error = _s10.request(_f56, _p18, HTTPClient.METHOD_POST, _g5)
	if error != OK:
		pass
func _e22(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray) -> void:
	if _n37 != HTTPRequest.RESULT_SUCCESS:
		return
	if _a6 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_v73.get_string_from_utf8())
	if error != OK:
		return
	var _o77 = json.get_data()
	if not _o77 is Dictionary:
		return
	var _r52 = _o77.get("tokens", 0)
	var breakdown = _o77.get("breakdown", [])
	var _y25 = _o77.get("context_limit", 128000)
	_s39.emit(_r52, breakdown, _y25)
func _e96() -> void:
	if _p17:
		pass
	var _h82 = _i41()
	var _f41 = _a36()
func _s55() -> void:
	if not _x48.is_empty():
		_c82()
func _c82() -> void:
	var _k74 := _x48.strip_edges(true, true)
	if _k74.is_empty():
		return
	if _p93.is_processing():
		return
	var _p18: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _k74
	]
	var _f56 = _y60 + "/plugin/whoami"
	var error = _p93.request(_f56, _p18, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _s81(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray) -> void:
	if _n37 != HTTPRequest.RESULT_SUCCESS:
		_x31()
		return
	if _a6 != 200:
		_x31()
		return
	var json = JSON.new()
	var error = json.parse(_v73.get_string_from_utf8())
	if error != OK:
		_x31()
		return
	var _o77 = json.get_data()
	if not _o77 is Dictionary:
		_x31()
		return
	_d15 = _o77
	_d6.emit(_d15)
	_l97()
func _x31() -> void:
	_d15 = {
		"tier": "FREE",
		"features": {
			"explain": true,
			"refactor": false
		},
		"credits": {
			"used": 0.0,
			"limit": 50,
			"pct": 0,
			"remaining": 50.0
		}
	}
	_d6.emit(_d15)
func _r88() -> String:
	return _b61(_d15.get("tier", "FREE"))
func _b61(_m8: String) -> String:
	if _m8 == null:
		return "FREE"
	var _b35 = _m8.strip_edges()
	if _b35.is_empty():
		return "FREE"
	_b35 = _b35.replace("-", "_").replace(" ", "_").to_upper()
	return _b35
func _c33(_n33: String) -> String:
	if _n33.is_empty():
		return ""
	var _w68 = _n33.split("T")[0] if "T" in _n33 else _n33
	var _c93 = _w68.split("-")
	if _c93.size() < 3:
		return _n33  
	var year = _c93[0]
	var month = int(_c93[1]) if _c93[1].is_valid_int() else 0
	var day = int(_c93[2]) if _c93[2].is_valid_int() else 0
	if month < 1 or month > 12 or day < 1 or day > 31:
		return _n33  
	var _r95 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [_r95[month - 1], day, year]
func _g27() -> Dictionary:
	return _d15.get("features", {"explain": true, "refactor": true})
func _w70() -> Dictionary:
	var _q95 = {
		"used": 0.0,
		"limit": 50,
		"pct": 0,
		"remaining": 50.0
	}
	return _d15.get("credits", _q95)
func _e3() -> bool:
	var features = _g27()
	return features.get("refactor", true)
func _i20() -> Array:
	if _d15.has("allowed_models"):
		var _w85 = _d15["allowed_models"]
		if _w85 is Array and _w85.size() > 0:
			var _b69: Array = []
			for model in _w85:
				if model is Dictionary and model.has("id"):
					_b69.append(model["id"])
			if _b69.size() > 0:
				return _b69
	var _d29 = _r88()
	var _o23 = _d63.get(_d29, ["GROUP_FREE"])
	var _z58: Array = []
	for _r94 in _u76:
		if _r94 in _o23 and _e60.has(_r94):
			_z58.append_array(_e60[_r94])
	return _z58
func _w9() -> Array:
	if _d15.has("allowed_models"):
		var _w85 = _d15["allowed_models"]
		if _w85 is Array and _w85.size() > 0:
			return _w85
	return []
func _l97() -> void:
	var _b64 = _w70()
	var used = _b64.get("used", 0.0)
	var limit = _b64.get("limit", 0)
	var _p85 = _b64.get("pct", 0)
	if limit <= 0:
		return  
	var _x98 = ""
	var _l66 = ""
	if _p85 >= 95:
		_x98 = "credits_95"
		_l66 = "critical"
	elif _p85 >= 90:
		_x98 = "credits_90"
		_l66 = "high"
	elif _p85 >= 85:
		_x98 = "credits_85"
		_l66 = "medium"
	elif _p85 >= 80:
		_x98 = "credits_80"
		_l66 = "low"
	if not _x98.is_empty() and not _u36.has(_x98):
		_u36[_x98] = Time.get_ticks_msec()
		var _t91 = _d15.get("renewal_date", "")
		_f67.emit(_l66, "credits", float(_p85), _t91)
func _f84() -> void:
	_d15.clear()
	_c82()
func _j40(_c97: String) -> void:
	if _c97.is_empty():
		return
	var _r62 = _d15.get("tier", "")
	if _c97 != _r62:
		_d15["tier"] = _c97
		_d6.emit(_d15)
func _l99() -> void:
	var _j33 = Time.get_ticks_msec()
	var _r90 = []
	for _x98 in _u36:
		var _x53 = _u36[_x98]
		if (_j33 - _x53) > 3600000:  
			_r90.append(_x98)
	for _b22 in _r90:
		_u36.erase(_b22)
func _k93() -> void:
	if not _z91():
		return
	var _f56 = "https://api.gdsense.com/api/v1/plugin/latest-version"
	var _p18: PackedStringArray = [
		"Content-Type: application/json"
	]
	var error = _h87.request(_f56, _p18, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _z91() -> bool:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") != OK:
		return true  
	var _v63 = config.get_value("updates", "last_check_timestamp", 0)
	var _j33 = int(Time.get_unix_time_from_system())
	return (_j33 - _v63) >= _l12
func _g94(_n37: int, _a6: int, _p18: PackedStringArray, _v73: PackedByteArray) -> void:
	if _n37 != HTTPRequest.RESULT_SUCCESS:
		return
	if _a6 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_v73.get_string_from_utf8())
	if error != OK:
		return
	var _o77 = json.get_data()
	if not _o77 is Dictionary:
		return
	var _p60 = _o77.get("version", "")
	var is_active = _o77.get("isActive", true)
	if _p60.is_empty():
		return
	_z84()
	var _e8 = _j79()
	if is_active and _l49(_e8, _p60) < 0:
		_z97.emit(_p60, _e8)
	else:
		pass
func _z84() -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")  
	config.set_value("updates", "last_check_timestamp", int(Time.get_unix_time_from_system()))
	config.save("user://gdsense_settings.cfg")
func _l49(current: String, _o69: String) -> int:
	var _t92 = current.split(".")
	var _x44 = _o69.split(".")
	var _o89 = max(_t92.size(), _x44.size())
	while _t92.size() < _o89:
		_t92.append("0")
	while _x44.size() < _o89:
		_x44.append("0")
	for i in range(_o89):
		var _y81 = int(_t92[i])
		var _o54 = int(_x44[i])
		if _y81 < _o54:
			return -1
		elif _y81 > _o54:
			return 1
	return 0
func _v34() -> String:
	return _j79()
func _j79() -> String:
	if _f57.is_empty():
		var config = ConfigFile.new()
		if config.load("res://addons/gdsense/plugin.cfg") == OK:
			_f57 = config.get_value("plugin", "version", "0.0.0")
		else:
			_f57 = "0.0.0"
	return _f57
