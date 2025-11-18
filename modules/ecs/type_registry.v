module ecs

// ComponentTypeID identifies a component type
pub type ComponentTypeID = u32

pub struct TypeRegistry {
mut:
	names       []string                // Stores component type names
	runtime_id  ComponentTypeID         // Stores next available sequential runtime id
	runtime_map map[int]ComponentTypeID // Maps static type id with runtime id
}

pub fn (mut type_registry TypeRegistry) add[T]() ComponentTypeID {
	component_id := typeof[T]().idx
	component_name := typeof[T]().name

	if component_id in type_registry.runtime_map {
		return type_registry.runtime_map[component_id]
	}

	runtime_id := type_registry.runtime_id
	type_registry.runtime_id += 1
	type_registry.runtime_map[component_id] = runtime_id
	type_registry.names << component_name

	return runtime_id
}

pub fn (type_registry &TypeRegistry) get[T]() !ComponentTypeID {
	component_id := typeof[T]().idx

	return type_registry.runtime_map[component_id] or {
		component_name := typeof[T]().name
		return error('Component type ${component_name} is not registered')
	}
}
