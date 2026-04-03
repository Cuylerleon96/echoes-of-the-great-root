## hud.gd
## In-game HUD: 3 health hearts + stun cooldown bar.
## All nodes built in code — swap ColorRects for TextureRects when art is ready.
extends CanvasLayer

const HEART_SIZE  := Vector2(18.0, 18.0)
const HEART_GAP   := 5.0
const MARGIN      := Vector2(14.0, 14.0)

# Bar width = 3 hearts + 2 gaps = 3*18 + 2*5 = 64px
const BAR_SIZE    := Vector2(64.0, 3.0)
const BAR_GAP_Y   := 6.0

const COLOR_HEART_FULL  := Color(0.92, 0.20, 0.22)
const COLOR_HEART_EMPTY := Color(0.22, 0.08, 0.08)
const COLOR_BAR_FILL    := Color(0.78, 0.95, 1.0)    # spirit blue — matches stun light
const COLOR_BAR_BG      := Color(0.10, 0.13, 0.18)

# Must match echo.gd
const STUN_COOLDOWN := 1.5

var _player: Node         = null
var _hearts: Array[ColorRect] = []
var _bar_bg:   ColorRect
var _bar_fill: ColorRect

func _ready() -> void:
	_build_ui()

func _process(_delta: float) -> void:
	if _player == null:
		var group := get_tree().get_nodes_in_group("player")
		if not group.is_empty():
			_player = group[0]
		return
	_update_hearts()
	_update_bar()

# ── Build ─────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Hearts — row across the top-left
	for i in 3:
		var h       := ColorRect.new()
		h.size       = HEART_SIZE
		h.color      = COLOR_HEART_FULL
		h.position   = MARGIN + Vector2(i * (HEART_SIZE.x + HEART_GAP), 0.0)
		root.add_child(h)
		_hearts.append(h)

	# Stun bar background
	_bar_bg          = ColorRect.new()
	_bar_bg.color    = COLOR_BAR_BG
	_bar_bg.size     = BAR_SIZE
	_bar_bg.position = MARGIN + Vector2(0.0, HEART_SIZE.y + BAR_GAP_Y)
	root.add_child(_bar_bg)

	# Stun bar fill (sits on top of bg, shrinks left when on cooldown)
	_bar_fill          = ColorRect.new()
	_bar_fill.color    = COLOR_BAR_FILL
	_bar_fill.size     = BAR_SIZE
	_bar_fill.position = _bar_bg.position
	root.add_child(_bar_fill)

# ── Update ────────────────────────────────────────────────────────────────────

func _update_hearts() -> void:
	var hp: int = _player.current_hp
	for i in _hearts.size():
		_hearts[i].color = COLOR_HEART_FULL if i < hp else COLOR_HEART_EMPTY

func _update_bar() -> void:
	# 0 cooldown remaining → bar full.  Full cooldown → bar empty.
	var ratio := 1.0 - clampf(_player._stun_cooldown / STUN_COOLDOWN, 0.0, 1.0)
	_bar_fill.size.x = BAR_SIZE.x * ratio
