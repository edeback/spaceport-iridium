Goal: Add detail to the world and show it to the player

**Audio:**
- Goal: Add sounds for feedback and immersion
- Create a system to easily play sounds at positions
- New sounds:
	- On module placement (can be unique per module type)
	- When a module is clicked on (again unique per module)
	- When an alert is triggered
	- When the trader arrives
	- Combat sounds (firing and when a target is hit)


**Dialogue:**
- Dialogue Manager
	- https://github.com/nathanhoad/godot_dialogue_manager
- Events change to using this to display choices.
- Events gain images to display, or portraits of whoever the player is talking to
	- Such as a pirate or trader

**Tutorial/Onboarding:**
- Automatically triggered when a game starts
	- Option when creating a game to "Skip Onboarding"
- Needs dialogue work implemented first

**Starting Flow:**
- Select 2 pawns from a pool of candidates to start with (instead of starting completely randomly)
- Can randomize the pool any number of times

**Star and Planet Variations:**
- https://www.shadertoy.com/view/Wcf3W7
- https://deep-fold.itch.io/pixel-planet-generator
	- https://github.com/Deep-Fold/PixelPlanets
- 

**Stars, Planets and Other Stations:**
- Right now we only ever see one system, but in the future we will be travelling to different systems with different stars, planets, and optional other stations in the distance.
- The system we are in should hold some data on the star (required), planet (optional), and other bodies (like stations, optional).
	- Also ore type richness that fees into the spawned asteroids

**New Combat Options**:
- Xenobeasts, different types of ships


**Travel to Other Systems:**
- The station should be able to move to other systems which have different aspects
- Menu option doesn't exist until (and unless) the station has a warp core module built


**Corporations:**
- Different corporation options when starting the game
- Corporations have different starting techs unlocked and different starting resources

**Pawn Relationships:**
- Goal: Pawns should have meaningful interactions with each other. Give more flavor to the game, add story.
- When pawns "chat" they should record that interaction
- Chats can be positive or negative
	- More likely overall to be positive, unless the pawns already dislike each other
		- The general trend should be that people who work together usually like each other
	- A conflict in traits (optimist vs pessimist, for example) makes it more likely to have a negative chat, while aligned traits make it more likely to have a positive chats
- When pawns share a module, they get a small boost or penalty to their mood based upon if they like each other or not, with a moderate-sized "neutral" zone around zero where mood is not impacted

**Pawn Inspect Pane:**
- Goal: Be able to see all the details of a pawn
- This already exists, but should be anchored to screenspace (bottom left) instead of to the pawn (as they wander around)
- "Needs" pane should also break out all the mood modifiers that go into the "happiness" calculation
- New "Relationships" pane for describing relationships (requires relationships to be implemented first)

**Droids:**
- Should get descriptive names with ids (like "Mining Droid 2") in order to separate them from each other in the UI

**Alerts:**
- "High priority" alerts should require the player to click to dismiss them, so they aren't missed
	- Low priority alerts - someone is hungry, for example, can be transient
	- Critical alerts should additionally pause the game until acknowledged
- Alerts that specifically mention a pawn or module can be clicked on to jump to that pawn or module
- There should be a log of those high/critical priority alerts so the player can go back and see what has happened

**Pawn Death:**
- When health goes to zero, the pawn should die
- Pawns nearby (in the same module) as well as pawns with relationships should get a heavy mood penalty for a long time

**More Events:**
- More!

