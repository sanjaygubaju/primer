import gg
import math
import math.vec { Vec2 }
import rand
import sokol.audio
import primer_ecs { App, EntityHandle, IPlugin, ISystem, QuerySystem }
import primer_input { InputManager }
import primer_camera { CameraView, ViewportConfig }
import primer_time { Time }

// ========================================
// GAME CONSTANTS
// ========================================

// World dimensions
const world_width = 800
const world_height = 600

// Paddle
const paddle_width = 100.0
const paddle_height = 15.0
const paddle_speed = 500.0
const paddle_y_offset = 50.0

// Ball
const ball_diameter = 15.0
const ball_initial_speed_x = 200.0
const ball_initial_speed_y = -250.0
const ball_y_offset = 80.0
const ball_speed_increase = 1.03
const ball_bounce_angle_max = math.pi / 3.0

// Bricks
const brick_cols = 10
const brick_rows = 6
const brick_width = 60.0
const brick_height = 20.0
const brick_spacing_x = 70.0
const brick_spacing_y = 30.0
const brick_offset_x = 60.0
const brick_offset_y = 50.0

// Particles
const particle_count = 8
const particle_size = 4.0
const particle_lifetime = 0.5
const particle_speed_min = 50.0
const particle_speed_max = 150.0

// Stars
const star_count = 150

// Camera shake
const shake_wall_intensity = 3.0
const shake_wall_duration = 0.15
const shake_paddle_intensity = 5.0
const shake_paddle_duration = 0.2
const shake_brick_intensity = 4.0
const shake_brick_duration = 0.15
const shake_lose_intensity = 15.0
const shake_lose_duration = 0.5

// UI
const ui_panel_x = 10
const ui_panel_y = 10
const ui_panel_width = 180
const ui_panel_height = 110

// Lives
const initial_lives = 3
const points_per_brick = 10

// ========================================
// COLOR PALETTE
// ========================================
const bg_dark = gg.color_from_string('#0A0A19')
const bg_medium = gg.color_from_string('#14142D')
const neon_cyan = gg.color_from_string('#00E7EC')
const neon_magenta = gg.color_from_string('#FE04FF')
const neon_yellow = gg.color_from_string('#FDD615')
const neon_orange = gg.color_from_string('#FF8C00')
const neon_red = gg.color_from_string('#FF004D')
const neon_blue = gg.color_from_string('#002DD1')
const neon_green = gg.color_from_string('#16FF00')
const neon_purple = gg.color_from_string('#8E2BE2')

// ========================================
// COMPONENTS
// ========================================

type Position = Vec2[f64]
type Velocity = Vec2[f64]

struct Size {
pub mut:
	w f64
	h f64
}

struct Paddle {
pub mut:
	speed f64
}

struct Ball {
pub mut:
	speed f64
}

struct Brick {
pub mut:
	color           gg.Color
	secondary_color gg.Color
}

struct Particle {
pub mut:
	lifetime     f64
	max_lifetime f64
	color        gg.Color
}

struct Star {
pub mut:
	depth      f64
	brightness f64
}

// ========================================
// RESOURCES
// ========================================

struct GameConfig {
pub mut:
	design_size Vec2[int]
}

struct GameScore {
pub mut:
	points int
	lives  int = initial_lives
}

struct GameState {
pub mut:
	paused       bool = true
	game_over    bool
	won          bool
	bricks_count int
}

// ========================================
// AUDIO MANAGER
// ========================================

enum SoundKind {
	paddle
	brick
	wall
	lose_ball
}

struct SoundManager {
mut:
	sounds      [6][]f32
	initialised bool
}

struct SoundConfig {
	freq     f32
	duration f32
	volume   f32
}

const sound_configs = [
	SoundConfig{
		freq:     1850
		duration: 0.035
		volume:   0.28
	},
	SoundConfig{
		freq:     2400
		duration: 0.025
		volume:   0.32
	},
	SoundConfig{
		freq:     1200
		duration: 0.040
		volume:   0.25
	},
	SoundConfig{
		freq:     650
		duration: 0.055
		volume:   0.22
	},
]

fn (mut sm SoundManager) init() {
	if sm.initialised {
		return
	}

	if !audio.is_valid() {
		audio.setup(buffer_frames: 512)
	}

	sample_rate := f32(audio.sample_rate())
	for i, config in sound_configs {
		frames := int(sample_rate * config.duration)
		for j in 0 .. frames {
			t := f32(j) / sample_rate
			progress := f32(j) / f32(frames)
			envelope := math.powf(1.0 - progress, 2.5)

			freq_mod := if i == 3 {
				config.freq * (1.0 - progress * 0.3)
			} else {
				config.freq
			}
			sm.sounds[i] << config.volume * envelope * math.sinf(t * freq_mod * 2 * math.pi)
		}
	}
	sm.initialised = true
}

fn (mut sm SoundManager) play(kind SoundKind) {
	if sm.initialised {
		sound := sm.sounds[int(kind)]
		audio.push(sound.data, sound.len)
	}
}

fn (mut _ SoundManager) fade_out(ms int) {
	samples := int(audio.sample_rate() * ms / 1000)
	silence := []f64{len: samples, init: 0.0}
	audio.push(silence.data, silence.len)
}

// ========================================
// ENTITY FACTORIES
// ========================================

fn create_paddle(mut app App, config &GameConfig) !EntityHandle {
	return app.world.create_with_components([
		app.world.component[Position](Position{
			x: (f64(config.design_size.x) - paddle_width) / 2.0
			y: f64(config.design_size.y) - paddle_y_offset
		}),
		app.world.component[Size](Size{ w: paddle_width, h: paddle_height }),
		app.world.component[Velocity](Velocity{}),
		app.world.component[Paddle](Paddle{ speed: paddle_speed }),
	])
}

fn create_ball(mut app App, config &GameConfig) !EntityHandle {
	direction := if rand.intn(2) or { 0 } == 0 { 1.0 } else { -1.0 }
	return app.world.create_with_components([
		app.world.component[Position](Position{
			x: f64(config.design_size.x) / 2.0 - ball_diameter / 2.0
			y: f64(config.design_size.y) - ball_y_offset
		}),
		app.world.component[Size](Size{ w: ball_diameter, h: ball_diameter }),
		app.world.component[Velocity](Velocity{
			x: ball_initial_speed_x * direction
			y: ball_initial_speed_y
		}),
		app.world.component[Ball](Ball{ speed: ball_initial_speed_y }),
	])
}

fn create_brick(mut app App, x f64, y f64, color gg.Color, secondary_color gg.Color) !EntityHandle {
	return app.world.create_with_components([
		app.world.component[Position](Position{ x: x, y: y }),
		app.world.component[Size](Size{ w: brick_width, h: brick_height }),
		app.world.component[Brick](Brick{
			color:           color
			secondary_color: secondary_color
		}),
	])
}

fn create_star(mut app App, x f64, y f64) !EntityHandle {
	return app.world.create_with_components([
		app.world.component[Position](Position{ x: x, y: y }),
		app.world.component[Star](Star{
			depth:      rand.f64()
			brightness: rand.f64()
		}),
	])
}

fn create_particle(mut app App, x f64, y f64, color gg.Color) ! {
	angle := rand.f64() * 2 * math.pi
	speed := particle_speed_min + rand.f64() * (particle_speed_max - particle_speed_min)

	app.world.create_with_components([
		app.world.component[Position](Position{ x: x, y: y }),
		app.world.component[Size](Size{ w: particle_size, h: particle_size }),
		app.world.component[Velocity](Velocity{
			x: math.cos(angle) * speed
			y: math.sin(angle) * speed
		}),
		app.world.component[Particle](Particle{
			lifetime:     particle_lifetime
			max_lifetime: particle_lifetime
			color:        color
		}),
	])!
}

// ========================================
// QUERY HELPERS
// ========================================

fn spawn_particles(mut app App, x f64, y f64, color gg.Color) {
	for _ in 0 .. particle_count {
		create_particle(mut app, x, y, color) or { continue }
	}
}

fn reset_ball(mut app App, ball_entity EntityHandle, config &GameConfig) {
	mut pos := app.world.get[Position](ball_entity) or { return }
	mut vel := app.world.get[Velocity](ball_entity) or { return }

	direction := if rand.intn(2) or { 0 } == 0 { 1.0 } else { -1.0 }
	pos.x = f64(config.design_size.x) / 2.0 - ball_diameter / 2.0
	pos.y = f64(config.design_size.y) - ball_y_offset
	vel.x = ball_initial_speed_x * direction
	vel.y = ball_initial_speed_y
}

fn reset_paddle(mut app App, config &GameConfig) {
	paddle_id := app.world.get_type_id[Paddle]()
	pos_id := app.world.get_type_id[Position]()

	for result in app.world.query([paddle_id, pos_id]) {
		mut pos := result.get[Position](app.world) or { continue }
		pos.x = (f64(config.design_size.x) - paddle_width) / 2.0
		break
	}
}

// ========================================
// BREAKOUT PLUGIN
// ========================================

struct BreakoutPlugin implements IPlugin {
pub:
	config GameConfig
}

fn new_breakout_plugin(config GameConfig) BreakoutPlugin {
	return BreakoutPlugin{
		config: config
	}
}

fn (_ &BreakoutPlugin) name() string {
	return 'BreakoutPlugin'
}

fn (_ &BreakoutPlugin) dependencies() []string {
	return ['InputPlugin', 'CameraPlugin', 'TimePlugin']
}

fn (bp &BreakoutPlugin) build(mut app App) ! {
	// Register components
	app.world.register_type[Position]()
	app.world.register_type[Velocity]()
	app.world.register_type[Size]()
	app.world.register_type[Paddle]()
	app.world.register_type[Ball]()
	app.world.register_type[Brick]()
	app.world.register_type[Particle]()
	app.world.register_type[Star]()

	// Initialize resources
	app.resource_manager.insert(bp.config)
	app.resource_manager.insert(GameScore{ lives: initial_lives })
	app.resource_manager.insert(GameState{})
	app.resource_manager.insert(SoundManager{})

	// Add systems
	app.system_manager.add(new_paddle_control_system(app), .update)!
	app.system_manager.add(new_movement_system(app), .update)!
	app.system_manager.add(new_ball_physics_system(app), .update)!
	app.system_manager.add(new_collision_system(app), .post_update)!
	app.system_manager.add(new_particle_system(app), .update)!
	app.system_manager.add(new_render_system(app), .render)!
	app.system_manager.init_all(mut app)!

	// Init GG context
	mut ctx := gg.new_context(
		width:        bp.config.design_size.x
		height:       bp.config.design_size.y
		window_title: 'Neon Breakout ECS'
		bg_color:     bg_dark
		frame_fn:     update_frame
		resized_fn:   resize_window
		user_data:    &app
	)
	app.resource_manager.insert_ref(ctx)
}

fn (bp &BreakoutPlugin) on_enable(mut app App) ! {
	setup_game(mut app)

	if mut ctx := app.resource_manager.get_ref[gg.Context]() {
		ctx.run()
	}
}

fn (_ &BreakoutPlugin) on_disable(mut _ App) ! {}

// ========================================
// SYSTEMS
// ========================================

struct PaddleControlSystem implements ISystem {
	QuerySystem
}

fn new_paddle_control_system(app &App) PaddleControlSystem {
	return PaddleControlSystem{
		QuerySystem: primer_ecs.new_query_system([
			app.world.get_type_id[Paddle](),
			app.world.get_type_id[Velocity](),
		])
	}
}

fn (_ &PaddleControlSystem) name() string {
	return 'PaddleControlSystem'
}

fn (ps &PaddleControlSystem) update(mut app App, _ f64) ! {
	input := app.resource_manager.get[InputManager]() or { return }
	mut query_sys := ps.QuerySystem

	for result in query_sys.query(app.world) {
		paddle := result.get[Paddle](app.world) or { continue }
		mut vel := result.get[Velocity](app.world) or { continue }
		vel.x = 0

		if input.keys[int(gg.KeyCode.a)].pressed {
			vel.x = -paddle.speed
		}
		if input.keys[int(gg.KeyCode.d)].pressed {
			vel.x = paddle.speed
		}
	}
}

struct MovementSystem {
	QuerySystem
}

fn new_movement_system(app &App) MovementSystem {
	return MovementSystem{
		QuerySystem: primer_ecs.new_query_system([
			app.world.get_type_id[Position](),
			app.world.get_type_id[Velocity](),
		])
	}
}

fn (_ &MovementSystem) name() string {
	return 'MovementSystem'
}

fn (ms &MovementSystem) update(mut app App, dt f64) ! {
	config := app.resource_manager.get[GameConfig]() or { return }
	mut query_sys := ms.QuerySystem

	for result in query_sys.query(app.world) {
		mut pos := result.get[Position](app.world) or { continue }
		vel := result.get[Velocity](app.world) or { continue }
		pos.x += vel.x * dt
		pos.y += vel.y * dt

		// Keep paddle in world bounds
		if app.world.has[Paddle](result.entity) {
			if size := app.world.get[Size](result.entity) {
				pos.x = math.clamp(pos.x, 0, config.design_size.x - size.w)
			}
		}
	}
}

struct BallPhysicsSystem {
	QuerySystem
}

fn new_ball_physics_system(app &App) BallPhysicsSystem {
	return BallPhysicsSystem{
		QuerySystem: primer_ecs.new_query_system([
			app.world.get_type_id[Ball](),
			app.world.get_type_id[Position](),
			app.world.get_type_id[Velocity](),
			app.world.get_type_id[Size](),
		])
	}
}

fn (_ &BallPhysicsSystem) name() string {
	return 'BallPhysicsSystem'
}

fn (bps &BallPhysicsSystem) update(mut app App, _ f64) ! {
	config := app.resource_manager.get[GameConfig]() or { return }
	mut score := app.resource_manager.get[GameScore]() or { return }
	mut state := app.resource_manager.get[GameState]() or { return }
	mut sound := app.resource_manager.get[SoundManager]() or { return }
	mut view := app.resource_manager.get[CameraView]() or { return }
	mut query_sys := bps.QuerySystem

	for result in query_sys.query(app.world) {
		pos := result.get[Position](app.world) or { continue }
		size := result.get[Size](app.world) or { continue }
		mut vel := result.get[Velocity](app.world) or { continue }

		// Bounce off walls
		if pos.x <= 0 || pos.x + size.w >= config.design_size.x {
			vel.x *= -1
			sound.play(.wall)
			view.shake(shake_wall_intensity, shake_wall_duration)
			spawn_particles(mut app, pos.x + size.w / 2, pos.y + size.h / 2, neon_cyan)
		}

		if pos.y <= 0 {
			vel.y *= -1
			sound.play(.wall)
			view.shake(shake_wall_intensity, shake_wall_duration)
			spawn_particles(mut app, pos.x + size.w / 2, pos.y + size.h / 2, neon_cyan)
		}

		// Ball fell off bottom
		if pos.y > config.design_size.y {
			sound.play(.lose_ball)
			view.shake(shake_lose_intensity, shake_lose_duration)
			spawn_particles(mut app, pos.x + size.w / 2, pos.y, neon_red)

			score.lives--
			state.paused = true
			if score.lives <= 0 {
				state.game_over = true
			}

			reset_ball(mut app, result.entity, config)
			reset_paddle(mut app, config)
		}
	}
}

struct CollisionSystem {
	QuerySystem
mut:
	ball_id   u32
	paddle_id u32
	brick_id  u32
	pos_id    u32
	vel_id    u32
	size_id   u32
}

fn new_collision_system(app &App) CollisionSystem {
	return CollisionSystem{
		ball_id:     app.world.get_type_id[Ball]()
		paddle_id:   app.world.get_type_id[Paddle]()
		brick_id:    app.world.get_type_id[Brick]()
		pos_id:      app.world.get_type_id[Position]()
		vel_id:      app.world.get_type_id[Velocity]()
		size_id:     app.world.get_type_id[Size]()
		QuerySystem: primer_ecs.new_query_system([
			app.world.get_type_id[Position](),
			app.world.get_type_id[Size](),
		])
	}
}

fn (_ &CollisionSystem) name() string {
	return 'CollisionSystem'
}

fn (cs &CollisionSystem) update(mut app App, _ f64) ! {
	mut score := app.resource_manager.get[GameScore]() or { return }
	mut state := app.resource_manager.get[GameState]() or { return }
	mut sound := app.resource_manager.get[SoundManager]() or { return }
	mut view := app.resource_manager.get[CameraView]() or { return }

	for ball in app.world.query([cs.ball_id, cs.pos_id, cs.vel_id, cs.size_id]) {
		mut ball_pos := ball.get[Position](app.world) or { continue }
		ball_size := ball.get[Size](app.world) or { continue }
		mut ball_vel := ball.get[Velocity](app.world) or { continue }

		// Check paddle collision
		for paddle in app.world.query([cs.paddle_id, cs.pos_id, cs.size_id]) {
			paddle_pos := paddle.get[Position](app.world) or { continue }
			paddle_size := paddle.get[Size](app.world) or { continue }

			if collides(ball_pos, ball_size, paddle_pos, paddle_size) {
				ball_pos.y = paddle_pos.y - ball_size.h - 1

				hit_x := (ball_pos.x + ball_size.w / 2) - (paddle_pos.x + paddle_size.w / 2)
				normalized := math.clamp(hit_x / (paddle_size.w / 2), -1.0, 1.0)

				speed := 300.0
				angle := normalized * ball_bounce_angle_max
				ball_vel.x = speed * math.sin(angle)
				ball_vel.y = -math.abs(speed * math.cos(angle))

				sound.play(.paddle)
				view.shake(shake_paddle_intensity, shake_paddle_duration)
				spawn_particles(mut app, ball_pos.x + ball_size.w / 2, ball_pos.y + ball_size.h / 2,
					neon_magenta)
			}
		}

		// Check brick collisions
		for brick in app.world.query([cs.brick_id, cs.pos_id, cs.size_id]) {
			brick_pos := brick.get[Position](app.world) or { continue }
			brick_size := brick.get[Size](app.world) or { continue }
			brick_comp := brick.get[Brick](app.world) or { continue }

			if collides(ball_pos, ball_size, brick_pos, brick_size) {
				ball_vel.y *= -1
				ball_vel.x *= ball_speed_increase
				ball_vel.y *= ball_speed_increase

				sound.play(.brick)
				view.shake(shake_brick_intensity, shake_brick_duration)
				spawn_particles(mut app, brick_pos.x + brick_size.w / 2, brick_pos.y +
					brick_size.h / 2, brick_comp.color)
				app.world.despawn(brick.entity)

				score.points += points_per_brick
				state.bricks_count--
				if state.bricks_count <= 0 {
					state.won = true
				}
				break
			}
		}
	}
}

struct ParticleSystem {
	QuerySystem
}

fn new_particle_system(app &App) ParticleSystem {
	return ParticleSystem{
		QuerySystem: primer_ecs.new_query_system([
			app.world.get_type_id[Particle](),
			app.world.get_type_id[Position](),
		])
	}
}

fn (_ &ParticleSystem) name() string {
	return 'ParticleSystem'
}

fn (ps &ParticleSystem) update(mut app App, dt f64) ! {
	mut query_sys := ps.QuerySystem
	for result in query_sys.query(app.world) {
		mut particle := result.get[Particle](app.world) or { continue }
		particle.lifetime -= dt
		if particle.lifetime <= 0 {
			app.world.despawn(result.entity)
		}
	}
}

struct RenderSystem {
	QuerySystem
}

fn new_render_system(app &App) RenderSystem {
	return RenderSystem{
		QuerySystem: primer_ecs.new_query_system([
			app.world.get_type_id[Position](),
			app.world.get_type_id[Size](),
		])
	}
}

fn (_ &RenderSystem) name() string {
	return 'RenderSystem'
}

fn (rs &RenderSystem) update(mut app App, _ f64) ! {
	mut ctx := app.resource_manager.get_ref[gg.Context]() or { return }
	view := app.resource_manager.get[CameraView]() or { return }

	draw_starfield(mut app, mut ctx, view)

	mut query_sys := rs.QuerySystem
	for result in query_sys.query(app.world) {
		pos := result.get[Position](app.world) or { continue }
		size := result.get[Size](app.world) or { continue }

		if app.world.has[Ball](result.entity) {
			draw_ball(mut ctx, view, pos, size)
		} else if app.world.has[Paddle](result.entity) {
			draw_paddle(mut ctx, view, pos, size)
		} else if brick := app.world.get[Brick](result.entity) {
			draw_brick(mut ctx, view, pos, size, brick.color, brick.secondary_color)
		} else if particle := app.world.get[Particle](result.entity) {
			draw_particle(mut ctx, view, pos, size, particle)
		}
	}

	draw_ui(mut app)
}

// ========================================
// RENDER HELPERS
// ========================================

fn draw_ball(mut ctx gg.Context, view &CameraView, pos Position, size Size) {
	screen_pos := view.world_to_screen(pos)
	radius := f32(size.w / 2 * view.viewport.scale)
	cx := f32(screen_pos.x) + radius
	cy := f32(screen_pos.y) + radius

	ctx.draw_circle_filled(cx, cy, radius, neon_cyan)

	// Highlight
	highlight_r := radius * 0.5
	ctx.draw_circle_filled(cx - radius * 0.3, cy - radius * 0.3, highlight_r, gg.Color{255, 255, 255, 180})
}

fn draw_paddle(mut ctx gg.Context, view &CameraView, pos Position, size Size) {
	screen_pos := view.world_to_screen(pos)
	w := f32(size.w * view.viewport.scale)
	h := f32(size.h * view.viewport.scale)
	x := f32(screen_pos.x)
	y := f32(screen_pos.y)
	scale := f32(view.viewport.scale)

	ctx.draw_rounded_rect_filled(x, y, w, h, 8.0 * scale, neon_magenta)

	// Highlight
	highlight_h := h * 0.4
	ctx.draw_rounded_rect_filled(x, y, w, highlight_h, 8.0 * scale, gg.Color{255, 150, 255, 120})

	// Border
	ctx.draw_rounded_rect_empty(x, y, w, h, 8.0 * scale, gg.Color{255, 255, 255, 80})
}

fn draw_brick(mut ctx gg.Context, view &CameraView, pos Position, size Size, color gg.Color, secondary_color gg.Color) {
	screen_pos := view.world_to_screen(pos)
	w := f32(size.w * view.viewport.scale)
	h := f32(size.h * view.viewport.scale)
	x := f32(screen_pos.x)
	y := f32(screen_pos.y)
	scale := f32(view.viewport.scale)

	ctx.draw_rounded_rect_filled(x, y, w, h, 3.0 * scale, color)

	// Gradient
	gradient_h := h * 0.5
	ctx.draw_rounded_rect_filled(x, y, w, gradient_h, 3.0 * scale, gg.Color{255, 255, 255, 40})

	// Border
	ctx.draw_rounded_rect_empty(x, y, w, h, 3.0 * scale, secondary_color)
}

fn draw_particle(mut ctx gg.Context, view &CameraView, pos Position, size Size, particle Particle) {
	screen_pos := view.world_to_screen(pos)
	life_ratio := particle.lifetime / particle.max_lifetime
	radius := f32(size.w / 2 * view.viewport.scale * life_ratio)

	alpha := u8(f32(particle.color.a) * life_ratio)
	ctx.draw_circle_filled(f32(screen_pos.x), f32(screen_pos.y), radius, gg.Color{
		r: particle.color.r
		g: particle.color.g
		b: particle.color.b
		a: alpha
	})
}

fn draw_starfield(mut app App, mut ctx gg.Context, view &CameraView) {
	width := f32(view.viewport.size.x)
	height := f32(view.viewport.size.y)

	// Gradient background
	steps := 30
	for i in 0 .. steps {
		y := height * f32(i) / f32(steps)
		h := height / f32(steps)
		t := f32(i) / f32(steps)

		r := u8(bg_dark.r + int((bg_medium.r - bg_dark.r) * t))
		g := u8(bg_dark.g + int((bg_medium.g - bg_dark.g) * t))
		b := u8(bg_dark.b + int((bg_medium.b - bg_dark.b) * t))

		ctx.draw_rect_filled(0, y, width, h, gg.Color{r, g, b, 255})
	}

	// Stars
	star_id := app.world.get_type_id[Star]()
	pos_id := app.world.get_type_id[Position]()
	for result in app.world.query([star_id, pos_id]) {
		pos := result.get[Position](app.world) or { continue }
		star := result.get[Star](app.world) or { continue }
		screen_pos := view.world_to_screen(pos)

		size := f32(1.0 + star.depth * 2) * f32(view.viewport.scale)
		alpha := u8(100 + int(star.brightness * 155))

		ctx.draw_circle_filled(f32(screen_pos.x), f32(screen_pos.y), size, gg.Color{200, 200, 255, alpha})
	}
}

fn draw_ui(mut app App) {
	mut ctx := app.resource_manager.get_ref[gg.Context]() or { return }
	score := app.resource_manager.get[GameScore]() or { return }
	state := app.resource_manager.get[GameState]() or { return }
	view := app.resource_manager.get[CameraView]() or { return }

	ctx.draw_rounded_rect_filled(ui_panel_x, ui_panel_y, ui_panel_width, ui_panel_height,
		8, gg.Color{0, 0, 0, 150})
	ctx.draw_text(20, 20, 'SCORE', size: 16, color: neon_cyan)
	ctx.draw_text(20, 45, '${score.points}', size: 32, color: neon_yellow)
	ctx.draw_text(20, 85, 'LIVES: ${score.lives}', size: 20, color: neon_magenta)

	if state.game_over {
		draw_overlay(mut ctx, view, 'GAME OVER', neon_red, score.points)
	} else if state.won {
		draw_overlay(mut ctx, view, 'YOU WIN!', neon_green, score.points)
	}
}

fn draw_overlay(mut ctx gg.Context, view &CameraView, title string, title_color gg.Color, score_points int) {
	width := f32(view.viewport.size.x)
	height := f32(view.viewport.size.y)
	ctx.draw_rect_filled(0, 0, width, height, gg.Color{0, 0, 0, 200})

	center_x := view.viewport.size.x / 2
	center_y := view.viewport.size.y / 2

	ctx.draw_text(center_x, center_y - 80, title, size: 60, color: title_color, align: .center)
	ctx.draw_text(center_x, center_y, 'FINAL SCORE', size: 20, color: neon_cyan, align: .center)
	ctx.draw_text(center_x, center_y + 40, '${score_points}',
		size:  40
		color: neon_yellow
		align: .center
	)
	ctx.draw_text(center_x, center_y + 110, 'PRESS SPACE TO RESTART',
		size:  18
		color: gg.Color{200, 200, 200, 255}
		align: .center
	)
}

// ========================================
// HELPERS
// ========================================

fn collides(pos1 Position, size1 Size, pos2 Position, size2 Size) bool {
	return pos1.x < pos2.x + size2.w && pos1.x + size1.w > pos2.x && pos1.y < pos2.y + size2.h
		&& pos1.y + size1.h > pos2.y
}

fn setup_game(mut app App) {
	config := app.resource_manager.get[GameConfig]() or { return }
	mut state := app.resource_manager.get[GameState]() or { return }

	// Center camera on world
	mut view := app.resource_manager.get[CameraView]() or { return }
	view.move_to(Vec2[f64]{
		x: f64(config.design_size.x) / 2.0
		y: f64(config.design_size.y) / 2.0
	})
	app.resource_manager.insert(view)

	// Create stars
	for _ in 0 .. star_count {
		create_star(mut app, rand.f64() * config.design_size.x, rand.f64() * config.design_size.y) or {
			continue
		}
	}

	// Create paddle
	create_paddle(mut app, config) or { return }

	// Create ball
	create_ball(mut app, config) or { return }

	// Create bricks
	brick_colors := [
		[neon_red, neon_orange],
		[neon_orange, neon_yellow],
		[neon_yellow, neon_green],
		[neon_cyan, neon_blue],
		[neon_blue, neon_purple],
		[neon_magenta, neon_red],
	]

	for y in 0 .. brick_rows {
		for x in 0 .. brick_cols {
			create_brick(mut app, brick_offset_x + x * brick_spacing_x, brick_offset_y +
				y * brick_spacing_y, brick_colors[y][0], brick_colors[y][1]) or { continue }
			state.bricks_count++
		}
	}

	// Initialize audio
	mut sound := app.resource_manager.get[SoundManager]() or { return }
	sound.init()
}

fn restart_game(mut app App) {
	app.world.clear()

	mut score := app.resource_manager.get[GameScore]() or { return }
	score.points = 0
	score.lives = initial_lives

	mut state := app.resource_manager.get[GameState]() or { return }
	state.game_over = false
	state.won = false
	state.bricks_count = 0

	setup_game(mut app)
}

// ========================================
// MAIN
// ========================================

struct Game {
mut:
	app App
}

fn update_frame(mut app App) {
	mut ctx := app.resource_manager.get_ref[gg.Context]() or { return }
	ctx.begin()

	mut state := app.resource_manager.get[GameState]() or {
		ctx.end()
		return
	}

	is_paused := state.paused || state.game_over || state.won
	if is_paused {
		mut sound := app.resource_manager.get[SoundManager]() or {
			ctx.end()
			return
		}
		sound.fade_out(100)
	}

	app.system_manager.set_enabled('MovementSystem', !is_paused)
	app.system_manager.set_enabled('BallPhysicsSystem', !is_paused)
	app.system_manager.set_enabled('CollisionSystem', !is_paused)

	if time := app.resource_manager.get[Time]() {
		app.system_manager.update_all(mut app, time.delta_seconds) or {
			eprintln('[ERROR] System update failed: ${err}')
		}
	}

	if input := app.resource_manager.get[InputManager]() {
		if input.keys[int(gg.KeyCode.space)].just_pressed {
			if state.game_over || state.won {
				restart_game(mut app)
			} else if state.paused {
				state.paused = false
			}
		}
	}

	ctx.end()
}

fn resize_window(e &gg.Event, mut app App) {
	if e.typ == .resized {
		mut view := app.resource_manager.get[CameraView]() or { return }
		view.resize(e.window_width, e.window_height)
		app.resource_manager.insert(view)
	}
}

fn main() {
	design_size := Vec2[int]{
		x: world_width
		y: world_height
	}

	mut game := Game{
		app: primer_ecs.new_app()
	}
	mut plugin_mgr := primer_ecs.new_plugin_manager()

	plugin_mgr.add(primer_input.new_input_plugin())!
	plugin_mgr.add(primer_time.new_time_plugin())!
	plugin_mgr.add(primer_camera.new_camera_plugin_with_config(design_size.x, design_size.y,
		.orthographic, true, ViewportConfig{
		aspect_mode: .keep
		design_size: design_size
	}))!
	plugin_mgr.add(new_breakout_plugin(GameConfig{
		design_size: design_size
	}))!

	plugin_mgr.build(mut game.app)!
}
