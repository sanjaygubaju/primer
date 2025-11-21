module primer_camera

import math
import math.vec { Vec2 }

pub enum AspectMode {
	ignore      // Stretch to fill (distort aspect ratio)
	keep        // Letterbox/pillarbox (maintain aspect ratio)
	keep_width  // Fixed width, expand height to show more
	keep_height // Fixed height, expand width to show more
	expand      // Fill screen, show more content (no black bars)
}

pub struct ViewportConfig {
pub mut:
	aspect_mode AspectMode = .keep
	design_size Vec2[int] // Base/design resolution
}

pub struct Viewport {
pub mut:
	size   Vec2[int] // Current window size
	offset Vec2[int] // Letterbox/pillarbox offset for centering
	scale  f64 = 1.0 // Scale factor from design to window
	config ViewportConfig
}

// Constructors
pub fn new_viewport(width int, height int) Viewport {
	return new_viewport_with_config(width, height, ViewportConfig{
		design_size: Vec2[int]{
			x: width
			y: height
		}
		aspect_mode: .keep
	})
}

pub fn new_viewport_with_config(width int, height int, config ViewportConfig) Viewport {
	mut vp := Viewport{
		size:   Vec2[int]{
			x: width
			y: height
		}
		offset: Vec2[int]{
			x: 0
			y: 0
		}
		scale:  1.0
		config: config
	}
	vp.apply_scaling()
	return vp
}

// Apply scaling based on aspect mode
pub fn (mut vp Viewport) apply_scaling() {
	design_w := f64(vp.config.design_size.x)
	design_h := f64(vp.config.design_size.y)
	window_w := f64(vp.size.x)
	window_h := f64(vp.size.y)

	match vp.config.aspect_mode {
		.ignore {
			// Stretch to fill - scales may differ (distortion)
			vp.scale = 1.0
			vp.offset.x = 0
			vp.offset.y = 0
		}
		.keep {
			// Maintain aspect ratio with letterboxing
			vp.scale = math.min(window_w / design_w, window_h / design_h)

			scaled_w := design_w * vp.scale
			scaled_h := design_h * vp.scale

			vp.offset.x = int((window_w - scaled_w) / 2.0)
			vp.offset.y = int((window_h - scaled_h) / 2.0)
		}
		.keep_width {
			// Fixed width, height expands (camera zoom adjusts to show more)
			vp.scale = window_w / design_w
			vp.offset.x = 0
			vp.offset.y = 0
		}
		.keep_height {
			// Fixed height, width expands (camera zoom adjusts to show more)
			vp.scale = window_h / design_h
			vp.offset.x = 0
			vp.offset.y = 0
		}
		.expand {
			// Fill screen, show more content
			vp.scale = math.min(window_w / design_w, window_h / design_h)
			vp.offset.x = 0
			vp.offset.y = 0
		}
	}
}

// Resize viewport (call this on window resize)
pub fn (mut vp Viewport) resize(width int, height int) {
	vp.size.x = width
	vp.size.y = height
	vp.apply_scaling()
}

// Transform world position to screen pixels
pub fn (vp &Viewport) world_to_screen(world_position Vec2[f64], camera &Camera) Vec2[f64] {
	// Camera converts world → view (handles zoom, rotation, position)
	view_position := camera.world_to_view(world_position)

	// Center view in design space
	design_center := Vec2[f64]{
		x: f64(vp.config.design_size.x) / 2.0
		y: f64(vp.config.design_size.y) / 2.0
	}

	// Apply viewport scaling and offset
	return Vec2{
		x: (view_position.x + design_center.x) * vp.scale + f64(vp.offset.x)
		y: (view_position.y + design_center.y) * vp.scale + f64(vp.offset.y)
	}
}

// Transform screen pixels to world position
pub fn (vp &Viewport) screen_to_world(screen_position Vec2[f64], camera &Camera) Vec2[f64] {
	// Remove viewport offset and scale
	local := Vec2[f64]{
		x: (screen_position.x - f64(vp.offset.x)) / vp.scale
		y: (screen_position.y - f64(vp.offset.y)) / vp.scale
	}

	// Center in design space
	design_center := Vec2[f64]{
		x: f64(vp.config.design_size.x) / 2.0
		y: f64(vp.config.design_size.y) / 2.0
	}

	view := Vec2[f64]{
		x: local.x - design_center.x
		y: local.y - design_center.y
	}

	// Camera converts view → world
	return camera.view_to_world(view)
}

// Check if screen position is inside viewport
pub fn (vp &Viewport) contains(screen_position Vec2[f64]) bool {
	return screen_position.x >= 0 && screen_position.x < vp.size.x && screen_position.y >= 0
		&& screen_position.y < vp.size.y
}

// Check if screen position is in rendered game area (not in letterbox)
pub fn (vp &Viewport) contains_in_game_area(screen_position Vec2[f64]) bool {
	scaled_w := f64(vp.config.design_size.x) * vp.scale
	scaled_h := f64(vp.config.design_size.y) * vp.scale

	return screen_position.x >= vp.offset.x && screen_position.x < vp.offset.x + int(scaled_w)
		&& screen_position.y >= vp.offset.y && screen_position.y < vp.offset.y + int(scaled_h)
}

// Get world-space bounds of visible area
pub fn (vp &Viewport) get_visible_bounds(camera &Camera) (Vec2[f64], Vec2[f64]) {
	top_left := vp.screen_to_world(Vec2[f64]{
		x: f64(vp.offset.x)
		y: f64(vp.offset.y)
	}, camera)

	bottom_right := vp.screen_to_world(Vec2[f64]{
		x: f64(vp.offset.x + vp.size.x)
		y: f64(vp.offset.y + vp.size.y)
	}, camera)

	return top_left, bottom_right
}

// Check if world position is visible
pub fn (vp &Viewport) is_visible(world_position Vec2[f64], camera &Camera, margin f64) bool {
	screen_position := vp.world_to_screen(world_position, camera)
	return screen_position.x >= vp.offset.x - margin
		&& screen_position.x <= vp.offset.x + vp.size.x + margin
		&& screen_position.y >= vp.offset.y - margin
		&& screen_position.y <= vp.offset.y + vp.size.y + margin
}
