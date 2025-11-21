module primer_time

import time
import primer_ecs { App }

pub struct Time {
pub mut:
	delta_seconds   f64       // Time between frames (in seconds)
	elapsed_seconds f64       // App/game time since start, increments each frame
	frame_number    u64       // Increments each frame
	last_update     time.Time // Time at the end of last frame
}

pub struct TimeUpdateSystem {}

fn (ts &TimeUpdateSystem) name() string {
	return 'TimeUpdateSystem'
}

fn (ts &TimeUpdateSystem) priority() int {
	return -9999
} // Runs first

fn (ts &TimeUpdateSystem) update(mut app App, _ f64) ! {
	mut time_res := app.resource_manager.get[Time]() or {
		now := time.now()
		app.resource_manager.insert(Time{
			delta_seconds:   0
			elapsed_seconds: 0
			frame_number:    0
			last_update:     now
		})
		return
	}
	now := time.now()
	time_res.delta_seconds = (now - time_res.last_update).seconds()
	time_res.elapsed_seconds += time_res.delta_seconds
	time_res.last_update = now
	time_res.frame_number += 1
}
