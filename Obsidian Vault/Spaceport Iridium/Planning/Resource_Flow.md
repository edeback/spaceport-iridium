# Resource Flow

> [!warning] Generated file - do not edit by hand.
> `godot --headless -s tools/gen_resource_flow.gd` rebuilds it from
> `data/recipes/`, `data/modules/`, `data/space_bodies/`, `main.tscn`'s
> belt pool and `data/planned_flow.json`.
> **Solid = implemented. Dashed = planned** (edit `data/planned_flow.json`).

```mermaid
flowchart LR
  classDef res fill:#132630,stroke:#4fc3f7,color:#e7f4fb;
  classDef proc fill:#2a2214,stroke:#ffb74d,color:#fbf1e2;
  classDef planned stroke-dasharray:5 4,opacity:0.7;
  subgraph g_src_asteroid["Asteroid"]
    direction TB
    r_iron_ore(["Iron Ore"]):::res
    r_gold_ore(["Gold Ore"]):::res
    r_carbon(["Carbon"]):::res
    r_iridium_ore(["Iridium Ore"]):::res
    r_silicates(["Silicates"]):::res
    r_ice(["Ice"]):::res
    r_uranium_ore(["Uranium Ore"]):::res
  end
  subgraph g_src_comet["Comet"]
    direction TB
    r_ice(["Ice"]):::res
    r_carbon(["Carbon"]):::res
    r_silicates(["Silicates"]):::res
  end
  subgraph g_algae_tank["Algae Tank"]
    direction TB
    p_algae_tank_farm_algae["Farm Algae"]:::proc
  end
  subgraph g_hydroponics_bay["Hydroponics Bay"]
    direction TB
    p_hydroponics_bay_grow_plants["Grow Plants"]:::proc
  end
  subgraph g_ice_purifier["Ice Purifier"]
    direction TB
    p_ice_purifier_melt_ice["Melt Ice"]:::proc
    p_ice_purifier_purify_ice["Purify Ice"]:::proc
  end
  subgraph g_foundry["Foundry"]
    direction TB
    p_foundry_forge_steel["Forge Steel"]:::proc
    p_foundry_refine_gold["Refine Gold"]:::proc
    p_foundry_refine_iridium["Refine Iridium"]:::proc
  end
  subgraph g_silicon_furnace["Silicon Furnace"]
    direction TB
    p_silicon_furnace_refine_silicon["Refine Silicon"]:::proc
  end
  subgraph g_electrolyzer["Electrolyzer"]
    direction TB
    p_electrolyzer_electrolyze_water["Electrolyze Water"]:::proc
  end
  subgraph g_isotope_separator["Isotope Separator"]
    direction TB
    p_isotope_separator_enrich_uranium["Enrich Uranium"]:::proc
  end
  subgraph g_nuclear_fission_plant["Nuclear Fission Plant"]
    direction TB
    p_nuclear_fission_plant_fission_cycle["Fission Cycle"]:::proc
  end
  subgraph g_electronics_assembler["Electronics Assembler"]
    direction TB
    p_electronics_assembler_assemble_electronics["Assemble Electronics"]:::proc
  end
  subgraph g_advanced_circuitry_fabricator["Advanced Circuitry Fabricator"]
    direction TB
    p_advanced_circuitry_fabricator_fabricate_data_core["Fabricate Data Core"]:::proc
  end
  subgraph g_kiln["Kiln"]
    direction TB
    p_kiln_fire_ceramics["Fire Ceramics"]:::proc
  end
  subgraph g_chemical_plant["Chemical Plant"]
    direction TB
    p_chemical_plant_compound_fuel["Compound Fuel"]:::proc
    p_chemical_plant_mix_coolant["Mix Coolant"]:::proc
    p_chemical_plant_synthesise_polymer["Synthesise Polymer"]:::proc
  end
  subgraph g_fabricator["Fabricator"]
    direction TB
    p_fabricator_make_consumer_goods["Make Consumer Goods"]:::proc
    p_fabricator_make_luxury_goods["Make Luxury Goods"]:::proc
  end
  r_water(["Water"]):::res -->|1| p_algae_tank_farm_algae
  r_carbon(["Carbon"]):::res -->|1| p_algae_tank_farm_algae
  p_algae_tank_farm_algae -->|2| r_biomass(["Biomass"]):::res
  r_water(["Water"]):::res -->|1| p_hydroponics_bay_grow_plants
  r_carbon(["Carbon"]):::res -->|1| p_hydroponics_bay_grow_plants
  p_hydroponics_bay_grow_plants -->|3| r_biomass(["Biomass"]):::res
  r_ice(["Ice"]):::res -->|1| p_ice_purifier_melt_ice
  p_ice_purifier_melt_ice -->|1| r_water(["Water"]):::res
  r_ice(["Ice"]):::res -. 2 .-> p_ice_purifier_purify_ice
  p_ice_purifier_purify_ice -. 2 .-> r_water(["Water"]):::res
  p_ice_purifier_purify_ice -. 1 .-> r_carbon(["Carbon"]):::res
  r_carbon(["Carbon"]):::res -->|1| p_foundry_forge_steel
  r_iron_ore(["Iron Ore"]):::res -->|2| p_foundry_forge_steel
  p_foundry_forge_steel -->|2| r_steel(["Steel"]):::res
  r_gold_ore(["Gold Ore"]):::res -->|2| p_foundry_refine_gold
  p_foundry_refine_gold -->|1| r_gold(["Gold"]):::res
  r_iridium_ore(["Iridium Ore"]):::res -->|2| p_foundry_refine_iridium
  p_foundry_refine_iridium -->|1| r_iridium(["Iridium"]):::res
  r_silicates(["Silicates"]):::res -->|2| p_silicon_furnace_refine_silicon
  r_carbon(["Carbon"]):::res -->|1| p_silicon_furnace_refine_silicon
  p_silicon_furnace_refine_silicon -->|1| r_silicon(["Silicon"]):::res
  r_water(["Water"]):::res -->|2| p_electrolyzer_electrolyze_water
  p_electrolyzer_electrolyze_water -->|1| r_oxygen(["Oxygen"]):::res
  p_electrolyzer_electrolyze_water -->|2| r_hydrogen(["Hydrogen"]):::res
  r_uranium_ore(["Uranium Ore"]):::res -. 4 .-> p_isotope_separator_enrich_uranium
  p_isotope_separator_enrich_uranium -. 1 .-> r_enriched_uranium(["Enriched Uranium"]):::res
  r_enriched_uranium(["Enriched Uranium"]):::res -. 1 .-> p_nuclear_fission_plant_fission_cycle
  p_nuclear_fission_plant_fission_cycle -. 100 .-> r_stored_energy(["Stored Energy"]):::res
  p_nuclear_fission_plant_fission_cycle -. 1 .-> r_depleted_uranium(["Depleted Uranium"]):::res
  r_silicon(["Silicon"]):::res -. 2 .-> p_electronics_assembler_assemble_electronics
  r_gold(["Gold"]):::res -. 1 .-> p_electronics_assembler_assemble_electronics
  p_electronics_assembler_assemble_electronics -. 1 .-> r_electronics(["Electronics"]):::res
  r_electronics(["Electronics"]):::res -. 2 .-> p_advanced_circuitry_fabricator_fabricate_data_core
  r_iridium(["Iridium"]):::res -. 1 .-> p_advanced_circuitry_fabricator_fabricate_data_core
  p_advanced_circuitry_fabricator_fabricate_data_core -. 1 .-> r_data_core(["Data Core"]):::res
  r_silicon(["Silicon"]):::res -. 2 .-> p_kiln_fire_ceramics
  r_carbon(["Carbon"]):::res -. 1 .-> p_kiln_fire_ceramics
  p_kiln_fire_ceramics -. 2 .-> r_ceramics(["Ceramics"]):::res
  r_hydrogen(["Hydrogen"]):::res -. 2 .-> p_chemical_plant_compound_fuel
  r_oxygen(["Oxygen"]):::res -. 1 .-> p_chemical_plant_compound_fuel
  p_chemical_plant_compound_fuel -. 2 .-> r_fuel(["Fuel"]):::res
  r_water(["Water"]):::res -. 2 .-> p_chemical_plant_mix_coolant
  r_polymer(["Polymer"]):::res -. 1 .-> p_chemical_plant_mix_coolant
  p_chemical_plant_mix_coolant -. 2 .-> r_coolant(["Coolant"]):::res
  r_carbon(["Carbon"]):::res -. 2 .-> p_chemical_plant_synthesise_polymer
  r_hydrogen(["Hydrogen"]):::res -. 1 .-> p_chemical_plant_synthesise_polymer
  p_chemical_plant_synthesise_polymer -. 2 .-> r_polymer(["Polymer"]):::res
  r_polymer(["Polymer"]):::res -. 1 .-> p_fabricator_make_consumer_goods
  r_steel(["Steel"]):::res -. 2 .-> p_fabricator_make_consumer_goods
  p_fabricator_make_consumer_goods -. 1 .-> r_consumer_goods(["Consumer Goods"]):::res
  r_polymer(["Polymer"]):::res -. 1 .-> p_fabricator_make_luxury_goods
  r_gold(["Gold"]):::res -. 2 .-> p_fabricator_make_luxury_goods
  p_fabricator_make_luxury_goods -. 1 .-> r_luxury_goods(["Luxury Goods"]):::res
  class r_uranium_ore,p_ice_purifier_purify_ice,p_isotope_separator_enrich_uranium,p_nuclear_fission_plant_fission_cycle,p_electronics_assembler_assemble_electronics,p_advanced_circuitry_fabricator_fabricate_data_core,p_kiln_fire_ceramics,p_chemical_plant_compound_fuel,p_chemical_plant_mix_coolant,p_chemical_plant_synthesise_polymer,p_fabricator_make_consumer_goods,p_fabricator_make_luxury_goods planned;
```

