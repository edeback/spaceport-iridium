extends GutTest

## WI-47 M2: the save_key() / save_order() contract that replaced ModuleBase's
## hand-written component chain.
##
## These constraints used to be comments in the middle of a 100-line function
## ("Construction before storage", "Processor before storage", "Shield AFTER
## upgrades"). Now they're numbers on the components, which means they can be
## asserted - and a component that quietly renumbers itself fails here rather
## than in someone's save file.
##
## Components are constructed bare, never added to a tree, so nothing here
## touches Global or SignalBus.

func _module_components() -> Dictionary[String, ComponentBase]:
	var out: Dictionary[String, ComponentBase] = {
		"construction": autofree(ConstructionComponent.new()),
		"processor": autofree(ProcessorComponent.new()),
		"workspace": autofree(WorkspaceComponent.new()),
		"storage": autofree(StorageComponent.new()),
		"trade": autofree(TradeComponent.new()),
		"atmosphere": autofree(AtmosphereComponent.new()),
		"o2_generator": autofree(OxygenGeneratorComponent.new()),
		"sustenance": autofree(SustenanceComponent.new()),
		"shop": autofree(ShopComponent.new()),
		"conveyor": autofree(ConveyorComponent.new()),
		"power_consumption": autofree(PowerConsumptionComponent.new()),
		"power_generation": autofree(PowerGenerationComponent.new()),
		"mining": autofree(MiningComponent.new()),
		"shield": autofree(ShieldComponent.new()),
		"battery": autofree(BatteryComponent.new()),
		# WI-60/WI-67, pinned by WI-68 F9.
		"heat": autofree(HeatComponent.new()),
		"heat_emitter": autofree(HeatEmitterComponent.new()),
	}
	return out

func _pawn_components() -> Dictionary[String, PawnComponentBase]:
	var out: Dictionary[String, PawnComponentBase] = {
		"needs": autofree(PawnNeedsComponent.new()),
		"health": autofree(PawnHealthComponent.new()),
		"skills": autofree(PawnSkillsComponent.new()),
		"traits": autofree(PawnTraitsComponent.new()),
		"disease": autofree(PawnDiseaseComponent.new()),
		"social": autofree(SocializeComponent.new()),
		"breathing": autofree(PawnBreathingComponent.new()),
		"robot_power": autofree(RobotPowerComponent.new()),
		"robot_integrity": autofree(RobotIntegrityComponent.new()),
		# WI-67, pinned by WI-68 F9.
		"suit": autofree(PawnSuitComponent.new()),
	}
	return out

# --- keys: the on-disk shape must not move --------------------------------------

func test_every_module_component_keeps_its_legacy_key() -> void:
	# These strings are in every save file ever written. Changing one silently
	# drops that component's state on load.
	for expected_key: String in _module_components():
		var component: ComponentBase = _module_components()[expected_key]
		assert_eq(String(component.save_key()), expected_key,
				"%s must keep its legacy save key" % component.get_script().resource_path.get_file())

func test_every_pawn_component_keeps_its_legacy_key() -> void:
	for expected_key: String in _pawn_components():
		var component: PawnComponentBase = _pawn_components()[expected_key]
		assert_eq(String(component.save_key()), expected_key,
				"%s must keep its legacy save key" % component.get_script().resource_path.get_file())

func test_an_unowned_component_falls_back_to_its_node_name() -> void:
	# The default key is a node path, which needs an owner. Without one it must
	# still produce something rather than erroring - this is the path a bare
	# unit-test component takes.
	var component: ComponentBase = autofree(ComponentBase.new())
	component.name = "SomeModComponent"
	assert_eq(String(component.save_key()), "SomeModComponent")

# --- order: the constraints that used to be comments ----------------------------

func test_construction_restores_before_storage() -> void:
	# The deconstruction path reconfigures the material storage; contents go in after.
	var components: Dictionary[String, ComponentBase] = _module_components()
	assert_lt(components["construction"].save_order(), components["storage"].save_order())

func test_processor_restores_before_storage() -> void:
	# Restoring the recipe reconfigures the input/output slots.
	var components: Dictionary[String, ComponentBase] = _module_components()
	assert_lt(components["processor"].save_order(), components["storage"].save_order())

func test_shield_restores_after_the_upgrades_block() -> void:
	# effective_capacity() reads the upgrade-modified stat and the charge is
	# clamped against it (WI-38 A2). This one is a correctness requirement.
	var components: Dictionary[String, ComponentBase] = _module_components()
	assert_gt(components["shield"].save_order(), ComponentBase.UPGRADE_SAVE_ORDER)

func test_the_conveyor_restores_before_the_upgrades_block() -> void:
	# It grows its own lane array rather than waiting for the Extra Belt upgrade.
	var components: Dictionary[String, ComponentBase] = _module_components()
	assert_lt(components["conveyor"].save_order(), ComponentBase.UPGRADE_SAVE_ORDER)

func test_disease_restores_after_skills_and_traits() -> void:
	# Its load re-derives skill maluses and mood modifiers from them (WI-31).
	var components: Dictionary[String, PawnComponentBase] = _pawn_components()
	assert_gt(components["disease"].save_order(), components["skills"].save_order())
	assert_gt(components["disease"].save_order(), components["traits"].save_order())

func test_no_two_module_components_share_an_order() -> void:
	# Ties are broken by registration order, which is stable but arbitrary. Vanilla
	# should never rely on it.
	var seen: Dictionary[int, String] = {}
	for key: String in _module_components():
		var order: int = _module_components()[key].save_order()
		assert_false(seen.has(order), "%s and %s both claim order %d" % [key, seen.get(order, ""), order])
		seen[order] = key

func test_a_mod_component_restores_after_everything_vanilla() -> void:
	# The WI-47 edge case: a component that doesn't override save_order must not
	# land before construction and storage, where it could break their ordering.
	for key: String in _module_components():
		assert_lt(_module_components()[key].save_order(), ComponentBase.DEFAULT_SAVE_ORDER,
				"%s must sort before the default a mod component gets" % key)
	for key: String in _pawn_components():
		assert_lt(_pawn_components()[key].save_order(), PawnComponentBase.DEFAULT_SAVE_ORDER,
				"%s must sort before the default a mod component gets" % key)

# --- per-instance ---------------------------------------------------------------

func test_storage_is_the_only_per_instance_component() -> void:
	# A processor genuinely has an Input bin and an Output bin, which is why the
	# storage block is a path-keyed dict and nothing else is.
	for key: String in _module_components():
		var expected: bool = key == "storage"
		assert_eq(_module_components()[key].saves_per_instance(), expected, key)

# --- empty blocks are not written -----------------------------------------------

func test_the_base_saves_nothing_by_default() -> void:
	# A component with no state must produce no key at all, so modules that carry
	# path/structure/adjacency components stay compact in the file.
	assert_eq(autofree(ComponentBase.new()).get_save_data(), {})
	assert_eq(autofree(PawnComponentBase.new()).get_save_data(), {})

func test_traits_round_trip_through_the_dictionary_shape() -> void:
	# The one component whose block shape changed in stage 2 (a bare Array can't
	# satisfy a Dictionary-typed hook). An empty trait list writes nothing.
	var component: PawnTraitsComponent = autofree(PawnTraitsComponent.new())
	assert_eq(component.get_save_data(), {}, "no traits means no block")
