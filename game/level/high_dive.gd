extends Node3D
## Level 2, The High Dive (gray-box, first pass). A tall natatorium over one deep diving pool: you
## can't wade here, only swim, and the Wader crawls along the bottom. Falls are huge.
##
##   Start room (south) -> the south deck -> a ladder up to the west gallery (4 m up, with gaps to
##   jump) -> a long narrow beam out to the diving tower -> ladders up its platforms (4, 7.5 and
##   10 m) -> the key on the top platform. Then back the careful way (ladders, beam, gallery), or
##   dive from 10 m (fast, and the loudest thing you can do) and swim for the north ladder -> the
##   north deck -> a ladder up to the north gallery -> the locked door on the north-east gallery ->
##   the exit.
##
## The look: a vast hall under a stepped, tiled vault, high windows glowing warm along both long
## walls, and a dark arched tunnel leading off the north deck into nowhere.
##
## Built from the same pieces as the Shallow Halls; more gets added to it step by step.

const SURFACE := -0.3
const DEEP := -2.7                  # the pool floor: 2.4 m of water
const X0 := -14.0                   # the natatorium
const X1 := 22.0
const Z0 := -44.0
const Z1 := 0.0
const H := 12.0
const GALLERY := 4.0                # the galleries' walking height
const TOWER := Rect2(2.0, -30.0, 3.0, 3.0)   # the diving tower's core (x, z, w, d)
const VAULT_RISE := 6.0             # the roof rises this far above the walls, at the middle
const VAULT_STEP := 1.5             # ... in tiled steps this wide
const TUNNEL_X := Vector2(-9.0, -6.0)   # the dark arched tunnel off the north deck (x from, to)
const TUNNEL_H := 3.0
const TUNNEL_END := -52.0
const FITTINGS := [Vector3(-4, H - 0.3, -12), Vector3(12, H - 0.3, -12), Vector3(-4, H - 0.3, -30), Vector3(12, H - 0.3, -30)]

var level: Node3D
var G: LevelGeometry


func build(lv: Node3D) -> void:
	level = lv
	G = lv.G
	var env: Environment = lv.world_env.environment
	env.ambient_light_energy = 0.06
	_start_room()
	_hall()
	_vault()
	_windows()
	_tunnel()
	_galleries()
	_tower()
	_exit()
	_items()
	var spawns: Array[Vector3] = [Vector3(2.5, 0.05, 4.5), Vector3(5.5, 0.05, 4.5), Vector3(2.5, 0.05, 6.5), Vector3(5.5, 0.05, 6.5)]
	lv.spawn_points = spawns
	lv.creature_spawn = Vector3(4.0, DEEP, -16.0)
	lv.zones = [
		{"name": "start", "rect": Rect2(0, 0, 8, 8), "amb": "halls", "checkpoint": Vector3(4, 0.05, 5)},
		{"name": "south_deck", "rect": Rect2(X0, -4, X1 - X0, 4), "amb": "halls", "checkpoint": Vector3(4, 0.05, -2)},
		{"name": "hall", "rect": Rect2(X0, Z0, X1 - X0, Z1 - Z0 - 4), "amb": "halls"},
		{"name": "exit", "rect": Rect2(22, -43, 6, 6), "amb": "halls", "exit": true},
	]


# --- Rooms ---------------------------------------------------------------------------------------

func _start_room() -> void:
	G.floor_slab(0, 8, 0, 8)
	G.walls(0, 8, 0, 8, 0.0, 3.2, {"n": [[3.0, 5.0, 2.4]]})
	G.ceiling(0, 8, 0, 8, 3.2)
	G.light(Vector3(4, 3.0, 4), 1.2, 9.0)
	G.plaque("THE HIGH DIVE\n\nThe water here is deep: you can't wade, only swim, and it hears every stroke. Falling in from up high is the loudest thing you can do.\n\nThe key is at the top of the diving tower. The way out is the locked door on the north-east gallery.\n\nIf you hear it coming, freeze.", Vector3(4, 1.7, 7.95), 180, 0.0021)


## The natatorium: a deck at each end, the deep pool between them filling the hall wall to wall.
func _hall() -> void:
	G.floor_slab(X0, X1, -4, Z1)                 # the south deck (you come in here)
	G.floor_slab(X0, X1, Z0, -38)                # the north deck
	G.pool(X0, X1, -38, -4, DEEP, SURFACE)
	# Walls in two bands: the ground floor (the start room's door) and the galleries (the exit door).
	G.walls(X0, X1, Z0, Z1, 0.0, GALLERY, {"s": [[3.0, 5.0, 2.4]], "n": [[TUNNEL_X.x, TUNNEL_X.y, TUNNEL_H]]})
	G.walls(X0, X1, Z0, Z1, GALLERY, H, {"e": [[-40.64, -39.36, 2.15]]})
	# Out of the water: a ladder at each end of the pool, and one up the tower from the water.
	G.ladder(Vector3(-6, DEEP, -4), Vector3(0, 0, -1), 0.0)
	G.ladder(Vector3(12, DEEP, -4), Vector3(0, 0, -1), 0.0)
	G.ladder(Vector3(-2, DEEP, -38), Vector3(0, 0, 1), 0.0)
	G.ladder(Vector3(14, DEEP, -38), Vector3(0, 0, 1), 0.0)
	# High, cold light: a few big fittings under the roof, a lamp on each deck.
	for p in FITTINGS:
		G.fitting(p, Color(0.85, 0.95, 1.0))
	G.light(Vector3(4, H - 0.6, -12), 1.6, 18.0, Color(0.85, 0.95, 1.0))
	G.light(Vector3(4, H - 0.6, -30), 1.6, 18.0, Color(0.85, 0.95, 1.0))
	G.wall_lamp(Vector3(4, 2.6, Z1), Vector3.FORWARD, 1.0, 8.0)
	G.wall_lamp(Vector3(4, 2.6, Z0), Vector3.BACK, 1.0, 8.0)
	G.wet_sign(Vector3(1.5, 0, -1.2), 20)
	G.plaque("DEEP WATER\nNO DIVING\nEXCEPT FROM THE TOWER", Vector3(9, 2.2, -0.03), 180, 0.004)


## The underside of the roof above x: a shallow arc from the tops of the long walls to the middle.
func _vault_y(x: float) -> float:
	var a := (X1 - X0) * 0.5
	var r := VAULT_RISE
	var big_r := (a * a + r * r) / (2.0 * r)
	var u := x - (X0 + X1) * 0.5
	return H + sqrt(maxf(big_r * big_r - u * u, 0.0)) - (big_r - r)


## The roof: a tiled vault in steps, springing from the tops of the long walls, with the end walls
## built up under it. One mesh and no collision (nobody gets up there).
func _vault() -> void:
	var t := LevelGeometry.WALL_T
	var n := int(ceil((X1 - X0) * 0.5 / VAULT_STEP))
	var ys: Array[float] = []
	for i in n:
		ys.append(_vault_y(X0 + (i + 0.5) * VAULT_STEP))
	var mid := (X0 + X1) * 0.5
	var boxes := []
	for i in n:
		var top: float = (ys[i + 1] if i + 1 < n else ys[i]) + 0.4
		var a := X0 + i * VAULT_STEP
		var b := minf(a + VAULT_STEP, mid)
		boxes.append([a, b, ys[i], top, Z0 - t, Z1 + t])                          # the west half
		boxes.append([X0 + X1 - b, X0 + X1 - a, ys[i], top, Z0 - t, Z1 + t])      # the east half
		var lo: float = H if i == 0 else ys[i - 1]
		for z in [[Z0 - t, Z0], [Z1, Z1 + t]]:                                      # the end walls
			boxes.append([a, X0 + X1 - a, lo, ys[i] + 0.05, z[0], z[1]])
	# where it springs from the long walls
	boxes.append([X0 - t, X0, H, ys[0] + 0.4, Z0 - t, Z1 + t])
	boxes.append([X1, X1 + t, H, ys[0] + 0.4, Z0 - t, Z1 + t])
	_merged("Vault", boxes, G.mat_white)
	# the hanging lights' rods, up to the roof
	var rods := []
	for p in FITTINGS:
		rods.append([p.x - 0.02, p.x + 0.02, p.y + 0.13, _vault_y(p.x) + 0.1, p.z - 0.02, p.z + 0.02])
	_merged("Rods", rods, G.mat_metal)


## High windows along both long walls, deep-set and glowing warm: a bright somewhere-else outside.
func _windows() -> void:
	var frames := []
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pane := QuadMesh.new()
	pane.size = Vector2(1.6, 2.0)
	for z in range(-38, -3, 4):
		for x in [X0, X1]:
			var into := 1.0 if x == X0 else -1.0       # into the hall: +x from the west wall
			st.append_from(pane, 0, Transform3D(Basis(Vector3.UP, PI * 0.5 * into), Vector3(x + into * 0.02, 9.5, z)))
			var xa := minf(x, x + into * 0.3)
			var xb := maxf(x, x + into * 0.3)
			frames.append([xa, xb, 8.3, 8.5, z - 1.0, z + 1.0])      # sill
			frames.append([xa, xb, 10.5, 10.7, z - 1.0, z + 1.0])    # head
			frames.append([xa, xb, 8.5, 10.5, z - 1.0, z - 0.8])     # sides
			frames.append([xa, xb, 8.5, 10.5, z + 0.8, z + 1.0])
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 0.84, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.95, 0.85), Color(1.0, 0.82, 0.58), Color(0.98, 0.78, 0.55), Color(0.4, 0.85, 0.8), Color(0.9, 0.82, 0.66)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	var glow := MeshInstance3D.new()
	glow.name = "WindowGlow"
	glow.mesh = st.commit()
	glow.material_override = m
	G.geo.add_child(glow)
	_merged("WindowFrames", frames, G.mat_white)
	G.light(Vector3(X0 + 2.5, 9.5, -22), 0.7, 16.0, Color(1.0, 0.8, 0.58), false)
	G.light(Vector3(X1 - 2.5, 9.5, -22), 0.7, 16.0, Color(1.0, 0.8, 0.58), false)


## A dark arched tunnel off the north deck, under the gallery: it goes back into the dark, and
## nowhere you need to go.
func _tunnel() -> void:
	var a := TUNNEL_X.x
	var b := TUNNEL_X.y
	var t := LevelGeometry.WALL_T
	var outer := Z0 - t
	G.floor_slab(a, b, TUNNEL_END, outer, 0.0)
	G.block(a - t, a, -0.02, TUNNEL_H, TUNNEL_END, outer, G.mat_white)
	G.block(b, b + t, -0.02, TUNNEL_H, TUNNEL_END, outer, G.mat_white)
	G.block(a - t, b + t, TUNNEL_H, TUNNEL_H + 0.2, TUNNEL_END, Z0, G.mat_white)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.01, 0.012, 0.014)
	black.roughness = 1.0
	G.block(a - t, b + t, -0.02, TUNNEL_H, TUNNEL_END - t, TUNNEL_END, black)
	# the arch: stepped corners all along it, through the hall's wall too
	var arch := []
	for step in [[0.45, 2.2], [0.85, 2.6], [1.15, 2.85]]:
		arch.append([a, a + step[0], step[1], TUNNEL_H, TUNNEL_END, Z0])
		arch.append([b - step[0], b, step[1], TUNNEL_H, TUNNEL_END, Z0])
	_merged("TunnelArch", arch, G.mat_white)


## Boxes ([x0, x1, y0, y1, z0, z1]) as one mesh, so a whole feature costs one draw call. No collision.
func _merged(node_name: String, boxes: Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in boxes:
		var bm := BoxMesh.new()
		bm.size = Vector3(absf(b[1] - b[0]), absf(b[3] - b[2]), absf(b[5] - b[4]))
		st.append_from(bm, 0, Transform3D(Basis(), Vector3((b[0] + b[1]) * 0.5, (b[2] + b[3]) * 0.5, (b[4] + b[5]) * 0.5)))
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = mat
	G.geo.add_child(mi)
	return mi


## The galleries, 4 m up: along the west wall (gaps to jump, one with only a plank across) and
## along the north wall to the locked door on the east side.
func _galleries() -> void:
	var y0 := GALLERY - 0.3
	var y1 := GALLERY
	# Up from the south deck: a ladder against the gallery's edge (you climb onto what's behind it).
	G.ladder(Vector3(X0 + 2.0, 0.0, -6.0), Vector3(1, 0, 0), GALLERY)
	# The west gallery, z -40..-4, in pieces.
	for seg in [[-4.0, -12.8], [-14.0, -22.4], [-24.0, -42.0]]:
		_slab(X0, X0 + 2.0, seg[1], seg[0], y0, y1)
	# The second gap only has a plank across it, along the wall.
	G.block(X0 + 0.15, X0 + 0.45, y1 - 0.08, y1, -24.0, -22.4, G.mat_metal)
	# The north gallery, from the west gallery to the door, with a gap to jump; a ladder up to it
	# from the north deck (for whoever came the wet way).
	_slab(X0, 6.0, Z0, -42.0, y0, y1)
	_slab(7.2, X1, Z0, -42.0, y0, y1)
	G.ladder(Vector3(12.0, 0.0, -42.0), Vector3(0, 0, 1), GALLERY)
	# The east stub up to the door.
	_slab(X1 - 2.0, X1, -42.0, -37.0, y0, y1)
	level._make_staff_door(Vector3(X1 - 16.0, GALLERY, -40.0 + 5.0))
	G.wall_lamp(Vector3(X1, GALLERY + 2.4, -38.0), Vector3.LEFT, 1.0, 7.0)
	G.wall_lamp(Vector3(X0, GALLERY + 2.4, -8.0), Vector3.RIGHT, 0.9, 7.0)
	G.wall_lamp(Vector3(X0, GALLERY + 2.4, -30.0), Vector3.RIGHT, 0.9, 7.0)


## The diving tower in the middle of the pool: a core from the pool floor to 10 m, a platform on
## its west side at 4 m (where the beam from the west gallery lands), one on its south side at
## 7.5 m, the top at 10 m with a diving board. Ladders between them, and one up from the water.
func _tower() -> void:
	var t := TOWER
	var tx0 := t.position.x
	var tx1 := t.end.x
	var tz0 := t.position.y
	var tz1 := t.end.y
	G.pillar(tx0, tx1, tz0, tz1, DEEP, 10.0)
	# The beam: 40 cm wide, 13 m long, nothing to hold on to.
	G.block(X0 + 2.0, tx0 - 3.0, GALLERY - 0.25, GALLERY, -28.7, -28.3, G.mat_metal)
	G.grab_rim(Vector3(X0 + 2.0, GALLERY, -28.7), Vector3(tx0 - 3.0, GALLERY, -28.7))
	G.grab_rim(Vector3(X0 + 2.0, GALLERY, -28.3), Vector3(tx0 - 3.0, GALLERY, -28.3))
	# 4 m: west of the core. A ladder from its south edge up to the 7.5 m platform behind it.
	_slab(tx0 - 3.0, tx0, tz0, tz1, GALLERY - 0.3, GALLERY)
	G.ladder(Vector3(tx0 - 0.75, GALLERY, tz1), Vector3(0, 0, -1), 7.5)
	# 7.5 m: south of the core (reaching back over the 4 m one); a ladder up the core to the top.
	_slab(tx0 - 1.5, tx1, tz1, tz1 + 1.6, 7.2, 7.5)
	G.ladder(Vector3(tx1 - 0.8, 7.5, tz1), Vector3(0, 0, 1), 10.0)
	# 10 m: the top, and the board over the water.
	G.block(tx1, tx1 + 2.2, 9.9, 10.0, -28.8, -28.2, G.mat_blue)
	G.grab_rim(Vector3(tx1, 10.0, -28.8), Vector3(tx1 + 2.2, 10.0, -28.8))
	G.grab_rim(Vector3(tx1, 10.0, -28.2), Vector3(tx1 + 2.2, 10.0, -28.2))
	# From the water up the east face to the 4 m platform? No: up to a small landing at 1 m, so a
	# swimmer can get out of the water there, but not up the tower.
	_slab(tx1, tx1 + 1.2, tz0 + 0.8, tz1 - 0.8, 0.7, 1.0)
	G.ladder(Vector3(tx1 + 1.2, DEEP, tz0 + 1.5), Vector3(1, 0, 0), 1.0)
	G.light(Vector3(3.5, 11.3, -28.5), 0.8, 6.0, Color(0.9, 0.95, 1.0), false)


## Through the locked door: a dry room at gallery height. Everyone inside ends the level.
func _exit() -> void:
	G.floor_slab(22, 28, -43, -37, GALLERY)
	G.walls(22, 28, -43, -37, GALLERY, GALLERY + 3.2, {"w": [[-40.64, -39.36, 2.15]]})
	G.ceiling(22, 28, -43, -37, GALLERY + 3.2)
	G.wall_lamp(Vector3(25, GALLERY + 2.4, -43), Vector3.BACK, 1.4, 8.0, Color(0.85, 1.0, 0.85))
	var doors: Node3D = preload("res://assets/props/exit_doors.glb").instantiate()
	doors.position = Vector3(27.92, GALLERY, -40.0)
	level.get_node("Props").add_child(doors)
	G.plaque("You made it. Wait here for the others.", Vector3(25, GALLERY + 1.8, -37.03), 180, 0.003)


func _items() -> void:
	level._spawn_item("key", "Key", Vector3(3.5, 10.08, -28.5))
	level._spawn_item("flashlight", "Flashlight", Vector3(3.2, 0.06, 1.6))
	level._spawn_item("lidar", "Lidar", Vector3(5.0, 0.06, 1.6))
	level._spawn_item("throwable", "Bottle1", Vector3(-2.0, 0.1, -1.5))
	level._spawn_item("throwable", "Bottle2", Vector3(X0 + 1.0, GALLERY + 0.1, -8.0))
	level._spawn_item("throwable", "Bottle3", Vector3(TOWER.position.x - 1.5, GALLERY + 0.1, -28.5))
	level._spawn_item("throwable", "Bottle4", Vector3(0.0, 0.1, -40.5))


## A walkway slab with grab rims along its edges (VR hands can catch it if a jump falls short).
func _slab(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float) -> void:
	G.block(x0, x1, y0, y1, z0, z1, G.mat_white)
	G.grab_rim(Vector3(x0, y1, z0), Vector3(x1, y1, z0))
	G.grab_rim(Vector3(x0, y1, z1), Vector3(x1, y1, z1))
	G.grab_rim(Vector3(x0, y1, z0), Vector3(x0, y1, z1))
	G.grab_rim(Vector3(x1, y1, z0), Vector3(x1, y1, z1))
