module ecs

// EntityRecord tracks where an entity is stored
struct EntityRecord {
	archetype_id ArchetypeID
	row          int
}

// World is the main ECS container
pub struct World {
mut:
	entity_manager EntityManager
	type_registry  TypeRegistry
	archetypes     map[ArchetypeID]Archetype
	entity_index   map[EntityID]EntityRecord // Maps EntityID to archetype location
}

// Helper struct for passing component data
pub struct ComponentData {
pub:
	type_id ComponentTypeID
	data    voidptr
}

// Create a new world
pub fn new_world() World {
	return World{
		entity_manager: new_entity_manager()
		type_registry:  TypeRegistry{}
		archetypes:     map[ArchetypeID]Archetype{}
		entity_index:   map[EntityID]EntityRecord{}
	}
}

// Register a component type (must be called before using components)
pub fn (mut w World) register[T]() ComponentTypeID {
	return w.type_registry.add[T]()
}

// Get registered component type ID
pub fn (w &World) get_component_id[T]() ?ComponentTypeID {
	return w.type_registry.get[T]()
}

// Create entity with multiple components at once (avoids intermediate archetypes)
pub fn (mut w World) create_with_components(components []ComponentData) EntityHandle {
	// Create entity with generation
	entity_handle := w.entity_manager.create()
	entity_id := entity_handle.id()

	// Build component type list and data map
	mut component_types := []ComponentTypeID{}
	mut component_data := map[ComponentTypeID]voidptr{}

	for comp in components {
		component_types << comp.type_id
		component_data[comp.type_id] = comp.data
	}

	// Sort component types for consistent archetype ID
	component_types.sort()

	// Get or create archetype with all components
	mut arch := w.get_or_create_archetype(component_types)

	// Add entity to archetype with all components
	arch.add(entity_id, component_data)

	// Update entity index
	w.entity_index[entity_id] = EntityRecord{
		archetype_id: arch.id
		row:          arch.size() - 1
	}

	return entity_handle
}

// Create a new entity (returns EntityHandle with generation)
pub fn (mut w World) create() EntityHandle {
	// Create entity with generation
	entity_handle := w.entity_manager.create()
	entity_id := entity_handle.id()

	// Get or create empty archetype
	mut arch := w.get_or_create_archetype([])

	// Add entity to archetype
	arch.add(entity_id, map[ComponentTypeID]voidptr{})

	// Update entity index
	w.entity_index[entity_id] = EntityRecord{
		archetype_id: arch.id
		row:          arch.size() - 1
	}

	return entity_handle
}

// Check if entity is alive (validates generation)
pub fn (w &World) is_alive(entity EntityHandle) bool {
	return w.entity_manager.is_alive(entity)
}

// Add component to entity
pub fn (mut w World) add[T](entity EntityHandle, component T) bool {
	if !w.is_alive(entity) {
		return false
	}

	entity_id := entity.id()
	comp_type_id := w.type_registry.get[T]() or { return false }

	record := w.entity_index[entity_id] or { return false }
	mut old_arch := w.archetypes[record.archetype_id] or { return false }

	// Check if already has this component
	if old_arch.has_component_type(comp_type_id) {
		return false
	}

	// Build new component type list
	mut new_types := old_arch.component_types.clone()
	new_types << comp_type_id
	new_types.sort()

	// Get or create new archetype
	mut new_arch := w.get_or_create_archetype(new_types)

	// Extract entity data from old archetype
	mut component_data := old_arch.extract(entity_id) or { return false }

	// Add new component
	component_data[comp_type_id] = voidptr(&component)

	// Add to new archetype
	new_arch.add(entity_id, component_data)

	// Update entity index
	w.entity_index[entity_id] = EntityRecord{
		archetype_id: new_arch.id
		row:          new_arch.size() - 1
	}

	return true
}

// Remove component from entity
pub fn (mut w World) remove[T](entity EntityHandle) bool {
	if !w.is_alive(entity) {
		return false
	}

	entity_id := entity.id()
	comp_type_id := w.type_registry.get[T]() or { return false }

	record := w.entity_index[entity_id] or { return false }
	mut old_arch := w.archetypes[record.archetype_id] or { return false }

	// Check if has this component
	if !old_arch.has_component_type(comp_type_id) {
		return false
	}

	// Build new component type list (without removed component)
	mut new_types := []ComponentTypeID{}
	for comp_type in old_arch.component_types {
		if comp_type != comp_type_id {
			new_types << comp_type
		}
	}

	// Get or create new archetype
	mut new_arch := w.get_or_create_archetype(new_types)

	// Extract entity data from old archetype
	mut component_data := old_arch.extract(entity_id) or { return false }

	// Remove the component
	component_data.delete(comp_type_id)

	// Add to new archetype
	new_arch.add(entity_id, component_data)

	// Update entity index
	w.entity_index[entity_id] = EntityRecord{
		archetype_id: new_arch.id
		row:          new_arch.size() - 1
	}

	return true
}

// Get component from entity
pub fn (w &World) get[T](entity EntityHandle) ?&T {
	if !w.is_alive(entity) {
		return none
	}

	entity_id := entity.id()
	comp_type_id := w.type_registry.get[T]() or { return none }

	record := w.entity_index[entity_id] or { return none }
	arch := w.archetypes[record.archetype_id] or { return none }

	data := arch.get_component(entity_id, comp_type_id) or { return none }

	unsafe {
		return &T(data)
	}
}

// Check if entity has component
pub fn (w &World) has[T](entity EntityHandle) bool {
	if !w.is_alive(entity) {
		return false
	}

	entity_id := entity.id()
	comp_type_id := w.type_registry.get[T]() or { return false }

	record := w.entity_index[entity_id] or { return false }
	arch := w.archetypes[record.archetype_id] or { return false }

	return arch.has_component_type(comp_type_id)
}

// Despawn entity (destroys entity and invalidates generation)
pub fn (mut w World) despawn(entity EntityHandle) bool {
	if !w.is_alive(entity) {
		return false
	}

	entity_id := entity.id()

	// Remove from archetype
	record := w.entity_index[entity_id] or { return false }
	mut arch := w.archetypes[record.archetype_id] or { return false }
	arch.remove(entity_id)

	// Remove from entity index
	w.entity_index.delete(entity_id)

	// Destroy in entity manager (increments generation)
	w.entity_manager.destroy(entity)

	return true
}

// Get all alive entity handles (for debugging/iteration)
pub fn (w &World) get_all_entities() []EntityHandle {
	mut handles := []EntityHandle{}
	for entity_id in w.entity_index.keys() {
		// Reconstruct handle from ID and current generation
		if entity_id < u32(w.entity_manager.generations.len) {
			gen := w.entity_manager.generations[int(entity_id)]
			handles << pack_entity(entity_id, gen)
		}
	}
	return handles
}

// Get entity count
pub fn (w &World) entity_count() int {
	return w.entity_manager.alive_count
}

// Get archetype count
pub fn (w &World) archetype_count() int {
	return w.archetypes.len
}

// Helper function to create ComponentData from a component
pub fn (w &World) component[T](component T) ComponentData {
	type_id := w.type_registry.get[T]() or { panic('Component type not registered: ${T.name}') }
	return ComponentData{
		type_id: type_id
		data:    voidptr(&component)
	}
}

// Get or create archetype with given component types
fn (mut w World) get_or_create_archetype(component_types []ComponentTypeID) &Archetype {
	arch_id := compute_archetype_id_from_types(component_types)

	if arch_id in w.archetypes {
		unsafe {
			return &w.archetypes[arch_id]
		}
	}

	mut new_arch := new_archetype(component_types)
	new_arch.id = arch_id

	w.archetypes[arch_id] = new_arch
	unsafe {
		return &w.archetypes[arch_id]
	}
}

// Helper function to generate compute archetype id
fn compute_archetype_id_from_types(types []ComponentTypeID) ArchetypeID {
	mut sorted := types.clone()
	sorted.sort()
	return compute_archetype_id(sorted) // Reuse your existing function
}
