@tool
class_name _r91
extends Node
signal _b48(_d92: String, _t53: Array, _d96: String, _u90: String)
signal _s1
signal _p16(_j71: int, _e1: String)
signal _o11
signal _v40(_z52: int, _x3: int, _s26: int)
signal _i61(_n54: String, _d75: int)
signal _w28(success: bool)
signal _u52(refactored_code: String, original_hash: String, function_name: String)
signal _q53(_s26: int, breakdown: Array, _t43: int)
signal _n20(_e69: Dictionary)
signal _i10(_h18: String, _y21: String, _n33: float, _d62: String)
signal _l16(message: String)
signal _d51(_r24: String, _j37: String)
var _m53: HTTPRequest
var _g91: HTTPRequest
var _q31: HTTPRequest
var _u9: HTTPRequest
var _q2: HTTPRequest
var _f70: HTTPRequest
var _l95: String = ""
var _d78: bool = false
var _v16: String = "https://api.gdsense.com/api/v1"
var _v66: int = 0
var _e28: String = ""
var _y97: String = ""
var _k18: Dictionary = {}  
var _m49: Dictionary = {}  
var _h72: String = ""  
const _h69 = 86400  
var _m95: String = ""
const _b47 = {
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
const _g4 = {
	"FREE": ["GROUP_FREE"],
	"STARTER": ["GROUP_FREE", "GROUP_STD"],
	"BETA_FREE": ["GROUP_FREE", "GROUP_STD"],
	"PRO": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"],
	"ULTRA": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
}
const _p81 = ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
func _enter_tree() -> void:
	_m53 = HTTPRequest.new()
	add_child(_m53)
	_m53.request_completed.connect(_b61)
	_g91 = HTTPRequest.new()
	add_child(_g91)
	_g91.request_completed.connect(_j24)
	_g91.timeout = 0.5  
	_q31 = HTTPRequest.new()
	add_child(_q31)
	_q31.request_completed.connect(_x38)
	_q31.timeout = 30.0  
	_u9 = HTTPRequest.new()
	add_child(_u9)
	_u9.request_completed.connect(_o25)
	_u9.timeout = 5.0  
	_q2 = HTTPRequest.new()
	add_child(_q2)
	_q2.request_completed.connect(_g87)
	_q2.timeout = 10.0  
	_f70 = HTTPRequest.new()
	add_child(_f70)
	_f70.request_completed.connect(_o8)
	_f70.timeout = 10.0  
	_d91()
	_i25()
	_e45()
	_u100()
	_h76()
	_s29.call_deferred()
	_p42.call_deferred()
func _b61(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray) -> void:
	if _s61 != HTTPRequest.RESULT_SUCCESS:
		_p16.emit(0, "Network error")
		return
	if _j71 != 200:
		if _j71 == 401:
			_s1.emit()
		elif _j71 == 403:
			var _x73 = "This feature/model is not available in your tier. Please upgrade."
			var json = JSON.new()
			var _v96 = json.parse(_x89.get_string_from_utf8())
			if _v96 == OK:
				var _c35 = json.get_data()
				if _c35 is Dictionary and _c35.has("message"):
					_x73 = _c35.get("message", _x73)
			_p16.emit(_j71, _x73)
		elif _j71 == 429:
			var _x73 = "You've exceeded your quota. Please wait before making more requests."
			var json = JSON.new()
			var _v96 = json.parse(_x89.get_string_from_utf8())
			if _v96 == OK:
				var _c35 = json.get_data()
				if _c35 is Dictionary:
					var _y21 = _c35.get("group", "")
					var _d62 = _c35.get("reset_date", "")
					if not _y21.is_empty():
						if not _d62.is_empty():
							_x73 = "You've exceeded your quota for %s. Resets on %s." % [_y21, _q9(_d62)]
						else:
							_x73 = "You've exceeded your quota for %s." % _y21
					elif _c35.has("message"):
						_x73 = _c35.get("message", _x73)
			_p16.emit(_j71, _x73)
		elif _j71 == 400:
			var _x73 = "Bad request"
			var json = JSON.new()
			var _v96 = json.parse(_x89.get_string_from_utf8())
			if _v96 == OK:
				var _c35 = json.get_data()
				if _c35 is Dictionary and _c35.has("message"):
					_x73 = _c35.get("message", "Bad request")
			_p16.emit(_j71, _x73)
		elif _j71 == 422:
			_p16.emit(_j71, "Request validation failed. Please check your custom rules and parameters.")
		else:
			_p16.emit(_j71, "Server returned an error")
		return
	var json = JSON.new()
	var error = json.parse(_x89.get_string_from_utf8())
	if error != OK:
		_p16.emit(_j71, "Invalid JSON response")
		return
	var _c35 = json.get_data()
	if not _c35 is Dictionary:
		_p16.emit(_j71, "JSON response is not a dictionary.")
		return
	if not _c35.has("content"):
		_p16.emit(_j71, "Response does not contain 'content' field.")
		return
	var content = _c35.get("content", "")
	var _t53 = []
	if _c35.has("documentation_sources"):
		var _m45 = _c35.get("documentation_sources", [])
		if _m45 is Array:
			for source in _m45:
				if source is Dictionary:
					_t53.append({
						"url": source.get("url", ""),
						"title": source.get("title", "Godot Documentation"),
						"priority": source.get("priority", 0.0),
						"language": source.get("language", "en")
					})
	if _c35.has("response_id"):
		_e28 = _c35.get("response_id", "")
	else:
		pass
	var _d96 = ""
	if _c35.has("thought_signature"):
		_d96 = _c35.get("thought_signature", "")
		_h72 = _d96
	else:
		_h72 = ""
	var _u90 = ""
	if _c35.has("enhanced_user_message"):
		_u90 = _c35.get("enhanced_user_message", "")
	if _c35.has("quota_warning") and _c35.get("quota_warning") is Dictionary:
		var _e5 = _c35.get("quota_warning")
		var _h18 = _e5.get("severity", "notice").to_lower()
		var _y21 = _e5.get("model_group", "")
		var _n33 = _e5.get("usage_percentage", 0.0)
		var _d62 = _e5.get("reset_date", "")
		match _h18:
			"notice":
				_h18 = "medium"
			"warning":
				_h18 = "high"
			"critical", "limit_reached":
				_h18 = "critical"
			_:
				_h18 = "medium"
		var _x76 = "%s_%s_%d" % [_y21, _h18, int(_n33 / 5) * 5]  
		if not _y21.is_empty() and not _m49.has(_x76):
			_m49[_x76] = Time.get_ticks_msec()
			_i10.emit(_h18, _y21, _n33, _d62)
	if _c35.has("truncation_warning"):
		var _l84 = _c35.get("truncation_warning", "")
		if _l84 is String and not _l84.is_empty():
			_l16.emit(_l84)
	if _c35.has("tier"):
		var _x24 = _c35.get("tier", "")
		if _x24 is String and not _x24.is_empty():
			var _g49 = _k18.get("tier", "")
			if _x24 != _g49:
				_k18["tier"] = _x24
				_n20.emit(_k18)
	for _i92 in _z38:
		if _i92.begins_with("X-Usage-Warning:"):
			var _j56 = _i92.split(": ", true, 1)[1] if _i92.contains(": ") else ""
		elif _i92.begins_with("X-Model-Group:"):
			var _c33 = _i92.split(": ", true, 1)[1] if _i92.contains(": ") else ""
	_b48.emit(content, _t53, _d96, _u90)
	if _c35.has("usage"):
		var _r11 = _c35.get("usage", {})
		var _z52 = _r11.get("prompt_tokens", 0)
		var _x3 = _r11.get("completion_tokens", 0)
		var _s26 = _r11.get("total_tokens", 0)
		_v40.emit(_z52, _x3, _s26)
func _i25() -> void:
	var _f27 := ConfigFile.new()
	var error := _f27.load("user://gdsense_api_key.cfg")
	if error == OK:
		if _d78:
			var env = _c8()
			_l95 = _f27.get_value("api_keys", env, "")
			if _l95.is_empty():
				_l95 = _f27.get_value("plugin", "api_key", "")
				if not _l95.is_empty() and env == "production":
					_f27.set_value("api_keys", "production", _l95)
					_f27.save("user://gdsense_api_key.cfg")
		else:
			_l95 = _f27.get_value("api_keys", "production", "")
			if _l95.is_empty():
				_l95 = _f27.get_value("plugin", "api_key", "")
	else:
		pass
func _w5(_y40: String) -> void:
	var _f27 := ConfigFile.new()
	_f27.load("user://gdsense_api_key.cfg")  
	if _d78:
		var env = _c8()
		_f27.set_value("api_keys", env, _y40)
	else:
		_f27.set_value("api_keys", "production", _y40)
	if not _d78 or _c8() == "production":
		_f27.set_value("plugin", "api_key", _y40)
	_f27.save("user://gdsense_api_key.cfg")
	_l95 = _y40
	_o11.emit()
	_e67.call_deferred()
func _a37() -> String:
	return _l95
func _p53() -> String:
	return _v16
func _u76() -> bool:
	return not _l95.strip_edges().is_empty()
func _f61() -> Dictionary:
	return _k18
func _w87(environment: String) -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", environment, "")
	return ""
func _a35(model: String) -> void:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
	else:
		config.set_value("plugin", "api_key", _l95)
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
func _x46() -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var model = config.get_value("settings", "selected_model", "llama-3.1-8b-instant")
		if model == "Meta-Llama-3-8B-Instruct" or model == "Meta-Llama-3.1-8B-Instruct" or model == "llama-3.1-8b-instruct":
			model = "llama-3.1-8b-instant"
			_a35(model)  
		elif model == "Meta-Llama-3-70B-Instruct" or model == "Meta-Llama-3.1-70B-Instruct":
			model = "llama-3.1-70b-instruct"
			_a35(model)  
		elif model == "gemini-2.5-flash-lite-preview-06-17":
			model = "gemini-2.5-flash-lite"
			_a35(model)  
		return model
	return "llama-3.1-8b-instant"
func _d91() -> void:
	var _s16 = FileAccess.open("res://.gdsense-dev", FileAccess.READ)
	_d78 = _s16 != null
	if _s16:
		_s16.close()
	if _d78:
		pass
func _l46() -> bool:
	return _d78
func _e45() -> void:
	if not _d78:
		_v16 = "https://api.gdsense.com/api/v1"
		return
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var env = config.get_value("developer", "api_environment", "production")
		if env == "development":
			_v16 = "http://localhost:8080/api/v1"
		else:
			_v16 = "https://api.gdsense.com/api/v1"
func _z21(environment: String) -> void:
	if not _d78:
		return
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("developer", "api_environment", environment)
	config.save("user://gdsense_api_key.cfg")
	_e45()
	_i25()
func _c8() -> String:
	if not _d78:
		return "production"
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("developer", "api_environment", "production")
	return "production"
func _h21(messages: Array, _u54: String = "", _o41: String = "", context_metadata: Dictionary = {}) -> void:
	_i25() 
	_m47()
	var _g3 := _l95.strip_edges(true, true)
	if _g3.is_empty():
		_s1.emit()
		return
	if _m53.is_processing():
		return
	var _z38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _g3
	]
	var _h29 = _x46()
	var _z9 = {
		"messages": messages,
		"model": _h29,
		"godotVersion": _k25(),
		"chat_session_id": _y97
	}
	if not context_metadata.is_empty():
		_z9["context_metadata"] = context_metadata
	if not _u54.is_empty():
		_z9["command"] = _u54
	if not _o41.is_empty():
		_z9["function_context"] = _o41
	var _o86 = _x6()
	if _o86.size() > 0:
		_z9["custom_rules"] = _o86
	var _a4 = _d15()
	if not _a4.is_empty():
		_z9["parametersOverride"] = _a4
	var _x89: String = JSON.stringify(_z9)
	if _z9.has("custom_rules"):
		var _e64 = _z9["custom_rules"]
	else:
		pass
	var _w79 = _v16 + "/completion"
	var error = _m53.request(_w79, _z38, HTTPClient.METHOD_POST, _x89)
	if error != OK:
		_p16.emit(0, "Failed to start request.")
		return 
func _y35(context: Dictionary) -> void:
	_i25() 
	var _g3 := _l95.strip_edges(true, true)
	if _g3.is_empty():
		return
	if is_instance_valid(_g91):
		if _g91.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_g91.cancel_request()
	var _z38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _g3
	]
	var _x89: String = JSON.stringify({
		"context": context,
		"maxTokens": 150  
	})
	_v66 = Time.get_ticks_msec()
	var _w79 = _v16 + "/autocomplete"
	var error = _g91.request(_w79, _z38, HTTPClient.METHOD_POST, _x89)
	if error != OK:
		return
func _j24(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray) -> void:
	var _d75 = Time.get_ticks_msec() - _v66
	if _s61 != HTTPRequest.RESULT_SUCCESS:
		return
	if _j71 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_x89.get_string_from_utf8())
	if error != OK:
		return
	var _c35 = json.get_data()
	if not _c35 is Dictionary:
		return
	var _n54 = _c35.get("suggestion", "")
	if _n54.is_empty():
		return
	_i61.emit(_n54, _d75)
var _h90: Dictionary = {}  
func _p41(function_name: String, _j46: String, _t17: String, file_path: String = "", model: String = "") -> void:
	_i25() 
	var _g3 := _l95.strip_edges(true, true)
	if _g3.is_empty():
		_s1.emit()
		return
	if is_instance_valid(_q31):
		if _q31.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_q31.cancel_request()
	else:
		pass
	var _z38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _g3
	]
	var original_hash = _h46(_j46)
	_h90 = {
		"function_name": function_name,
		"original_hash": original_hash
	}
	if _y97.is_empty():
		_h76()
	var _i99 = model if not model.is_empty() else "gemini-2.5-flash"
	var _c5 = {
		"file_path": file_path if file_path else "unknown.gd",
		"language": "gdscript",
		"func_name": function_name,
		"func_code": _j46,
		"user_prompt": _t17,
		"editor_version": _k25(),
		"chat_session_id": _y97,
		"model": _i99
	}
	var _x89: String = JSON.stringify(_c5)
	var _w79 = _v16 + "/refactor"
	if not is_instance_valid(_q31):
		_q31 = HTTPRequest.new()
		add_child(_q31)
		_q31.request_completed.connect(_x38)
		_q31.timeout = 30.0
	var error = _q31.request(_w79, _z38, HTTPClient.METHOD_POST, _x89)
	if error != OK:
		_p16.emit(0, "Failed to start refactor request.")
		return
func _x38(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray) -> void:
	if _s61 != HTTPRequest.RESULT_SUCCESS:
		_p16.emit(0, "Network error during refactor")
		return
	if _j71 != 200:
		var _x73 = ""
		var json = JSON.new()
		var _v96 = json.parse(_x89.get_string_from_utf8())
		var _c35 = {}
		if _v96 == OK:
			var data = json.get_data()
			if data is Dictionary:
				_c35 = data
		if _j71 == 401:
			_s1.emit()
		elif _j71 == 403:
			_x73 = "Refactor is not available in your tier. Please upgrade."
			if _c35.has("message"):
				_x73 = _c35.get("message", _x73)
			_p16.emit(_j71, _x73)
		elif _j71 == 429:
			_x73 = "You've exceeded your refactor quota. Please wait before making more requests."
			if _c35.has("group") or _c35.has("reset_date"):
				var _y21 = _c35.get("group", "")
				var _d62 = _c35.get("reset_date", "")
				if not _y21.is_empty():
					if not _d62.is_empty():
						_x73 = "You've exceeded your quota for %s. Resets on %s." % [_y21, _q9(_d62)]
					else:
						_x73 = "You've exceeded your quota for %s." % _y21
			elif _c35.has("message"):
				_x73 = _c35.get("message", _x73)
			_p16.emit(_j71, _x73)
		elif _j71 == 400:
			_x73 = "Bad refactor request"
			if _c35.has("message"):
				_x73 = _c35.get("message", _x73)
			_p16.emit(_j71, _x73)
		elif _j71 == 422:
			_x73 = "Refactor request validation failed."
			if _c35.has("message"):
				_x73 = _c35.get("message", _x73)
			_p16.emit(_j71, _x73)
		else:
			_x73 = "Server returned an error during refactor (code: %d)" % _j71
			if _c35.has("message"):
				_x73 = _c35.get("message", _x73)
			elif _c35.has("error"):
				_x73 = _c35.get("error", _x73)
			_p16.emit(_j71, _x73)
		return
	var json = JSON.new()
	var error = json.parse(_x89.get_string_from_utf8())
	if error != OK:
		_p16.emit(_j71, "Invalid JSON response from refactor")
		return
	var _c35 = json.get_data()
	if not _c35 is Dictionary:
		_p16.emit(_j71, "Refactor response is not a dictionary")
		return
	if not _c35.has("rewritten_func"):
		_p16.emit(_j71, "Refactor response missing 'rewritten_func' field")
		return
	var refactored_code = _c35.get("rewritten_func", "")
	if refactored_code.is_empty():
		_p16.emit(_j71, "Refactor response contains empty code")
		return
	var function_name = _h90.get("function_name", "")
	var original_hash = _h90.get("original_hash", "")
	_h90.clear()
	_u52.emit(refactored_code, original_hash, function_name)
func _h46(text: String) -> String:
	var _g19 = HashingContext.new()
	_g19.start(HashingContext.HASH_SHA256)
	_g19.update(text.to_utf8_buffer())
	var _h100 = _g19.finish()
	return _h100.hex_encode()
func _k25() -> String:
	var _w99 = Engine.get_version_info()
	return "%d.%d.%d" % [_w99.major, _w99.minor, _w99.patch]
func _x6() -> PackedStringArray:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _h67 = config.get_value("custom_rules", "rules_text", "")
		if not _h67.is_empty():
			var _u35 = _h67.split("\n")
			var _v63 = PackedStringArray()
			for _z24 in _u35:
				var _n6 = _z24.strip_edges()
				if not _n6.is_empty():
					_v63.append(_n6)
			return _v63
	return PackedStringArray()
func _d15() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _h59 = {}
		var _f47 = config.get_value("parameters", "temperature_override", 0.0)
		var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
		if _f47 > 0.0:
			_h59["temperature"] = _f47
		if max_tokens > 0:
			_h59["max_tokens"] = max_tokens
		return _h59
	return {}
func _p21(_h67: String) -> Dictionary:
	var _s61 = {"valid": true, "errors": []}
	if _h67.length() > 500:
		_s61["valid"] = false
		_s61["errors"].append("Custom rules must be under 500 characters")
	var _s4 = [
		"system:", "assistant:", "user:",
		"ignore all previous", "disregard instructions",
		"forget previous", "override system"
	]
	var _i1 = _h67.to_lower()
	for _s76 in _s4:
		if _i1.find(_s76) != -1:
			_s61["valid"] = false
			_s61["errors"].append("System instruction overrides are not allowed")
			break
	return _s61
func _w32(_h67: String) -> bool:
	var _o92 = _p21(_h67)
	if not _o92.get("valid", false):
		return false
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("custom_rules", "rules_text", _h67)
	config.save("user://gdsense_settings.cfg")
	return true
func _z51(_f47: float, max_tokens: int) -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("parameters", "temperature_override", _f47)
	config.set_value("parameters", "max_tokens_override", max_tokens)
	config.save("user://gdsense_settings.cfg")
func _g30() -> String:
	return _e28
func _r6() -> String:
	var _y100 = []
	for i in range(32):
		_y100.append(randi() % 16)
	_y100[12] = 4  
	_y100[16] = (_y100[16] & 0x3) | 0x8  
	var _v28 = "0123456789abcdef"
	var _s61 = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			_s61 += "-"
		_s61 += _v28[_y100[i]]
	return _s61
func _h76() -> void:
	_y97 = _r6()
func _u23() -> String:
	return _y97
func _g46(rating: String, category: String = "", details: String = "") -> void:
	if _e28.is_empty():
		return
	var _g3 := _l95.strip_edges(true, true)
	if _g3.is_empty():
		return
	var _z38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _g3
	]
	var _a83 = {
		"responseId": _e28,
		"rating": rating,
		"category": category,
		"details": details,
		"chat_session_id": _y97,
		"context": {
			"model": _x46(),
			"godotVersion": _k25()
		}
	}
	var _x89: String = JSON.stringify(_a83)
	var _r23 = HTTPRequest.new()
	add_child(_r23)
	_r23.request_completed.connect(_s70)
	var _w79 = _v16 + "/feedback"
	var error = _r23.request(_w79, _z38, HTTPClient.METHOD_POST, _x89)
	if error != OK:
		_r23.queue_free()
func _s70(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray) -> void:
	var _z20 = null
	for _o14 in get_children():
		if _o14 is HTTPRequest and _o14 != _m53 and _o14 != _g91:
			_z20 = _o14
			break
	if _z20:
		_z20.queue_free()
	var success = _s61 == HTTPRequest.RESULT_SUCCESS and _j71 == 200
	if success:
		pass
	else:
		pass
	_w28.emit(success)
func _u100() -> void:
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
func _d74(messages: Array, context_metadata: Dictionary = {}) -> void:
	if _l95.is_empty():
		return
	if _u9 and _u9.is_processing():
		return
	var _z38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l95
	]
	var _z9 = {
		"messages": messages,
		"model": _x46(),
		"context_metadata": context_metadata
	}
	var _y80 = JSON.stringify(_z9)
	var _w79 = _v16 + "/context/estimate"
	var error = _u9.request(_w79, _z38, HTTPClient.METHOD_POST, _y80)
	if error != OK:
		pass
func _o25(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray) -> void:
	if _s61 != HTTPRequest.RESULT_SUCCESS:
		return
	if _j71 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_x89.get_string_from_utf8())
	if error != OK:
		return
	var _c35 = json.get_data()
	if not _c35 is Dictionary:
		return
	var _s26 = _c35.get("tokens", 0)
	var breakdown = _c35.get("breakdown", [])
	var _t43 = _c35.get("context_limit", 128000)
	_q53.emit(_s26, breakdown, _t43)
func _b43() -> void:
	if _d78:
		pass
	var _o86 = _x6()
	var _a4 = _d15()
func _s29() -> void:
	if not _l95.is_empty():
		_i21()
func _i21() -> void:
	var _g3 := _l95.strip_edges(true, true)
	if _g3.is_empty():
		return
	if _q2.is_processing():
		return
	var _z38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _g3
	]
	var _w79 = _v16 + "/plugin/whoami"
	var error = _q2.request(_w79, _z38, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _g87(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray) -> void:
	if _s61 != HTTPRequest.RESULT_SUCCESS:
		_o42()
		return
	if _j71 != 200:
		_o42()
		return
	var json = JSON.new()
	var error = json.parse(_x89.get_string_from_utf8())
	if error != OK:
		_o42()
		return
	var _c35 = json.get_data()
	if not _c35 is Dictionary:
		_o42()
		return
	_k18 = _c35
	_n20.emit(_k18)
	_u8()
func _o42() -> void:
	_k18 = {
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
	_n20.emit(_k18)
func _x72() -> String:
	return _l15(_k18.get("tier", "FREE"))
func _l15(_s58: String) -> String:
	if _s58 == null:
		return "FREE"
	var _e16 = _s58.strip_edges()
	if _e16.is_empty():
		return "FREE"
	_e16 = _e16.replace("-", "_").replace(" ", "_").to_upper()
	return _e16
func _q9(_v70: String) -> String:
	if _v70.is_empty():
		return ""
	var _l82 = _v70.split("T")[0] if "T" in _v70 else _v70
	var _k4 = _l82.split("-")
	if _k4.size() < 3:
		return _v70  
	var year = _k4[0]
	var month = int(_k4[1]) if _k4[1].is_valid_int() else 0
	var day = int(_k4[2]) if _k4[2].is_valid_int() else 0
	if month < 1 or month > 12 or day < 1 or day > 31:
		return _v70  
	var _a72 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %s" % [_a72[month - 1], day, year]
func _e58() -> Dictionary:
	return _k18.get("features", {"explain": true, "refactor": true})
func _p54() -> Dictionary:
	var _f18 = {
		"used": 0.0,
		"limit": 50,
		"pct": 0,
		"remaining": 50.0
	}
	return _k18.get("credits", _f18)
func _z79() -> bool:
	var features = _e58()
	return features.get("refactor", true)
func _w81() -> Array:
	if _k18.has("allowed_models"):
		var _v67 = _k18["allowed_models"]
		if _v67 is Array and _v67.size() > 0:
			var _x43: Array = []
			for model in _v67:
				if model is Dictionary and model.has("id"):
					_x43.append(model["id"])
			if _x43.size() > 0:
				return _x43
	var _d6 = _x72()
	var _c79 = _g4.get(_d6, ["GROUP_FREE"])
	var _v38: Array = []
	for _y21 in _p81:
		if _y21 in _c79 and _b47.has(_y21):
			_v38.append_array(_b47[_y21])
	return _v38
func _c63() -> Array:
	if _k18.has("allowed_models"):
		var _v67 = _k18["allowed_models"]
		if _v67 is Array and _v67.size() > 0:
			return _v67
	return []
func _u8() -> void:
	var _c43 = _p54()
	var used = _c43.get("used", 0.0)
	var limit = _c43.get("limit", 0)
	var _n33 = _c43.get("pct", 0)
	if limit <= 0:
		return  
	var _x76 = ""
	var _h18 = ""
	if _n33 >= 95:
		_x76 = "credits_95"
		_h18 = "critical"
	elif _n33 >= 90:
		_x76 = "credits_90"
		_h18 = "high"
	elif _n33 >= 85:
		_x76 = "credits_85"
		_h18 = "medium"
	elif _n33 >= 80:
		_x76 = "credits_80"
		_h18 = "low"
	if not _x76.is_empty() and not _m49.has(_x76):
		_m49[_x76] = Time.get_ticks_msec()
		var _d98 = _k18.get("renewal_date", "")
		_i10.emit(_h18, "credits", float(_n33), _d98)
func _e67() -> void:
	_k18.clear()
	_i21()
func _v10(_x24: String) -> void:
	if _x24.is_empty():
		return
	var _g49 = _k18.get("tier", "")
	if _x24 != _g49:
		_k18["tier"] = _x24
		_n20.emit(_k18)
func _m47() -> void:
	var _n75 = Time.get_ticks_msec()
	var _a12 = []
	for _x76 in _m49:
		var _i39 = _m49[_x76]
		if (_n75 - _i39) > 3600000:  
			_a12.append(_x76)
	for _y40 in _a12:
		_m49.erase(_y40)
func _p42() -> void:
	if not _n84():
		return
	var _w79 = "https://api.gdsense.com/api/v1/plugin/latest-version"
	var _z38: PackedStringArray = [
		"Content-Type: application/json"
	]
	var error = _f70.request(_w79, _z38, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _n84() -> bool:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") != OK:
		return true  
	var _n43 = config.get_value("updates", "last_check_timestamp", 0)
	var _n75 = int(Time.get_unix_time_from_system())
	return (_n75 - _n43) >= _h69
func _o8(_s61: int, _j71: int, _z38: PackedStringArray, _x89: PackedByteArray) -> void:
	if _s61 != HTTPRequest.RESULT_SUCCESS:
		return
	if _j71 != 200:
		return
	var json = JSON.new()
	var error = json.parse(_x89.get_string_from_utf8())
	if error != OK:
		return
	var _c35 = json.get_data()
	if not _c35 is Dictionary:
		return
	var _r24 = _c35.get("version", "")
	var is_active = _c35.get("isActive", true)
	if _r24.is_empty():
		return
	_d18()
	var _j37 = _i22()
	if is_active and _x50(_j37, _r24) < 0:
		_d51.emit(_r24, _j37)
	else:
		pass
func _d18() -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")  
	config.set_value("updates", "last_check_timestamp", int(Time.get_unix_time_from_system()))
	config.save("user://gdsense_settings.cfg")
func _x50(current: String, _a70: String) -> int:
	var _s12 = current.split(".")
	var _h99 = _a70.split(".")
	var _y99 = max(_s12.size(), _h99.size())
	while _s12.size() < _y99:
		_s12.append("0")
	while _h99.size() < _y99:
		_h99.append("0")
	for i in range(_y99):
		var _x81 = int(_s12[i])
		var _a33 = int(_h99[i])
		if _x81 < _a33:
			return -1
		elif _x81 > _a33:
			return 1
	return 0
func _j23() -> String:
	return _i22()
func _i22() -> String:
	if _m95.is_empty():
		var config = ConfigFile.new()
		if config.load("res://addons/gdsense/plugin.cfg") == OK:
			_m95 = config.get_value("plugin", "version", "0.0.0")
		else:
			_m95 = "0.0.0"
	return _m95
