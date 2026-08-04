
**Localization Prep:**
- Goal: Make it easier to localize in the future
- Create a localization CSV
- Move existing text in code to using tr("")

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

