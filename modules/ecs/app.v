module ecs

pub struct App {
mut:
	world World
}

pub fn new_app() &App {
	return &App{
		world: new_world()
	}
}
