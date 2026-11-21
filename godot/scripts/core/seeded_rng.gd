class_name SeededRng
extends RefCounted
## Seeded RNG (mulberry32), bit-exact with the old TypeScript version, so a seed gives the
## same shuffles in both. Used instead of RandomNumberGenerator for reproducible tests/sims.

const MASK := 0xFFFFFFFF

var _a: int


func _init(rng_seed: int) -> void:
	_a = rng_seed & MASK


## Float in [0, 1).
func next() -> float:
	_a = (_a + 0x6d2b79f5) & MASK
	var t := _a
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & MASK)) & MASK
	return float((t ^ (t >> 14)) & MASK) / 4294967296.0


## Fisher–Yates in place; returns the same array.
func shuffle(items: Array) -> Array:
	for i in range(items.size() - 1, 0, -1):
		var j := floori(next() * (i + 1))
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
	return items


## 32-bit multiply like JS Math.imul, without overflowing 64-bit ints.
static func _imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & MASK
