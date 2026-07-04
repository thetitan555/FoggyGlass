extends SceneTree

## One-time authoring tool (TKT-P1-10): builds character A via CharacterA
## (game/content/character_a.gd) and saves it as the authored `.tres` Resource
## at data/character-a.tres, matching move-format.md's authoring format (AD-006)
## — Godot custom Resource files, not hand-transcribed text. Baking from the one
## builder function guarantees the shipped `.tres` and the dev-test twin
## (tests/test_character_a.gd) agree by construction; there is exactly one
## authored definition (CharacterA.build_character()).
##
## This is a ONE-TIME AUTHORING TOOL, not runtime/game code (move-format.md
## criterion 1 concerns authoring a move without touching ENGINE code — this
## script is the authoring step itself, analogous to typing the .tres by hand,
## and is not part of the shipped game or the sim's runtime path).
##
## Run:  godot --headless --path game -s res://tools/bake_character_a.gd

func _init() -> void:
	var c: Character = CharacterA.build_character()
	var path := "res://data/character-a.tres"
	var err := ResourceSaver.save(c, path)
	if err != OK:
		printerr("[bake_character_a] FAILED to save %s (error %d)" % [path, err])
		quit(1)
		return
	print("[bake_character_a] saved %s (states=%d, button_map=%d)" % [
		path, c.states.size(), c.button_map.size()])
	quit(0)
