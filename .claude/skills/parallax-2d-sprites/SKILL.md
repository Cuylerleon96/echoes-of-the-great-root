---
name: parallax-2d-sprites
description: 3D parallax depth effect using 2D sprites in Godot 4 — ParallaxBackground/ParallaxLayer setup, sprite billboard modes, depth sorting, and layered art pipeline for metroidvania environments.
---

# 3D Parallax with 2D Sprites in Godot 4

## Concept
"2.5D" or "3D parallax 2D sprite" means: gameplay is strictly 2D (physics, collision, movement) but the visual presentation uses depth-sorted sprite layers that scroll at different rates to simulate 3D depth — identical to Hollow Knight, Dead Cells, and Ori.

## Two Approaches

### Approach A — ParallaxBackground (simple, built-in)
Best for: simple scrolling backgrounds with 2–5 layers.

```
CanvasLayer (layer = -1)
  └─ ParallaxBackground
       ├─ ParallaxLayer (motion_scale = Vector2(0.1, 0.05))  ← far mountains
       │    └─ TextureRect or Sprite2D (tiling)
       ├─ ParallaxLayer (motion_scale = Vector2(0.3, 0.1))   ← midground
       │    └─ Sprite2D
       ├─ ParallaxLayer (motion_scale = Vector2(0.6, 0.3))   ← near background
       │    └─ Sprite2D
       └─ ParallaxLayer (motion_scale = Vector2(0.9, 0.5))   ← foreground props
            └─ Sprite2D
```

`motion_scale` of `(1.0, 1.0)` = moves 1:1 with camera (gameplay layer).
`(0.0, 0.0)` = fixed (sky).

```gdscript
# Smooth camera follow with parallax
# CameraController.gd (attach to Camera2D)
extends Camera2D

@export var follow_target: Node2D
@export var smoothing: float = 8.0

func _process(delta: float) -> void:
    if follow_target:
        global_position = global_position.lerp(follow_target.global_position, smoothing * delta)
```

### Approach B — WorldEnvironment + SubViewport (full 3D depth)
Best for: dramatic depth, fog, dynamic lighting across layers.

```
SubViewport (size matches game resolution, transparent_bg = true)
  └─ Node3D
       ├─ Camera3D (orthographic, projection = ORTHOGONAL)
       ├─ SpriteLayer (z = -800)  ← far bg (MeshInstance3D with quad mesh + sprite texture)
       ├─ SpriteLayer (z = -400)  ← mid bg
       ├─ SpriteLayer (z = -100)  ← near bg
       └─ SpriteLayer (z = 0)     ← gameplay plane
SubViewportContainer (stretch = true)
```

For this approach each sprite is a `MeshInstance3D` with a `QuadMesh` and `StandardMaterial3D` with:
- `albedo_texture`: your sprite sheet
- `billboard_mode`: BILLBOARD_DISABLED (keep facing camera since it's orthographic)
- `transparency`: TRANSPARENCY_ALPHA_SCISSOR
- `shading_mode`: SHADING_MODE_UNSHADED (no lighting on 2D sprites unless desired)

## Recommended Layer Stack for Metroidvania

```
Z-Index  Layer                     Parallax Scale  CanvasLayer
──────────────────────────────────────────────────────────────
-10      Sky / void                0.0             -10
-9       Distant mountains/clouds  0.05–0.1        -9
-8       Far background (caves)    0.15–0.25       -8
-7       Mid background (pillars)  0.35–0.45       -7
-6       Near background (fog)     0.55–0.65       -6
-5       Background props          0.75–0.85       -5
 0       GAMEPLAY (collision)      1.0              0  ← player, enemies, tiles
+1       Foreground props          1.0–1.1         +1
+2       Near foreground           1.1–1.2         +2
+3       UI / HUD                  (CanvasLayer)   +10
```

## TileMapLayer for Terrain

```gdscript
# In Godot 4.3+ use TileMapLayer (replaces TileMap)
# One TileMapLayer per visual depth level
# Only the GAMEPLAY TileMapLayer needs collision shapes
```

## Sprite Sheet / Atlas Setup

```gdscript
# Animated sprite for characters
var sprite = AnimatedSprite2D.new()
sprite.sprite_frames = preload("res://characters/player/player_frames.tres")
sprite.scale = Vector2(2.0, 2.0)  # pixel art upscale

# In Project Settings:
# Rendering > Textures > Default Texture Filter = Nearest (for pixel art)
# Rendering > Textures > Default Texture Repeat = Enabled (for tiling BGs)
```

## Depth-Based Visual Effects (GDShader)

```glsl
// background_depth.gdshader — add atmospheric fog/tint per layer
shader_type canvas_item;
uniform vec4 fog_color : source_color = vec4(0.05, 0.05, 0.15, 1.0);
uniform float fog_amount : hint_range(0.0, 1.0) = 0.3;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = mix(tex, fog_color, fog_amount * tex.a);
}
```

## Camera Bounds / Room Transitions

```gdscript
# CameraRoom.gd — attach to Area2D marking room boundaries
extends Area2D

@export var camera: Camera2D

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        var rect = $CollisionShape2D.shape.get_rect()
        camera.limit_left   = int(global_position.x + rect.position.x)
        camera.limit_right  = int(global_position.x + rect.end.x)
        camera.limit_top    = int(global_position.y + rect.position.y)
        camera.limit_bottom = int(global_position.y + rect.end.y)
```

## Performance Notes
- Use `CanvasItem > Use Parent Material = false` on background layers — they don't need the gameplay material
- Set background `ParallaxLayer` nodes to `follow_viewport = false` on layers behind gameplay
- For very large backgrounds use `TextureRect` with `expand_mode = EXPAND_IGNORE_SIZE` + `stretch_mode = STRETCH_TILE`
- Keep sprite textures power-of-2 dimensions for GPU efficiency
