class_name AiProfile
extends Resource
## How a drafting rival weighs its options (GRAND_DESIGN §3.3). Each rival's EnemyDef holds one;
## tune the weights in the Inspector and check the result with tests/sim.gd (it prints win
## rates and duel length per rival).

## greedy | trickster | showman | patient | boss (label only; the weights decide).
@export var id := "greedy"
## Value of 1 Pressure dealt to Apis.
@export var w_attack := 1.0
## Value of 1 Composure / healing, scaled up when Apis looks dangerous.
@export var w_defend := 0.3
## 0 = serve the moment a recipe is ready. Higher = hold a dish that is not in Perfect Order
## for a better one (it still serves when lethal, or when its own Confidence is low).
@export_range(0.0, 1.0) var w_patience := 0.0
## Value of debuffs on Apis (Spicy, Flustered, Rattled, Burnt).
@export var w_debuff := 0.5
## Ends the turn when no action scores above this.
@export var end_threshold := 0.5
