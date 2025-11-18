module ecs

// ArchetypeID uniquely identifies an archetype by its component combination
pub type ArchetypeID = u64

// Archetype stores entities that share the same component combination
pub struct Archetype {
pub mut:
	id              ArchetypeID                   // Unique archetype identifier
	component_types []ComponentTypeID             // Sorted component type IDs
	entities        []EntityID                    // Dense array of entity IDs
	components      map[ComponentTypeID][]voidptr // Component data per type
	entity_to_row   map[EntityID]int              // Maps entity to row index
}

// Create a new archetype with given component types
pub fn new_archetype(component_types []ComponentTypeID) Archetype {
	mut sorted := component_types.clone()
	sorted.sort()

	arch_id := compute_archetype_id(sorted)

	mut comp_map := map[ComponentTypeID][]voidptr{}
	for comp_type in sorted {
		comp_map[comp_type] = []voidptr{cap: 64}
	}

	return Archetype{
		id:              arch_id
		component_types: sorted
		entities:        []EntityID{cap: 64}
		components:      comp_map
		entity_to_row:   map[EntityID]int{}
	}
}

// Get the number of entities in this archetype
pub fn (arch &Archetype) size() int {
	return arch.entities.len
}

// Check if entity exists in this archetype
pub fn (arch &Archetype) has(entity_id EntityID) bool {
	return entity_id in arch.entity_to_row
}

// Get the row index of an entity
pub fn (arch &Archetype) get_row(entity_id EntityID) ?int {
	if entity_id !in arch.entity_to_row {
		return none
	}
	return arch.entity_to_row[entity_id]
}

// Get component data for an entity
pub fn (arch &Archetype) get_component(entity_id EntityID, comp_type ComponentTypeID) ?voidptr {
	if entity_id !in arch.entity_to_row {
		return none
	}
	if comp_type !in arch.components {
		return none
	}
	row := arch.entity_to_row[entity_id]
	comp_array := arch.components[comp_type] or { return none }
	return comp_array[row]
}

// Get all entities in this archetype
pub fn (arch &Archetype) get_entities() []EntityID {
	return arch.entities
}

// Get component array for a specific type
pub fn (arch &Archetype) get_component_array(comp_type ComponentTypeID) ?[]voidptr {
	if comp_type !in arch.components {
		return none
	}
	return arch.components[comp_type]
}

// Check if archetype contains a component type
pub fn (arch &Archetype) has_component_type(comp_type ComponentTypeID) bool {
	return comp_type in arch.components
}

// Check if archetype has all required component types
pub fn (arch &Archetype) matches(required []ComponentTypeID) bool {
	for comp_type in required {
		if !arch.has_component_type(comp_type) {
			return false
		}
	}
	return true
}

// Add entity with components to archetype
pub fn (mut arch Archetype) add(entity_id EntityID, component_data map[ComponentTypeID]voidptr) bool {
	if arch.has(entity_id) {
		return false
	}

	// Verify all required components are provided
	for comp_type in arch.component_types {
		if comp_type !in component_data {
			return false
		}
	}

	row := arch.entities.len

	// Add entity
	arch.entities << entity_id
	arch.entity_to_row[entity_id] = row

	// Add component data
	for comp_type in arch.component_types {
		arch.components[comp_type] << component_data[comp_type]
	}

	return true
}

// Remove entity from archetype (swap-remove)
pub fn (mut arch Archetype) remove(entity_id EntityID) bool {
	if !arch.has(entity_id) {
		return false
	}

	row := arch.entity_to_row[entity_id]
	last_idx := arch.entities.len - 1

	if row != last_idx {
		// Swap with last entity
		moved_entity := arch.entities[last_idx]
		arch.entities[row] = moved_entity
		arch.entity_to_row[moved_entity] = row

		// Swap component data
		for comp_type in arch.component_types {
			mut comp_array := arch.components[comp_type]
			comp_array[row] = comp_array[last_idx]
		}
	}

	// Remove last element
	arch.entities.pop()
	arch.entity_to_row.delete(entity_id)

	// Pop component data
	for comp_type in arch.component_types {
		mut comp_array := arch.components[comp_type]
		comp_array.pop()
	}

	return true
}

// Extract entity data from archetype (returns component data map)
pub fn (mut arch Archetype) extract(entity_id EntityID) ?map[ComponentTypeID]voidptr {
	if !arch.has(entity_id) {
		return none
	}

	row := arch.entity_to_row[entity_id]

	mut component_data := map[ComponentTypeID]voidptr{}
	for comp_type in arch.component_types {
		component_data[comp_type] = arch.components[comp_type][row]
	}

	arch.remove(entity_id)

	return component_data
}

// Clear all entities and data from archetype
pub fn (mut arch Archetype) clear() {
	arch.entities.clear()
	arch.entity_to_row.clear()
	for comp_type in arch.component_types {
		arch.components[comp_type].clear()
	}
}

// Compute archetype ID from sorted component types
fn compute_archetype_id(sorted_types []ComponentTypeID) ArchetypeID {
	mut hash := u64(14695981039346656037) // FNV offset basis
	for comp_type in sorted_types {
		hash ^= u64(comp_type)
		hash *= 1099511628211 // FNV prime
	}
	return hash
}
