@tool
class_name _y82
extends Node

signal _g14(_y63: String, _y70: Array, _c83: String, _w37: String)
signal _d87
signal _l62(_u67: int, _x68: String)
signal _q66
signal _m38(_j33: int, _i30: int, _u99: int)
signal _x33(_i100: String, _m81: int)
signal _p52(success: bool)
signal _r67(refactored_code: String, original_hash: String, function_name: String)
signal _p18(_u99: int, breakdown: Array, _g39: int)
signal _e51(_k25: Dictionary)
signal _z93(_m90: String, _q4: String, _p96: float, _t15: String)
signal _o37(message: String)
signal _t32(_l6: String, _y50: String)

var _w70: HTTPRequest
var _z76: HTTPRequest
var _d74: HTTPRequest
var _v82: HTTPRequest
var _o72: HTTPRequest
var _a69: HTTPRequest
var _k13: String = ""
var _x27: bool = false
var _i76: String = "https://api.gdsense.com/api/v1"
var _y40: int = 0
var _j38: String = ""
var _y72: String = ""
var _l15: Dictionary = {}  
var _k6: Dictionary = {}  
var _a80: String = ""  

const _k56 = 86400  
var _x38: String = ""

const _l14 = {
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

const _o94 = {
	"FREE": ["GROUP_FREE"],
	"STARTER": ["GROUP_FREE", "GROUP_STD"],
	"BETA_FREE": ["GROUP_FREE", "GROUP_STD"],
	"PRO": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"],
	"ULTRA": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
}

const _u63 = ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]

func _enter_tree() -> void:
	_w70 = HTTPRequest.new()
	add_child(_w70)
	_w70.request_completed.connect(_a93)

	_z76 = HTTPRequest.new()
	add_child(_z76)
	_z76.request_completed.connect(_y34)
	_z76.timeout = 0.5  

	_d74 = HTTPRequest.new()
	add_child(_d74)
	_d74.request_completed.connect(_p24)
	_d74.timeout = 30.0  

	_v82 = HTTPRequest.new()
	add_child(_v82)
	_v82.request_completed.connect(_q33)
	_v82.timeout = 5.0  

	_o72 = HTTPRequest.new()
	add_child(_o72)
	_o72.request_completed.connect(_o34)
	_o72.timeout = 10.0  

	_a69 = HTTPRequest.new()
	add_child(_a69)
	_a69.request_completed.connect(_k27)
	_a69.timeout = 10.0  

	_r76()
	_z62()
	_m6()
	_l38()
	_f7()

	_q31.call_deferred()

	_e99.call_deferred()

func _a93(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_l62.emit(0, "Network error")
		return

	if _u67 != 200:
		if _u67 == 401:
			_d87.emit()
		elif _u67 == 403:
			var _e22 = "This feature/model is not available in your tier. Please upgrade."
			var json = JSON.new()
			var _o36 = json.parse(_k5.get_string_from_utf8())
			if _o36 == OK:
				var _u39 = json.get_data()
				if _u39 is Dictionary and _u39.has("message"):
					_e22 = _u39.get("message", _e22)
			_l62.emit(_u67, _e22)
		elif _u67 == 429:
			var _e22 = "You've exceeded your quota. Please wait before making more requests."
			var json = JSON.new()
			var _o36 = json.parse(_k5.get_string_from_utf8())
			if _o36 == OK:
				var _u39 = json.get_data()
				if _u39 is Dictionary:
					var _q4 = _u39.get("group", "")
					var _t15 = _u39.get("reset_date", "")
					if not _q4.is_empty():
						if not _t15.is_empty():
							_e22 = "You've exceeded your quota for %s. Resets on %s." % [_q4, _p7(_t15)]
						else:
							_e22 = "You've exceeded your quota for %s." % _q4
					elif _u39.has("message"):
						_e22 = _u39.get("message", _e22)
			_l62.emit(_u67, _e22)
		elif _u67 == 400:
			var _e22 = "Bad request"
			var json = JSON.new()
			var _o36 = json.parse(_k5.get_string_from_utf8())
			if _o36 == OK:
				var _u39 = json.get_data()
				if _u39 is Dictionary and _u39.has("message"):
					_e22 = _u39.get("message", "Bad request")
			_l62.emit(_u67, _e22)
		elif _u67 == 422:
			_l62.emit(_u67, "Request validation failed. Please check your custom rules and parameters.")
		else:
			_l62.emit(_u67, "Server returned an error")
		return

	var json = JSON.new()
	var error = json.parse(_k5.get_string_from_utf8())
	if error != OK:
		_l62.emit(_u67, "Invalid JSON response")
		return

	var _u39 = json.get_data()
	if not _u39 is Dictionary:
		_l62.emit(_u67, "JSON response is not a dictionary.")
		return
	
	if not _u39.has("content"):
		_l62.emit(_u67, "Response does not contain 'content' field.")
		return

	var content = _u39.get("content", "")
	
	var _y70 = []
	if _u39.has("documentation_sources"):
		var _d32 = _u39.get("documentation_sources", [])
		if _d32 is Array:
			for source in _d32:
				if source is Dictionary:
					_y70.append({
						"url": source.get("url", ""),
						"title": source.get("title", "Godot Documentation"),
						"priority": source.get("priority", 0.0),
						"language": source.get("language", "en")
					})

	if _u39.has("response_id"):
		_j38 = _u39.get("response_id", "")

	else:
		pass

	var _c83 = ""
	if _u39.has("thought_signature"):
		_c83 = _u39.get("thought_signature", "")
		_a80 = _c83
	else:
		_a80 = ""

	var _w37 = ""
	if _u39.has("enhanced_user_message"):
		_w37 = _u39.get("enhanced_user_message", "")

	if _u39.has("quota_warning") and _u39.get("quota_warning") is Dictionary:
		var _b68 = _u39.get("quota_warning")
		var _m90 = _b68.get("severity", "notice").to_lower()
		var _q4 = _b68.get("model_group", "")
		var _p96 = _b68.get("usage_percentage", 0.0)
		var _t15 = _b68.get("reset_date", "")

		match _m90:
			"notice":
				_m90 = "medium"
			"warning":
				_m90 = "high"
			"critical", "limit_reached":
				_m90 = "critical"
			_:
				_m90 = "medium"

		var _v22 = "%s_%s_%d" % [_q4, _m90, int(_p96 / 5) * 5]  

		if not _q4.is_empty() and not _k6.has(_v22):
			_k6[_v22] = Time.get_ticks_msec()
			_z93.emit(_m90, _q4, _p96, _t15)

	if _u39.has("truncation_warning"):
		var _d27 = _u39.get("truncation_warning", "")
		if _d27 is String and not _d27.is_empty():
			_o37.emit(_d27)

	if _u39.has("tier"):
		var _s85 = _u39.get("tier", "")
		if _s85 is String and not _s85.is_empty():
			var _w58 = _l15.get("tier", "")
			if _s85 != _w58:
				_l15["tier"] = _s85
				_e51.emit(_l15)

	for _j29 in _e88:
		if _j29.begins_with("X-Usage-Warning:"):
			var _x39 = _j29.split(": ", true, 1)[1] if _j29.contains(": ") else ""
		elif _j29.begins_with("X-Model-Group:"):
			var _w45 = _j29.split(": ", true, 1)[1] if _j29.contains(": ") else ""

	_g14.emit(content, _y70, _c83, _w37)

	if _u39.has("usage"):
		var _v38 = _u39.get("usage", {})
		var _j33 = _v38.get("prompt_tokens", 0)
		var _i30 = _v38.get("completion_tokens", 0)
		var _u99 = _v38.get("total_tokens", 0)
		_m38.emit(_j33, _i30, _u99)

func _z62() -> void:
	var _m25 := ConfigFile.new()
	var error := _m25.load("user://gdsense_api_key.cfg")
	if error == OK:
		if _x27:
			var env = _a99()
			_k13 = _m25.get_value("api_keys", env, "")
			
			if _k13.is_empty():
				_k13 = _m25.get_value("plugin", "api_key", "")

				if not _k13.is_empty() and env == "production":
					_m25.set_value("api_keys", "production", _k13)
					_m25.save("user://gdsense_api_key.cfg")
		else:
			_k13 = _m25.get_value("api_keys", "production", "")

			if _k13.is_empty():
				_k13 = _m25.get_value("plugin", "api_key", "")
		
	else:
		pass

func _y16(_t90: String) -> void:
	var _m25 := ConfigFile.new()
	_m25.load("user://gdsense_api_key.cfg")  
	
	if _x27:
		var env = _a99()
		_m25.set_value("api_keys", env, _t90)

	else:
		_m25.set_value("api_keys", "production", _t90)
	
	if not _x27 or _a99() == "production":
		_m25.set_value("plugin", "api_key", _t90)
	
	_m25.save("user://gdsense_api_key.cfg")
	_k13 = _t90

	_q66.emit()

	_i97.call_deferred()

func _x42() -> String:
	return _k13

func _w6() -> String:
	return _i76

func _k38() -> bool:
	return not _k13.strip_edges().is_empty()

func _p92() -> Dictionary:
	return _l15

func _f10(environment: String) -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", environment, "")
	return ""

func _w60(model: String) -> void:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
	else:
		config.set_value("plugin", "api_key", _k13)
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")

func _p43() -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var model = config.get_value("settings", "selected_model", "llama-3.1-8b-instant")

		if model == "Meta-Llama-3-8B-Instruct" or model == "Meta-Llama-3.1-8B-Instruct" or model == "llama-3.1-8b-instruct":
			model = "llama-3.1-8b-instant"
			_w60(model)  
		elif model == "Meta-Llama-3-70B-Instruct" or model == "Meta-Llama-3.1-70B-Instruct":
			model = "llama-3.1-70b-instruct"
			_w60(model)  
		elif model == "gemini-2.5-flash-lite-preview-06-17":
			model = "gemini-2.5-flash-lite"
			_w60(model)  
		
		return model
	return "llama-3.1-8b-instant"

func _r76() -> void:
	var _f29 = FileAccess.open("res://.gdsense-dev", FileAccess.READ)
	_x27 = _f29 != null
	if _f29:
		_f29.close()
	if _x27:
		pass

func _o98() -> bool:
	return _x27

func _m6() -> void:
	if not _x27:
		_i76 = "https://api.gdsense.com/api/v1"
		return
	
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var env = config.get_value("developer", "api_environment", "production")
		if env == "development":
			_i76 = "http://localhost:8080/api/v1"
		else:
			_i76 = "https://api.gdsense.com/api/v1"

func _l88(environment: String) -> void:
	if not _x27:
		return
	
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("developer", "api_environment", environment)
	config.save("user://gdsense_api_key.cfg")
	_m6()

	_z62()

func _a99() -> String:
	if not _x27:
		return "production"
	
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("developer", "api_environment", "production")
	return "production"

func _m37(messages: Array, _n49: String = "", _x32: String = "", context_metadata: Dictionary = {}) -> void:
	_z62() 

	_n67()

	var _t88 := _k13.strip_edges(true, true)

	if _t88.is_empty():
		_d87.emit()
		return

	if _w70.is_processing():
		return

	var _e88: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _t88
	]
	
	var _i62 = _p43()
	var _e11 = {
		"messages": messages,
		"model": _i62,
		"godotVersion": _s18(),
		"chat_session_id": _y72
	}
	
	if not context_metadata.is_empty():
		_e11["context_metadata"] = context_metadata

	if not _n49.is_empty():
		_e11["command"] = _n49

	if not _x32.is_empty():
		_e11["function_context"] = _x32

	var _d81 = _f19()
	if _d81.size() > 0:
		_e11["custom_rules"] = _d81
	
	var _y31 = _u56()
	if not _y31.is_empty():
		_e11["parametersOverride"] = _y31
	
	var _k5: String = JSON.stringify(_e11)
	
	if _e11.has("custom_rules"):
		var _f6 = _e11["custom_rules"]

	else:
		pass

	var _o41 = _i76 + "/completion"

	var error = _w70.request(_o41, _e88, HTTPClient.METHOD_POST, _k5)
	if error != OK:
		_l62.emit(0, "Failed to start request.")
		return 

func _h96(context: Dictionary) -> void:
	_z62() 
	
	var _t88 := _k13.strip_edges(true, true)
	
	if _t88.is_empty():
		return
	
	if is_instance_valid(_z76):
		if _z76.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_z76.cancel_request()
	
	var _e88: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _t88
	]
	
	var _k5: String = JSON.stringify({
		"context": context,
		"maxTokens": 150  
	})
	
	_y40 = Time.get_ticks_msec()
	
	var _o41 = _i76 + "/autocomplete"

	var error = _z76.request(_o41, _e88, HTTPClient.METHOD_POST, _k5)
	if error != OK:
		return

func _y34(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray) -> void:
	var _m81 = Time.get_ticks_msec() - _y40

	if _x97 != HTTPRequest.RESULT_SUCCESS:
		return
	
	if _u67 != 200:
		return
	
	var json = JSON.new()
	var error = json.parse(_k5.get_string_from_utf8())
	if error != OK:
		return
	
	var _u39 = json.get_data()
	if not _u39 is Dictionary:
		return
	
	var _i100 = _u39.get("suggestion", "")
	if _i100.is_empty():
		return
	
	_x33.emit(_i100, _m81)

var _b6: Dictionary = {}  

func _s41(function_name: String, _c25: String, _s1: String, file_path: String = "", model: String = "") -> void:
	_z62() 

	var _t88 := _k13.strip_edges(true, true)

	if _t88.is_empty():
		_d87.emit()
		return

	if is_instance_valid(_d74):
		if _d74.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_d74.cancel_request()
	else:
		pass

	var _e88: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _t88
	]

	var original_hash = _w67(_c25)

	_b6 = {
		"function_name": function_name,
		"original_hash": original_hash
	}

	if _y72.is_empty():
		_f7()

	var _w4 = model if not model.is_empty() else "gemini-2.5-flash"

	var _r55 = {
		"file_path": file_path if file_path else "unknown.gd",
		"language": "gdscript",
		"func_name": function_name,
		"func_code": _c25,
		"user_prompt": _s1,
		"editor_version": _s18(),
		"chat_session_id": _y72,
		"model": _w4
	}
	
	var _k5: String = JSON.stringify(_r55)
	
	var _o41 = _i76 + "/refactor"

	if not is_instance_valid(_d74):
		_d74 = HTTPRequest.new()
		add_child(_d74)
		_d74.request_completed.connect(_p24)
		_d74.timeout = 30.0
	
	var error = _d74.request(_o41, _e88, HTTPClient.METHOD_POST, _k5)
	if error != OK:
		_l62.emit(0, "Failed to start refactor request.")
		return

func _p24(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_l62.emit(0, "Network error during refactor")
		return
	
	if _u67 != 200:
		var _e22 = ""
		var json = JSON.new()
		var _o36 = json.parse(_k5.get_string_from_utf8())
		var _u39 = {}
		if _o36 == OK:
			var data = json.get_data()
			if data is Dictionary:
				_u39 = data

		if _u67 == 401:
			_d87.emit()
		elif _u67 == 403:
			_e22 = "Refactor is not available in your tier. Please upgrade."
			if _u39.has("message"):
				_e22 = _u39.get("message", _e22)
			_l62.emit(_u67, _e22)
		elif _u67 == 429:
			_e22 = "You've exceeded your refactor quota. Please wait before making more requests."
			if _u39.has("group") or _u39.has("reset_date"):
				var _q4 = _u39.get("group", "")
				var _t15 = _u39.get("reset_date", "")
				if not _q4.is_empty():
					if not _t15.is_empty():
						_e22 = "You've exceeded your quota for %s. Resets on %s." % [_q4, _p7(_t15)]
					else:
						_e22 = "You've exceeded your quota for %s." % _q4
			elif _u39.has("message"):
				_e22 = _u39.get("message", _e22)
			_l62.emit(_u67, _e22)
		elif _u67 == 400:
			_e22 = "Bad refactor request"
			if _u39.has("message"):
				_e22 = _u39.get("message", _e22)
			_l62.emit(_u67, _e22)
		elif _u67 == 422:
			_e22 = "Refactor request validation failed."
			if _u39.has("message"):
				_e22 = _u39.get("message", _e22)
			_l62.emit(_u67, _e22)
		else:
			_e22 = "Server returned an error during refactor (code: %d)" % _u67
			if _u39.has("message"):
				_e22 = _u39.get("message", _e22)
			elif _u39.has("error"):
				_e22 = _u39.get("error", _e22)
			_l62.emit(_u67, _e22)
		return
	
	var json = JSON.new()
	var error = json.parse(_k5.get_string_from_utf8())
	if error != OK:
		_l62.emit(_u67, "Invalid JSON response from refactor")
		return
	
	var _u39 = json.get_data()
	if not _u39 is Dictionary:
		_l62.emit(_u67, "Refactor response is not a dictionary")
		return
	
	if not _u39.has("rewritten_func"):
		_l62.emit(_u67, "Refactor response missing 'rewritten_func' field")
		return
	
	var refactored_code = _u39.get("rewritten_func", "")
	
	if refactored_code.is_empty():
		_l62.emit(_u67, "Refactor response contains empty code")
		return
	
	var function_name = _b6.get("function_name", "")
	var original_hash = _b6.get("original_hash", "")
	
	_b6.clear()
	
	_r67.emit(refactored_code, original_hash, function_name)

func _w67(text: String) -> String:
	var _e33 = HashingContext.new()
	_e33.start(HashingContext.HASH_SHA256)
	_e33.update(text.to_utf8_buffer())
	var _k15 = _e33.finish()
	
	return _k15.hex_encode()

func _s18() -> String:
	var _m65 = Engine.get_version_info()
	return "%d.%d.%d" % [_m65.major, _m65.minor, _m65.patch]

func _f19() -> PackedStringArray:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _v69 = config.get_value("custom_rules", "rules_text", "")
		if not _v69.is_empty():
			var _o76 = _v69.split("\n")
			var _q44 = PackedStringArray()
			for _w22 in _o76:
				var _m69 = _w22.strip_edges()
				if not _m69.is_empty():
					_q44.append(_m69)
			return _q44
	return PackedStringArray()

func _u56() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _u88 = {}
		var _p98 = config.get_value("parameters", "temperature_override", 0.0)
		var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
		
		if _p98 > 0.0:
			_u88["temperature"] = _p98
		if max_tokens > 0:
			_u88["max_tokens"] = max_tokens
			
		return _u88
	return {}

func _a73(_v69: String) -> Dictionary:
	var _x97 = {"valid": true, "errors": []}

	if _v69.length() > 500:
		_x97["valid"] = false
		_x97["errors"].append("Custom rules must be under 500 characters")

	var _m40 = [
		"system:", "assistant:", "user:",
		"ignore all previous", "disregard instructions",
		"forget previous", "override system"
	]

	var _r73 = _v69.to_lower()
	for _t30 in _m40:
		if _r73.find(_t30) != -1:
			_x97["valid"] = false
			_x97["errors"].append("System instruction overrides are not allowed")
			break

	return _x97

func _o43(_v69: String) -> bool:
	var _u74 = _a73(_v69)
	if not _u74.get("valid", false):
		return false
	
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("custom_rules", "rules_text", _v69)
	config.save("user://gdsense_settings.cfg")
	return true

func _g57(_p98: float, max_tokens: int) -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("parameters", "temperature_override", _p98)
	config.set_value("parameters", "max_tokens_override", max_tokens)
	config.save("user://gdsense_settings.cfg")

func _n25() -> String:
	return _j38

func _y5() -> String:
	var _q69 = []
	for i in range(32):
		_q69.append(randi() % 16)
	
	_q69[12] = 4  
	_q69[16] = (_q69[16] & 0x3) | 0x8  
	
	var _v75 = "0123456789abcdef"
	var _x97 = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			_x97 += "-"
		_x97 += _v75[_q69[i]]
	
	return _x97

func _f7() -> void:
	_y72 = _y5()

func _e91() -> String:
	return _y72

func _i91(rating: String, category: String = "", details: String = "") -> void:
	if _j38.is_empty():
		return
	
	var _t88 := _k13.strip_edges(true, true)
	if _t88.is_empty():
		return
	
	var _e88: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _t88
	]
	
	var _k2 = {
		"responseId": _j38,
		"rating": rating,
		"category": category,
		"details": details,
		"chat_session_id": _y72,
		"context": {
			"model": _p43(),
			"godotVersion": _s18()
		}
	}
	
	var _k5: String = JSON.stringify(_k2)
	
	var _p20 = HTTPRequest.new()
	add_child(_p20)
	_p20.request_completed.connect(_u54)
	
	var _o41 = _i76 + "/feedback"

	var error = _p20.request(_o41, _e88, HTTPClient.METHOD_POST, _k5)
	if error != OK:
		_p20.queue_free()

func _u54(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray) -> void:
	var _s92 = null
	for _c100 in get_children():
		if _c100 is HTTPRequest and _c100 != _w70 and _c100 != _z76:
			_s92 = _c100
			break
	
	if _s92:
		_s92.queue_free()
	
	var success = _x97 == HTTPRequest.RESULT_SUCCESS and _u67 == 200
	if success:
		pass

	else:
		pass

	_p52.emit(success)

func _l38() -> void:
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

func _a77(messages: Array, context_metadata: Dictionary = {}) -> void:
	if _k13.is_empty():
		return

	if _v82 and _v82.is_processing():
		return

	var _e88: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _k13
	]

	var _e11 = {
		"messages": messages,
		"model": _p43(),
		"context_metadata": context_metadata
	}

	var _j32 = JSON.stringify(_e11)
	var _o41 = _i76 + "/context/estimate"

	var error = _v82.request(_o41, _e88, HTTPClient.METHOD_POST, _j32)
	if error != OK:
		pass

func _q33(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		return
	
	if _u67 != 200:
		return
	
	var json = JSON.new()
	var error = json.parse(_k5.get_string_from_utf8())
	if error != OK:
		return
	
	var _u39 = json.get_data()
	if not _u39 is Dictionary:
		return
	
	var _u99 = _u39.get("tokens", 0)
	var breakdown = _u39.get("breakdown", [])
	var _g39 = _u39.get("context_limit", 128000)

	_p18.emit(_u99, breakdown, _g39)

func _b42() -> void:
	if _x27:
		pass

	var _d81 = _f19()

	var _y31 = _u56()

func _q31() -> void:
	if not _k13.is_empty():
		_a60()

func _a60() -> void:
	var _t88 := _k13.strip_edges(true, true)
	if _t88.is_empty():
		return

	if _o72.is_processing():
		return

	var _e88: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _t88
	]

	var _o41 = _i76 + "/plugin/whoami"

	var error = _o72.request(_o41, _e88, HTTPClient.METHOD_GET)
	if error != OK:
		pass

func _o34(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		_j6()
		return

	if _u67 != 200:
		_j6()
		return

	var json = JSON.new()
	var error = json.parse(_k5.get_string_from_utf8())
	if error != OK:
		_j6()
		return

	var _u39 = json.get_data()
	if not _u39 is Dictionary:
		_j6()
		return

	_l15 = _u39

	_e51.emit(_l15)

	_c20()

func _j6() -> void:
	_l15 = {
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
	_e51.emit(_l15)

func _g25() -> String:
	return _b25(_l15.get("tier", "FREE"))

func _b25(_x43: String) -> String:
	if _x43 == null:
		return "FREE"
	var _d66 = _x43.strip_edges()
	if _d66.is_empty():
		return "FREE"
	_d66 = _d66.replace("-", "_").replace(" ", "_").to_upper()
	return _d66

func _p7(_s46: String) -> String:
	if _s46.is_empty():
		return ""

	var _j69 = _s46.split("T")[0] if "T" in _s46 else _s46
	var _d21 = _j69.split("-")

	if _d21.size() < 3:
		return _s46  

	var year = _d21[0]
	var month = int(_d21[1]) if _d21[1].is_valid_int() else 0
	var day = int(_d21[2]) if _d21[2].is_valid_int() else 0

	if month < 1 or month > 12 or day < 1 or day > 31:
		return _s46  

	var _u78 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

	return "%s %d, %s" % [_u78[month - 1], day, year]

func _r17() -> Dictionary:
	return _l15.get("features", {"explain": true, "refactor": true})

func _v51() -> Dictionary:
	var _k83 = {
		"used": 0.0,
		"limit": 50,
		"pct": 0,
		"remaining": 50.0
	}
	return _l15.get("credits", _k83)

func _c99() -> bool:
	var features = _r17()
	return features.get("refactor", true)

func _j48() -> Array:
	if _l15.has("allowed_models"):
		var _q25 = _l15["allowed_models"]
		if _q25 is Array and _q25.size() > 0:
			var _m100: Array = []
			for model in _q25:
				if model is Dictionary and model.has("id"):
					_m100.append(model["id"])
			if _m100.size() > 0:
				return _m100

	var _n92 = _g25()

	var _n68 = _o94.get(_n92, ["GROUP_FREE"])
	var _g96: Array = []

	for _q4 in _u63:
		if _q4 in _n68 and _l14.has(_q4):
			_g96.append_array(_l14[_q4])

	return _g96

func _r45() -> Array:
	if _l15.has("allowed_models"):
		var _q25 = _l15["allowed_models"]
		if _q25 is Array and _q25.size() > 0:
			return _q25

	return []

func _c20() -> void:
	var _e37 = _v51()

	var used = _e37.get("used", 0.0)
	var limit = _e37.get("limit", 0)
	var _p96 = _e37.get("pct", 0)

	if limit <= 0:
		return  

	var _v22 = ""
	var _m90 = ""

	if _p96 >= 95:
		_v22 = "credits_95"
		_m90 = "critical"
	elif _p96 >= 90:
		_v22 = "credits_90"
		_m90 = "high"
	elif _p96 >= 85:
		_v22 = "credits_85"
		_m90 = "medium"
	elif _p96 >= 80:
		_v22 = "credits_80"
		_m90 = "low"

	if not _v22.is_empty() and not _k6.has(_v22):
		_k6[_v22] = Time.get_ticks_msec()

		var _b83 = _l15.get("renewal_date", "")
		_z93.emit(_m90, "credits", float(_p96), _b83)

func _i97() -> void:
	_l15.clear()
	_a60()

func _h65(_s85: String) -> void:
	if _s85.is_empty():
		return
	var _w58 = _l15.get("tier", "")
	if _s85 != _w58:
		_l15["tier"] = _s85
		_e51.emit(_l15)
func _n67() -> void:
	var _l95 = Time.get_ticks_msec()
	var _j87 = []

	for _v22 in _k6:
		var _t53 = _k6[_v22]

		if (_l95 - _t53) > 3600000:  
			_j87.append(_v22)

	for _t90 in _j87:
		_k6.erase(_t90)

func _e99() -> void:
	if not _n5():
		return

	var _o41 = "https://api.gdsense.com/api/v1/plugin/latest-version"

	var _e88: PackedStringArray = [
		"Content-Type: application/json"
	]

	var error = _a69.request(_o41, _e88, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _n5() -> bool:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") != OK:
		return true  

	var _a10 = config.get_value("updates", "last_check_timestamp", 0)
	var _l95 = int(Time.get_unix_time_from_system())

	return (_l95 - _a10) >= _k56

func _k27(_x97: int, _u67: int, _e88: PackedStringArray, _k5: PackedByteArray) -> void:
	if _x97 != HTTPRequest.RESULT_SUCCESS:
		return

	if _u67 != 200:
		return

	var json = JSON.new()
	var error = json.parse(_k5.get_string_from_utf8())
	if error != OK:
		return

	var _u39 = json.get_data()
	if not _u39 is Dictionary:
		return

	var _l6 = _u39.get("version", "")
	var is_active = _u39.get("isActive", true)

	if _l6.is_empty():
		return

	_h7()

	var _y50 = _m71()

	if is_active and _m2(_y50, _l6) < 0:
		_t32.emit(_l6, _y50)
	else:
		pass
func _h7() -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")  
	config.set_value("updates", "last_check_timestamp", int(Time.get_unix_time_from_system()))
	config.save("user://gdsense_settings.cfg")

func _m2(current: String, _s43: String) -> int:
	var _d7 = current.split(".")
	var _f16 = _s43.split(".")

	var _p78 = max(_d7.size(), _f16.size())
	while _d7.size() < _p78:
		_d7.append("0")
	while _f16.size() < _p78:
		_f16.append("0")

	for i in range(_p78):
		var _q29 = int(_d7[i])
		var _r79 = int(_f16[i])

		if _q29 < _r79:
			return -1
		elif _q29 > _r79:
			return 1

	return 0

func _c64() -> String:
	return _m71()

func _m71() -> String:
	if _x38.is_empty():
		var config = ConfigFile.new()
		if config.load("res://addons/gdsense/plugin.cfg") == OK:
			_x38 = config.get_value("plugin", "version", "0.0.0")
		else:
			_x38 = "0.0.0"
	return _x38

