@tool
@icon("icon.png")
extends CSGShape3D
class_name CSGDeform3D

@export var lattice : Array[Vector3] = [] :
    set(value):
        lattice = value
        dirty = true
@export var lattice_size := Vector3(2, 2, 2) :
    set(value):
        lattice_size = value
        dirty = true
@export var lattice_res := Vector3i(9, 9, 9) :
    set(value):
        lattice_res = value.clamp(Vector3i.ONE, Vector3i.ONE * 64)
        dirty = true

@export var fix_normals := true :
    set(value):
        fix_normals = value
        dirty = true
@export var smooth := false :
    set(value):
        smooth = value
        dirty = true

func lattice_get(coord : Vector3) -> Vector3:
    var resm1 := lattice_res-Vector3i.ONE
    coord = (coord/lattice_size + Vector3(0.5, 0.5, 0.5)) * Vector3(resm1)
    var cf := coord.floor()
    var a := Vector3i(cf).clamp(Vector3i(), resm1)
    var b := Vector3i(cf + Vector3.ONE).clamp(Vector3i(), resm1)
    var t := (coord - Vector3(a)).clamp(Vector3(), Vector3.ONE)

    return lattice_get_i_interp_3d(a, b, t)

func lattice_get_fast(coord : Vector3) -> Vector3:
    var res := lattice_res
    var resm1 := lattice_res-Vector3i.ONE
    coord = (coord/lattice_size + Vector3(0.5, 0.5, 0.5)) * Vector3(resm1)
    var cf := coord.floor()
    var a := Vector3i(cf).clamp(Vector3i(), resm1) * Vector3i(1, res.x, res.x*res.y)
    var b := Vector3i(cf + Vector3.ONE).clamp(Vector3i(), resm1) * Vector3i(1, res.x, res.x*res.y)
    var t := (coord - Vector3(a)).clamp(Vector3(), Vector3.ONE)
    
    var aaa = lattice[a.z + a.y + a.x]
    var baa = lattice[a.z + a.y + b.x]
    var aba = lattice[a.z + b.y + a.x]
    var bba = lattice[a.z + b.y + b.x]
    var aab = lattice[b.z + a.y + a.x]
    var bab = lattice[b.z + a.y + b.x]
    var abb = lattice[b.z + b.y + a.x]
    var bbb = lattice[b.z + b.y + b.x]
    
    var _aa = aaa.lerp(baa, t.x)
    var _ba = aba.lerp(bba, t.x)
    var _ab = aab.lerp(bab, t.x)
    var _bb = abb.lerp(bbb, t.x)
    
    var __a = _aa.lerp(_ba, t.y)
    var __b = _ab.lerp(_bb, t.y)

    return __a.lerp(__b, t.z)

func lattice_get_weights(coord : Vector3, amount : float, weights : Dictionary, counts : Dictionary):
    var resm1 := lattice_res-Vector3i.ONE
    coord = (coord/lattice_size) * Vector3(resm1) + Vector3(resm1)*0.5
    var cf := coord.floor()
    var a := Vector3i(cf).clamp(Vector3i(), resm1)
    var b := Vector3i(cf + Vector3.ONE).clamp(Vector3i(), resm1)
    var t := (coord - Vector3(a)).clamp(Vector3(), Vector3.ONE)
    
    for z in range(a.z, b.z+1):
        # t.z=0.0 : a -> 1.0, b -> 0.0
        # t.z=0.5 : a -> 0.5, b -> 0.5
        # t.z=1.0 : a -> 0.0, b -> 1.0
        var w_z = lerp(a.z-z+1, z-a.z, t.z)
        for y in range(a.y, b.y+1):
            var w_y = lerp(a.y-y+1, y-a.y, t.y) * w_z
            for x in range(a.x, b.x+1):
                var w = lerp(a.x-x+1, x-a.x, t.x) * w_y
                var vec := Vector3i(x, y, z)
                if not vec in weights:
                    weights[vec] = 0.0
                    counts[vec] = 0
                weights[vec] = max(weights[vec], w * amount)
                counts[vec] = 1
                #weights[vec] += w * amount
                #counts[vec] += 1

func lattice_get_i_interp_1d(c1 : Vector3i, c2 : Vector3i, t : float) -> Vector3:
    var res := lattice_res
    var a := lattice[c1.z*res.x*res.y + c1.y*res.x + c1.x]
    var b := lattice[c2.z*res.x*res.y + c2.y*res.x + c2.x]
    if smooth:
        var d = c2-c1
        var c0 = (c1 - d).clamp(Vector3i(), res-Vector3i.ONE)
        var c3 = (c2 + d).clamp(Vector3i(), res-Vector3i.ONE)
        var pre  := lattice[c0.z*res.x*res.y + c0.y*res.x + c0.x]
        var post := lattice[c3.z*res.x*res.y + c3.y*res.x + c3.x]
        return a.cubic_interpolate(b, pre, post, t)
    else:
        return a.lerp(b, t)

func lattice_get_i_interp_2d(c1 : Vector3i, c2 : Vector3i, tx : float, ty : float) -> Vector3:
    var res := lattice_res
    var dy := (c2-c1) * Vector3i(0, 1, 0)
    var a := lattice_get_i_interp_1d(c1, c2 - dy, tx)
    var b := lattice_get_i_interp_1d(c1 + dy, c2, tx)
    if smooth:
        var c0_a = (c1 - dy  ).clamp(Vector3i(), res-Vector3i.ONE)
        var c0_b = (c2 - dy*2).clamp(Vector3i(), res-Vector3i.ONE)
        var c1_a = (c1 + dy*2).clamp(Vector3i(), res-Vector3i.ONE)
        var c1_b = (c2 + dy  ).clamp(Vector3i(), res-Vector3i.ONE)
        var pre  := lattice_get_i_interp_1d(c0_a, c0_b, tx)
        var post := lattice_get_i_interp_1d(c1_a, c1_b, tx)
        return a.cubic_interpolate(b, pre, post, ty)
    else:
        return a.lerp(b, ty)

func lattice_get_i_interp_3d(c1 : Vector3i, c2 : Vector3i, tv : Vector3) -> Vector3:
    var res := lattice_res
    var dz := (c2-c1) * Vector3i(0, 0, 1)
    var a := lattice_get_i_interp_2d(c1, c2 - dz, tv.x, tv.y)
    var b := lattice_get_i_interp_2d(c1 + dz, c2, tv.x, tv.y)
    if smooth:
        var c0_a = (c1 - dz  ).clamp(Vector3i(), res-Vector3i.ONE)
        var c0_b = (c2 - dz*2).clamp(Vector3i(), res-Vector3i.ONE)
        var c1_a = (c1 + dz*2).clamp(Vector3i(), res-Vector3i.ONE)
        var c1_b = (c2 + dz  ).clamp(Vector3i(), res-Vector3i.ONE)
        var pre  := lattice_get_i_interp_2d(c0_a, c0_b, tv.x, tv.y)
        var post := lattice_get_i_interp_2d(c1_a, c1_b, tv.x, tv.y)
        return a.cubic_interpolate(b, pre, post, tv.z)
    else:
        return a.lerp(b, tv.z)

func build_lattice():
    lattice = []
    lattice.resize(lattice_res.x * lattice_res.y * lattice_res.z)
    for i in lattice.size():
        lattice[i] = Vector3()

func affect_lattice(where : Vector3, radius : float, normal : Vector3, delta : float, add : float, multiply : float):
    var mesh : ArrayMesh = get_meshes()[1]
    var hit_lattice_weights := {}
    var hit_lattice_counts := {}
    for id in mesh.get_surface_count():
        var arrays := mesh.surface_get_arrays(id)
        var verts = arrays[ArrayMesh.ARRAY_VERTEX]
        
        var original_arrays := original_mesh.surface_get_arrays(id)
        var original_verts = original_arrays[ArrayMesh.ARRAY_VERTEX]
        
        for i in verts.size():
            var vert := verts[i] as Vector3
            var diff := (vert - where) / radius
            var l := 1.0 - diff.length_squared()
            l = max(0, l)
            l *= l
            if l > 0.0:
                var original_vert := original_verts[i] as Vector3
                lattice_get_weights(original_vert, l, hit_lattice_weights, hit_lattice_counts)
    
    # ensure the minimum weight is at least 1.0
    var max_weight = 0.0
    for coord in hit_lattice_weights:
        max_weight = max(max_weight, (hit_lattice_weights[coord] / hit_lattice_counts[coord]))
    if max_weight > 0.0:
        max_weight = 1.0 / min(max_weight, 1.0)
    else:
        var closest_id = -1
        var closest_i = -1
        var closest_dist = 10000000000.0
        for id in mesh.get_surface_count():
            var arrays := mesh.surface_get_arrays(id)
            var verts = arrays[ArrayMesh.ARRAY_VERTEX]
            for i in verts.size():
                var vert := verts[i] as Vector3
                var diff := (vert - where) / radius
                var dist = diff.length_squared()
                if dist < closest_dist:
                    closest_dist = dist
                    closest_id = id
                    closest_i = i
        if closest_i >= 0:
            var original_arrays := original_mesh.surface_get_arrays(closest_id)
            var original_verts = original_arrays[ArrayMesh.ARRAY_VERTEX]
            lattice_get_weights(original_verts[closest_i], 1.0, hit_lattice_weights, hit_lattice_counts)
            
        max_weight = 1.0
    
    
    var res := lattice_res
    for coord in hit_lattice_weights:
        var weight : float = hit_lattice_weights[coord] / hit_lattice_counts[coord] * max_weight
        var index : int = coord.z*res.x*res.y + coord.y*res.x + coord.x
        lattice[index] += normal * weight * delta * add
        lattice[index] *= pow(multiply, delta * weight * 10.0)
    
    dirty = true

#func affect_lattice(where : Vector3, radius : float, normal : Vector3, delta : float, add : float, multiply : float):
#    var res := lattice_res
#    where = (where/lattice_size + Vector3(0.5, 0.5, 0.5)) * Vector3(res)
#    var radius_vec3 = Vector3.ONE * radius
#    radius_vec3 = radius_vec3/lattice_size * Vector3(res)
#
#    var start = where - radius_vec3
#    var end = where + radius_vec3
#
#    print(radius_vec3)
#
#    var a := Vector3i(start.floor()).clamp(Vector3i(), res-Vector3i.ONE)
#    var b := Vector3i(end.floor() + Vector3.ONE).clamp(Vector3i(), res-Vector3i.ONE)
#
#    for z in range(a.z, b.z):
#        for y in range(a.y, b.y):
#            for x in range(a.x, b.x):
#                var pos = Vector3(x, y, z)
#                var diff = (pos - where) / radius_vec3
#                var l = 1.0 - diff.length_squared()
#                l = max(0, l)
#                l *= l
#
#                var index = z*res.x*res.y + y*res.x + x
#                lattice[index] += normal * l * delta * add
#                lattice[index] *= pow(multiply, delta)
#    dirty = true
#

var dummy_space : RID = PhysicsServer3D.space_create()
var dummy_body : RID = PhysicsServer3D.body_create()

func _init():
    dummy_space = PhysicsServer3D.space_create()
    dummy_body = PhysicsServer3D.body_create()
    PhysicsServer3D.body_set_space(dummy_body, dummy_space)
    build_lattice()

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        PhysicsServer3D.free_rid(dummy_body)
        PhysicsServer3D.free_rid(dummy_space)

func translate_coord(coord : Vector3, force_fast := false) -> Vector3:
    if smooth and !force_fast:
        return coord + lattice_get(coord)
    else:
        return coord + lattice_get_fast(coord)

func get_normal_at_coord(c : Vector3, n : Vector3) -> Vector3:
    var y := n.cross(Vector3(n.y, n.z, -n.x))
    var x := n.cross(y)
    var s := lattice_size/Vector3(lattice_res)/4.0 * (0.2 if smooth else 1.0)
    var s2 := s * 2.0
    var tan := (translate_coord(c + x * s, true) - translate_coord(c - x * s, true)) / s2
    var bitan := (translate_coord(c + y * s, true) - translate_coord(c - y * s, true)) / s2
    return -tan.cross(bitan).normalized()

func _validate_property():
    pass

var used_mesh : ArrayMesh = null
var original_mesh : ArrayMesh = null
var dirty = false

var timer = 0.0

func randomize_lattice():
    var s = 0.1
    for i in lattice.size():
        seed(hash(i) + Time.get_ticks_usec())
        lattice[i] = Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
    dirty = true

#var mapping := {}

var collision : Shape3D = null

func _process(delta : float) -> void:
    var capacity = lattice_res.x * lattice_res.y * lattice_res.z
    if lattice.size() != capacity:
        build_lattice()
        dirty = true
    
    var mesh : ArrayMesh = get_meshes()[1]
    if used_mesh != mesh:
        used_mesh = mesh
        original_mesh = mesh.duplicate()
        dirty = true
    
    #timer += delta
    if timer > 2.0:
        timer = 0.0
        randomize_lattice()
    
    if dirty:
        print("it's dirty!")
        var time_a = Time.get_ticks_usec()
        
        dirty = false
        var new_surfaces = []
        for id in original_mesh.get_surface_count():
            var type := original_mesh.surface_get_primitive_type(id)
            var arrays := original_mesh.surface_get_arrays(id)
            var blend := original_mesh.surface_get_blend_shape_arrays(id)
            var mat := original_mesh.surface_get_material(id)
            var verts = arrays[ArrayMesh.ARRAY_VERTEX]
            var normals = arrays[ArrayMesh.ARRAY_NORMAL]
            for i in verts.size():
                var old_vert = verts[i]
                var new_vert := translate_coord(verts[i])
                if fix_normals:
                    normals[i] = get_normal_at_coord(old_vert, normals[i])
                verts[i] = new_vert
            new_surfaces.push_back([type, arrays, blend, mat])
        
        var time_b = Time.get_ticks_usec()
        
        mesh.clear_surfaces()
        for info in new_surfaces:
            mesh.add_surface_from_arrays(info[0], info[1], info[2])
            mesh.surface_set_material(mesh.get_surface_count()-1, info[3])
        
        var time_c = Time.get_ticks_usec()
        
        collision = mesh.create_trimesh_shape()
        PhysicsServer3D.body_clear_shapes(dummy_body)
        PhysicsServer3D.body_add_shape(dummy_body, collision.get_rid())
        
        var time_d = Time.get_ticks_usec()
        
        # force broadphase update
        PhysicsServer3D.body_set_space(dummy_body, get_tree().root.find_world_3d().space)
        PhysicsServer3D.body_set_space(dummy_body, dummy_space)
        
        var time_e = Time.get_ticks_usec()
        
        print("mesh update time a: ", (time_b - time_a)/1000000.0)
        print("mesh update time b: ", (time_c - time_b)/1000000.0)
        print("mesh update time c: ", (time_d - time_c)/1000000.0)
        print("mesh update time d: ", (time_e - time_e)/1000000.0)
    
    force_update_transform()
    var state := PhysicsServer3D.body_get_direct_state(dummy_body)
    state.transform = global_transform
