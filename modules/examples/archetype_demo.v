import ecs

// Components
struct Position {
mut:
	x f32
	y f32
}

struct Velocity {
mut:
	x f32
	y f32
}

struct Health {
mut:
	current int
	max     int
}

struct Name {
	value string
}

struct Enemy {}

struct Player {}

fn main() {
	println('=== Archetype-Based ECS Demo ===\n')

	mut world := ecs.new_world()

	// Register all component types
	world.register[Position]()
	world.register[Velocity]()
	world.register[Health]()
	world.register[Name]()
	world.register[Enemy]()
	world.register[Player]()

	println('--- Creating Entities ---')

	// Create player entity - FIXED: Use world.comp() method
	player := world.create_with_components([
		world.component(Position{ x: 0.0, y: 0.0 }),
		world.component(Velocity{ x: 0.0, y: 0.0 }),
		world.component(Health{ current: 100, max: 100 }),
		world.component(Name{ value: 'Hero' }),
		world.component(Player{}),
	])

	println('Created player entity: ${player}')

	// Create some enemy entities with create_with_components
	mut enemies := []ecs.EntityHandle{}
	for i in 0 .. 5 {
		enemy := world.create_with_components([
			world.component(Position{ x: f32(i * 10), y: f32(i * 5) }),
			world.component(Velocity{ x: f32(i % 3 - 1), y: f32(i % 2) }),
			world.component(Health{ current: 50, max: 50 }),
			world.component(Name{ value: 'Enemy ${i + 1}' }),
			world.component(Enemy{}),
		])
		enemies << enemy
		println('Created enemy: ${enemy}')
	}

	// Create some static objects (no velocity)
	for i in 0 .. 3 {
		obj := world.create_with_components([
			world.component(Position{ x: f32(i * 20), y: f32(i * 20) }),
			world.component(Name{ value: 'Object ${i + 1}' }),
		])
		println('Created static object: ${obj}')
	}

	println('\nWorld stats:')
	println('  Entities: ${world.entity_count()}')
	println('  Archetypes: ${world.archetype_count()}')

	println('\n--- Running Systems ---')

	// Simulate a few frames
	for frame in 0 .. 3 {
		println('\n[Frame ${frame}]')

		// Movement system - update positions based on velocity
		movement_system(mut world)

		// Display system - show entity info
		display_system(world)
	}

	println('\n--- Testing Component Operations ---')

	// Remove velocity from first enemy
	if enemies.len > 0 {
		first_enemy := enemies[0]
		println('\nRemoving velocity from enemy ${first_enemy}')
		world.remove[Velocity](first_enemy)

		if world.has[Velocity](first_enemy) {
			println('  Still has velocity (unexpected!)')
		} else {
			println('  Velocity removed successfully')
		}
	}

	// Damage player
	println('\nDamaging player...')
	if mut health := world.get[Health](player) {
		health.current -= 25
		println('  Player health: ${health.current}/${health.max}')
	}

	// Kill an enemy
	if enemies.len > 1 {
		target := enemies[1]
		println('\nDestroying enemy ${target}...')
		world.despawn(target)
		println('  Entities remaining: ${world.entity_count()}')
	}

	println('\n--- Final State ---')
	display_system(world)

	println('\n=== Demo Complete ===')
}

// Movement system - updates positions based on velocity
fn movement_system(mut world ecs.World) {
	// In a real query system, you'd iterate over archetypes
	// For now, we'll check all entities manually
	all_entities := world.get_all_entities()

	mut moved := 0
	for entity in all_entities {
		if !world.has[Position](entity) || !world.has[Velocity](entity) {
			continue
		}

		if mut pos := world.get[Position](entity) {
			if vel := world.get[Velocity](entity) {
				pos.x += vel.x
				pos.y += vel.y
				moved++
			}
		}
	}

	println('  Movement: Updated ${moved} entities')
}

// Display system - prints entity information
fn display_system(world ecs.World) {
	all_entities := world.get_all_entities()

	println('  Entity States:')
	for entity in all_entities {
		mut info := '    Entity ${entity}: '

		if name := world.get[Name](entity) {
			info += name.value + ' '
		}

		if pos := world.get[Position](entity) {
			info += 'pos=(${pos.x:.1f}, ${pos.y:.1f}) '
		}

		if vel := world.get[Velocity](entity) {
			info += 'vel=(${vel.x:.1f}, ${vel.y:.1f}) '
		}

		if health := world.get[Health](entity) {
			info += 'hp=${health.current}/${health.max} '
		}

		if world.has[Player](entity) {
			info += '[PLAYER]'
		}

		if world.has[Enemy](entity) {
			info += '[ENEMY]'
		}

		println(info)
	}
}
