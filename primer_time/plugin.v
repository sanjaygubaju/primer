module primer_time

import time
import primer_ecs { App }

pub struct TimePlugin {}

pub fn new_time_plugin() TimePlugin {
	return TimePlugin{}
}

fn (_ &TimePlugin) name() string {
	return 'TimePlugin'
}

fn (_ &TimePlugin) build(mut app App) ! {
	// Insert initial resource
	app.resource_manager.insert(Time{
		delta_seconds:   0
		elapsed_seconds: 0
		frame_number:    0
		last_update:     time.now()
	})

	// Add timer system
	app.system_manager.add(TimeUpdateSystem{}, .pre_update)!
}
