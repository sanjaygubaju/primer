module primer_camera

import math.vec { Vec2 }
import primer_ecs { App, IPlugin, IPrioritizer, ISystem }

// ===============================
//    Camera Update System
// ===============================

pub struct CameraUpdateSystem implements ISystem, IPrioritizer {
	use_simple bool
}

pub fn (_ &CameraUpdateSystem) name() string {
	return 'CameraUpdateSystem'
}

pub fn (_ &CameraUpdateSystem) priority() int {
	return 900 // Run early in pre_update
}

pub fn (cus &CameraUpdateSystem) update(mut app App, dt f64) ! {
	if cus.use_simple {
		// Update CameraView
		mut view := app.resource_manager.get[CameraView]() or { return }
		view.update(dt)
		app.resource_manager.insert(view)
	} else {
		// Update Camera only (Viewport is static)
		mut camera := app.resource_manager.get[Camera]() or { return }
		camera.update(dt)
		app.resource_manager.insert(camera)
	}
}

// ================================
//      Camera Plugin for ECS
// ================================

pub struct CameraPlugin implements IPlugin {
pub:
	initial_width   int
	initial_height  int
	projection_kind ProjectionKind
	viewport_config ViewportConfig // Add this
	use_simple      bool = true
}

// Simple constructor (uses .keep aspect mode by default)
pub fn new_camera_plugin(width int, height int, projection_kind ProjectionKind, use_simple bool) CameraPlugin {
	return CameraPlugin{
		initial_width:   width
		initial_height:  height
		projection_kind: projection_kind
		use_simple:      use_simple
		viewport_config: ViewportConfig{
			design_size: Vec2[int]{
				x: width
				y: height
			}
			aspect_mode: .keep
		}
	}
}

// Constructor with custom viewport config
pub fn new_camera_plugin_with_config(width int, height int, projection_kind ProjectionKind, use_simple bool, viewport_config ViewportConfig) CameraPlugin {
	return CameraPlugin{
		initial_width:   width
		initial_height:  height
		projection_kind: projection_kind
		viewport_config: viewport_config
		use_simple:      use_simple
	}
}

fn (_ &CameraPlugin) name() string {
	return 'CameraPlugin'
}

fn (_ &CameraPlugin) dependencies() []string {
	return []
}

fn (c &CameraPlugin) build(mut app App) ! {
	if c.use_simple {
		// Use CameraView with viewport config
		view := new_camera_view_with_config(c.initial_width, c.initial_height, c.projection_kind,
			c.viewport_config)
		app.resource_manager.insert(view)
	} else {
		// Separate Camera and Viewport
		camera := new_camera(c.projection_kind)
		viewport := new_viewport_with_config(c.initial_width, c.initial_height, c.viewport_config)

		app.resource_manager.insert(camera)
		app.resource_manager.insert(viewport)
	}

	// Add camera update system
	app.system_manager.add(CameraUpdateSystem{ use_simple: c.use_simple }, .pre_update)!
}

fn (_ &CameraPlugin) on_enable(mut _ App) ! {}

fn (_ &CameraPlugin) on_disable(mut _ App) ! {}
