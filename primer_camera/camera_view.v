module primer_camera

import math.vec { Vec2 }

// CameraView combines a camera and viewport
pub struct CameraView {
pub mut:
	camera   Camera
	viewport Viewport
}

// Basic constructor (uses .keep aspect mode)
pub fn new_camera_view(width int, height int, projection_kind ProjectionKind) CameraView {
	return CameraView{
		camera:   new_camera(projection_kind)
		viewport: new_viewport(width, height)
	}
}

// Constructor with viewport config (aspect mode support)
pub fn new_camera_view_with_config(width int, height int, projection_kind ProjectionKind, viewport_config ViewportConfig) CameraView {
	return CameraView{
		camera:   new_camera(projection_kind)
		viewport: new_viewport_with_config(width, height, viewport_config)
	}
}

// ========================================
// Coordinate Transformations
// ========================================

pub fn (cv &CameraView) world_to_screen(world_position Vec2[f64]) Vec2[f64] {
	return cv.viewport.world_to_screen(world_position, &cv.camera)
}

pub fn (cv &CameraView) screen_to_world(screen_position Vec2[f64]) Vec2[f64] {
	return cv.viewport.screen_to_world(screen_position, &cv.camera)
}

pub fn (cv &CameraView) is_visible(world_position Vec2[f64], margin f64) bool {
	return cv.viewport.is_visible(world_position, &cv.camera, margin)
}

pub fn (cv &CameraView) get_visible_bounds() (Vec2[f64], Vec2[f64]) {
	return cv.viewport.get_visible_bounds(&cv.camera)
}

// ========================================
// Viewport Controls
// ========================================

pub fn (mut cv CameraView) resize(width int, height int) {
	cv.viewport.resize(width, height)

	// Sync camera zoom with viewport scale for certain modes
	match cv.viewport.config.aspect_mode {
		.expand, .keep_width, .keep_height {
			cv.camera.zoom = cv.viewport.scale
		}
		.keep, .ignore {}
	}
}

pub fn (cv &CameraView) contains_in_game_area(screen_pos Vec2[f64]) bool {
	return cv.viewport.contains_in_game_area(screen_pos)
}

// ========================================
// Camera Controls (Convenience Methods)
// ========================================

pub fn (mut cv CameraView) update(dt f64) {
	cv.camera.update(dt)
}

pub fn (mut cv CameraView) move_to(position Vec2[f64]) {
	cv.camera.move_to(position)
}

pub fn (mut cv CameraView) move_by(offset Vec2[f64]) {
	cv.camera.move_by(offset)
}

pub fn (mut cv CameraView) set_zoom(zoom f64) {
	cv.camera.set_zoom(zoom)
}

pub fn (mut cv CameraView) zoom_by(factor f64) {
	cv.camera.zoom_by(factor)
}

pub fn (mut cv CameraView) shake(magnitude f64, duration f64) {
	cv.camera.shake(magnitude, duration)
}

pub fn (mut cv CameraView) set_bounds(min Vec2[f64], max Vec2[f64]) {
	cv.camera.set_bounds(min, max)
}

pub fn (mut cv CameraView) clear_bounds() {
	cv.camera.clear_bounds()
}
