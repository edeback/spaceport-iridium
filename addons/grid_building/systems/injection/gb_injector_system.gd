## Dependency injection system for the Grid Building Plugin.
##
## This system automatically handles:
## 1. **Dependency Injection**: Wires the `GBCompositionContainer` into all nodes
##    that implement `resolve_gb_dependencies(p_config: GBCompositionContainer)`
## 2. **Automatic Validation**: Validates the complete setup after injection and
##    reports any configuration issues via the container's logger
##
## **No manual validation calls are required** - the injector handles everything
## automatically after dependency injection is complete.
##
## The injector operates on a scoped portion of the scene tree (or the whole
## tree when no `injection_roots` are provided). It does not own the composition
## container — it holds a reference to one and performs injection and validation.
##
## **Setup Requirements**:
## - Assign a `GBCompositionContainer` resource to this injector
## - Ensure `GBLevelContext` and `GBOwner` are properly configured before
##   the injector runs (usually in `_ready()` methods)
## - The injector will automatically validate after injection and log any issues
##
## **Usage Example**:
## ```gdscript
## # In your scene node:
## func resolve_gb_dependencies(p_config: GBCompositionContainer) -> void:
##     _composition_container = p_config
##     _logger = p_config.get_logger()
##     # No validation call needed - injector handles it automatically
## ```
##
## [i]Nodes that implement `resolve_gb_dependencies(p_config: GBCompositionContainer)`
## will be injected automatically by this system.[/i]
class_name GBInjectorSystem
extends GBSystem

## Emits when the initial scene injection is completed
signal initial_injection_completed()

## Emit whenever a node is injected
signal node_injected(node : Node)

## Container services as the single source of truth for settings
## within it's scope for systems and other nodes concerned with grid building
## operations. [br][br]
## 
## [b]Dependencies are injected out of this container by the GBInjectorSystem[/b]
@export var composition_container : GBCompositionContainer

## Debug settings for logging and warnings.
## Note: runtime validation is intentionally NOT auto-run on `_ready()` because
## other game-level dependencies (GB level context, GBOwner, etc.) may not be
## fully settled. Call `run_validation()` from your world/initializer script
## after those dependencies are created and injected.

## Root nodes for injection. These nodes and any children node added will
## be injected by the GBInjectorSystem. Use this for scoping injection.
## If left empty, all nodes in the scene tree will be injected.
@export var injection_roots : Array[Node] = []

## Debug settings for logging and warnings.
var _debug : GBDebugSettings
var _logger : GBLogger

const INJECTION_META_KEY : String = "gb_injection_meta"
const RESOLVE_METHOD : StringName = "resolve_gb_dependencies"
const ORPHAN_MESSAGE : String = "[ORPHANED NODE]"

# Tracks whether initial recursive injection has completed
var _initialized : bool = false
var _scene_node_added_connected : bool = false

# Tracks the number of nodes injected during initial injection
var _initial_injection_count : int = 0

func _init(p_composition_container : GBCompositionContainer = null):
	if p_composition_container:
		composition_container = p_composition_container

func _ready():
	if composition_container == null:
		push_error("GBInjectorSystem requires a valid composition_container! Injector disabled.")
		set_process(false)
		return

	_initialize()
	
	# Editor-time validation is kept separate and is explicitly invoked here to
	# surface editor-only diagnostics. Runtime validation should be invoked by
	# host code after owner/context are available (see top-level notes).
	composition_container.validate_editor()
	_connect_scene_tree_node_added()

func _initialize():
	if _initialized:
		return
		
	_debug = composition_container.get_debug_settings()
	_logger = composition_container.get_logger()

	# Reset injection counter for initial injection
	_initial_injection_count = 0

	# Initial full recursive injection of current tree (captures existing nodes)
	for injection_root : Node in get_injection_roots():
		if not injection_root.is_inside_tree():
			push_warning("Injection root node '%s' is not inside the scene tree." % injection_root)
		_inject_existing(injection_root)
		_connect_child_entered_tree(injection_root)

	_initialized = true
	
	# Log injection count at DEBUG level or higher
	if _debug and _debug.level >= GBDebugSettings.LogLevel.DEBUG:
		_logger.log_debug("GBInjectorSystem: Initial injection completed - %d nodes injected" % _initial_injection_count)
	
	initial_injection_completed.emit()
	
	# Automatically validate after injection completes
	call_deferred("_validate_after_injection")

## Gets the scoped root nodes for injection
func get_injection_roots() -> Array[Node]:
	# Return the list of root nodes for injection
	if injection_roots.is_empty():
		# If no specific roots, inject all nodes in the scene tree
		return [get_tree().get_root()]
	else:
		var roots: Array[Node] = []
		for node in injection_roots:
			if node:
				roots.append(node)
			else:
				push_warning("Injection root node '%s' does not exist in the scene tree." % node)
		return roots

## Validates the runtime level setup for the grid building system.
##
## Notes:
## - The authoritative validation is performed by `composition_container.get_runtime_issues()`;
##   this method aggregates container-level issues and any injector-specific checks.
## - This function does NOT auto-run during `_ready()`; call `run_validation()` or
##   call into the container from host code after the composition container has
##   been injected and `GBLevelContext` / `GBOwner` are available.
func validate_runtime() -> bool:
	var issues := []
	# Prefer the container's runtime issues first (authoritative)
	if composition_container:
		var container_issues := composition_container.get_runtime_issues()
		issues.append_array(container_issues)

	# Add injector-specific runtime issues on top
	issues.append_array(get_runtime_issues())

	# Ensure logger is available
	if _logger == null and composition_container:
		_logger = composition_container.get_logger()

	for issue in issues:
		if _logger:
			_logger.log_error(issue)
		else:
			push_error(issue)

	return issues.is_empty()


## Public helper: run validation and return boolean result. Logs issues using the container logger.
## Public helper: run validation and return boolean result. Logs issues using
## the container logger. Prefer calling `composition_container.get_runtime_issues()`
## directly from host scripts when you want to inspect the issue list without
## logging side-effects.
func run_validation() -> bool:
	if _logger == null and composition_container:
		_logger = composition_container.get_logger()
	var ok := validate_runtime()
	if _logger:
		if ok:
			_logger.log_verbose("GBInjectorSystem: runtime validation passed")
		else:
			_logger.log_error("GBInjectorSystem: runtime validation failed — see logged issues")
	else:
		if ok:
			print("GBInjectorSystem: runtime validation passed")
		else:
			push_error("GBInjectorSystem: runtime validation failed — see logs or call composition_container.get_runtime_issues()")
	return ok

func get_editor_issues() -> Array[String]:
	var issues : Array[String] = []
	
	for root in injection_roots:
		if root == null:
			issues.append("Should not have null roots in injection_roots")
			
	return issues

func get_runtime_issues() -> Array[String]:
	var issues := get_editor_issues()
	
	if composition_container == null:
		issues.append("GBInjectorSystem requires a valid composition_container!")
		
	return issues
	
func _inject_existing(p_node: Node) -> void:
	inject_node(p_node)
	for child in p_node.get_children():
		_inject_existing(child)

## Handler for new nodes added to the injection scope.
## [code]p_scope[/code]: The scope node to which the new child belongs.
## [code]p_node[/code]: The newly added child node.
func _on_node_added_to_scope(p_scope: Node, p_node : Node) -> void:
	var was_injected : bool = inject_node(p_node)
	var message : String = "[scope-child_entered_tree] added=%s injected=%s" % [p_node, was_injected]
	_logger.log_verbose( message)

## Creates a GBInjectorSystem with dependency injection from container.
static func create_with_injection(p_parent : Node, container: GBCompositionContainer) -> GBInjectorSystem:
	var system = GBInjectorSystem.new(container)
	p_parent.add_child(system)
	
	# No additional dependencies to inject since this system manages injection itself
	
	return system

## Default resolve hook used by the injector when injecting this system into
## the scene. Host projects may implement their own `resolve_gb_dependencies`
## on world or player scripts to capture the container pointer and to run
## validation. The default implementation here only captures a logger and
## prints a small diagnostic.
func resolve_gb_dependencies(p_config : GBCompositionContainer) -> void:
	if p_config == null:
		return
	_logger = p_config.get_logger()
	var rule_count := 0
	if p_config.config and p_config.config.settings and p_config.config.settings.placement_rules:
		rule_count = p_config.config.settings.placement_rules.size()
	# Use log_info to report successful initialization without causing test failures
	# (Previously used log_error for visibility but this causes GdUnit test failures)
	if _logger:
		_logger.log_info("GBInjectorSystem: initialized injection with %s base placement rules" % rule_count)
	else:
		print("[GBInjectorSystem] Initialized injection with %s base placement rules" % rule_count)

## Injects dependencies into a single node (not recursive).
## Also connects signals to monitor future children and node exiting.
func inject_node(p_node: Node) -> bool:
	if p_node == null:
		return false
	if not p_node.is_inside_tree():
		return false
	# Avoid duplicate injection: if meta exists with same injector id skip
	if p_node.has_meta(INJECTION_META_KEY):
		var existing = p_node.get_meta(INJECTION_META_KEY)
		if typeof(existing) == TYPE_DICTIONARY and existing.has("injector_id") and existing["injector_id"] == int(self.get_instance_id()):
			return false
	_connect_tree_exiting(p_node)
	if p_node.has_method(RESOLVE_METHOD):
		p_node.resolve_gb_dependencies(composition_container)
		set_injection_meta(p_node)
		node_injected.emit(p_node)
		
		if _logger == null:
			_logger = composition_container.get_logger()
		
		# Increment counter during initial injection phase
		if not _initialized:
			_initial_injection_count += 1
		
		# Only log individual injections at TRACE level to reduce test noise  
		if _debug and _debug.level >= GBDebugSettings.LogLevel.TRACE:
			print("[GBInjectorSystem] Injected: %-25s at %s" % [p_node.name, p_node.get_path()])
		return true
	return false

## Injects dependencies into the node and all its children recursively.
## Used only on startup to cover existing tree nodes.
func inject_recursive(p_node: Node) -> void:
	_inject_existing(p_node)

## Sets the meta data on the object following a successful injection.
func set_injection_meta(p_node : Node) -> void:
	var meta : Dictionary[String, Variant] = {
		"injector_ref": weakref(self),
		"injector_id": int(self.get_instance_id()),
		"timestamp_ms": int(Time.get_unix_time_from_system() * 1000)
	}
	p_node.set_meta(INJECTION_META_KEY, meta)

## Removes the injection meta data from the object.
func remove_injection_meta(p_node: Node) -> void:
	p_node.remove_meta(INJECTION_META_KEY)

## Handler for new nodes entering the tree at runtime.
## Injects only the single node; child nodes will trigger their own injections.
func _on_child_entered_tree(p_node: Node) -> void:
	# Kept for backward compatibility if something still connects; prefer _on_node_added now
	inject_node(p_node)

## Handler for node exiting tree to clean up signal connections[br]
func _on_node_exiting_tree(p_node: Node) -> void:
	_disconnect_child_entered_tree(p_node)
	_disconnect_tree_exiting(p_node)

	# Only log node exits at TRACE level to reduce test noise during cleanup
	if _debug.level >= GBDebugSettings.LogLevel.TRACE && p_node.has_method(RESOLVE_METHOD):
		var node_path := p_node.get_path() if p_node.is_inside_tree() else ORPHAN_MESSAGE
		var msg := "[GBInjectorSystem] Node exiting: %-25s at %s" % [p_node.name, node_path]
		print(msg)

	## Cleanup injected metadata
	remove_injection_meta(p_node)

## [b]Private helper: Connect child_entered_tree signal if not already connected.[/b][br]
func _connect_child_entered_tree(p_node: Node) -> void:
	if p_node == null:
		return
	# Use explicit Callable for reliability
	var bound_cb : Callable = Callable(self, "_on_node_added_to_scope").bind(p_node)
	if not p_node.child_entered_tree.is_connected(bound_cb):
		p_node.child_entered_tree.connect(bound_cb)
		var meta = p_node.get_meta(INJECTION_META_KEY) if p_node.has_meta(INJECTION_META_KEY) else {}
		meta["_child_entered_cb"] = bound_cb
		p_node.set_meta(INJECTION_META_KEY, meta)

## [b]Private helper: Disconnect child_entered_tree signal if connected.[/b][br]
func _disconnect_child_entered_tree(p_node: Node) -> void:
	if p_node == null:
		return
	if not p_node.has_meta(INJECTION_META_KEY):
		return
	var meta = p_node.get_meta(INJECTION_META_KEY)
	if meta.has("_child_entered_cb"):
		var bound_cb = meta["_child_entered_cb"]
		if p_node.child_entered_tree.is_connected(bound_cb):
			p_node.child_entered_tree.disconnect(bound_cb)
		meta.erase("_child_entered_cb")
		# If meta is now empty, remove it entirely, otherwise update
		if meta.size() == 0:
			p_node.remove_meta(INJECTION_META_KEY)
		else:
			p_node.set_meta(INJECTION_META_KEY, meta)

## [b]Private helper: Connect tree_exiting signal if not already connected.[/b][br]
func _connect_tree_exiting(p_node: Node) -> void:
	if p_node == null:
		return
	var bound_exit_cb : Callable = Callable(self, "_on_node_exiting_tree").bind(p_node)
	if not p_node.tree_exiting.is_connected(bound_exit_cb):
		p_node.tree_exiting.connect(bound_exit_cb)
		var meta = p_node.get_meta(INJECTION_META_KEY) if p_node.has_meta(INJECTION_META_KEY) else {}
		meta["_tree_exiting_cb"] = bound_exit_cb
		p_node.set_meta(INJECTION_META_KEY, meta)

## [b]Private helper: Disconnect tree_exiting signal if connected.[/b][br]
func _disconnect_tree_exiting(p_node: Node) -> void:
	if p_node == null or not p_node.has_meta(INJECTION_META_KEY):
		return
	var meta = p_node.get_meta(INJECTION_META_KEY)
	if meta.has("_tree_exiting_cb"):
		var bound_exit_cb = meta["_tree_exiting_cb"]
		if p_node.tree_exiting.is_connected(bound_exit_cb):
			p_node.tree_exiting.disconnect(bound_exit_cb)
		meta.erase("_tree_exiting_cb")
		if meta.size() == 0:
			p_node.remove_meta(INJECTION_META_KEY)
		else:
			p_node.set_meta(INJECTION_META_KEY, meta)

func _connect_scene_tree_node_added() -> void:
	if _scene_node_added_connected:
		return
	var tree := get_tree()
	if tree and not tree.node_added.is_connected(_on_scene_tree_node_added):
		tree.node_added.connect(_on_scene_tree_node_added)
		_scene_node_added_connected = true

func _on_scene_tree_node_added(p_node: Node) -> void:
	if not _initialized:
		return
	if p_node == self:
		return
	# Skip if already injected
	if p_node.has_meta(INJECTION_META_KEY):
		return
	# Ensure within an injection root
	for root in get_injection_roots():
		if root == p_node or root.is_ancestor_of(p_node):
			inject_node(p_node)
			break

## Automatically validates the Grid Building setup after injection completes.
## This is called deferred after initial_injection_completed to ensure all
## nodes are properly injected and GBLevelContext/GBOwner are configured.
func _validate_after_injection() -> void:
	if composition_container == null:
		_logger.log_error("GBInjectorSystem: Cannot validate - composition_container is null")
		return
	
	var issues := composition_container.get_runtime_issues()
	if issues.size() > 0:
		_logger.log_error("Grid Building validation failed after injection:")
		for issue in issues:
			_logger.log_error("  - %s" % issue)
	else:
		_logger.log_verbose("Grid Building validation passed after injection")

## [b]Private helper: Report warnings through direct print or push_warning.[/b][br]
func _report_warning(message: String) -> void:
	print("[WARNING] " + message)
	push_warning(message)
