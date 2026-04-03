## touch_controls.gd
## On-screen touch buttons mapped to the existing input actions.
## Automatically hidden on desktop — set force_show = true in the Inspector
## to preview the layout while developing on PC.
extends CanvasLayer

@export var force_show: bool = false

const _BTN_MOVE := 68    # diameter in virtual px — movement buttons
const _BTN_ACT  := 76    # diameter — action buttons (slightly larger target)

const _ALPHA_IDLE    := 0.42
const _ALPHA_PRESSED := 0.72

func _ready() -> void:
	follow_viewport_enabled = true
	if not OS.has_feature("mobile") and not force_show:
		queue_free()
		return
	_build_controls()

func _build_controls() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ── Left thumb — movement ──────────────────────────────────────────────────
	# passby_press = true so a held finger can slide between left/right
	_add_btn(root, "move_left",  Vector2( 58, 618), _BTN_MOVE, Color(0.92, 0.87, 0.72), "◄", true)
	_add_btn(root, "move_right", Vector2(158, 618), _BTN_MOVE, Color(0.92, 0.87, 0.72), "►", true)
	_add_btn(root, "move_down",  Vector2(108, 688), _BTN_MOVE, Color(0.92, 0.87, 0.72), "▼", true)

	# ── Right thumb — actions ──────────────────────────────────────────────────
	_add_btn(root, "jump",  Vector2(1222, 592), _BTN_ACT, Color(0.40, 0.90, 0.50), "▲", false)
	_add_btn(root, "dash",  Vector2(1138, 666), _BTN_ACT, Color(0.95, 0.55, 0.22), "B", false)
	_add_btn(root, "stun",  Vector2(1222, 666), _BTN_ACT, Color(0.76, 0.93, 1.00), "E", false)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_btn(parent: Control, action: String, center: Vector2,
		size: int, color: Color, symbol: String, passby: bool) -> void:
	var btn                 := TouchScreenButton.new()
	btn.texture_normal       = _circle_tex(size, Color(color.r, color.g, color.b, _ALPHA_IDLE))
	btn.texture_pressed      = _circle_tex(size, Color(color.r, color.g, color.b, _ALPHA_PRESSED))
	btn.action               = action
	btn.passby_press         = passby
	btn.position             = center - Vector2(size * 0.5, size * 0.5)
	parent.add_child(btn)

	# Symbol label centered on the button
	var lbl                         := Label.new()
	lbl.text                         = symbol
	lbl.size                         = Vector2(size, size)
	lbl.position                     = btn.position
	lbl.horizontal_alignment         = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment           = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter                 = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04, 0.88))
	parent.add_child(lbl)

## Generates a soft-edged filled circle as an ImageTexture.
func _circle_tex(size: int, color: Color) -> ImageTexture:
	var img    := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var r      := size * 0.5 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center)
			if d <= r:
				# Soft edge: fade the last 3px
				var a := color.a * clampf(1.0 - (d - (r - 3.0)) / 3.0, 0.0, 1.0)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)
