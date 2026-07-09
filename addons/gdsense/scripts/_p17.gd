@tool
class_name _p17
extends Node
signal _a16(_x77: String, _x42: Array, _j43: String, _u30: String)
signal _b16
signal _i36(_j100: int, _q64: String)
signal _l25
signal _q89(_b79: int, _m15: int, _c92: int)
signal _v3(_x43: String, _i1: int)
signal _k81(success: bool)
signal _d24(refactored_code: String, original_hash: String, function_name: String)
signal _i99(_c92: int, breakdown: Array, _y2: int)
signal _d99(_g93: Dictionary)
signal _m5(_e30: String, _i61: String, _d51: float, _q3: String)
signal _u64(message: String)
signal _b33(_v8: String, _j18: String)
var _n43: HTTPRequest
var _t35: HTTPRequest
var _u89: HTTPRequest
var _g25: HTTPRequest
var _r100: HTTPRequest
var _q27: HTTPRequest
var _v73: String = ""
var _c60: bool = false
var _n16: String = "https://api.gdsense.com/api/v1"
var _c29: int = 0
var _v4: String = ""
var _e50: String = ""
var _k89: Dictionary = {}  
var _c26: Dictionary = {}  
var _l69: String = ""  
const _c99 = 86400  
var _r57: String = ""
const _n95 = {
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
const _m70 = {
	"FREE": ["GROUP_FREE"],
	"STARTER": ["GROUP_FREE", "GROUP_STD"],
	"BETA_FREE": ["GROUP_FREE", "GROUP_STD"],
	"PRO": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"],
	"ULTRA": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
}
const _b12 = ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
func _enter_tree() -> void:
	_n43 = HTTPRequest.new()
	add_child(_n43)
	_n43.request_completed.connect(_o63)
	_t35 = HTTPRequest.new()
	add_child(_t35)
	_t35.request_completed.connect(_w65)
	_t35.timeout = 0.5  
	_u89 = HTTPRequest.new()
	add_child(_u89)
	_u89.request_completed.connect(_y61)
	_u89.timeout = 30.0  
	_g25 = HTTPRequest.new()
	add_child(_g25)
	_g25.request_completed.connect(_k70)
	_g25.timeout = 5.0  
	_r100 = HTTPRequest.new()
	add_child(_r100)
	_r100.request_completed.connect(_d78)
	_r100.timeout = 10.0  
	_q27 = HTTPRequest.new()
	add_child(_q27)
	_q27.request_completed.connect(_r17)
	_q27.timeout = 10.0  
	_h19()
	_t13()
	_v93()
	_y1()
	_x37()
	_p62.call_deferred()
	_x93.call_deferred()
func _o63(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray) -> void:
	if _e21 != HTTPRequest.RESULT_SUCCESS:
		_i36.emit(0, "Network error")
		return
	if _j100 != 200:
		if _j100 == 401:
			_b16.emit()
		elif _j100 == 403:
			var _u39 = "This feature/model is not available in your tier. Please upgrade."
			var json = JSON.new()
			var _n76 = json.parse(_r63.get_string_from_utf8())
			if _n76 == OK:
				var _j24 = json.get_data()
				if _j24 is Dictionary and _j24.has("message"):
					_u39 = _j24.get("message", _u39)
			_i36.emit(_j100, _u39)
		elif _j100 == 429:
			var _u39 = "You've exceeded your quota. Please wait before making more requests."
			var json = JSON.new()
			var _n76 = json.parse(_r63.get_string_from_utf8())
			if _n76 == OK:
				var _j24 = json.get_data()
				if _j24 is Dictionary:
					var _i61 = _j24.get("group", "")
					var _q3 = _j24.get("reset_date", "")
					if not _i61.is_empty():
						if not _q3.is_empty():
							_u39 = "You've exceeded your quota for %s. Resets on %s." % [_i61, _g60(_q3)]
						else:
							_u39 = "You've exceeded your quota for %s." % _i61
					elif _j24.has("message"):
						_u39 = _j24.get("message", _u39)
			_i36.emit(_j100, _u39)
		elif _j100 == 400:
			var _u39 = "Bad request"
			var json = JSON.new()
			var _n76 = json.parse(_r63.get_string_from_utf8())
			if _n76 == OK:
				var _j24 = json.get_data()
				if _j24 is Dictionary and _j24.has("message"):
					_u39 = _j24.get("message", "Bad request")
			_i36.emit(_j100, _u39)
		elif _j100 == 422:
			_i36.emit(_j100, "Request validation failed. Please check your custom rules and parameters.")
		else:
			_i36.emit(_j100, "Server returned an error")
		return
	var json = JSON.new()
	var error = json.parse(_r63.get_string_from_utf8())
	if error != OK:
		_i36.emit(_j100, "Invalid JSON response")
		return
	var _j24 = json.get_data()
	if not _j24 is Dictionary:
		_i36.emit(_j100, "JSON response is not a dictionary.")
		return
	if not _j24.has("content"):
		_i36.emit(_j100, "Response does not contain 'content' field.")
		return
	var content = _j24.get("content", "")
	var _x42 = []
	if _j24.has("documentation_sources"):
		var _a40 = _j24.get("documentation_sources", [])
		if _a40 is Array:
			for source in _a40:
				if source is Dictionary:
					_x42.append({
						"url": source.get("url", ""),
						"title": source.get("title", "Godot Documentation"),
						"priority": source.get("priority", 0.0),
						"language": source.get("language", "en")
					})
	if _j24.has("response_id"):
		_v4 = _j24.get("response_id", "")
	else:
		pass
	var _j43 = ""
	if _j24.has("thought_signature"):
		_j43 = _j24.get("thought_signature", "")
		_l69 = _j43
	else:
		_l69 = ""
	var _u30 = ""
	if _j24.has("enhanced_user_message"):
		_u30 = _j24.get("enhanced_user_message", "")
	if _j24.has("quota_warning") and _j24.get("quota_warning") is Dictionary:
		var _w2 = _j24.get("quota_warning")
		var _e30 = _w2.get("severity", "notice").to_lower()
		var _i61 = _w2.get("model_group", "")
		var _d51 = _w2.get("usage_percentage", 0.0)
		var _q3 = _w2.get("reset_date", "")
		match _e30:
			"notice":
				_e30 = "medium"
			"warning":
				_e30 = "high"
			"critical", "limit_reached":
				_e30 = "critical"
			_:
				_e30 = "medium"
		var _y84 = "%s_%s_%d" % [_i61, _e30, int(_d51 / 5) * 5]  
		if not _i61.is_empty() and not _c26.has(_y84):
			_c26[_y84] = Time.get_ticks_msec()
			_m5.emit(_e30, _i61, _d51, _q3)
	if _j24.has("truncation_warning"):
		var _a72 = _j24.get("truncation_warning", "")
		if _a72 is String and not _a72.is_empty():
			_u64.emit(_a72)
	if _j24.has("tier"):
		var _z37 = _j24.get("tier", "")
		if _z37 is String and not _z37.is_empty():
			var _r47 = _k89.get("tier", "")
			if _z37 != _r47:
				_k89["tier"] = _z37
				_d99.emit(_k89)
	for _i9 in _x35:
		if _i9.begins_with("X-Usage-Warning:"):
			var _u29 = _i9.split(": ", true, 1)[1] if _i9.contains(": ") else ""
		elif _i9.begins_with("X-Model-Group:"):
			var _x14 = _i9.split(": ", true, 1)[1] if _i9.contains(": ") else ""
	_a16.emit(content, _x42, _j43, _u30)
	if _j24.has("usage"):
		var _p20 = _j24.get("usage", {})
		var _b79 = _p20.get("prompt_tokens", 0)
		var _m15 = _p20.get("completion_tokens", 0)
		var _c92 = _p20.get("total_tokens", 0)
		_q89.emit(_b79, _m15, _c92)
func _t13() -> void:
	var _q95 := ConfigFile.new()
	var error := _q95.load("user://gdsense_api_key.cfg")
	if error == OK:
		if _c60:
			var env = _j19()
			_v73 = _q95.get_value("api_keys", env, "")
			if _v73.is_empty():
				_v73 = _q95.get_value("plugin", "api_key", "")
				if not _v73.is_empty() and env == "production":
					_q95.set_value("api_keys", "production", _v73)
					_q95.save("user://gdsense_api_key.cfg")
		else:
			_v73 = _q95.get_value("api_keys", "production", "")
			if _v73.is_empty():
				_v73 = _q95.get_value("plugin", "api_key", "")
	else:
		pass
func _g9(_i19: String) -> void:
	var _q95 := ConfigFile.new()
	_q95.load("user://gdsense_api_key.cfg")  
	if _c60:
		var env = _j19()
		_q95.set_value("api_keys", env, _i19)
	else:
		_q95.set_value("api_keys", "production", _i19)
	if not _c60 or _j19() == "production":
		_q95.set_value("plugin", "api_key", _i19)
	_q95.save("user://gdsense_api_key.cfg")
	_v73 = _i19
	_l25.emit()
	_n80.call_deferred()
func _a77() -> String:
	return _v73
func _o51() -> String:
	return _n16
func _u46() -> bool:
	return not _v73.strip_edges().is_empty()
func _m90() -> Dictionary:
	return _k89
func _x81(environment: String) -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", environment, "")
	return ""
func _m58(model: String) -> void:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
	else:
		config.set_value("plugin", "api_key", _v73)
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
func _v41() -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var model = config.get_value("settings", "selected_model", "llama-3.1-8b-instant")
		if model == "Meta-Llama-3-8B-Instruct" or model == "Meta-Llama-3.1-8B-Instruct" or model == "llama-3.1-8b-instruct":
			model = "llama-3.1-8b-instant"
			_m58(model)  
		elif model == "Meta-Llama-3-70B-Instruct" or model == "Meta-Llama-3.1-70B-Instruct":
			model = "llama-3.1-70b-instruct"
			_m58(model)  
		elif model == "gemini-2.5-flash-lite-preview-06-17":
			model = "gemini-2.5-flash-lite"
			_m58(model)  
		return model
	return "llama-3.1-8b-instant"
func _h19() -> void:
	var _l90 = FileAccess.open("res://.gdsense-dev", FileAccess.READ)
	_c60 = _l90 != null
	if _l90:
		_l90.close()
	if _c60:
		pass
func _b17() -> bool:
	return _c60
func _v93() -> void:
	if not _c60:
		_n16 = "https://api.gdsense.com/api/v1"
		return
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var env = config.get_value("developer", "api_environment", "production")
		if env == "development":
			_n16 = "http://localhost:8080/api/v1"
		else:
			_n16 = "https://api.gdsense.com/api/v1"
func _s71(environment: String) -> void:
	if not _c60:
		return
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("developer", "api_environment", environment)
	config.save("user://gdsense_api_key.cfg")
	_v93()
	_t13()
func _j19() -> String:
	if not _c60:
		return "production"
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("developer", "api_environment", "production")
	return "production"
func _p35(messages: Array, _k52: String = "", _o39: String = "", context_metadata: Dictionary = {}) -> void:
	_t13() 
	_k18()
	var _l97 := _v73.strip_edges(true, true)
	if _l97.is_empty():
		_b16.emit()
		return
	if _n43.is_processing():
		return
	var _x35: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l97
	]
	var _n20 = _v41()
	var _s9 = {
		"messages": messages,
		"model": _n20,
		"godotVersion": _o31(),
		"chat_session_id": _e50
	}
	if not context_metadata.is_empty():
		_s9["context_metadata"] = context_metadata
	if not _k52.is_empty():
		_s9["command"] = _k52
	if not _o39.is_empty():
		_s9["function_context"] = _o39
	var _q77 = _u82()
	if _q77.size() > 0:
		_s9["custom_rules"] = _q77
	var _b28 = _f82()
	if not _b28.is_empty():
		_s9["parametersOverride"] = _b28
	var _r63: String = JSON.stringify(_s9)
	if _s9.has("custom_rules"):
		var _l55 = _s9["custom_rules"]
	else:
		pass
	var _p8 = _n16 + "/completion"
	var error = _n43.request(_p8, _x35, HTTPClient.METHOD_POST, _r63)
	if error != OK:
		_i36.emit(0, "Failed to start request.")
		return 
func _a63(context: Dictionary) -> void:
	_t13() 
	var _l97 := _v73.strip_edges(true, true)
	if _l97.is_empty():
		return
	if is_instance_valid(_t35):
		if _t35.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_t35.cancel_request()
	var _x35: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l97
	]
	var _r63: String = JSON.stringify({
		"context": context,
		"maxTokens": 150  
	})
	_c29 = Time.get_ticks_msec()
	var _p8 = _n16 + "/autocomplete"
	var error = _t35.request(_p8, _x35, HTTPClient.METHOD_POST, _r63)
	if error != OK:
		return
func _w65(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray) -> void:
	var _i1 = Time.get_ticks_msec() - _c29
	if _e21 != HTTPRequest.RESULT_SUCCESS:
		return
	if _j100 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_r63.get_string_from_utf8())
	if error != OK:
		return
	var _j24 = json.get_data()
	if not _j24 is Dictionary:
		return
	var _x43 = _j24.get("suggestion", "")
	if _x43.is_empty():
		return
	_v3.emit(_x43, _i1)
var _e40: Dictionary = {}  
func _d4(function_name: String, _k94: String, _t51: String, file_path: String = "", model: String = "") -> void:
	_t13() 
	var _l97 := _v73.strip_edges(true, true)
	if _l97.is_empty():
		_b16.emit()
		return
	if is_instance_valid(_u89):
		if _u89.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_u89.cancel_request()
	else:
		pass
	var _x35: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l97
	]
	var original_hash = _q39(_k94)
	_e40 = {
		"function_name": function_name,
		"original_hash": original_hash
	}
	if _e50.is_empty():
		_x37()
	var _k20 = model if not model.is_empty() else "gemini-2.5-flash"
	var _b71 = {
		"file_path": file_path if file_path else "unknown.gd",
		"language": "gdscript",
		"func_name": function_name,
		"func_code": _k94,
		"user_prompt": _t51,
		"editor_version": _o31(),
		"chat_session_id": _e50,
		"model": _k20
	}
	var _r63: String = JSON.stringify(_b71)
	var _p8 = _n16 + "/refactor"
	if not is_instance_valid(_u89):
		_u89 = HTTPRequest.new()
		add_child(_u89)
		_u89.request_completed.connect(_y61)
		_u89.timeout = 30.0
	var error = _u89.request(_p8, _x35, HTTPClient.METHOD_POST, _r63)
	if error != OK:
		_i36.emit(0, "Failed to start refactor request.")
		return
func _y61(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray) -> void:
	if _e21 != HTTPRequest.RESULT_SUCCESS:
		_i36.emit(0, "Network error during refactor")
		return
	if _j100 != 200:
		var _u39 = ""
		var json = JSON.new()
		var _n76 = json.parse(_r63.get_string_from_utf8())
		var _j24 = {}
		if _n76 == OK:
			var data = json.get_data()
			if data is Dictionary:
				_j24 = data
		if _j100 == 401:
			_b16.emit()
		elif _j100 == 403:
			_u39 = "Refactor is not available in your tier. Please upgrade."
			if _j24.has("message"):
				_u39 = _j24.get("message", _u39)
			_i36.emit(_j100, _u39)
		elif _j100 == 429:
			_u39 = "You've exceeded your refactor quota. Please wait before making more requests."
			if _j24.has("group") or _j24.has("reset_date"):
				var _i61 = _j24.get("group", "")
				var _q3 = _j24.get("reset_date", "")
				if not _i61.is_empty():
					if not _q3.is_empty():
						_u39 = "You've exceeded your quota for %s. Resets on %s." % [_i61, _g60(_q3)]
					else:
						_u39 = "You've exceeded your quota for %s." % _i61
			elif _j24.has("message"):
				_u39 = _j24.get("message", _u39)
			_i36.emit(_j100, _u39)
		elif _j100 == 400:
			_u39 = "Bad refactor request"
			if _j24.has("message"):
				_u39 = _j24.get("message", _u39)
			_i36.emit(_j100, _u39)
		elif _j100 == 422:
			_u39 = "Refactor request validation failed."
			if _j24.has("message"):
				_u39 = _j24.get("message", _u39)
			_i36.emit(_j100, _u39)
		else:
			_u39 = "Server returned an error during refactor (code: %d)" % _j100
			if _j24.has("message"):
				_u39 = _j24.get("message", _u39)
			elif _j24.has("error"):
				_u39 = _j24.get("error", _u39)
			_i36.emit(_j100, _u39)
		return
	var json = JSON.new()
	var error = json.parse(_r63.get_string_from_utf8())
	if error != OK:
		_i36.emit(_j100, "Invalid JSON response from refactor")
		return
	var _j24 = json.get_data()
	if not _j24 is Dictionary:
		_i36.emit(_j100, "Refactor response is not a dictionary")
		return
	if not _j24.has("rewritten_func"):
		_i36.emit(_j100, "Refactor response missing 'rewritten_func' field")
		return
	var refactored_code = _j24.get("rewritten_func", "")
	if refactored_code.is_empty():
		_i36.emit(_j100, "Refactor response contains empty code")
		return
	var function_name = _e40.get("function_name", "")
	var original_hash = _e40.get("original_hash", "")
	_e40.clear()
	_d24.emit(refactored_code, original_hash, function_name)
func _q39(text: String) -> String:
	var _f51 = HashingContext.new()
	_f51.start(HashingContext.HASH_SHA256)
	_f51.update(text.to_utf8_buffer())
	var _x6 = _f51.finish()
	return _x6.hex_encode()
func _o31() -> String:
	var _f90 = Engine.get_version_info()
	return "%d.%d.%d" % [_f90.major, _f90.minor, _f90.patch]
func _u82() -> PackedStringArray:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _g21 = config.get_value("custom_rules", "rules_text", "")
		if not _g21.is_empty():
			var _u87 = _g21.split("\n")
			var _s35 = PackedStringArray()
			for _c6 in _u87:
				var _e58 = _c6.strip_edges()
				if not _e58.is_empty():
					_s35.append(_e58)
			return _s35
	return PackedStringArray()
func _f82() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _y45 = {}
		var _a54 = config.get_value("parameters", "temperature_override", 0.0)
		var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
		if _a54 > 0.0:
			_y45["temperature"] = _a54
		if max_tokens > 0:
			_y45["max_tokens"] = max_tokens
		return _y45
	return {}
func _q10(_g21: String) -> Dictionary:
	var _e21 = {"valid": true, "errors": []}
	if _g21.length() > 500:
		_e21["valid"] = false
		_e21["errors"].append("Custom rules must be under 500 characters")
	var _i45 = [
		"system:", "assistant:", "user:",
		"ignore all previous", "disregard instructions",
		"forget previous", "override system"
	]
	var _c81 = _g21.to_lower()
	for _j73 in _i45:
		if _c81.find(_j73) != -1:
			_e21["valid"] = false
			_e21["errors"].append("System instruction overrides are not allowed")
			break
	return _e21
func _r62(_g21: String) -> bool:
	var _q62 = _q10(_g21)
	if not _q62.get("valid", false):
		return false
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("custom_rules", "rules_text", _g21)
	config.save("user://gdsense_settings.cfg")
	return true
func _x21(_a54: float, max_tokens: int) -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("parameters", "temperature_override", _a54)
	config.set_value("parameters", "max_tokens_override", max_tokens)
	config.save("user://gdsense_settings.cfg")
func _z33() -> String:
	return _v4
func _o15() -> String:
	var _a69 = []
	for i in range(32):
		_a69.append(randi() % 16)
	_a69[12] = 4  
	_a69[16] = (_a69[16] & 0x3) | 0x8  
	var _j71 = "0123456789abcdef"
	var _e21 = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			_e21 += "-"
		_e21 += _j71[_a69[i]]
	return _e21
func _x37() -> void:
	_e50 = _o15()
func _b11() -> String:
	return _e50
func _q81(rating: String, category: String = "", details: String = "") -> void:
	if _v4.is_empty():
		return
	var _l97 := _v73.strip_edges(true, true)
	if _l97.is_empty():
		return
	var _x35: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l97
	]
	var _s19 = {
		"responseId": _v4,
		"rating": rating,
		"category": category,
		"details": details,
		"chat_session_id": _e50,
		"context": {
			"model": _v41(),
			"godotVersion": _o31()
		}
	}
	var _r63: String = JSON.stringify(_s19)
	var _i23 = HTTPRequest.new()
	add_child(_i23)
	_i23.request_completed.connect(_k34)
	var _p8 = _n16 + "/feedback"
	var error = _i23.request(_p8, _x35, HTTPClient.METHOD_POST, _r63)
	if error != OK:
		_i23.queue_free()
func _k34(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray) -> void:
	var _z53 = null
	for _x15 in get_children():
		if _x15 is HTTPRequest and _x15 != _n43 and _x15 != _t35:
			_z53 = _x15
			break
	if _z53:
		_z53.queue_free()
	var success = _e21 == HTTPRequest.RESULT_SUCCESS and _j100 == 200
	if success:
		pass
	else:
		pass
	_k81.emit(success)
func _y1() -> void:
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
func _s12(messages: Array, context_metadata: Dictionary = {}) -> void:
	if _v73.is_empty():
		return
	if _g25 and _g25.is_processing():
		return
	var _x35: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _v73
	]
	var _s9 = {
		"messages": messages,
		"model": _v41(),
		"context_metadata": context_metadata
	}
	var _f74 = JSON.stringify(_s9)
	var _p8 = _n16 + "/context/estimate"
	var error = _g25.request(_p8, _x35, HTTPClient.METHOD_POST, _f74)
	if error != OK:
		pass
func _k70(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray) -> void:
	if _e21 != HTTPRequest.RESULT_SUCCESS:
		return
	if _j100 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_r63.get_string_from_utf8())
	if error != OK:
		return
	var _j24 = json.get_data()
	if not _j24 is Dictionary:
		return
	var _c92 = _j24.get("tokens", 0)
	var breakdown = _j24.get("breakdown", [])
	var _y2 = _j24.get("context_limit", 128000)
	_i99.emit(_c92, breakdown, _y2)
func _u96() -> void:
	if _c60:
		pass
	var _q77 = _u82()
	var _b28 = _f82()
func _p62() -> void:
	if not _v73.is_empty():
		_w74()
func _w74() -> void:
	var _l97 := _v73.strip_edges(true, true)
	if _l97.is_empty():
		return
	if _r100.is_processing():
		return
	var _x35: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l97
	]
	var _p8 = _n16 + "/plugin/whoami"
	var error = _r100.request(_p8, _x35, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _d78(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray) -> void:
	if _e21 != HTTPRequest.RESULT_SUCCESS:
		_v58()
		return
	if _j100 != 200:
		_v58()
		return
	var json = JSON.new()
	var error = json.parse(_r63.get_string_from_utf8())
	if error != OK:
		_v58()
		return
	var _j24 = json.get_data()
	if not _j24 is Dictionary:
		_v58()
		return
	_k89 = _j24
	_d99.emit(_k89)
	_y73()
func _v58() -> void:
	_k89 = {
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
	_d99.emit(_k89)
func _d68() -> String:
	return _i25(_k89.get("tier", "FREE"))
func _i25(_b23: String) -> String:
	if _b23 == null:
		return "FREE"
	var _h16 = _b23.strip_edges()
	if _h16.is_empty():
		return "FREE"
	_h16 = _h16.replace("-", "_").replace(" ", "_").to_upper()
	return _h16
func _g60(_c95: String) -> String:
	if _c95.is_empty():
		return ""
	var _x12 = _c95.split("T")[0] if "T" in _c95 else _c95
	var _c57 = _x12.split("-")
	if _c57.size() < 3:
		return _c95  
	var year = _c57[0]
	var month = int(_c57[1]) if _c57[1].is_valid_int() else 0
	var day = int(_c57[2]) if _c57[2].is_valid_int() else 0
	if month < 1 or month > 12 or day < 1 or day > 31:
		return _c95  
	var _m98 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [_m98[month - 1], day, year]
func _p45() -> Dictionary:
	return _k89.get("features", {"explain": true, "refactor": true})
func _b80() -> Dictionary:
	var _r67 = {
		"used": 0.0,
		"limit": 50,
		"pct": 0,
		"remaining": 50.0
	}
	return _k89.get("credits", _r67)
func _n53() -> bool:
	var features = _p45()
	return features.get("refactor", true)
func _k12() -> Array:
	if _k89.has("allowed_models"):
		var _f42 = _k89["allowed_models"]
		if _f42 is Array and _f42.size() > 0:
			var _a19: Array = []
			for model in _f42:
				if model is Dictionary and model.has("id"):
					_a19.append(model["id"])
			if _a19.size() > 0:
				return _a19
	var _j38 = _d68()
	var _q46 = _m70.get(_j38, ["GROUP_FREE"])
	var _e33: Array = []
	for _i61 in _b12:
		if _i61 in _q46 and _n95.has(_i61):
			_e33.append_array(_n95[_i61])
	return _e33
func _l40() -> Array:
	if _k89.has("allowed_models"):
		var _f42 = _k89["allowed_models"]
		if _f42 is Array and _f42.size() > 0:
			return _f42
	return []
func _y73() -> void:
	var _y49 = _b80()
	var used = _y49.get("used", 0.0)
	var limit = _y49.get("limit", 0)
	var _d51 = _y49.get("pct", 0)
	if limit <= 0:
		return  
	var _y84 = ""
	var _e30 = ""
	if _d51 >= 95:
		_y84 = "credits_95"
		_e30 = "critical"
	elif _d51 >= 90:
		_y84 = "credits_90"
		_e30 = "high"
	elif _d51 >= 85:
		_y84 = "credits_85"
		_e30 = "medium"
	elif _d51 >= 80:
		_y84 = "credits_80"
		_e30 = "low"
	if not _y84.is_empty() and not _c26.has(_y84):
		_c26[_y84] = Time.get_ticks_msec()
		var _d26 = _k89.get("renewal_date", "")
		_m5.emit(_e30, "credits", float(_d51), _d26)
func _n80() -> void:
	_k89.clear()
	_w74()
func _x73(_z37: String) -> void:
	if _z37.is_empty():
		return
	var _r47 = _k89.get("tier", "")
	if _z37 != _r47:
		_k89["tier"] = _z37
		_d99.emit(_k89)
func _k18() -> void:
	var _s36 = Time.get_ticks_msec()
	var _m74 = []
	for _y84 in _c26:
		var _t23 = _c26[_y84]
		if (_s36 - _t23) > 3600000:  
			_m74.append(_y84)
	for _i19 in _m74:
		_c26.erase(_i19)
func _x93() -> void:
	if not _t96():
		return
	var _p8 = "https://api.gdsense.com/api/v1/plugin/latest-version"
	var _x35: PackedStringArray = [
		"Content-Type: application/json"
	]
	var error = _q27.request(_p8, _x35, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _t96() -> bool:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") != OK:
		return true  
	var _g68 = config.get_value("updates", "last_check_timestamp", 0)
	var _s36 = int(Time.get_unix_time_from_system())
	return (_s36 - _g68) >= _c99
func _r17(_e21: int, _j100: int, _x35: PackedStringArray, _r63: PackedByteArray) -> void:
	if _e21 != HTTPRequest.RESULT_SUCCESS:
		return
	if _j100 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_r63.get_string_from_utf8())
	if error != OK:
		return
	var _j24 = json.get_data()
	if not _j24 is Dictionary:
		return
	var _v8 = _j24.get("version", "")
	var is_active = _j24.get("isActive", true)
	if _v8.is_empty():
		return
	_v48()
	var _j18 = _n97()
	if is_active and _q59(_j18, _v8) < 0:
		_b33.emit(_v8, _j18)
	else:
		pass
func _v48() -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")  
	config.set_value("updates", "last_check_timestamp", int(Time.get_unix_time_from_system()))
	config.save("user://gdsense_settings.cfg")
func _q59(current: String, _s46: String) -> int:
	var _j20 = current.split(".")
	var _s53 = _s46.split(".")
	var _r86 = max(_j20.size(), _s53.size())
	while _j20.size() < _r86:
		_j20.append("0")
	while _s53.size() < _r86:
		_s53.append("0")
	for i in range(_r86):
		var _d45 = int(_j20[i])
		var _z82 = int(_s53[i])
		if _d45 < _z82:
			return -1
		elif _d45 > _z82:
			return 1
	return 0
func _l29() -> String:
	return _n97()
func _n97() -> String:
	if _r57.is_empty():
		var config = ConfigFile.new()
		if config.load("res://addons/gdsense/plugin.cfg") == OK:
			_r57 = config.get_value("plugin", "version", "0.0.0")
		else:
			_r57 = "0.0.0"
	return _r57
