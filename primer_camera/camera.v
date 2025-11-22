module primer_camera

import math.vec { Vec2 }
import math
import rand

// ProjectionKind determines projection type
pub enum ProjectionKind {
	orthographic // Standard 2D (top-down, side-view)
	isometric    // Isometric projection (2:1) ratio
}

// Camera represents a 2D camera with various projection modes
pub struct Camera {
pub mut:
	// Position and transformation
	position Vec2[f64] // World position (center of view)
	rotation f64       // Rotation in radians
	zoom     f64 = 1.0 // Zoom level (default = 1.0)

	// Viewport
	projection_kind ProjectionKind

	// Isometric settings
	angle f64 = 30.0 // Isometric angle in degrees
	ratio f64 = 2.0  // Width to height ratio (2:1 for isometric

	// Boundary - restricts camera movement
	bounds_enabled bool
	bounds_min     Vec2[f64]
	bounds_max     Vec2[f64]

	// Smooth following
	follow_smoothing f64 = 10.0 // Higher = faster following
	follow_target    ?Vec2[f64] // Target position to follow

	// Shake effect
	shake_magnitude f64
	shake_duration  f64
	shake_time      f64
	shake_offset    Vec2[f64]
}

pub fn new_camera(projection_kind ProjectionKind) Camera {
	return Camera{
		position:        Vec2[f64]{
			x: 0.0
			y: 0.0
		}
		zoom:            1.0
		projection_kind: projection_kind
	}
}

// update should be called each frame.
pub fn (mut cam Camera) update(dt f64) {
	// Update shake effect
	if cam.shake_time > 0 {
		cam.shake_time -= f64(dt)

		if cam.shake_time <= 0 {
			cam.shake_offset = Vec2[f64]{
				x: 0
				y: 0
			}
		} else {
			// Random shake offset
			angle := f64(rand.f64() * 2.0 * math.pi)
			magnitude := cam.shake_magnitude * (cam.shake_time / cam.shake_duration)
			cam.shake_offset = Vec2[f64]{
				x: f64(math.cos(angle)) * magnitude
				y: f64(math.sin(angle)) * magnitude
			}
		}
	}

	// Smooth following
	if target := cam.follow_target {
		diff := Vec2[f64]{
			x: target.x - cam.position.x
			y: target.y - cam.position.y
		}

		// Exponential smoothing
		factor := 1.0 - f64(math.exp(-cam.follow_smoothing * dt))
		cam.position.x += diff.x * factor
		cam.position.y += diff.y * factor
	}

	// Apply bounds
	if cam.bounds_enabled {
		cam.position.x = f64(math.clamp(cam.position.x, cam.bounds_min.x, cam.bounds_max.x))
		cam.position.y = f64(math.clamp(cam.position.y, cam.bounds_min.y, cam.bounds_max.y))
	}
}

// ========================================
// Coordinate Transformations
// ========================================

// world_to_view converts world coordinates to view space (relative to camera)
pub fn (c &Camera) world_to_view(world_position Vec2[f64]) Vec2[f64] {
	match c.projection_kind {
		.orthographic {
			return c.world_to_view_ortho(world_position)
		}
		.isometric {
			return c.world_to_view_iso(world_position)
		}
	}
}

// view_to_world converts view space back to world coordinates
pub fn (c &Camera) view_to_world(view_position Vec2[f64]) Vec2[f64] {
	match c.projection_kind {
		.orthographic {
			return c.view_to_world_ortho(view_position)
		}
		.isometric {
			return c.view_to_world_iso(view_position)
		}
	}
}

// ========================================
// Orthographic Transformations
// ========================================

fn (c &Camera) world_to_view_ortho(world_position Vec2[f64]) Vec2[f64] {
	// Translate relative to camera
	mut dx := world_position.x - c.position.x
	mut dy := world_position.y - c.position.y

	// Apply rotation if needed
	if c.rotation != 0 {
		cos_r := f64(math.cos(c.rotation))
		sin_r := f64(math.sin(c.rotation))
		rotated_x := dx * cos_r - dy * sin_r
		rotated_y := dx * sin_r + dy * cos_r
		dx = rotated_x
		dy = rotated_y
	}

	// Apply zoom
	dx *= c.zoom
	dy *= c.zoom

	// Apply shake
	return Vec2[f64]{
		x: dx + c.shake_offset.x
		y: dy + c.shake_offset.y
	}
}

fn (c &Camera) view_to_world_ortho(view_position Vec2[f64]) Vec2[f64] {
	// Remove shake
	mut vx := view_position.x - c.shake_offset.x
	mut vy := view_position.y - c.shake_offset.y

	// Remove zoom
	vx /= c.zoom
	vy /= c.zoom

	// Apply inverse rotation
	if c.rotation != 0 {
		cos_r := f64(math.cos(-c.rotation))
		sin_r := f64(math.sin(-c.rotation))
		rotated_x := vx * cos_r - vy * sin_r
		rotated_y := vx * sin_r + vy * cos_r
		vx = rotated_x
		vy = rotated_y
	}

	// Translate to world space
	return Vec2[f64]{
		x: vx + c.position.x
		y: vy + c.position.y
	}
}

// ========================================
// Isometric Transformations
// ========================================

fn (c &Camera) world_to_view_iso(world_position Vec2[f64]) Vec2[f64] {
	// Convert world coordinates to isometric view space
	iso_x := (world_position.x - world_position.y) * c.ratio
	iso_y := (world_position.x + world_position.y)

	// Apply camera position
	dx := iso_x - (c.position.x - c.position.y) * c.ratio
	dy := iso_y - (c.position.x + c.position.y)

	// Apply zoom
	return Vec2[f64]{
		x: dx * c.zoom + c.shake_offset.x
		y: dy * c.zoom + c.shake_offset.y
	}
}

fn (c &Camera) view_to_world_iso(view_position Vec2[f64]) Vec2[f64] {
	// Remove shake
	mut vx := view_position.x - c.shake_offset.x
	mut vy := view_position.y - c.shake_offset.y

	// Remove zoom
	vx /= c.zoom
	vy /= c.zoom

	// Add camera position in iso space
	iso_cam_x := (c.position.x - c.position.y) * c.ratio
	iso_cam_y := (c.position.x + c.position.y)
	vx += iso_cam_x
	vy += iso_cam_y

	// Convert from isometric view space to world coordinates
	world_x := (vx / c.ratio + vy) / 2.0
	world_y := (vy - vx / c.ratio) / 2.0

	return Vec2[f64]{
		x: world_x
		y: world_y
	}
}

// ========================================
// Camera Controls
// ========================================

pub fn (mut c Camera) move_by(offset Vec2[f64]) {
	c.position.x += offset.x
	c.position.y += offset.y
}

pub fn (mut c Camera) move_to(position Vec2[f64]) {
	c.position = position
}

pub fn (mut c Camera) set_zoom(zoom f64) {
	c.zoom = f64(math.clamp(zoom, 0.1, 10.0))
}

pub fn (mut c Camera) zoom_by(factor f64) {
	c.set_zoom(c.zoom * factor)
}

pub fn (mut c Camera) set_bounds(min Vec2[f64], max Vec2[f64]) {
	c.bounds_enabled = true
	c.bounds_min = min
	c.bounds_max = max
}

pub fn (mut c Camera) clear_bounds() {
	c.bounds_enabled = false
}

pub fn (mut cam Camera) shake(magnitude f64, duration f64) {
	cam.shake_magnitude = magnitude
	cam.shake_duration = duration
	cam.shake_time = duration
}
