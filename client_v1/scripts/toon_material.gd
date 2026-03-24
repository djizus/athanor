## Helper script to apply toon + outline shaders to MeshInstance3D nodes
## Usage:
##   ToonMaterial.apply_toon(player_model, Color(0.831, 0.659, 0.286))
##   ToonMaterial.set_flash(player_model, 1.0)
##   ToonMaterial.remove_toon(player_model)

extends Object

const TOON_SHADER_PATH = "res://shaders/toon.gdshader"
const OUTLINE_SHADER_PATH = "res://shaders/outline.gdshader"
const ORIGINAL_MATERIAL_META = "_toon_orig_mat"


## Apply toon shader with outline to all MeshInstance3D children of node
static func apply_toon(node: Node3D, color: Color = Color.WHITE) -> void:
	var toon_shader = load(TOON_SHADER_PATH)
	var outline_shader = load(OUTLINE_SHADER_PATH)
	
	if not toon_shader or not outline_shader:
		push_error("Failed to load toon or outline shader")
		return
	
	# Find all MeshInstance3D children recursively
	var mesh_instances = node.find_children("*", "MeshInstance3D", true, false)
	
	for mesh_instance in mesh_instances:
		# Store original material for restoration
		var original_material = mesh_instance.material_override
		mesh_instance.set_meta(ORIGINAL_MATERIAL_META, original_material)
		
		# Create toon material
		var toon_mat = ShaderMaterial.new()
		toon_mat.shader = toon_shader
		toon_mat.set_shader_parameter("albedo_color", color)
		toon_mat.set_shader_parameter("flash_amount", 0.0)
		
		# Create outline material as next_pass
		var outline_mat = ShaderMaterial.new()
		outline_mat.shader = outline_shader
		
		toon_mat.next_pass = outline_mat
		
		# Apply toon material to mesh
		mesh_instance.material_override = toon_mat


## Set flash amount on all MeshInstance3D children (animates 0→1→0)
static func set_flash(node: Node3D, amount: float) -> void:
	var mesh_instances = node.find_children("*", "MeshInstance3D", true, false)
	
	for mesh_instance in mesh_instances:
		var mat = mesh_instance.material_override
		if mat and mat is ShaderMaterial:
			mat.set_shader_parameter("flash_amount", amount)


## Remove toon shader and restore original materials
static func remove_toon(node: Node3D) -> void:
	var mesh_instances = node.find_children("*", "MeshInstance3D", true, false)
	
	for mesh_instance in mesh_instances:
		if mesh_instance.has_meta(ORIGINAL_MATERIAL_META):
			var original = mesh_instance.get_meta(ORIGINAL_MATERIAL_META)
			mesh_instance.material_override = original
			mesh_instance.remove_meta(ORIGINAL_MATERIAL_META)
