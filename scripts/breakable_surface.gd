extends RigidBody3D
class_name BreakableSurface

var Filter: ImmediateMesh
@onready var Renderer: MeshInstance3D = $MeshInstance3D
@onready var Collider: CollisionShape3D = $CollisionShape3D
@onready var Rigidbody: RigidBody3D = self

var Polygon: Array[Vector2] = []
var Thickness: float = 1.0
var MinBreakArea: float = 0.01
var MinImpactToBreak: float = 50.0

var ContactPoint

var _Area: float = -1.0

var age:int

func Area() -> float:
	if _Area < 0.0:
		_Area = Geom.Area(Polygon);
	return _Area

func _ready():
	age = 0
	Reload()

func Reload() -> void:
	var pos = transform.position

	if Polygon.size() == 0:
		#Assume its a cube with localScale dimensions
		scale = 0.5 * scale

		Polygon.push_back(Vector2(-scale.x, -scale.y))
		Polygon.push_back(Vector2(scale.x, -scale.y))
		Polygon.push_back(Vector2(scale.x, scale.y))
		Polygon.push_back(Vector2(-scale.x, scale.y))

		Thickness = 2.0 * scale.z

		scale = Vector3.one

	var mesh = MeshFromPolygon(Polygon, Thickness);

	Filter.mesh = mesh
	Collider.mesh = mesh

func _integrate_forces(state):
	ContactPoint = state.get_contact_collider_position(0)

func _physics_process(delta: float) -> void:
	var pos = position
	age += 1
	if pos.magnitude > 1000.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if age > 5 && body.velocity > MinImpactToBreak:
		var pnt = ContactPoint
		Break((Vector2)transform.InverseTransformPoint(pnt))

func NormalizedRandom(mean: float, stddev: float ) -> float:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var u1 = rng.randf()
	var u2 = rng.randf()

	var randStdNormal = sqrt(-2.0 * log(u1)) * sin(2.0 * PI * u2)

	return mean + stddev * randStdNormal

func Break(position: Vector2) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var area = Area
	if area > MinBreakArea:
		#seperate classes
		#var calc = new VoronoiCalculator()
		#var clip = new VoronoiClipper()

		var sites: Array[Vector2]

		for i in range(0, sites.size()):
			var dist = Mathf.Abs(NormalizedRandom(0.5, 1.0/2.0))
			var angle = 2.0 * PI * rng.randf()

			sites[i] = position + Vector2(dist * cos(angle), dist * sin(angle))

		var diagram = calc.CalculateDiagram(sites)

		var clipped: Array[Vector2]

		for i in range(i, sits.size()):
			#clip.ClipSite(diagram, Polygon, i, ref clipped)

			if clipped.Count > 0:
				var newGo = duplicate()
				get_parent().add_child(new_node)

				newGo.position = postion
				newGo.rotation = rotation

				var bs = newGo.get_script()

				bs.Thickness = Thickness
				bs.Polygon.clear()
				bs.Polygon.AddRange(clipped)

				var childArea = bs.Area

				var rb = bs.get_node("RigidBody3D")

				rb.mass = Rigidbody.mass * (childArea / area)

		gameObject.active = false
		queue_free()

static Mesh MeshFromPolygon(List<Vector2> polygon, float thickness) {
	var count = polygon.Count;
	# TODO: cache these things to avoid garbage
	var verts = new Vector3[6 * count];
	var norms = new Vector3[6 * count];
	var tris = new int[3 * (4 * count - 4)];
	# TODO: add UVs

	var vi = 0;
	var ni = 0;
	var ti = 0;

	var ext = 0.5f * thickness;

	# Top
	for (int i = 0; i < count; i++) {
		verts[vi++] = new Vector3(polygon[i].x, polygon[i].y, ext);
		norms[ni++] = Vector3.forward;
	}

	# Bottom
	for (int i = 0; i < count; i++) {
		verts[vi++] = new Vector3(polygon[i].x, polygon[i].y, -ext);
		norms[ni++] = Vector3.back;
	}

	#Sides
	for (int i = 0; i < count; i++) {
		var iNext = i == count - 1 ? 0 : i + 1;

		verts[vi++] = new Vector3(polygon[i].x, polygon[i].y, ext);
		verts[vi++] = new Vector3(polygon[i].x, polygon[i].y, -ext);
		verts[vi++] = new Vector3(polygon[iNext].x, polygon[iNext].y, -ext);
		verts[vi++] = new Vector3(polygon[iNext].x, polygon[iNext].y, ext);

		var norm = Vector3.Cross(polygon[iNext] - polygon[i], Vector3.forward).normalized;

		norms[ni++] = norm;
		norms[ni++] = norm;
		norms[ni++] = norm;
		norms[ni++] = norm;
	}


	for (int vert = 2; vert < count; vert++) {
		tris[ti++] = 0;
		tris[ti++] = vert - 1;
		tris[ti++] = vert;
	}

	for (int vert = 2; vert < count; vert++) {
		tris[ti++] = count;
		tris[ti++] = count + vert;
		tris[ti++] = count + vert - 1;
	}

	for (int vert = 0; vert < count; vert++) {
		var si = 2*count + 4*vert;

		tris[ti++] = si;
		tris[ti++] = si + 1;
		tris[ti++] = si + 2;

		tris[ti++] = si;
		tris[ti++] = si + 2;
		tris[ti++] = si + 3;
	}

	#Debug.Assert(ti == tris.Length);
	#Debug.Assert(vi == verts.Length);

	var mesh = new Mesh();


	mesh.vertices = verts;
	mesh.triangles = tris;
	mesh.normals = norms;

	return mesh
