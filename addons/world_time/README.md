I've updated the **WorldAgeSystem** section in the README to reflect the new aging settings.

Here's the corrected README:

# World Time Plugin for Godot 4

This Godot 4 plugin helps you manage time, day-night transitions, and object aging in your 2D games. It includes a savable **TimeState** resource and an **AgeState** (RefCounted) with reactive signals for both global and local time management, as well as support for marking special event days in your calendar.

For video tutorials, check out the [World Time Plugin Playlist](https://www.google.com/search?q=https://www.youtube.com/playlist%3Flist%3DPLuzC4E4e3oM2-uO0q0i-Y2y7gY1y8hS8p). If you have questions or feedback, join the [ChrisTutorials Discord](https://www.google.com/search?q=https://discord.gg/ChrisTutorials) or visit [Linktree](https://linktr.ee/christutorials).

## Features

  * **GameTimeSystem**: Manages game time, calendars, date-time progression, and special event days.
  * **DayNightCycleSystem**: Handles time-of-day transitions (like Dawn, Day, Dusk, Night) with customizable signals.
  * **WorldAgeSystem**: Tracks the aging of objects using **AgeState** (via **AgeingComponent**) and supports scene replacements or resource additions.
  * **WorldTimeSerializer**: Simplifies saving and loading time-related states.
  * **Customizable GameCalendar**: Allows for flexible time systems (years, months, days, event days, etc.).
  * **Signal-based architecture**: Provides decoupled updates for time, age, and events.

-----

## Installation

To upgrade the plugin (if applicable):

1.  Disable the plugin: `Project Settings > Plugins > World Time > Status > Disabled`.
2.  **Back up your project** and delete the old `addons/world_time` folder.
3.  Copy the new plugin to `addons/world_time`.
4.  Enable the plugin: `Project Settings > Plugins > World Time > Status > Enabled`.
5.  For quicker setup, place template scenes in `templates/world_time` (available in the templates ZIP).

-----

## Setup Guides

### GameTimeSystem

This system manages core time progression, calendar logic, and special event days.

1.  Add a **GameTimeSystem** node to your main scene (you'll find it in the node creation menu).
2.  In the **Inspector**:
      * Create or assign a **TimeState** resource.
      * Create or assign a **GameCalendar** resource, then configure its years and months.
      * In each **GameMonth** resource, assign **EventDay** sub-resources to specific days, customizing properties like `display_name` (e.g., "Festival").
      * You can use `default_game_year.tres` for a real-world calendar if you prefer.
      * Save the **TimeState** as a `.tres` file so other nodes can easily access it.
3.  To display dates, times, and event days:
      * Add `date_time_display.tscn` (found in the `templates/world_time` folder) to a **CanvasLayer** in your UI hierarchy.
      * Assign the saved **TimeState** to the **DateTimeDisplay** in the Inspector to show event day details when applicable.
4.  Set the desired time scale on the **GameTimeSystem**, run your game, and verify that time progresses and event day signals (e.g., **event\_day\_started**) are working.

### DayNightCycleSystem

This system controls time-of-day transitions and emits signals for UI or lighting updates.

1.  Add a **DayNightCycleSystem** node to your scene.
2.  Assign the **TimeState** from the **GameTimeSystem** in the Inspector.
3.  Create an array of **TimeOfDay** resources in the Inspector, defining:
      * `enter_time`: The hour/minute when that time of day begins.
      * `game_time_duration`: The duration of the transition to fully enter that time of day.
      * `color`: A UI color for that time of day.
4.  To visually show the time of day:
      * Add or inherit `time_of_day_display.tscn` (from `templates/world_time`) to your UI and assign the **TimeState**.
      * Run the game to verify time-of-day changes in the UI.
      * Use the **time\_of\_day\_changed** signal to trigger custom logic (e.g., UI updates or lighting changes).
5.  For lighting:
      * Add `time_of_day_directional_light_2d.gd` to a 2D scene.
      * Assign the **TimeState** and define **TimeOfDayLightSettings** for each time of day.
      * Refer to the video tutorial for more details.

### WorldAgeSystem

This system tracks the aging of objects in your game world using **AgeState** (RefCounted) via **AgeingComponent** nodes.

1.  Add a **WorldAgeSystem** node to your main scene.

2.  Assign the **TimeState** from the **GameTimeSystem** in the Inspector.

3.  Configure **AgeingSettings** by creating or assigning a new `AgeingSettings` resource in the Inspector. Within this resource, you can set:

      * **Update Timing**: When aging updates (e.g., `GAME_TIME_ELAPSED`, `REAL_TIME_ELAPSED`, `DATE_CHANGED`).
      * **Interval Unit**: The unit of time for measuring aging (e.g., `DAY`).
      * **Intervals Per Age**: How many times the interval unit must elapse for the age to increase by 1.
      * **Allow Negative Age Changes**: Whether aging can decrease if time goes backward.

4.  To enable aging for objects:

      * Add an **AgeingComponent** node to any scene you want to age.
      * (Optional) Assign an **AgePreset** to set the starting age.
      * The **AgeingComponent** holds a reference to an **AgeState** (RefCounted) and automatically registers it with the **AgeStateRegistry** singleton.
      * Connect to the `age_state_changed` signal to track age updates:

    <!-- end list -->

    ```gdscript
    ageing_component.age_state_changed.connect(func(new_state: AgeState, old_state: AgeState):
        print("Age state updated: ", new_state.current)
    )
    ```

5.  For scene replacements:

      * Add an **AgeingSceneReplacement** node as a child of the target object.
      * Set `scene_to_replace`, **AgeingComponent**, age threshold, and the replacement scene path.
      * At the threshold age, the scene is replaced, and the **AgeState** can be transferred to the new scene's **AgeingComponent** using `transfer_state`.

6.  For resource additions:

      * Add an **AddWhenAgeing** node, referencing the **AgeingComponent**.
      * Configure actions or resources to add when the object reaches a specified age.

### TimeOfDayDirectionalLight2D

This component applies dynamic lighting based on the time of day.

1.  Add a **TimeOfDayDirectionalLight2D** node to your scene (after setting up **DayNightCycleSystem**).
2.  Assign the **TimeState** to receive **time\_of\_day\_changed** signals.
3.  Create an array of **TimeOfDayLightSettings**, specifying:
      * Lighting color, energy, height, and linked **TimeOfDay**.
      * Save **TimeOfDay** resources for easy reuse.
4.  Set a transition curve (e.g., linear or smoothstep) to control the lighting transition speed.
5.  Test the scene to verify lighting changes with the time of day.

-----

## Core Components

  * **DateTime**, **GameDate**, and **HoursTime**:
      * **DateTime**: Combines **GameDate** (days, months, years) and **HoursTime** (hours, minutes, seconds).
      * **GameCalendar**: Defines your time system (years, months, days). Each **GameMonth** can include **EventDay** sub-resources for specific days with customizable properties like `display_name`. Use this for conversions like `date_time_as_seconds`.
      * **GameYear**: Defines months and their day counts, cycled by the **GameCalendar**.
      * **GameMonth**: Represents a month with a name, number of days, and optional **EventDay** sub-resources.
      * **GameTimeProgress**: Tracks elapsed time between start and end **DateTime** values (e.g., for lighting transitions).
      * **EventDay**: A sub-resource for marking special days in a **GameMonth**, with customizable properties like `display_name` (e.g., "Festival"). It emits **event\_day\_started** via **TimeState** when the day starts.

-----

## Signals

**TimeState** is resource-based, allowing for multiple time systems without global singletons. **AgeState** is RefCounted and accessed via **AgeingComponent** nodes.

Key signals:

  * **time\_of\_day\_changed**: Emitted when the current **TimeOfDay** changes.

  * **event\_day\_started**: Emitted when a special event day starts, passing the **EventDay** resource.

    ```gdscript
    TimeState.event_day_started.connect(func(event_day: EventDay):
        print("Event day started: ", event_day.display_name)
    )
    ```

  * `age_state_changed`: Emitted by **AgeingComponent** when its **AgeState** updates.

    ```gdscript
    ageing_component.age_state_changed.connect(func(new_state: AgeState, old_state: AgeState):
        print("Age state updated: ", new_state.current)
    )
    ```

Connect to **TimeState** signals via saved `.tres` resources and to **AgeState** signals via **AgeingComponent**.

### GameCalendar

This is a resource that defines your time system. Configure years, months, time scales, and optional **EventDay** sub-resources within **GameMonth** to mark special days. Use it for time conversions and calculations.

-----

## Saving and Loading

The **WorldTimeSerializer** (included in `world_time_systems.tscn`) handles the serialization of time-related states (**TimeState**, **WorldAgeSystem**, **AgeStateRegistry** etc.).

### Usage

1.  Add `world_time_systems.tscn` to your project to include the **WorldTimeSerializer** node.
2.  Create a custom save/load system to handle file I/O.

**Save example:**

```gdscript
var save_data = world_time_serializer.to_dict()
var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
file.store_string(JSON.stringify(save_data))
file.close()
```

**Load example:**

```gdscript
var file = FileAccess.open("user://savegame.json", FileAccess.READ)
var save_data = JSON.parse_string(file.get_as_text())
world_time_serializer.from_dict(save_data)
file.close()
```

-----

## FAQ

**Where are time properties like Month, Day, and Hours stored?**

  * **Month**: `TimeState.date_time.date.month`
  * **Day**: `TimeState.date_time.date.day`
  * **Hours**: `TimeState.date_time.time.hours`
  * **Event Days**: Defined in **GameMonth** sub-resources and accessed via **TimeState.event\_day\_started**.
  * **Calculation**: **GameTimeSystem** updates **TimeState** via `GameCalendar.advance_date_time`.
  * **Weeks**: Used only in the Calendar UI, not in **DateTime** calculations.

**How do I create custom signals with GameTimeDuration?**

1.  Use **GameTimeDuration** to define a time threshold (e.g., days, hours).
2.  Connect to **TimeState.time\_elapsed** to track time updates.
3.  Accumulate elapsed time, emit a custom signal when the threshold is reached, and reset the timer.

**Example:**

```gdscript
var time_elapsed = 0.0
var duration = GameTimeDuration.new(...) # Set your desired duration
TimeState.time_elapsed.connect(func(delta):
    time_elapsed += delta
    if time_elapsed >= duration.as_seconds():
        emit_signal("custom_signal")
        time_elapsed -= duration.as_seconds()
)
```