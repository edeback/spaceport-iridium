@tool
class_name _w70
extends Node

signal _w22(_r73: String, _i76: Array, _y8: String, _f1: String)
signal _t4
signal _i53(_s65: int, _o23: String)
signal _r78
signal _b48(_j51: int, _e34: int, _u3: int)
signal _b67(_q88: String, _c46: int)
signal _u23(success: bool)
signal _o98(refactored_code: String, original_hash: String, function_name: String)
signal _y98(_u3: int, breakdown: Array, _y86: int)
signal _w60(_v57: Dictionary)
signal _n43(_i90: String, _n75: String, _i73: float, _f91: String)
signal _f5(message: String)
signal _g27(_r35: String, _d38: String)

var _q76: HTTPRequest
var _d6: HTTPRequest
var _l98: HTTPRequest
var _e37: HTTPRequest
var _b61: HTTPRequest
var _o99: HTTPRequest
var _i59: String = ""
var _k68: bool = false
var _v55: String = "https://api.gdsense.com/api/v1"
var _n15: int = 0
var _j79: String = ""
var _b53: String = ""
var _i57: Dictionary = {}  
var _v90: Dictionary = {}  
var _a99: String = ""  

const _y66 = 86400  
var _z82: String = ""

const _e15 = {
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

const _x72 = {
	"FREE": ["GROUP_FREE"],
	"STARTER": ["GROUP_FREE", "GROUP_STD"],
	"BETA_FREE": ["GROUP_FREE", "GROUP_STD"],
	"PRO": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"],
	"ULTRA": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
}

const _u15 = ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]

func _enter_tree() -> void:
	_q76 = HTTPRequest.new()
	add_child(_q76)
	_q76.request_completed.connect(_t85)

	_d6 = HTTPRequest.new()
	add_child(_d6)
	_d6.request_completed.connect(_j12)
	_d6.timeout = 0.5  

	_l98 = HTTPRequest.new()
	add_child(_l98)
	_l98.request_completed.connect(_w58)
	_l98.timeout = 30.0  

	_e37 = HTTPRequest.new()
	add_child(_e37)
	_e37.request_completed.connect(_w31)
	_e37.timeout = 5.0  

	_b61 = HTTPRequest.new()
	add_child(_b61)
	_b61.request_completed.connect(_j6)
	_b61.timeout = 10.0  

	_o99 = HTTPRequest.new()
	add_child(_o99)
	_o99.request_completed.connect(_m64)
	_o99.timeout = 10.0  

	_m53()
	_y31()
	_u73()
	_k59()
	_l94()

	_p81.call_deferred()

	_x39.call_deferred()

func _t85(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray) -> void:
	if _k3 != HTTPRequest.RESULT_SUCCESS:
		_i53.emit(0, "Network error")
		return

	if _s65 != 200:
		if _s65 == 401:
			_t4.emit()
		elif _s65 == 403:
			var _p59 = "This feature/model is not available in your tier. Please upgrade."
			var json = JSON.new()
			var _d58 = json.parse(_r16.get_string_from_utf8())
			if _d58 == OK:
				var _v4 = json.get_data()
				if _v4 is Dictionary and _v4.has("message"):
					_p59 = _v4.get("message", _p59)
			_i53.emit(_s65, _p59)
		elif _s65 == 429:
			var _p59 = "You've exceeded your quota. Please wait before making more requests."
			var json = JSON.new()
			var _d58 = json.parse(_r16.get_string_from_utf8())
			if _d58 == OK:
				var _v4 = json.get_data()
				if _v4 is Dictionary:
					var _n75 = _v4.get("group", "")
					var _f91 = _v4.get("reset_date", "")
					if not _n75.is_empty():
						if not _f91.is_empty():
							_p59 = "You've exceeded your quota for %s. Resets on %s." % [_n75, _o15(_f91)]
						else:
							_p59 = "You've exceeded your quota for %s." % _n75
					elif _v4.has("message"):
						_p59 = _v4.get("message", _p59)
			_i53.emit(_s65, _p59)
		elif _s65 == 400:
			var _p59 = "Bad request"
			var json = JSON.new()
			var _d58 = json.parse(_r16.get_string_from_utf8())
			if _d58 == OK:
				var _v4 = json.get_data()
				if _v4 is Dictionary and _v4.has("message"):
					_p59 = _v4.get("message", "Bad request")
			_i53.emit(_s65, _p59)
		elif _s65 == 422:
			_i53.emit(_s65, "Request validation failed. Please check your custom rules and parameters.")
		else:
			_i53.emit(_s65, "Server returned an error")
		return

	var json = JSON.new()
	var error = json.parse(_r16.get_string_from_utf8())
	if error != OK:
		_i53.emit(_s65, "Invalid JSON response")
		return

	var _v4 = json.get_data()
	if not _v4 is Dictionary:
		_i53.emit(_s65, "JSON response is not a dictionary.")
		return
	
	if not _v4.has("content"):
		_i53.emit(_s65, "Response does not contain 'content' field.")
		return

	var content = _v4.get("content", "")
	
	var _i76 = []
	if _v4.has("documentation_sources"):
		var _x65 = _v4.get("documentation_sources", [])
		if _x65 is Array:
			for source in _x65:
				if source is Dictionary:
					_i76.append({
						"url": source.get("url", ""),
						"title": source.get("title", "Godot Documentation"),
						"priority": source.get("priority", 0.0),
						"language": source.get("language", "en")
					})

	if _v4.has("response_id"):
		_j79 = _v4.get("response_id", "")

	else:
		pass

	var _y8 = ""
	if _v4.has("thought_signature"):
		_y8 = _v4.get("thought_signature", "")
		_a99 = _y8
	else:
		_a99 = ""

	var _f1 = ""
	if _v4.has("enhanced_user_message"):
		_f1 = _v4.get("enhanced_user_message", "")

	if _v4.has("quota_warning") and _v4.get("quota_warning") is Dictionary:
		var _m1 = _v4.get("quota_warning")
		var _i90 = _m1.get("severity", "notice").to_lower()
		var _n75 = _m1.get("model_group", "")
		var _i73 = _m1.get("usage_percentage", 0.0)
		var _f91 = _m1.get("reset_date", "")

		match _i90:
			"notice":
				_i90 = "medium"
			"warning":
				_i90 = "high"
			"critical", "limit_reached":
				_i90 = "critical"
			_:
				_i90 = "medium"

		var _p87 = "%s_%s_%d" % [_n75, _i90, int(_i73 / 5) * 5]  

		if not _n75.is_empty() and not _v90.has(_p87):
			_v90[_p87] = Time.get_ticks_msec()
			_n43.emit(_i90, _n75, _i73, _f91)

	if _v4.has("truncation_warning"):
		var _w100 = _v4.get("truncation_warning", "")
		if _w100 is String and not _w100.is_empty():
			_f5.emit(_w100)

	if _v4.has("tier"):
		var _i31 = _v4.get("tier", "")
		if _i31 is String and not _i31.is_empty():
			var _l14 = _i57.get("tier", "")
			if _i31 != _l14:
				_i57["tier"] = _i31
				_w60.emit(_i57)

	for _l100 in _n38:
		if _l100.begins_with("X-Usage-Warning:"):
			var _a95 = _l100.split(": ", true, 1)[1] if _l100.contains(": ") else ""
		elif _l100.begins_with("X-Model-Group:"):
			var _c68 = _l100.split(": ", true, 1)[1] if _l100.contains(": ") else ""

	_w22.emit(content, _i76, _y8, _f1)

	if _v4.has("usage"):
		var _o40 = _v4.get("usage", {})
		var _j51 = _o40.get("prompt_tokens", 0)
		var _e34 = _o40.get("completion_tokens", 0)
		var _u3 = _o40.get("total_tokens", 0)
		_b48.emit(_j51, _e34, _u3)

func _y31() -> void:
	var _c66 := ConfigFile.new()
	var error := _c66.load("user://gdsense_api_key.cfg")
	if error == OK:
		if _k68:
			var env = _f35()
			_i59 = _c66.get_value("api_keys", env, "")
			
			if _i59.is_empty():
				_i59 = _c66.get_value("plugin", "api_key", "")

				if not _i59.is_empty() and env == "production":
					_c66.set_value("api_keys", "production", _i59)
					_c66.save("user://gdsense_api_key.cfg")
		else:
			_i59 = _c66.get_value("api_keys", "production", "")

			if _i59.is_empty():
				_i59 = _c66.get_value("plugin", "api_key", "")
		
	else:
		pass

func _t66(_y48: String) -> void:
	var _c66 := ConfigFile.new()
	_c66.load("user://gdsense_api_key.cfg")  
	
	if _k68:
		var env = _f35()
		_c66.set_value("api_keys", env, _y48)

	else:
		_c66.set_value("api_keys", "production", _y48)
	
	if not _k68 or _f35() == "production":
		_c66.set_value("plugin", "api_key", _y48)
	
	_c66.save("user://gdsense_api_key.cfg")
	_i59 = _y48

	_r78.emit()

	_q38.call_deferred()

func _m83() -> String:
	return _i59

func _n87() -> String:
	return _v55

func _l7() -> bool:
	return not _i59.strip_edges().is_empty()

func _r47() -> Dictionary:
	return _i57

func _m30(environment: String) -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", environment, "")
	return ""

func _k51(model: String) -> void:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
	else:
		config.set_value("plugin", "api_key", _i59)
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")

func _s21() -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var model = config.get_value("settings", "selected_model", "llama-3.1-8b-instant")

		if model == "Meta-Llama-3-8B-Instruct" or model == "Meta-Llama-3.1-8B-Instruct" or model == "llama-3.1-8b-instruct":
			model = "llama-3.1-8b-instant"
			_k51(model)  
		elif model == "Meta-Llama-3-70B-Instruct" or model == "Meta-Llama-3.1-70B-Instruct":
			model = "llama-3.1-70b-instruct"
			_k51(model)  
		elif model == "gemini-2.5-flash-lite-preview-06-17":
			model = "gemini-2.5-flash-lite"
			_k51(model)  
		
		return model
	return "llama-3.1-8b-instant"

func _m53() -> void:
	var _l54 = FileAccess.open("res://.gdsense-dev", FileAccess.READ)
	_k68 = _l54 != null
	if _l54:
		_l54.close()
	if _k68:
		pass

func _e2() -> bool:
	return _k68

func _u73() -> void:
	if not _k68:
		_v55 = "https://api.gdsense.com/api/v1"
		return
	
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var env = config.get_value("developer", "api_environment", "production")
		if env == "development":
			_v55 = "http://localhost:8080/api/v1"
		else:
			_v55 = "https://api.gdsense.com/api/v1"

func _a11(environment: String) -> void:
	if not _k68:
		return
	
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("developer", "api_environment", environment)
	config.save("user://gdsense_api_key.cfg")
	_u73()

	_y31()

func _f35() -> String:
	if not _k68:
		return "production"
	
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("developer", "api_environment", "production")
	return "production"

func _u25(messages: Array, _r33: String = "", _j57: String = "", context_metadata: Dictionary = {}) -> void:
	_y31() 

	_u97()

	var _l11 := _i59.strip_edges(true, true)

	if _l11.is_empty():
		_t4.emit()
		return

	if _q76.is_processing():
		return

	var _n38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l11
	]
	
	var _p26 = _s21()
	var _m33 = {
		"messages": messages,
		"model": _p26,
		"godotVersion": _s50(),
		"chat_session_id": _b53
	}
	
	if not context_metadata.is_empty():
		_m33["context_metadata"] = context_metadata

	if not _r33.is_empty():
		_m33["command"] = _r33

	if not _j57.is_empty():
		_m33["function_context"] = _j57

	var _s9 = _d49()
	if _s9.size() > 0:
		_m33["custom_rules"] = _s9
	
	var _j30 = _j34()
	if not _j30.is_empty():
		_m33["parametersOverride"] = _j30
	
	var _r16: String = JSON.stringify(_m33)
	
	if _m33.has("custom_rules"):
		var _n39 = _m33["custom_rules"]

	else:
		pass

	var _p12 = _v55 + "/completion"

	var error = _q76.request(_p12, _n38, HTTPClient.METHOD_POST, _r16)
	if error != OK:
		_i53.emit(0, "Failed to start request.")
		return 

func _w26(context: Dictionary) -> void:
	_y31() 
	
	var _l11 := _i59.strip_edges(true, true)
	
	if _l11.is_empty():
		return
	
	if is_instance_valid(_d6):
		if _d6.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_d6.cancel_request()
	
	var _n38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l11
	]
	
	var _r16: String = JSON.stringify({
		"context": context,
		"maxTokens": 150  
	})
	
	_n15 = Time.get_ticks_msec()
	
	var _p12 = _v55 + "/autocomplete"

	var error = _d6.request(_p12, _n38, HTTPClient.METHOD_POST, _r16)
	if error != OK:
		return

func _j12(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray) -> void:
	var _c46 = Time.get_ticks_msec() - _n15

	if _k3 != HTTPRequest.RESULT_SUCCESS:
		return
	
	if _s65 != 200:
		return
	
	var json = JSON.new()
	var error = json.parse(_r16.get_string_from_utf8())
	if error != OK:
		return
	
	var _v4 = json.get_data()
	if not _v4 is Dictionary:
		return
	
	var _q88 = _v4.get("suggestion", "")
	if _q88.is_empty():
		return
	
	_b67.emit(_q88, _c46)

var _h58: Dictionary = {}  

func _j84(function_name: String, _g33: String, _b52: String, file_path: String = "", model: String = "") -> void:
	_y31() 

	var _l11 := _i59.strip_edges(true, true)

	if _l11.is_empty():
		_t4.emit()
		return

	if is_instance_valid(_l98):
		if _l98.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_l98.cancel_request()
	else:
		pass

	var _n38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l11
	]

	var original_hash = _a50(_g33)

	_h58 = {
		"function_name": function_name,
		"original_hash": original_hash
	}

	if _b53.is_empty():
		_l94()

	var _q57 = model if not model.is_empty() else "gemini-2.5-flash"

	var _u75 = {
		"file_path": file_path if file_path else "unknown.gd",
		"language": "gdscript",
		"func_name": function_name,
		"func_code": _g33,
		"user_prompt": _b52,
		"editor_version": _s50(),
		"chat_session_id": _b53,
		"model": _q57
	}
	
	var _r16: String = JSON.stringify(_u75)
	
	var _p12 = _v55 + "/refactor"

	if not is_instance_valid(_l98):
		_l98 = HTTPRequest.new()
		add_child(_l98)
		_l98.request_completed.connect(_w58)
		_l98.timeout = 30.0
	
	var error = _l98.request(_p12, _n38, HTTPClient.METHOD_POST, _r16)
	if error != OK:
		_i53.emit(0, "Failed to start refactor request.")
		return

func _w58(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray) -> void:
	if _k3 != HTTPRequest.RESULT_SUCCESS:
		_i53.emit(0, "Network error during refactor")
		return
	
	if _s65 != 200:
		var _p59 = ""
		var json = JSON.new()
		var _d58 = json.parse(_r16.get_string_from_utf8())
		var _v4 = {}
		if _d58 == OK:
			var data = json.get_data()
			if data is Dictionary:
				_v4 = data

		if _s65 == 401:
			_t4.emit()
		elif _s65 == 403:
			_p59 = "Refactor is not available in your tier. Please upgrade."
			if _v4.has("message"):
				_p59 = _v4.get("message", _p59)
			_i53.emit(_s65, _p59)
		elif _s65 == 429:
			_p59 = "You've exceeded your refactor quota. Please wait before making more requests."
			if _v4.has("group") or _v4.has("reset_date"):
				var _n75 = _v4.get("group", "")
				var _f91 = _v4.get("reset_date", "")
				if not _n75.is_empty():
					if not _f91.is_empty():
						_p59 = "You've exceeded your quota for %s. Resets on %s." % [_n75, _o15(_f91)]
					else:
						_p59 = "You've exceeded your quota for %s." % _n75
			elif _v4.has("message"):
				_p59 = _v4.get("message", _p59)
			_i53.emit(_s65, _p59)
		elif _s65 == 400:
			_p59 = "Bad refactor request"
			if _v4.has("message"):
				_p59 = _v4.get("message", _p59)
			_i53.emit(_s65, _p59)
		elif _s65 == 422:
			_p59 = "Refactor request validation failed."
			if _v4.has("message"):
				_p59 = _v4.get("message", _p59)
			_i53.emit(_s65, _p59)
		else:
			_p59 = "Server returned an error during refactor (code: %d)" % _s65
			if _v4.has("message"):
				_p59 = _v4.get("message", _p59)
			elif _v4.has("error"):
				_p59 = _v4.get("error", _p59)
			_i53.emit(_s65, _p59)
		return
	
	var json = JSON.new()
	var error = json.parse(_r16.get_string_from_utf8())
	if error != OK:
		_i53.emit(_s65, "Invalid JSON response from refactor")
		return
	
	var _v4 = json.get_data()
	if not _v4 is Dictionary:
		_i53.emit(_s65, "Refactor response is not a dictionary")
		return
	
	if not _v4.has("rewritten_func"):
		_i53.emit(_s65, "Refactor response missing 'rewritten_func' field")
		return
	
	var refactored_code = _v4.get("rewritten_func", "")
	
	if refactored_code.is_empty():
		_i53.emit(_s65, "Refactor response contains empty code")
		return
	
	var function_name = _h58.get("function_name", "")
	var original_hash = _h58.get("original_hash", "")
	
	_h58.clear()
	
	_o98.emit(refactored_code, original_hash, function_name)

func _a50(text: String) -> String:
	var _p83 = HashingContext.new()
	_p83.start(HashingContext.HASH_SHA256)
	_p83.update(text.to_utf8_buffer())
	var _j76 = _p83.finish()
	
	return _j76.hex_encode()

func _s50() -> String:
	var _s67 = Engine.get_version_info()
	return "%d.%d.%d" % [_s67.major, _s67.minor, _s67.patch]

func _d49() -> PackedStringArray:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _r39 = config.get_value("custom_rules", "rules_text", "")
		if not _r39.is_empty():
			var _u48 = _r39.split("\n")
			var _r70 = PackedStringArray()
			for _f12 in _u48:
				var _e50 = _f12.strip_edges()
				if not _e50.is_empty():
					_r70.append(_e50)
			return _r70
	return PackedStringArray()

func _j34() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _k92 = {}
		var _w75 = config.get_value("parameters", "temperature_override", 0.0)
		var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
		
		if _w75 > 0.0:
			_k92["temperature"] = _w75
		if max_tokens > 0:
			_k92["max_tokens"] = max_tokens
			
		return _k92
	return {}

func _z94(_r39: String) -> Dictionary:
	var _k3 = {"valid": true, "errors": []}

	if _r39.length() > 500:
		_k3["valid"] = false
		_k3["errors"].append("Custom rules must be under 500 characters")

	var _c64 = [
		"system:", "assistant:", "user:",
		"ignore all previous", "disregard instructions",
		"forget previous", "override system"
	]

	var _e9 = _r39.to_lower()
	for _c84 in _c64:
		if _e9.find(_c84) != -1:
			_k3["valid"] = false
			_k3["errors"].append("System instruction overrides are not allowed")
			break

	return _k3

func _t41(_r39: String) -> bool:
	var _i8 = _z94(_r39)
	if not _i8.get("valid", false):
		return false
	
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("custom_rules", "rules_text", _r39)
	config.save("user://gdsense_settings.cfg")
	return true

func _a34(_w75: float, max_tokens: int) -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("parameters", "temperature_override", _w75)
	config.set_value("parameters", "max_tokens_override", max_tokens)
	config.save("user://gdsense_settings.cfg")

func _b6() -> String:
	return _j79

func _z53() -> String:
	var _w98 = []
	for i in range(32):
		_w98.append(randi() % 16)
	
	_w98[12] = 4  
	_w98[16] = (_w98[16] & 0x3) | 0x8  
	
	var _p13 = "0123456789abcdef"
	var _k3 = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			_k3 += "-"
		_k3 += _p13[_w98[i]]
	
	return _k3

func _l94() -> void:
	_b53 = _z53()

func _w96() -> String:
	return _b53

func _t1(rating: String, category: String = "", details: String = "") -> void:
	if _j79.is_empty():
		return
	
	var _l11 := _i59.strip_edges(true, true)
	if _l11.is_empty():
		return
	
	var _n38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l11
	]
	
	var _i71 = {
		"responseId": _j79,
		"rating": rating,
		"category": category,
		"details": details,
		"chat_session_id": _b53,
		"context": {
			"model": _s21(),
			"godotVersion": _s50()
		}
	}
	
	var _r16: String = JSON.stringify(_i71)
	
	var _t68 = HTTPRequest.new()
	add_child(_t68)
	_t68.request_completed.connect(_o66)
	
	var _p12 = _v55 + "/feedback"

	var error = _t68.request(_p12, _n38, HTTPClient.METHOD_POST, _r16)
	if error != OK:
		_t68.queue_free()

func _o66(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray) -> void:
	var _c58 = null
	for _w15 in get_children():
		if _w15 is HTTPRequest and _w15 != _q76 and _w15 != _d6:
			_c58 = _w15
			break
	
	if _c58:
		_c58.queue_free()
	
	var success = _k3 == HTTPRequest.RESULT_SUCCESS and _s65 == 200
	if success:
		pass

	else:
		pass

	_u23.emit(success)

func _k59() -> void:
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

func _h57(messages: Array, context_metadata: Dictionary = {}) -> void:
	if _i59.is_empty():
		return

	if _e37 and _e37.is_processing():
		return

	var _n38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _i59
	]

	var _m33 = {
		"messages": messages,
		"model": _s21(),
		"context_metadata": context_metadata
	}

	var _r87 = JSON.stringify(_m33)
	var _p12 = _v55 + "/context/estimate"

	var error = _e37.request(_p12, _n38, HTTPClient.METHOD_POST, _r87)
	if error != OK:
		pass

func _w31(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray) -> void:
	if _k3 != HTTPRequest.RESULT_SUCCESS:
		return
	
	if _s65 != 200:
		return
	
	var json = JSON.new()
	var error = json.parse(_r16.get_string_from_utf8())
	if error != OK:
		return
	
	var _v4 = json.get_data()
	if not _v4 is Dictionary:
		return
	
	var _u3 = _v4.get("tokens", 0)
	var breakdown = _v4.get("breakdown", [])
	var _y86 = _v4.get("context_limit", 128000)

	_y98.emit(_u3, breakdown, _y86)

func _m22() -> void:
	if _k68:
		pass

	var _s9 = _d49()

	var _j30 = _j34()

func _p81() -> void:
	if not _i59.is_empty():
		_b74()

func _b74() -> void:
	var _l11 := _i59.strip_edges(true, true)
	if _l11.is_empty():
		return

	if _b61.is_processing():
		return

	var _n38: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _l11
	]

	var _p12 = _v55 + "/plugin/whoami"

	var error = _b61.request(_p12, _n38, HTTPClient.METHOD_GET)
	if error != OK:
		pass

func _j6(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray) -> void:
	if _k3 != HTTPRequest.RESULT_SUCCESS:
		_u68()
		return

	if _s65 != 200:
		_u68()
		return

	var json = JSON.new()
	var error = json.parse(_r16.get_string_from_utf8())
	if error != OK:
		_u68()
		return

	var _v4 = json.get_data()
	if not _v4 is Dictionary:
		_u68()
		return

	_i57 = _v4

	_w60.emit(_i57)

	_d97()

func _u68() -> void:
	_i57 = {
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
	_w60.emit(_i57)

func _j7() -> String:
	return _n91(_i57.get("tier", "FREE"))

func _n91(_c23: String) -> String:
	if _c23 == null:
		return "FREE"
	var _r18 = _c23.strip_edges()
	if _r18.is_empty():
		return "FREE"
	_r18 = _r18.replace("-", "_").replace(" ", "_").to_upper()
	return _r18

func _o15(_q67: String) -> String:
	if _q67.is_empty():
		return ""

	var _j22 = _q67.split("T")[0] if "T" in _q67 else _q67
	var _b75 = _j22.split("-")

	if _b75.size() < 3:
		return _q67  

	var year = _b75[0]
	var month = int(_b75[1]) if _b75[1].is_valid_int() else 0
	var day = int(_b75[2]) if _b75[2].is_valid_int() else 0

	if month < 1 or month > 12 or day < 1 or day > 31:
		return _q67  

	var _p76 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

	return "%s %d, %s" % [_p76[month - 1], day, year]

func _u53() -> Dictionary:
	return _i57.get("features", {"explain": true, "refactor": true})

func _h96() -> Dictionary:
	var _q24 = {
		"used": 0.0,
		"limit": 50,
		"pct": 0,
		"remaining": 50.0
	}
	return _i57.get("credits", _q24)

func _u2() -> bool:
	var features = _u53()
	return features.get("refactor", true)

func _n25() -> Array:
	if _i57.has("allowed_models"):
		var _x92 = _i57["allowed_models"]
		if _x92 is Array and _x92.size() > 0:
			var _f100: Array = []
			for model in _x92:
				if model is Dictionary and model.has("id"):
					_f100.append(model["id"])
			if _f100.size() > 0:
				return _f100

	var _m37 = _j7()

	var _y81 = _x72.get(_m37, ["GROUP_FREE"])
	var _h7: Array = []

	for _n75 in _u15:
		if _n75 in _y81 and _e15.has(_n75):
			_h7.append_array(_e15[_n75])

	return _h7

func _p10() -> Array:
	if _i57.has("allowed_models"):
		var _x92 = _i57["allowed_models"]
		if _x92 is Array and _x92.size() > 0:
			return _x92

	return []

func _d97() -> void:
	var _e80 = _h96()

	var used = _e80.get("used", 0.0)
	var limit = _e80.get("limit", 0)
	var _i73 = _e80.get("pct", 0)

	if limit <= 0:
		return  

	var _p87 = ""
	var _i90 = ""

	if _i73 >= 95:
		_p87 = "credits_95"
		_i90 = "critical"
	elif _i73 >= 90:
		_p87 = "credits_90"
		_i90 = "high"
	elif _i73 >= 85:
		_p87 = "credits_85"
		_i90 = "medium"
	elif _i73 >= 80:
		_p87 = "credits_80"
		_i90 = "low"

	if not _p87.is_empty() and not _v90.has(_p87):
		_v90[_p87] = Time.get_ticks_msec()

		var _r30 = _i57.get("renewal_date", "")
		_n43.emit(_i90, "credits", float(_i73), _r30)

func _q38() -> void:
	_i57.clear()
	_b74()

func _c41(_i31: String) -> void:
	if _i31.is_empty():
		return
	var _l14 = _i57.get("tier", "")
	if _i31 != _l14:
		_i57["tier"] = _i31
		_w60.emit(_i57)
func _u97() -> void:
	var _t19 = Time.get_ticks_msec()
	var _r7 = []

	for _p87 in _v90:
		var _s37 = _v90[_p87]

		if (_t19 - _s37) > 3600000:  
			_r7.append(_p87)

	for _y48 in _r7:
		_v90.erase(_y48)

func _x39() -> void:
	if not _t64():
		return

	var _p12 = "https://api.gdsense.com/api/v1/plugin/latest-version"

	var _n38: PackedStringArray = [
		"Content-Type: application/json"
	]

	var error = _o99.request(_p12, _n38, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _t64() -> bool:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") != OK:
		return true  

	var _p67 = config.get_value("updates", "last_check_timestamp", 0)
	var _t19 = int(Time.get_unix_time_from_system())

	return (_t19 - _p67) >= _y66

func _m64(_k3: int, _s65: int, _n38: PackedStringArray, _r16: PackedByteArray) -> void:
	if _k3 != HTTPRequest.RESULT_SUCCESS:
		return

	if _s65 != 200:
		return

	var json = JSON.new()
	var error = json.parse(_r16.get_string_from_utf8())
	if error != OK:
		return

	var _v4 = json.get_data()
	if not _v4 is Dictionary:
		return

	var _r35 = _v4.get("version", "")
	var is_active = _v4.get("isActive", true)

	if _r35.is_empty():
		return

	_c3()

	var _d38 = _x33()

	if is_active and _d95(_d38, _r35) < 0:
		_g27.emit(_r35, _d38)
	else:
		pass
func _c3() -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")  
	config.set_value("updates", "last_check_timestamp", int(Time.get_unix_time_from_system()))
	config.save("user://gdsense_settings.cfg")

func _d95(current: String, _x50: String) -> int:
	var _f65 = current.split(".")
	var _o8 = _x50.split(".")

	var _c98 = max(_f65.size(), _o8.size())
	while _f65.size() < _c98:
		_f65.append("0")
	while _o8.size() < _c98:
		_o8.append("0")

	for i in range(_c98):
		var _g66 = int(_f65[i])
		var _h11 = int(_o8[i])

		if _g66 < _h11:
			return -1
		elif _g66 > _h11:
			return 1

	return 0

func _y50() -> String:
	return _x33()

func _x33() -> String:
	if _z82.is_empty():
		var config = ConfigFile.new()
		if config.load("res://addons/gdsense/plugin.cfg") == OK:
			_z82 = config.get_value("plugin", "version", "0.0.0")
		else:
			_z82 = "0.0.0"
	return _z82

