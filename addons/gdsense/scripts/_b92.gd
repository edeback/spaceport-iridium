@tool
class_name _b92
extends Node

signal _l54(_m54: String, _k15: Array, _n80: String, _v96: String)
signal _k42
signal _f93(_k63: int, _g45: String)
signal _y20
signal _c11(_l90: int, _o33: int, _e26: int)
signal _s23(_p72: String, _v89: int)
signal _s7(success: bool)
signal _n74(refactored_code: String, original_hash: String, function_name: String)
signal _e32(_e26: int, breakdown: Array, _m81: int)
signal _p47(_y90: Dictionary)
signal _c79(_h18: String, _e47: String, _d75: float, _y91: String)
signal _d52(message: String)
signal _d57(_d59: String, _z80: String)

var _p4: HTTPRequest
var _k68: HTTPRequest
var _f99: HTTPRequest
var _k16: HTTPRequest
var _y77: HTTPRequest
var _q45: HTTPRequest
var _h98: String = ""
var _v47: bool = false
var _h32: String = "https://api.gdsense.com/api/v1"
var _q19: int = 0
var _n38: String = ""
var _y95: String = ""
var _c89: Dictionary = {}  
var _a70: Dictionary = {}  
var _a42: String = ""  

const _r95 = 86400  
var _j16: String = ""

const _j39 = {
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

const _a40 = {
	"FREE": ["GROUP_FREE"],
	"STARTER": ["GROUP_FREE", "GROUP_STD"],
	"BETA_FREE": ["GROUP_FREE", "GROUP_STD"],
	"PRO": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"],
	"ULTRA": ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]
}

const _h14 = ["GROUP_FREE", "GROUP_STD", "GROUP_PREM"]

func _enter_tree() -> void:
	_p4 = HTTPRequest.new()
	add_child(_p4)
	_p4.request_completed.connect(_i98)

	_k68 = HTTPRequest.new()
	add_child(_k68)
	_k68.request_completed.connect(_i100)
	_k68.timeout = 0.5  

	_f99 = HTTPRequest.new()
	add_child(_f99)
	_f99.request_completed.connect(_e8)
	_f99.timeout = 30.0  

	_k16 = HTTPRequest.new()
	add_child(_k16)
	_k16.request_completed.connect(_t58)
	_k16.timeout = 5.0  

	_y77 = HTTPRequest.new()
	add_child(_y77)
	_y77.request_completed.connect(_m89)
	_y77.timeout = 10.0  

	_q45 = HTTPRequest.new()
	add_child(_q45)
	_q45.request_completed.connect(_z6)
	_q45.timeout = 10.0  

	_z35()
	_x56()
	_q55()
	_n30()
	_k41()

	_u27.call_deferred()

	_o93.call_deferred()

func _i98(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray) -> void:
	if _v42 != HTTPRequest.RESULT_SUCCESS:
		_f93.emit(0, "Network error")
		return

	if _k63 != 200:
		if _k63 == 401:
			_k42.emit()
		elif _k63 == 403:
			var _s52 = "This feature/model is not available in your tier. Please upgrade."
			var json = JSON.new()
			var _q58 = json.parse(_v64.get_string_from_utf8())
			if _q58 == OK:
				var _m47 = json.get_data()
				if _m47 is Dictionary and _m47.has("message"):
					_s52 = _m47.get("message", _s52)
			_f93.emit(_k63, _s52)
		elif _k63 == 429:
			var _s52 = "You've exceeded your quota. Please wait before making more requests."
			var json = JSON.new()
			var _q58 = json.parse(_v64.get_string_from_utf8())
			if _q58 == OK:
				var _m47 = json.get_data()
				if _m47 is Dictionary:
					var _e47 = _m47.get("group", "")
					var _y91 = _m47.get("reset_date", "")
					if not _e47.is_empty():
						if not _y91.is_empty():
							_s52 = "You've exceeded your quota for %s. Resets on %s." % [_e47, _u48(_y91)]
						else:
							_s52 = "You've exceeded your quota for %s." % _e47
					elif _m47.has("message"):
						_s52 = _m47.get("message", _s52)
			_f93.emit(_k63, _s52)
		elif _k63 == 400:
			var _s52 = "Bad request"
			var json = JSON.new()
			var _q58 = json.parse(_v64.get_string_from_utf8())
			if _q58 == OK:
				var _m47 = json.get_data()
				if _m47 is Dictionary and _m47.has("message"):
					_s52 = _m47.get("message", "Bad request")
			_f93.emit(_k63, _s52)
		elif _k63 == 422:
			_f93.emit(_k63, "Request validation failed. Please check your custom rules and parameters.")
		else:
			_f93.emit(_k63, "Server returned an error")
		return

	var json = JSON.new()
	var error = json.parse(_v64.get_string_from_utf8())
	if error != OK:
		_f93.emit(_k63, "Invalid JSON response")
		return

	var _m47 = json.get_data()
	if not _m47 is Dictionary:
		_f93.emit(_k63, "JSON response is not a dictionary.")
		return
	
	if not _m47.has("content"):
		_f93.emit(_k63, "Response does not contain 'content' field.")
		return

	var content = _m47.get("content", "")
	
	var _k15 = []
	if _m47.has("documentation_sources"):
		var _a1 = _m47.get("documentation_sources", [])
		if _a1 is Array:
			for source in _a1:
				if source is Dictionary:
					_k15.append({
						"url": source.get("url", ""),
						"title": source.get("title", "Godot Documentation"),
						"priority": source.get("priority", 0.0),
						"language": source.get("language", "en")
					})

	if _m47.has("response_id"):
		_n38 = _m47.get("response_id", "")

	else:
		pass

	var _n80 = ""
	if _m47.has("thought_signature"):
		_n80 = _m47.get("thought_signature", "")
		_a42 = _n80
	else:
		_a42 = ""

	var _v96 = ""
	if _m47.has("enhanced_user_message"):
		_v96 = _m47.get("enhanced_user_message", "")

	if _m47.has("quota_warning") and _m47.get("quota_warning") is Dictionary:
		var _d99 = _m47.get("quota_warning")
		var _h18 = _d99.get("severity", "notice").to_lower()
		var _e47 = _d99.get("model_group", "")
		var _d75 = _d99.get("usage_percentage", 0.0)
		var _y91 = _d99.get("reset_date", "")

		match _h18:
			"notice":
				_h18 = "medium"
			"warning":
				_h18 = "high"
			"critical", "limit_reached":
				_h18 = "critical"
			_:
				_h18 = "medium"

		var _o57 = "%s_%s_%d" % [_e47, _h18, int(_d75 / 5) * 5]  

		if not _e47.is_empty() and not _a70.has(_o57):
			_a70[_o57] = Time.get_ticks_msec()
			_c79.emit(_h18, _e47, _d75, _y91)

	if _m47.has("truncation_warning"):
		var _h97 = _m47.get("truncation_warning", "")
		if _h97 is String and not _h97.is_empty():
			_d52.emit(_h97)

	if _m47.has("tier"):
		var _r36 = _m47.get("tier", "")
		if _r36 is String and not _r36.is_empty():
			var _a51 = _c89.get("tier", "")
			if _r36 != _a51:
				_c89["tier"] = _r36
				_p47.emit(_c89)

	for _o44 in _g61:
		if _o44.begins_with("X-Usage-Warning:"):
			var _a43 = _o44.split(": ", true, 1)[1] if _o44.contains(": ") else ""
		elif _o44.begins_with("X-Model-Group:"):
			var _p70 = _o44.split(": ", true, 1)[1] if _o44.contains(": ") else ""

	_l54.emit(content, _k15, _n80, _v96)

	if _m47.has("usage"):
		var _x13 = _m47.get("usage", {})
		var _l90 = _x13.get("prompt_tokens", 0)
		var _o33 = _x13.get("completion_tokens", 0)
		var _e26 = _x13.get("total_tokens", 0)
		_c11.emit(_l90, _o33, _e26)

func _x56() -> void:
	var _p100 := ConfigFile.new()
	var error := _p100.load("user://gdsense_api_key.cfg")
	if error == OK:
		if _v47:
			var env = _o50()
			_h98 = _p100.get_value("api_keys", env, "")
			
			if _h98.is_empty():
				_h98 = _p100.get_value("plugin", "api_key", "")

				if not _h98.is_empty() and env == "production":
					_p100.set_value("api_keys", "production", _h98)
					_p100.save("user://gdsense_api_key.cfg")
		else:
			_h98 = _p100.get_value("api_keys", "production", "")

			if _h98.is_empty():
				_h98 = _p100.get_value("plugin", "api_key", "")
		
	else:
		pass

func _a82(_m15: String) -> void:
	var _p100 := ConfigFile.new()
	_p100.load("user://gdsense_api_key.cfg")  
	
	if _v47:
		var env = _o50()
		_p100.set_value("api_keys", env, _m15)

	else:
		_p100.set_value("api_keys", "production", _m15)
	
	if not _v47 or _o50() == "production":
		_p100.set_value("plugin", "api_key", _m15)
	
	_p100.save("user://gdsense_api_key.cfg")
	_h98 = _m15

	_y20.emit()

	_m73.call_deferred()

func _o19() -> String:
	return _h98

func _d9() -> String:
	return _h32

func _d32() -> bool:
	return not _h98.strip_edges().is_empty()

func _b18() -> Dictionary:
	return _c89

func _t93(environment: String) -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("api_keys", environment, "")
	return ""

func _e91(model: String) -> void:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")
	else:
		config.set_value("plugin", "api_key", _h98)
		config.set_value("settings", "selected_model", model)
		config.save("user://gdsense_api_key.cfg")

func _r22() -> String:
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var model = config.get_value("settings", "selected_model", "llama-3.1-8b-instant")

		if model == "Meta-Llama-3-8B-Instruct" or model == "Meta-Llama-3.1-8B-Instruct" or model == "llama-3.1-8b-instruct":
			model = "llama-3.1-8b-instant"
			_e91(model)  
		elif model == "Meta-Llama-3-70B-Instruct" or model == "Meta-Llama-3.1-70B-Instruct":
			model = "llama-3.1-70b-instruct"
			_e91(model)  
		elif model == "gemini-2.5-flash-lite-preview-06-17":
			model = "gemini-2.5-flash-lite"
			_e91(model)  
		
		return model
	return "llama-3.1-8b-instant"

func _z35() -> void:
	var _f72 = FileAccess.open("res://.gdsense-dev", FileAccess.READ)
	_v47 = _f72 != null
	if _f72:
		_f72.close()
	if _v47:
		pass

func _t60() -> bool:
	return _v47

func _q55() -> void:
	if not _v47:
		_h32 = "https://api.gdsense.com/api/v1"
		return
	
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		var env = config.get_value("developer", "api_environment", "production")
		if env == "development":
			_h32 = "http://localhost:8080/api/v1"
		else:
			_h32 = "https://api.gdsense.com/api/v1"

func _y74(environment: String) -> void:
	if not _v47:
		return
	
	var config = ConfigFile.new()
	config.load("user://gdsense_api_key.cfg")
	config.set_value("developer", "api_environment", environment)
	config.save("user://gdsense_api_key.cfg")
	_q55()

	_x56()

func _o50() -> String:
	if not _v47:
		return "production"
	
	var config = ConfigFile.new()
	if config.load("user://gdsense_api_key.cfg") == OK:
		return config.get_value("developer", "api_environment", "production")
	return "production"

func _e58(messages: Array, _c38: String = "", _l11: String = "", context_metadata: Dictionary = {}) -> void:
	_x56() 

	_z43()

	var _i66 := _h98.strip_edges(true, true)

	if _i66.is_empty():
		_k42.emit()
		return

	if _p4.is_processing():
		return

	var _g61: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _i66
	]
	
	var _o71 = _r22()
	var _j97 = {
		"messages": messages,
		"model": _o71,
		"godotVersion": _b61(),
		"chat_session_id": _y95
	}
	
	if not context_metadata.is_empty():
		_j97["context_metadata"] = context_metadata

	if not _c38.is_empty():
		_j97["command"] = _c38

	if not _l11.is_empty():
		_j97["function_context"] = _l11

	var _u26 = _b43()
	if _u26.size() > 0:
		_j97["custom_rules"] = _u26
	
	var _j85 = _j4()
	if not _j85.is_empty():
		_j97["parametersOverride"] = _j85
	
	var _v64: String = JSON.stringify(_j97)
	
	if _j97.has("custom_rules"):
		var _y5 = _j97["custom_rules"]

	else:
		pass

	var _p33 = _h32 + "/completion"

	var error = _p4.request(_p33, _g61, HTTPClient.METHOD_POST, _v64)
	if error != OK:
		_f93.emit(0, "Failed to start request.")
		return 

func _x39(context: Dictionary) -> void:
	_x56() 
	
	var _i66 := _h98.strip_edges(true, true)
	
	if _i66.is_empty():
		return
	
	if is_instance_valid(_k68):
		if _k68.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_k68.cancel_request()
	
	var _g61: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _i66
	]
	
	var _v64: String = JSON.stringify({
		"context": context,
		"maxTokens": 150  
	})
	
	_q19 = Time.get_ticks_msec()
	
	var _p33 = _h32 + "/autocomplete"

	var error = _k68.request(_p33, _g61, HTTPClient.METHOD_POST, _v64)
	if error != OK:
		return

func _i100(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray) -> void:
	var _v89 = Time.get_ticks_msec() - _q19

	if _v42 != HTTPRequest.RESULT_SUCCESS:
		return
	
	if _k63 != 200:
		return
	
	var json = JSON.new()
	var error = json.parse(_v64.get_string_from_utf8())
	if error != OK:
		return
	
	var _m47 = json.get_data()
	if not _m47 is Dictionary:
		return
	
	var _p72 = _m47.get("suggestion", "")
	if _p72.is_empty():
		return
	
	_s23.emit(_p72, _v89)

var _r70: Dictionary = {}  

func _b64(function_name: String, _z29: String, _x65: String, file_path: String = "", model: String = "") -> void:
	_x56() 

	var _i66 := _h98.strip_edges(true, true)

	if _i66.is_empty():
		_k42.emit()
		return

	if is_instance_valid(_f99):
		if _f99.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
			_f99.cancel_request()
	else:
		pass

	var _g61: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _i66
	]

	var original_hash = _e96(_z29)

	_r70 = {
		"function_name": function_name,
		"original_hash": original_hash
	}

	if _y95.is_empty():
		_k41()

	var _e24 = model if not model.is_empty() else "gemini-2.5-flash"

	var _x29 = {
		"file_path": file_path if file_path else "unknown.gd",
		"language": "gdscript",
		"func_name": function_name,
		"func_code": _z29,
		"user_prompt": _x65,
		"editor_version": _b61(),
		"chat_session_id": _y95,
		"model": _e24
	}
	
	var _v64: String = JSON.stringify(_x29)
	
	var _p33 = _h32 + "/refactor"

	if not is_instance_valid(_f99):
		_f99 = HTTPRequest.new()
		add_child(_f99)
		_f99.request_completed.connect(_e8)
		_f99.timeout = 30.0
	
	var error = _f99.request(_p33, _g61, HTTPClient.METHOD_POST, _v64)
	if error != OK:
		_f93.emit(0, "Failed to start refactor request.")
		return

func _e8(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray) -> void:
	if _v42 != HTTPRequest.RESULT_SUCCESS:
		_f93.emit(0, "Network error during refactor")
		return
	
	if _k63 != 200:
		var _s52 = ""
		var json = JSON.new()
		var _q58 = json.parse(_v64.get_string_from_utf8())
		var _m47 = {}
		if _q58 == OK:
			var data = json.get_data()
			if data is Dictionary:
				_m47 = data

		if _k63 == 401:
			_k42.emit()
		elif _k63 == 403:
			_s52 = "Refactor is not available in your tier. Please upgrade."
			if _m47.has("message"):
				_s52 = _m47.get("message", _s52)
			_f93.emit(_k63, _s52)
		elif _k63 == 429:
			_s52 = "You've exceeded your refactor quota. Please wait before making more requests."
			if _m47.has("group") or _m47.has("reset_date"):
				var _e47 = _m47.get("group", "")
				var _y91 = _m47.get("reset_date", "")
				if not _e47.is_empty():
					if not _y91.is_empty():
						_s52 = "You've exceeded your quota for %s. Resets on %s." % [_e47, _u48(_y91)]
					else:
						_s52 = "You've exceeded your quota for %s." % _e47
			elif _m47.has("message"):
				_s52 = _m47.get("message", _s52)
			_f93.emit(_k63, _s52)
		elif _k63 == 400:
			_s52 = "Bad refactor request"
			if _m47.has("message"):
				_s52 = _m47.get("message", _s52)
			_f93.emit(_k63, _s52)
		elif _k63 == 422:
			_s52 = "Refactor request validation failed."
			if _m47.has("message"):
				_s52 = _m47.get("message", _s52)
			_f93.emit(_k63, _s52)
		else:
			_s52 = "Server returned an error during refactor (code: %d)" % _k63
			if _m47.has("message"):
				_s52 = _m47.get("message", _s52)
			elif _m47.has("error"):
				_s52 = _m47.get("error", _s52)
			_f93.emit(_k63, _s52)
		return
	
	var json = JSON.new()
	var error = json.parse(_v64.get_string_from_utf8())
	if error != OK:
		_f93.emit(_k63, "Invalid JSON response from refactor")
		return
	
	var _m47 = json.get_data()
	if not _m47 is Dictionary:
		_f93.emit(_k63, "Refactor response is not a dictionary")
		return
	
	if not _m47.has("rewritten_func"):
		_f93.emit(_k63, "Refactor response missing 'rewritten_func' field")
		return
	
	var refactored_code = _m47.get("rewritten_func", "")
	
	if refactored_code.is_empty():
		_f93.emit(_k63, "Refactor response contains empty code")
		return
	
	var function_name = _r70.get("function_name", "")
	var original_hash = _r70.get("original_hash", "")
	
	_r70.clear()
	
	_n74.emit(refactored_code, original_hash, function_name)

func _e96(text: String) -> String:
	var _u15 = HashingContext.new()
	_u15.start(HashingContext.HASH_SHA256)
	_u15.update(text.to_utf8_buffer())
	var _a19 = _u15.finish()
	
	return _a19.hex_encode()

func _b61() -> String:
	var _t37 = Engine.get_version_info()
	return "%d.%d.%d" % [_t37.major, _t37.minor, _t37.patch]

func _b43() -> PackedStringArray:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _r27 = config.get_value("custom_rules", "rules_text", "")
		if not _r27.is_empty():
			var _s90 = _r27.split("\n")
			var _m39 = PackedStringArray()
			for _a86 in _s90:
				var _u47 = _a86.strip_edges()
				if not _u47.is_empty():
					_m39.append(_u47)
			return _m39
	return PackedStringArray()

func _j4() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") == OK:
		var _l55 = {}
		var _h62 = config.get_value("parameters", "temperature_override", 0.0)
		var max_tokens = config.get_value("parameters", "max_tokens_override", 0)
		
		if _h62 > 0.0:
			_l55["temperature"] = _h62
		if max_tokens > 0:
			_l55["max_tokens"] = max_tokens
			
		return _l55
	return {}

func _g63(_r27: String) -> Dictionary:
	var _v42 = {"valid": true, "errors": []}

	if _r27.length() > 500:
		_v42["valid"] = false
		_v42["errors"].append("Custom rules must be under 500 characters")

	var _w33 = [
		"system:", "assistant:", "user:",
		"ignore all previous", "disregard instructions",
		"forget previous", "override system"
	]

	var _u63 = _r27.to_lower()
	for _v48 in _w33:
		if _u63.find(_v48) != -1:
			_v42["valid"] = false
			_v42["errors"].append("System instruction overrides are not allowed")
			break

	return _v42

func _q84(_r27: String) -> bool:
	var _i33 = _g63(_r27)
	if not _i33.get("valid", false):
		return false
	
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("custom_rules", "rules_text", _r27)
	config.save("user://gdsense_settings.cfg")
	return true

func _a65(_h62: float, max_tokens: int) -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")
	config.set_value("parameters", "temperature_override", _h62)
	config.set_value("parameters", "max_tokens_override", max_tokens)
	config.save("user://gdsense_settings.cfg")

func _v70() -> String:
	return _n38

func _a9() -> String:
	var _t29 = []
	for i in range(32):
		_t29.append(randi() % 16)
	
	_t29[12] = 4  
	_t29[16] = (_t29[16] & 0x3) | 0x8  
	
	var _m35 = "0123456789abcdef"
	var _v42 = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			_v42 += "-"
		_v42 += _m35[_t29[i]]
	
	return _v42

func _k41() -> void:
	_y95 = _a9()

func _t62() -> String:
	return _y95

func _i35(rating: String, category: String = "", details: String = "") -> void:
	if _n38.is_empty():
		return
	
	var _i66 := _h98.strip_edges(true, true)
	if _i66.is_empty():
		return
	
	var _g61: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _i66
	]
	
	var _r51 = {
		"responseId": _n38,
		"rating": rating,
		"category": category,
		"details": details,
		"chat_session_id": _y95,
		"context": {
			"model": _r22(),
			"godotVersion": _b61()
		}
	}
	
	var _v64: String = JSON.stringify(_r51)
	
	var _d38 = HTTPRequest.new()
	add_child(_d38)
	_d38.request_completed.connect(_t75)
	
	var _p33 = _h32 + "/feedback"

	var error = _d38.request(_p33, _g61, HTTPClient.METHOD_POST, _v64)
	if error != OK:
		_d38.queue_free()

func _t75(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray) -> void:
	var _x100 = null
	for _j75 in get_children():
		if _j75 is HTTPRequest and _j75 != _p4 and _j75 != _k68:
			_x100 = _j75
			break
	
	if _x100:
		_x100.queue_free()
	
	var success = _v42 == HTTPRequest.RESULT_SUCCESS and _k63 == 200
	if success:
		pass

	else:
		pass

	_s7.emit(success)

func _n30() -> void:
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

func _p57(messages: Array, context_metadata: Dictionary = {}) -> void:
	if _h98.is_empty():
		return

	if _k16 and _k16.is_processing():
		return

	var _g61: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _h98
	]

	var _j97 = {
		"messages": messages,
		"model": _r22(),
		"context_metadata": context_metadata
	}

	var _w7 = JSON.stringify(_j97)
	var _p33 = _h32 + "/context/estimate"

	var error = _k16.request(_p33, _g61, HTTPClient.METHOD_POST, _w7)
	if error != OK:
		pass

func _t58(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray) -> void:
	if _v42 != HTTPRequest.RESULT_SUCCESS:
		return
	
	if _k63 != 200:
		return
	
	var json = JSON.new()
	var error = json.parse(_v64.get_string_from_utf8())
	if error != OK:
		return
	
	var _m47 = json.get_data()
	if not _m47 is Dictionary:
		return
	
	var _e26 = _m47.get("tokens", 0)
	var breakdown = _m47.get("breakdown", [])
	var _m81 = _m47.get("context_limit", 128000)

	_e32.emit(_e26, breakdown, _m81)

func _l85() -> void:
	if _v47:
		pass

	var _u26 = _b43()

	var _j85 = _j4()

func _u27() -> void:
	if not _h98.is_empty():
		_y54()

func _y54() -> void:
	var _i66 := _h98.strip_edges(true, true)
	if _i66.is_empty():
		return

	if _y77.is_processing():
		return

	var _g61: PackedStringArray = [
		"Content-Type: application/json",
		"X-API-Key: " + _i66
	]

	var _p33 = _h32 + "/plugin/whoami"

	var error = _y77.request(_p33, _g61, HTTPClient.METHOD_GET)
	if error != OK:
		pass

func _m89(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray) -> void:
	if _v42 != HTTPRequest.RESULT_SUCCESS:
		_g49()
		return

	if _k63 != 200:
		_g49()
		return

	var json = JSON.new()
	var error = json.parse(_v64.get_string_from_utf8())
	if error != OK:
		_g49()
		return

	var _m47 = json.get_data()
	if not _m47 is Dictionary:
		_g49()
		return

	_c89 = _m47

	_p47.emit(_c89)

	_j21()

func _g49() -> void:
	_c89 = {
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
	_p47.emit(_c89)

func _h26() -> String:
	return _e90(_c89.get("tier", "FREE"))

func _e90(_i95: String) -> String:
	if _i95 == null:
		return "FREE"
	var _q79 = _i95.strip_edges()
	if _q79.is_empty():
		return "FREE"
	_q79 = _q79.replace("-", "_").replace(" ", "_").to_upper()
	return _q79

func _u48(_c51: String) -> String:
	if _c51.is_empty():
		return ""

	var _y11 = _c51.split("T")[0] if "T" in _c51 else _c51
	var _m27 = _y11.split("-")

	if _m27.size() < 3:
		return _c51  

	var year = _m27[0]
	var month = int(_m27[1]) if _m27[1].is_valid_int() else 0
	var day = int(_m27[2]) if _m27[2].is_valid_int() else 0

	if month < 1 or month > 12 or day < 1 or day > 31:
		return _c51  

	var _y87 = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

	return "%s %d, %s" % [_y87[month - 1], day, year]

func _g18() -> Dictionary:
	return _c89.get("features", {"explain": true, "refactor": true})

func _s30() -> Dictionary:
	var _z46 = {
		"used": 0.0,
		"limit": 50,
		"pct": 0,
		"remaining": 50.0
	}
	return _c89.get("credits", _z46)

func _p20() -> bool:
	var features = _g18()
	return features.get("refactor", true)

func _s69() -> Array:
	if _c89.has("allowed_models"):
		var _i18 = _c89["allowed_models"]
		if _i18 is Array and _i18.size() > 0:
			var _r31: Array = []
			for model in _i18:
				if model is Dictionary and model.has("id"):
					_r31.append(model["id"])
			if _r31.size() > 0:
				return _r31

	var _s76 = _h26()

	var _m74 = _a40.get(_s76, ["GROUP_FREE"])
	var _s78: Array = []

	for _e47 in _h14:
		if _e47 in _m74 and _j39.has(_e47):
			_s78.append_array(_j39[_e47])

	return _s78

func _j19() -> Array:
	if _c89.has("allowed_models"):
		var _i18 = _c89["allowed_models"]
		if _i18 is Array and _i18.size() > 0:
			return _i18

	return []

func _j21() -> void:
	var _d39 = _s30()

	var used = _d39.get("used", 0.0)
	var limit = _d39.get("limit", 0)
	var _d75 = _d39.get("pct", 0)

	if limit <= 0:
		return  

	var _o57 = ""
	var _h18 = ""

	if _d75 >= 95:
		_o57 = "credits_95"
		_h18 = "critical"
	elif _d75 >= 90:
		_o57 = "credits_90"
		_h18 = "high"
	elif _d75 >= 85:
		_o57 = "credits_85"
		_h18 = "medium"
	elif _d75 >= 80:
		_o57 = "credits_80"
		_h18 = "low"

	if not _o57.is_empty() and not _a70.has(_o57):
		_a70[_o57] = Time.get_ticks_msec()

		var _l5 = _c89.get("renewal_date", "")
		_c79.emit(_h18, "credits", float(_d75), _l5)

func _m73() -> void:
	_c89.clear()
	_y54()

func _m44(_r36: String) -> void:
	if _r36.is_empty():
		return
	var _a51 = _c89.get("tier", "")
	if _r36 != _a51:
		_c89["tier"] = _r36
		_p47.emit(_c89)
func _z43() -> void:
	var _y68 = Time.get_ticks_msec()
	var _d29 = []

	for _o57 in _a70:
		var _r63 = _a70[_o57]

		if (_y68 - _r63) > 3600000:  
			_d29.append(_o57)

	for _m15 in _d29:
		_a70.erase(_m15)

func _o93() -> void:
	if not _k18():
		return

	var _p33 = "https://api.gdsense.com/api/v1/plugin/latest-version"

	var _g61: PackedStringArray = [
		"Content-Type: application/json"
	]

	var error = _q45.request(_p33, _g61, HTTPClient.METHOD_GET)
	if error != OK:
		pass
func _k18() -> bool:
	var config = ConfigFile.new()
	if config.load("user://gdsense_settings.cfg") != OK:
		return true  

	var _f26 = config.get_value("updates", "last_check_timestamp", 0)
	var _y68 = int(Time.get_unix_time_from_system())

	return (_y68 - _f26) >= _r95

func _z6(_v42: int, _k63: int, _g61: PackedStringArray, _v64: PackedByteArray) -> void:
	if _v42 != HTTPRequest.RESULT_SUCCESS:
		return

	if _k63 != 200:
		return

	var json = JSON.new()
	var error = json.parse(_v64.get_string_from_utf8())
	if error != OK:
		return

	var _m47 = json.get_data()
	if not _m47 is Dictionary:
		return

	var _d59 = _m47.get("version", "")
	var is_active = _m47.get("isActive", true)

	if _d59.is_empty():
		return

	_g14()

	var _z80 = _b99()

	if is_active and _f10(_z80, _d59) < 0:
		_d57.emit(_d59, _z80)
	else:
		pass
func _g14() -> void:
	var config = ConfigFile.new()
	config.load("user://gdsense_settings.cfg")  
	config.set_value("updates", "last_check_timestamp", int(Time.get_unix_time_from_system()))
	config.save("user://gdsense_settings.cfg")

func _f10(current: String, _m26: String) -> int:
	var _v95 = current.split(".")
	var _i20 = _m26.split(".")

	var _g51 = max(_v95.size(), _i20.size())
	while _v95.size() < _g51:
		_v95.append("0")
	while _i20.size() < _g51:
		_i20.append("0")

	for i in range(_g51):
		var _e33 = int(_v95[i])
		var _b94 = int(_i20[i])

		if _e33 < _b94:
			return -1
		elif _e33 > _b94:
			return 1

	return 0

func _p42() -> String:
	return _b99()

func _b99() -> String:
	if _j16.is_empty():
		var config = ConfigFile.new()
		if config.load("res://addons/gdsense/plugin.cfg") == OK:
			_j16 = config.get_value("plugin", "version", "0.0.0")
		else:
			_j16 = "0.0.0"
	return _j16

