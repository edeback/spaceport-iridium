## Centralized logging facility for the Grid Building plugin.
##
## USAGE: Consider dropping log level on the GBDebugSettings if you are getting too many messages
##
## Responsibilities:
## - Provide contextual logging (verbose, error, warning) integrated with plugin debug settings.
## - Support dependency-injected configuration and throttled verbose output.
class_name GBLogger
extends GBInjectable

# Internal default throttle interval for verbose logs (ms)
const VERBOSE_MIN_INTERVAL_MS := 250

## Shorthand alias for levels to reduce verbosity at callsites
const LogLevel = GBDebugSettings.LogLevel

## Creates a GBLogger with dependency injection from container.
static func create_with_injection(container: GBCompositionContainer) -> GBLogger:
	var debug_settings = container.get_debug_settings()
	var logger = GBLogger.new(debug_settings)
	
	# Inject dependencies
	logger.resolve_gb_dependencies(container)
	
	# Validate dependencies were properly injected
	var issues = logger.get_runtime_issues()
	if not issues.is_empty():
		# Can't use self to log warnings since we're in static context
		push_warning("GBLogger dependency validation issues: %s" % str(issues))
	
	return logger

# Debug settings resource
var _debug := GBDebugSettings.new()
# Tracks messages printed once per (sender,key)
var _verbose_once: Dictionary[String, bool] = {}
var _debug_once: Dictionary[String, bool] = {}
var _trace_once: Dictionary[String, bool] = {}
var _warning_once: Dictionary[String, bool] = {}
var _error_once: Dictionary[String, bool] = {}
var _info_once: Dictionary[String, bool] = {}
# Tracks last-printed timestamp per (sender,key) for throttling
var _verbose_last_ts: Dictionary[String, int] = {}
var _log_sink: Callable

func set_log_sink(p_sink: Callable) -> void:
	_log_sink = p_sink

## Helper to get caller identifier from stack
func _get_caller_id() -> String:
	var stack = get_stack()
	if stack.size() < 2:
		return "unknown"
	var caller = stack[1]
	var source: String = caller.get("source", "")
	var function: String = caller.get("function", "")
	return "%s:%s" % [source, function]

## Helper to check if logging should be throttled
func _is_throttled(caller_id: String, key: String) -> bool:
	var composite: String = "%s::%s" % [caller_id, key]
	var now_ms: int = Time.get_ticks_msec()
	var last_ms: int = _verbose_last_ts.get(composite, -1)
	if last_ms >= 0 && now_ms - last_ms < VERBOSE_MIN_INTERVAL_MS:
		return true
	_verbose_last_ts[composite] = now_ms
	return false

## Helper to check if logging should happen only once
func _should_log_once(caller_id: String, key: String, once_dict: Dictionary) -> bool:
	var composite: String = "%s::%s" % [caller_id, key]
	if once_dict.has(composite):
		return false
	once_dict[composite] = true
	return true

## Helper to get context string from stack
func _get_context_from_stack() -> String:
	var stack = get_stack()
	
	# Handle empty stack case - common in test environments
	if stack.size() == 0:
		# If we're in a test environment, try to provide a reasonable fallback
		# Check if we can detect we're being called from a test
		if _is_likely_test_environment():
			return "test_environment"
		return "empty_stack"
	
	if stack.size() < 2:
		return "insufficient_stack"
		
	# Find the first caller that's not in gb_logger.gd
	# Start from index 1 to skip this function itself
	for i in range(1, stack.size()):
		var caller = stack[i]
		var source: String = caller.get("source", "")
		if source.is_empty():
			continue
			
		# Skip logger internal functions
		if source.ends_with("/gb_logger.gd") or source.ends_with("\\gb_logger.gd"):
			continue
			
		# Found the first non-logger caller
		var function: String = caller.get("function", "")
		var line: int = caller.get("line", 0)
		var file_name: String = source.get_file()
		if file_name.ends_with(".gd"):
			file_name = file_name.replace(".gd", "")
		return "%s:%s:%d" % [file_name, function, line]
	
	# If we didn't find a non-logger caller, use the last frame we have
	if stack.size() > 0:
		var caller = stack[stack.size() - 1]
		var source: String = caller.get("source", "")
		var function: String = caller.get("function", "")
		var line: int = caller.get("line", 0)
		if not source.is_empty():
			var file_name: String = source.get_file()
			if file_name.ends_with(".gd"):
				file_name = file_name.replace(".gd", "")
			return "%s:%s:%d" % [file_name, function, line]
	
	# Fallback - return stack size info for debugging
	return "unknown_stack_%d" % stack.size()

## Helper to detect if we're likely in a test environment
func _is_likely_test_environment() -> bool:
	# Check if we have a custom sink (common in tests)
	if _log_sink.is_valid():
		return true
	# Check if GdUnit is running (if we can detect it)
	if ClassDB.class_exists("GdUnitTestSuite"):
		return true
	return false

## Central dispatcher that accepts a debug `level` and `p_message` which may be a `String` or a `Callable` provider.
func log_at(level: LogLevel, p_message) -> void:
	# p_message may be a String or a Callable provider; support both so older
	# callsites that pass a Callable still work with this centralized API.
	if not is_level_enabled(level):
		return
	var context: String = _get_context_from_stack()
	var msg: String = _materialize_message(p_message)
	_emit_log(level, context, msg)

## Validates that debug settings have been injected.
## Returns list of validation issues (empty if valid).
func get_runtime_issues() -> Array[String]:
	var issues: Array[String] = []
	if _debug == null:
		issues.append("GBLogger is missing debug settings (GBDebugSettings not injected)")
	return issues

## Receives injected dependencies from the composition container.
## Assigns debug settings if available.
func resolve_gb_dependencies(p_config: GBCompositionContainer) -> bool:
	if p_config:
		_debug = p_config.get_debug_settings()
		return true
	return false

func _init(p_debug_settings : GBDebugSettings) -> void:
	if p_debug_settings:
		_debug = p_debug_settings

## Returns true if the given debug level is enabled.
func is_level_enabled(level: LogLevel) -> bool:
	return _debug != null and _debug.level >= level

## Returns true if verbose/debug logging is currently enabled.
func is_debug_enabled() -> bool:
	return is_level_enabled(LogLevel.DEBUG)

## Returns true if verbose logging is currently enabled.
func is_verbose_enabled() -> bool:
	return is_level_enabled(LogLevel.VERBOSE)

## Returns true if trace logging is currently enabled (the most detailed level).
func is_trace_enabled() -> bool:
	return is_level_enabled(LogLevel.TRACE)

## Internal helper to materialize a message that may be a String or a Callable.
func _materialize_message(p_provider) -> String:
	# Accept either a Callable or a plain String/other value. If Callable,
	# invoke it lazily; otherwise convert to String.
	if p_provider == null:
		return ""
	if typeof(p_provider) == TYPE_CALLABLE:
		var c: Callable = p_provider
		if not c.is_valid():
			return ""
		var result := c.call()
		return str(result)
	return str(p_provider)


## Alias `log` to the central dispatcher for convenience
func log(level: LogLevel, p_message) -> void:
	log_at(level, p_message)

func log_debug_lazy(p_provider: Callable) -> void:
	log_at(LogLevel.DEBUG, p_provider)

## Emits the log message to the appropriate output (console or custom sink).
func _emit_log(level: int, context: String, message: String) -> void:
	if _log_sink.is_valid():
		_log_sink.call(level, context, message)
		return

	var msg_formatted: String = "[%s] %s" % [context, message]
	match level:
		LogLevel.ERROR:
			push_error(msg_formatted)
		LogLevel.WARNING:
			push_warning(msg_formatted)
		LogLevel.INFO:
			print(msg_formatted)
		LogLevel.DEBUG:
			print(msg_formatted)
		LogLevel.VERBOSE:
			print(msg_formatted)
		LogLevel.TRACE:
			print(msg_formatted)

func log_warning(p_issue: String) -> void:
	log_at(LogLevel.WARNING, p_issue)

## Logs an informational message (between WARNING and DEBUG levels)
## Only prints when debug level >= INFO
func log_info(p_message: String) -> void:
	log_at(LogLevel.INFO, p_message)

## Logs an error message for the specified sender object.[br][br]
## [code]p_issue[/code]: [i]String[/i] - Error message to log
func log_error(p_issue: String) -> void:
	log_at(LogLevel.ERROR, p_issue)

## Logs multiple warning messages for the specified sender object.[br][br]
## [code]p_issues[/code]: [i]Array[String][/i] - Array of warning messages to log
func log_warnings(p_issues: Array[String]) -> void:
	for issue in p_issues:
		log_warning(issue)

## Logs multiple issues as warnings (alias for log_warnings).[br][br]
## [code]p_issues[/code]: [i]Array[String][/i] - Array of issue messages to log as warnings
func log_issues(p_issues: Array[String]) -> void:
	log_warnings(p_issues)

## Logs a verbose message for debugging purposes.[br][br]
## [code]p_message[/code]: [i]String[/i] - Verbose message to log
func log_verbose(p_message: String) -> void:
	log_at(LogLevel.VERBOSE, p_message)

## Trace-level log for extremely detailed diagnostics (above VERBOSE)
func log_trace(p_message: String) -> void:
	log_at(LogLevel.TRACE, p_message)

## Debug-level log helper (alias of verbose at VERBOSE level)
func log_debug(p_message: String) -> void:
	log_at(LogLevel.DEBUG, p_message)

## Throttled verbose logging: prints at most every N ms per object instance.
func log_verbose_throttled(p_object: Object, p_message: String) -> void:
	if not is_level_enabled(LogLevel.VERBOSE):
		return
	var caller_id = _get_caller_id()
	var key = str(p_object.get_instance_id()) if p_object else "null_object"
	if _is_throttled(caller_id, key):
		return
	log_verbose(p_message)

## Throttled debug helper (alias of verbose throttled)
func log_debug_throttled(p_object: Object, p_message: String) -> void:
	if not is_level_enabled(LogLevel.DEBUG):
		return
	var caller_id = _get_caller_id()
	var key = str(p_object.get_instance_id()) if p_object else "null_object"
	if _is_throttled(caller_id, key):
		return
	log_debug(p_message)

## Throttled trace helper
func log_trace_throttled(p_object: Object, p_message: String) -> void:
	if not is_level_enabled(LogLevel.TRACE):
		return
	var caller_id = _get_caller_id()
	var key = str(p_object.get_instance_id()) if p_object else "null_object"
	if _is_throttled(caller_id, key):
		return
	log_trace(p_message)

## Logs a verbose message only once per object instance.
func log_verbose_once(p_object: Object, p_message: String) -> void:
	if not is_level_enabled(LogLevel.VERBOSE):
		return
	var caller_id = _get_caller_id()
	var key = str(p_object.get_instance_id()) if p_object else "null_object"
	if not _should_log_once(caller_id, key, _verbose_once):
		return
	log_verbose(p_message)

## Log a debug message only once per object instance.
func log_debug_once(p_object: Object, p_message: String) -> void:
	if not is_level_enabled(LogLevel.DEBUG):
		return
	var caller_id = _get_caller_id()
	var key = str(p_object.get_instance_id()) if p_object else "null_object"
	if not _should_log_once(caller_id, key, _debug_once):
		return
	log_debug(p_message)

## Log a trace message only once per object instance.
func log_trace_once(p_object: Object, p_message: String) -> void:
	if not is_level_enabled(LogLevel.TRACE):
		return
	var caller_id = _get_caller_id()
	var key = str(p_object.get_instance_id()) if p_object else "null_object"
	if not _should_log_once(caller_id, key, _trace_once):
		return
	log_trace(p_message)

## Log a warning message only once per object instance.
func log_warning_once(p_object: Object, p_message: String) -> void:
	if not is_level_enabled(LogLevel.WARNING):
		return
	var caller_id = _get_caller_id()
	var key = str(p_object.get_instance_id()) if p_object else "null_object"
	if not _should_log_once(caller_id, key, _warning_once):
		return
	log_warning(p_message)

## Logs an error message, but only once per object instance.
func log_error_once(p_object: Object, p_message: String) -> void:
	var caller_id = _get_caller_id()
	var key = str(p_object.get_instance_id()) if p_object else "null_object"
	if not _should_log_once(caller_id, key, _error_once):
		return
	log_error(p_message)

## Logs an info message, but only once per object instance.
func log_info_once(p_object: Object, p_message: String) -> void:
	var caller_id = _get_caller_id()
	var key = str(p_object.get_instance_id()) if p_object else "null_object"
	if not _should_log_once(caller_id, key, _info_once):
		return
	log_info(p_message)

## Returns the GBDebugSettings that the GBLogger is currently using
func get_debug_settings() -> GBDebugSettings:
	return _debug if _debug else null

## Change the level of the GBDebugSettings to change how much information is logged
func set_log_level(p_level: LogLevel) -> void:
	_debug.level = p_level
