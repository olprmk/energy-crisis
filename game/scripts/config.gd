class_name GameConfig
extends RefCounted
## All tunable numbers of the game live here.

## Apartment models (src/blender/apartment.py): floor<model>.glb + floor<model>_layout.json in this folder.
## Each floor names its model in FLOORS below; the select screen is in floor 1's apartment.
const APARTMENT_DIR := "res://assets/models/apartment/"

const ROUND_TIME := 60.0        # seconds per floor
const NO_SPAWN_LAST := 5.0      # last seconds without new appliances
const OVERLOAD_GRACE := 2.5     # seconds above the limit before the fuses blow (a floor can set its own "grace")
## Last LATE_SPAWN_WINDOW seconds: an appliance switches on only if the player can still switch everything off in time:
## walking the routes through the doors at LATE_SPAWN_PACE of the character's speed, LATE_SPAWN_REACT seconds to notice
## each appliance, with LATE_SPAWN_MARGIN seconds to spare. Keeps the end of the round fair in the big flats.
const LATE_SPAWN_WINDOW := 20.0
const LATE_SPAWN_PACE := 0.6
const LATE_SPAWN_REACT := 0.8
const LATE_SPAWN_MARGIN := 1.5
const FIRST_SPAWN := 1.5

## Camera: orthographic size = how many metres fit vertically on screen (smaller = closer).
const CAMERA_ZOOM := 4.5
const SELECT_ZOOM := 2.6
const SELECT_ZOOM_PHONE := 1.9   # the same on a phone: the view above the bottom sheet is low, so a closer look
const SELECT_POS := Vector3(2.1, 0.0, -2.5)   # where the character stands on the select screen (living room)
const SELECT_HEIGHT := 0.6                     # camera aim height on the select / result screens (character centred)
const ZOOM_MIN := 3.0
const ZOOM_MAX := 8.0

## Lighting in the Compatibility renderer (web browsers, old GPUs): it has no HDR, so with the desktop values the
## picture is washed out to white. These look like the desktop (Forward+) version: no glow, a much weaker sun,
## less ambient light, lamps (OmniLight) at 30%, the background colour as it comes out after the desktop's tonemapping.
const COMPAT_LIGHTING := {"glow": false, "sun": 0.33, "ambient": 0.27, "lamps": 0.3, "background": "4f6f7b"}

## Window: base resolution (logical pixels). On Retina/HiDPI screens the window is scaled up.
const WINDOW_SIZE := Vector2i(1280, 720)

## Adaptive layout (Figma "iPhone 17 - 1"): the game sits in a rounded frame on a light background.
const BACKGROUND_COLOR := Color("e5ecee")
const FRAME_MARGIN := 0.025       # gap round the frame: share of the window's shorter side (10 px on a phone)
const FRAME_RADIUS := 0.031       # corner radius: share of the frame's shorter side
const UI_REF_SIZE := Vector2(812, 720)   # the HUD is scaled so this much of it fits into the frame
## Touch controls (analog stick + two buttons): "auto" = in portrait, and on touch screens in landscape too;
## "always" / "never".
const TOUCH_CONTROLS := "auto"
## Names on the two round buttons (mockup: pixel "0" and "X"). On touch screens the hints name these buttons
## instead of the keys: "0" for Enter / Space (start, switch off, next), "X" for Esc (back).
const TOUCH_BUTTONS := {"a": "0", "b": "X"}
## On a phone the frame is small: the play HUD (timer, grid meter, prompt, toast) is drawn this much larger.
## (The menu / result sheet has its own size: hud.gd, SHEET_*.)
const TOUCH_HUD_BOOST := {"portrait": 1.6, "landscape_touch": 1.4}
const TOUCH_LAYOUT := {   # mockup sizes, px on a 402 px wide phone
	"ref_width": 402.0, "side": 24.0, "stick": 116.0, "button": 60.0,
	"gap": 90.0,          # from the frame down to the controls
	"bottom": 24.0,       # least room left under them
	"button_drop": 56.0,  # the second button sits this much lower than the first
}

## Background music (assets/music/calm|tension|urgent .ogg): volume of the Music bus, M toggles it in game.
const MUSIC_ENABLED := true
const MUSIC_VOLUME_DB := -11.4   # 85 % of the earlier -10 dB (-1.4 dB); the two result tracks below likewise
const MUSIC_HURRY_TIME := 15.0   # last seconds of a round: music gets more intense, faster and higher
const VICTORY_VOLUME_DB := -9.4   # victory music after a passed floor (assets/music/victory.ogg)
const DEFEAT_VOLUME_DB := -9.4    # sad music after a failed floor (assets/music/defeat.ogg)

## Image-noise burst when an appliance switches on.
const GLITCH_STRENGTH := 0.55
const GLITCH_TIME := 0.35

## Leaderboard table on the right (name screen and result screens). Hidden for now:
## names and scores are still saved to user://save.json, set to true to show the table again.
const SHOW_LEADERBOARD := false
## Switched-off power: the number starts this far (m) below the appliance's "!" marker, on the appliance itself.
const FLY_FROM_BELOW_TOP := 0.45

## Difficulty per floor (see docs/plan.md, section 1.1): 10 floors, each one a little harder.
##   interval  — seconds between appliance switch-ons (random value in the range)
##   max_on    — how many appliances may be on at the same time
##   limit_kw  — grid limit; above it for "grace" seconds (default OVERLOAD_GRACE) the fuses blow;
##               the bigger flats of floors 7-10 give more time to run to an appliance
##   threshold — minimal economy (share of energy saved) to pass the floor
##   double    — chance 0..1 that two appliances switch on at once
##   model     — apartment (APARTMENT_DIR/floor<model>.glb): 1, 2, 3 — 5 rooms (11 x 8 m),
##               7 — 6 rooms + corridor (13 x 9 m), 9 — 8 rooms + corridor (15 x 9.6 m)
##   recolor   — the second floor with the same apartment gets other wall / floor colours (RECOLOR below)
## New appliances join the game one by one (APPLIANCE_UNLOCK below).
const FLOORS := [
	{"floor": 1, "model": "1", "recolor": false, "interval": Vector2(6.0, 8.0), "max_on": 2, "limit_kw": 4.0, "threshold": 0.50, "double": 0.00},
	{"floor": 2, "model": "2", "recolor": false, "interval": Vector2(5.5, 7.3), "max_on": 2, "limit_kw": 4.0, "threshold": 0.53, "double": 0.00},
	{"floor": 3, "model": "3", "recolor": false, "interval": Vector2(5.0, 6.6), "max_on": 3, "limit_kw": 4.0, "threshold": 0.56, "double": 0.00},
	{"floor": 4, "model": "1", "recolor": true, "interval": Vector2(4.5, 5.9), "max_on": 3, "limit_kw": 3.9, "threshold": 0.59, "double": 0.00},
	{"floor": 5, "model": "2", "recolor": true, "grace": 3.0, "interval": Vector2(4.1, 5.4), "max_on": 4, "limit_kw": 3.9, "threshold": 0.62, "double": 0.06},
	{"floor": 6, "model": "3", "recolor": true, "grace": 4.0, "interval": Vector2(3.9, 5.1), "max_on": 4, "limit_kw": 3.8, "threshold": 0.66, "double": 0.10},
	{"floor": 7, "model": "7", "recolor": false, "grace": 6.0, "interval": Vector2(4.6, 6.2), "max_on": 4, "limit_kw": 3.8, "threshold": 0.69, "double": 0.13},
	{"floor": 8, "model": "7", "recolor": true, "grace": 6.0, "interval": Vector2(4.2, 5.5), "max_on": 5, "limit_kw": 3.7, "threshold": 0.71, "double": 0.16},
	{"floor": 9, "model": "9", "recolor": false, "grace": 7.5, "interval": Vector2(3.9, 5.1), "max_on": 5, "limit_kw": 3.7, "threshold": 0.73, "double": 0.20},
	{"floor": 10, "model": "9", "recolor": true, "grace": 8.0, "interval": Vector2(3.5, 4.6), "max_on": 5, "limit_kw": 3.6, "threshold": 0.76, "double": 0.25},
]

## Other colours for the second floor of each apartment ("recolor": true): material name -> colour.
## wall_<room> = wall paint; floor_<room> = tint over the floor texture (white = as is).
const RECOLOR := {
	"1": {"wall_living": "#8FBCA9", "wall_kitchen": "#F2C6A0", "wall_bedroom": "#B9A5D8", "wall_kids": "#A9CFE8",
		"wall_bath": "#F0B9C6", "floor_living": "#E9D2BE", "floor_kitchen": "#DCE8EC"},
	"2": {"wall_kitchen": "#CFE3A8", "wall_living": "#E4BA90", "wall_kids": "#9FD3D0", "wall_bath": "#C6B6E4",
		"wall_bedroom": "#A9C5E9", "floor_living": "#E2D6D0", "floor_bath": "#E6E0F2"},
	"3": {"wall_living": "#E6AA9C", "wall_bedroom": "#A6D7B6", "wall_kitchen": "#BAC8E9", "wall_kids": "#F1B7D3",
		"wall_bath": "#E9DA9B", "floor_living": "#F2E2CF", "floor_kitchen": "#E1E8F5"},
	"7": {"wall_living": "#94C0D2", "wall_kitchen": "#F3C0A2", "wall_study": "#BAD09B", "wall_hall": "#E5DAC3",
		"wall_bedroom": "#F2C48F", "wall_kids": "#C4B1E1", "wall_bath": "#F0B3B0", "floor_hall": "#D9C9B8"},
	"9": {"wall_living": "#A7C9E9", "wall_kitchen": "#F2CAA3", "wall_laundry": "#D8C5E7", "wall_guest": "#B6DAA7",
		"wall_hall": "#DDD4C4", "wall_bedroom": "#E9B4B4", "wall_kids": "#F3DD9B", "wall_study": "#9FCAC2",
		"wall_bath": "#C5B7E5", "floor_hall": "#EAD9C4"},
}

## Floor from which each appliance starts switching on (everything else: from floor 1).
## Overrides `min_floor` from floor<model>_layout.json. One new appliance per floor; the 2-2.5 kW heater, stove,
## washer and boiler come last: the more heavy devices, the more often two of them run at once and blow the fuses.
const APPLIANCE_UNLOCK := {
	"nightlight": 2, "microwave": 3, "console": 4, "iron": 5, "hair_dryer": 6,
	"heater": 7, "stove": 8, "washer": 9, "boiler": 10,
}

## Footsteps: "steps" = sound set (assets/sounds/steps/<steps>_<wood|tile>_<n>.wav: barefoot, paws, slippers,
## sneakers), "step_phases" = moments of the walk animation (0..1) when a foot touches the floor (taken from the
## animations: people step at 13% and 59% of the cycle; the dog's front and back paws land in pairs),
## "step_gains" = extra dB per step (the dog's back paws are softer). The floor of the room decides wood or tile.
const STEP_VOLUME_DB := -2.0
const CHARACTERS := [
	{"id": "mother", "name": "Джоан", "role": "Мати", "file": "res://assets/models/characters/mother.glb",
	 "speed": 3.0, "switch_time": 0.6, "radius": 0.22, "steps": "barefoot", "step_phases": [0.13, 0.59],
	 "desc": "Збалансована: середня швидкість і швидке вимикання."},
	{"id": "dog", "name": "Рекс", "role": "Собака", "file": "res://assets/models/characters/dog.glb",
	 "speed": 3.8, "switch_time": 1.0, "radius": 0.3, "steps": "paws", "step_phases": [0.97, 0.03, 0.47, 0.53],
	 "step_gains": [0.0, -4.0, 0.0, -4.0],
	 "desc": "Найшвидший, але вимикає прилад довше — тягне носом."},
	{"id": "father", "name": "Алекс", "role": "Батько", "file": "res://assets/models/characters/father.glb",
	 "speed": 2.6, "switch_time": 0.3, "radius": 0.22, "steps": "slippers", "step_phases": [0.13, 0.59],
	 "desc": "Повільніший, зате вимикає миттєво."},
	{"id": "child", "name": "Ніка", "role": "Донька", "file": "res://assets/models/characters/child.glb",
	 "speed": 3.4, "switch_time": 0.7, "radius": 0.2, "steps": "sneakers", "step_phases": [0.13, 0.59],
	 "desc": "Швидкий і маленький — легко пробігає між меблями."},
]
