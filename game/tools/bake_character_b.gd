extends SceneTree

## One-time authoring tool (TKT-P2-05), mirrors tools/bake_character_a.gd:
## builds character B via CharacterB.build_character() and saves it as the
## authored `.tres` Resource at data/character-b.tres (move-format.md's
## authoring format, AD-006). Baking from the one builder function guarantees
## the shipped `.tres` and the dev-test twin (tests/test_character_b.gd) agree
## by construction.
##
## ONE-TIME AUTHORING TOOL, not runtime/game code (same note as
## bake_character_a.gd).
##
## Run:  godot --headless --path game -s res://tools/bake_character_b.gd

func _init() -> void:
	var c: Character = CharacterB.build_character()
	var path := "res://data/character-b.tres"
	var err := ResourceSaver.save(c, path)
	if err != OK:
		printerr("[bake_character_b] FAILED to save %s (error %d)" % [path, err])
		quit(1)
		return
	print("[bake_character_b] saved %s (states=%d, button_map=%d, cancel_groups=%d)" % [
		path, c.states.size(), c.button_map.size(), c.cancel_groups.size()])
	quit(0)
