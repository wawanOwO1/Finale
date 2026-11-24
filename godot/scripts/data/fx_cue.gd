class_name FxCue
extends Resource
## One game moment's screen feel (FX_MASTERPLAN.md §3–4): how long the game freezes, how hard
## the screen shakes, whether it flashes or loses color. One .tres per moment in data/fx/,
## assigned to FxDirector in main.tscn. Tune it in the Inspector.
##
## Several cues in the same frame (a Serve fires dish_revealed + dish_served + confidence_lost)
## do not add up: FxDirector keeps the strongest value of each field.

## T0 micro, T1 hit, T2 big, T3 finisher. fx_check.gd keeps each tier inside its budget.
@export_enum("T0", "T1", "T2", "T3") var tier := 1
@export_group("Hitstop")
## Freeze, in real seconds (the game runs at HitStop.slow_scale meanwhile).
@export_range(0.0, 0.4, 0.01) var hitstop := 0.0
@export_group("Shake")
## Trauma added to Shake (0..1). Offset grows with trauma², so 0.5 is a quarter of the max.
@export_range(0.0, 1.0, 0.05) var trauma := 0.0
@export_group("Flash")
## Peak alpha of a full-screen flash (0 = none). Halved with Reduce Flashing.
@export_range(0.0, 1.0, 0.05) var flash := 0.0
@export var flash_color := Color.WHITE
## Fade-out of the flash, real seconds.
@export_range(0.02, 1.0, 0.01) var flash_time := 0.15
@export_group("Desaturate")
## Color drained from the whole screen (0 = none, 1 = gray).
@export_range(0.0, 1.0, 0.05) var desat := 0.0
## Seconds it stays drained before fading back over desat_fade.
@export_range(0.0, 5.0, 0.05) var desat_hold := 0.0
@export_range(0.05, 3.0, 0.05) var desat_fade := 0.4
@export_group("Camera")
## FOV punch-in of the stage camera (0.03 = 3% closer), springs back in punch_time.
@export_range(0.0, 0.15, 0.005) var zoom_punch := 0.0
@export_group("Particles")
## Burst kind from %FxHud: "crumbs", "steam", "sparks", "smoke", "shards", or "none".
@export_enum("none", "crumbs", "steam", "sparks", "smoke", "shards") var burst := "none"
## Second burst at the same spot (e.g. steam + sparks on a Perfect).
@export_enum("none", "crumbs", "steam", "sparks", "smoke", "shards") var burst_2 := "none"
@export_group("Text")
## Manga sound word slammed near the hit ("BAM!"). Empty = none.
@export var word := ""
@export var word_color := Color("#fbf3e2")
@export_group("Stage")
## Crowd jumps together (0 = no reaction, 1 = big cheer).
@export_range(0.0, 1.0, 0.05) var crowd := 0.0
## Crack the hit side's Confidence bar.
@export var crack := false
