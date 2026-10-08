"""Escultura do Tobi em malhas reais. Não processa a imagem de referência.

Gera JSON para RealityKit e USD editável com as peças nomeadas do rosto.
Coordenadas: X direita, Y cima, Z frente. Execute a partir da raiz do repo.
"""
import json
import math
from pathlib import Path


def smooth_min(a, b, radius):
    h = max(radius - abs(a - b), 0) / radius
    return min(a, b) - h * h * radius * 0.25


def ellipsoid_distance(p, center, radii):
    q = [(p[i] - center[i]) / radii[i] for i in range(3)]
    return (math.sqrt(sum(v * v for v in q)) - 1) * min(radii)


def head_distance(p):
    qx, qy, qz = p[0]/0.72, (p[1]-0.18)/0.70, p[2]/0.34
    # Curva larga no topo, mantendo profundidade arredondada; evita o crânio em ovo.
    outline = (abs(qx)**2.4+abs(qy)**2.4)**(2/2.4)
    forehead = (math.sqrt(outline+qz*qz)-1)*0.34
    left = ellipsoid_distance(p, (-0.32, -0.30, 0.025), (0.49, 0.36, 0.36))
    right = ellipsoid_distance(p, (0.32, -0.30, 0.025), (0.49, 0.36, 0.36))
    return smooth_min(smooth_min(forehead, left, 0.14), right, 0.14)


def normal(p):
    e = 0.0001
    n = []
    for i in range(3):
        a, b = list(p), list(p)
        a[i] += e
        b[i] -= e
        n.append(head_distance(a) - head_distance(b))
    length = math.sqrt(sum(v * v for v in n)) or 1
    return [v / length for v in n]


def front_z(x, y):
    lo, hi = 0.0, 0.65
    for _ in range(25):
        mid = (lo + hi) / 2
        if head_distance((x, y, mid)) < 0:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def mesh(name, color, vertices, triangles, normals=None, roughness=0.4):
    return dict(name=name, color=color, roughness=roughness, vertices=vertices,
                normals=normals or [], triangles=triangles)


def sculpt_head():
    size = 42
    step = 2 / size
    points = []
    values = []
    for z in range(size + 1):
        for y in range(size + 1):
            for x in range(size + 1):
                p = (x * step - 1, y * step - 1, z * step - 1)
                points.append(p)
                values.append(head_distance(p))
    vertices, normals, triangles, vertex_ids = [], [], [], {}

    def vertex(a, b):
        ratio = values[a] / (values[a] - values[b])
        p = tuple(points[a][i] + ratio * (points[b][i] - points[a][i]) for i in range(3))
        key = tuple(round(v, 6) for v in p)
        if key not in vertex_ids:
            vertex_ids[key] = len(vertices)
            vertices.append(p)
            normals.append(normal(p))
        return vertex_ids[key]

    def triangle(a, b, c):
        u = [vertices[b][i] - vertices[a][i] for i in range(3)]
        v = [vertices[c][i] - vertices[a][i] for i in range(3)]
        cross = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
        if sum(cross[i] * normals[a][i] for i in range(3)) < 0:
            b, c = c, b
        triangles.extend((a, b, c))

    def index(x, y, z):
        return (z * (size + 1) + y) * (size + 1) + x

    tetrahedra = ((0, 5, 1, 6), (0, 1, 2, 6), (0, 2, 3, 6),
                  (0, 3, 7, 6), (0, 7, 4, 6), (0, 4, 5, 6))
    offsets = ((0,0,0), (1,0,0), (1,1,0), (0,1,0), (0,0,1), (1,0,1), (1,1,1), (0,1,1))
    for z in range(size):
        for y in range(size):
            for x in range(size):
                ids = [index(x+a, y+b, z+c) for a,b,c in offsets]
                for tet in tetrahedra:
                    inside = [ids[i] for i in tet if values[ids[i]] < 0]
                    outside = [ids[i] for i in tet if values[ids[i]] >= 0]
                    if len(inside) in (1, 3):
                        one, others = (inside[0], outside) if len(inside) == 1 else (outside[0], inside)
                        triangle(*(vertex(one, other) for other in others))
                    elif len(inside) == 2:
                        a, b = inside
                        c, d = outside
                        ac, ad, bc, bd = vertex(a,c), vertex(a,d), vertex(b,c), vertex(b,d)
                        triangle(ac, ad, bc)
                        triangle(ad, bd, bc)
    return mesh('Head', WHITE, vertices, triangles, normals)


def sphere(name, color, center, scale, deform=None, roughness=0.4):
    vertices, normals, triangles = [], [], []
    rings, segments = 32, 48
    for ring in range(rings + 1):
        latitude = math.pi * ring / rings
        for segment in range(segments + 1):
            longitude = 2 * math.pi * segment / segments
            unit = (math.sin(latitude)*math.cos(longitude), math.cos(latitude), math.sin(latitude)*math.sin(longitude))
            p = [center[i] + scale[i]*unit[i] for i in range(3)]
            if deform:
                p = deform(p, unit)
            vertices.append(p)
            n = [unit[i] / scale[i] for i in range(3)]
            length = math.sqrt(sum(v*v for v in n)) or 1
            normals.append([v/length for v in n])
    for row in range(rings):
        for col in range(segments):
            a = row*(segments+1)+col
            b = a+segments+1
            triangles.extend((a,a+1,b, a+1,b+1,b))
    return mesh(name, color, vertices, triangles, normals, roughness)


def patch():
    vertices, normals, triangles = [], [], []
    rings, segments = 20, 64
    for row in range(rings+1):
        radius = row/rings
        for col in range(segments+1):
            angle = 2*math.pi*col/segments
            y = 0.06 + radius*0.31*math.sin(angle)
            x = 0.32 + radius*0.24*math.cos(angle)*(1-0.16*math.sin(angle))
            z = front_z(x,y)+0.003
            vertices.append((x,y,z))
            normals.append(normal((x,y,z)))
    for row in range(rings):
        for col in range(segments):
            a = row*(segments+1)+col
            b = a+segments+1
            triangles.extend((a,b,a+1, a+1,b,b+1))
    return mesh('EyePatch', BROWN, vertices, triangles, normals)


def smoothstep(value):
    t = max(0.0, min(1.0, value))
    return t*t*(3-2*t)


def face_normals(vertices, triangles):
    """Normais suaves por triângulo, somadas por posição para não marcar costura."""
    sums = {}
    keys = [tuple(round(v, 5) for v in p) for p in vertices]
    for index in range(0, len(triangles), 3):
        a, b, c = triangles[index:index+3]
        u = [vertices[b][i]-vertices[a][i] for i in range(3)]
        v = [vertices[c][i]-vertices[a][i] for i in range(3)]
        n = (u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0])
        for vertex in (a, b, c):
            total = sums.setdefault(keys[vertex], [0.0, 0.0, 0.0])
            for i in range(3): total[i] += n[i]
    normals = []
    for key in keys:
        n = sums[key]
        length = math.sqrt(sum(v*v for v in n)) or 1
        normals.append([v/length for v in n])
    return normals


def grid(rows, cols, point, closed=False):
    """Malha (rows+1) x (cols+1) a partir de point(row/rows, col/cols)."""
    vertices = [point(r/rows, c/cols) for r in range(rows+1) for c in range(cols+1)]
    triangles = []
    for r in range(rows):
        for c in range(cols):
            a = r*(cols+1)+c
            b = a+cols+1
            triangles.extend((a, b, a+1, a+1, b, b+1))
    return vertices, triangles


def rounded(values, digits=5):
    return [[round(v, digits) for v in p] for p in values]


def with_poses(part, frames, triangles, value_range, name='pose'):
    """Poses intermediárias com a mesma topologia: o app mistura as vizinhas, sem trocar malha.
    Cada canal (abrir, enrolar, dobrar, levantar) soma a sua diferença sobre a pose de repouso."""
    part.setdefault('morphs', []).append(dict(
        name=name, range=value_range,
        poses=[rounded(f) for f in frames],
        normals=[rounded(face_normals(f, triangles), 4) for f in frames]))
    return part


# Boca: um "w" pequeno saindo de baixo do nariz, com os cantos subindo. Aberta (bocejo, ofegar),
# vira uma abertura em U até o fim do focinho. É um decalque sobre a pele, nunca atravessa o rosto.
MOUTH_TOP = -0.497
MOUTH_HALF = 0.14


def mouth_curve(x):
    u = x/MOUTH_HALF
    return MOUTH_TOP - 0.034*math.sin(math.pi*min(1, abs(u)))**1.4 + 0.012*abs(u)**3


def mouth_frame(open_amount, inner=False):
    def point(row, col):
        u = col*2-1
        # Fechada é o "w"; aberta, um oval que vai de logo abaixo do nariz até o fim do focinho.
        width = MOUTH_HALF*(1-0.2*open_amount)
        x = u*width
        closed_top = mouth_curve(u*MOUTH_HALF)
        closed_bottom = closed_top - (0.011*math.sqrt(max(0, 1-u**4)) + 0.003)
        rim = math.sqrt(max(0, 1-u*u))
        open_top = -0.535 + 0.07*rim**0.8
        open_bottom = -0.535 - 0.072*rim**0.9
        top = closed_top + (open_top-closed_top)*open_amount
        bottom = closed_bottom + (open_bottom-closed_bottom)*open_amount
        offset = 0.006
        if inner:
            # A língua no chão da boca: mais estreita, só aparece aberta.
            x *= 0.72
            rim = math.sqrt(max(0, 1-(u*0.72)**2))
            low = -0.535 - 0.072*rim**0.9 + 0.006
            bottom = closed_bottom + (low-closed_bottom)*open_amount
            top = bottom + 0.05*math.sqrt(max(0, 1-u*u))*open_amount
            offset = 0.009
        y = top + (bottom-top)*row
        return on_skin(x, y, offset)
    return point


def on_skin(x, y, offset):
    z = front_z(x, y)
    n = normal((x, y, z))
    return [x + n[0]*offset, y + n[1]*offset, z + n[2]*offset]


def mouth_part(name, color, inner=False, roughness=0.55):
    frames, triangles = [], None
    for step in range(13):
        vertices, triangles = grid(10, 64, mouth_frame(step/12, inner))
        frames.append(vertices)
    part = mesh(name, color, rounded(frames[0]), triangles, None, roughness)
    part['normals'] = rounded(face_normals(frames[0], triangles), 4)
    return with_poses(part, frames, triangles, [0, 1], 'open')


# Língua: sai do meio da boca, mais larga na ponta, com sulco central, e pende pra frente do queixo.
TONGUE_HINGE = (0.0, -0.512, 0.292)
TONGUE_LENGTH = 0.25


def tongue_frame(curl):
    hy, hz = TONGUE_HINGE[1], TONGUE_HINGE[2]
    rows, cols = 28, 48
    root = 0.12  # trecho escondido dentro da boca

    def surface(row, col, side):
        s = row*(1+root) - root  # negativo dentro da boca, 0 na boca, 1 na ponta
        angle = col*2*math.pi
        half = 0.07 + 0.032*smoothstep((s+0.1)/0.75)
        # Ponta arredondada: fecha num semicírculo de verdade nos últimos 35%.
        tip = max(0, (s-0.65)/0.35)
        half *= math.sqrt(max(0, 1-tip*tip))
        x = half*math.cos(angle)
        y = hy - TONGUE_LENGTH*s
        across = abs(math.cos(angle))
        front = math.sin(angle) > 0
        body = math.sqrt(max(0, 1-across**2))*math.sqrt(max(0, 1-tip*tip))
        thickness = (0.03 if front else 0.016)*body
        groove = 0.008*math.exp(-x*x/0.0005)*smoothstep((s-0.05)/0.3)*(1-tip) if front else 0
        # A raiz entra na boca (pra trás); a ponta pende um pouco pra frente do queixo.
        z = hz + 0.03*max(0, s)**2 - 0.12*max(0, -s)/root + (thickness-groove if front else -thickness)
        # Enrolar: a ponta gira pra frente e pra cima em volta de um ponto no meio da língua.
        bend = curl*0.95*smoothstep((s-0.25)/0.75)
        pivot_y, pivot_z = hy - TONGUE_LENGTH*0.38, hz + 0.01
        dy, dz = y-pivot_y, z-pivot_z
        y = pivot_y + dy*math.cos(bend) - dz*math.sin(bend)
        z = pivot_z + dy*math.sin(bend) + dz*math.cos(bend)
        return [x, y, z]

    vertices, triangles = grid(rows, cols, lambda r, c: surface(r, c, 1))
    return vertices, triangles


def tongue_part():
    frames, triangles = [], None
    for step in range(9):
        vertices, triangles = tongue_frame(step/8)
        frames.append(vertices)
    part = mesh('Tongue', PINK, rounded(frames[0]), triangles, None, roughness=0.32)
    part['normals'] = rounded(face_normals(frames[0], triangles), 4)
    return with_poses(part, frames, triangles, [0, 1], 'curl')


# Orelha: gota achatada, estreita presa no topo e cheia embaixo, com a ponta virada pra fora e pra frente.
# A pose dobra a parte de baixo: positivo abre pra fora (abanar), negativo encolhe pra dentro.
EAR_PIVOT_Y, EAR_TOP, EAR_BOTTOM = 0.65, 0.12, -0.82


def ear_frame(sign, bend):
    def point(row, col):
        t = row
        theta = math.pi*t
        lat = (1-math.cos(theta))/2
        y = EAR_TOP + (EAR_BOTTOM-EAR_TOP)*lat
        width = 0.25*math.sqrt(max(0, math.sin(theta)))*(0.45+0.55*lat**0.8)
        depth = 0.075*math.sqrt(max(0, math.sin(theta)))*(0.75+0.25*lat)
        phi = col*2*math.pi
        x = width*math.cos(phi)
        z = depth*math.sin(phi)
        # Frente levemente estufada, verso côncavo onde encosta na cabeça.
        if z < 0: z *= 0.55
        # Torção: a parte de baixo vira pra frente e pra fora.
        twist = -sign*0.35*lat
        x, z = x*math.cos(twist) - z*math.sin(twist), x*math.sin(twist) + z*math.cos(twist)
        x += sign*(0.17*lat**1.6 - 0.02*(1-lat)) + 0.035*sign
        z += 0.05*lat*lat
        # Dobra progressiva a partir de um terço da orelha.
        amount = bend*smoothstep((lat-0.25)/0.75)
        hinge_y = EAR_TOP + (EAR_BOTTOM-EAR_TOP)*0.25
        angle = sign*0.55*amount
        dx, dy = x, y-hinge_y
        x, y = dx*math.cos(angle) - dy*math.sin(angle), hinge_y + dx*math.sin(angle) + dy*math.cos(angle)
        fold = 0.3*amount
        dy, dz = y-hinge_y, z
        y, z = hinge_y + dy*math.cos(fold) - dz*math.sin(fold), dy*math.sin(fold) + dz*math.cos(fold)
        return [x, y, z]
    return point


EAR_ROWS, EAR_COLS = 32, 48


def ear_part(sign, side):
    frames, triangles = [], None
    for step in range(9):
        vertices, triangles = grid(EAR_ROWS, EAR_COLS, ear_frame(sign, -1 + step/4))
        frames.append(vertices)
    base = frames[4]
    part = mesh('Ear'+side, BROWN, rounded(base), triangles, None, roughness=0.5)
    part['normals'] = rounded(face_normals(base, triangles), 4)
    part['position'] = [sign*0.69, EAR_PIVOT_Y, -0.09]
    return with_poses(part, frames, triangles, [-1, 1], 'bend')


WHITE = [0.94, 0.925, 0.90]
BROWN = [0.64, 0.36, 0.045]
BLACK = [0.012, 0.01, 0.009]
PINK = [0.88, 0.35, 0.46]
MOUTH = [0.075, 0.018, 0.026]
PINK_INNER = [0.80, 0.30, 0.40]
parts = [sculpt_head()]
for sign, side in ((-1,'Left'), (1,'Right')):
    parts.append(ear_part(sign, side))
parts.append(patch())
for sign, side in ((-1,'Left'), (1,'Right')):
    x, y = sign*0.32, -0.025
    z = front_z(x,y)+0.02
    # Local eye geometry is parented to independently movable sockets in RealityKit.
    part = sphere('Eye'+side, BLACK, (0,0,0), (0.073,0.15,0.053), roughness=0.25)
    part['position'] = [x,y,z]
    parts.append(part)


def nose_deform(p, unit):
    p[0] *= 0.75+0.25*unit[1]
    return p


parts.append(sphere('Nose', BLACK, (0,-0.30,front_z(0,-0.30)+0.045), (0.145,0.09,0.065), nose_deform, roughness=0.25))
parts.append(mouth_part('Mouth', MOUTH))
parts.append(mouth_part('MouthTongue', PINK_INNER, inner=True, roughness=0.4))
parts.append(tongue_part())

# Pivôs locais: boca e língua podem ganhar expressões sem deformar o resto do rosto.
for part in parts:
    if part['name'] in ('Nose', 'Mouth', 'MouthTongue', 'Tongue'):
        vertices = part['vertices']
        center = [(min(v[i] for v in vertices)+max(v[i] for v in vertices))/2 for i in range(3)]
        if part['name'] == 'Tongue': center = list(TONGUE_HINGE)
        part['position'] = center
        part['vertices'] = [[v[i]-center[i] for i in range(3)] for v in vertices]
        for morph in part.get('morphs', []):
            morph['poses'] = [[[round(v[i]-center[i], 5) for i in range(3)] for v in f] for f in morph['poses']]

output = Path('Tobi/Resources/tobi-face.json')
output.write_text(json.dumps(dict(parts=parts), separators=(',', ':')))

# Editable USD: a real mesh asset, not a rendered image.
usd = ['#usda 1.0', '(defaultPrim = "Tobi" upAxis = "Y" metersPerUnit = 1)', 'def Xform "Tobi" {']
for part in parts:
    name = part['name']
    positions = part.get('position',[0,0,0])
    usd += [f' def Mesh "{name}" {{', f'  double3 xformOp:translate = {tuple(positions)}',
            '  uniform token[] xformOpOrder = ["xformOp:translate"]',
            '  point3f[] points = ['+', '.join(str(tuple(round(v,6) for v in p)) for p in part['vertices'])+']',
            '  normal3f[] normals = ['+', '.join(str(tuple(round(v,6) for v in p)) for p in part['normals'])+']',
            '  int[] faceVertexCounts = ['+', '.join(['3']*(len(part['triangles'])//3))+']',
            '  int[] faceVertexIndices = '+str(part['triangles']),
            f'  color3f[] primvars:displayColor = [{tuple(part["color"])}]',
            '  uniform token subdivisionScheme = "none"', ' }']
usd += ['}']
Path('design/tobi-character/tobi-face.usda').write_text('\n'.join(usd))
print(f'Generated {len(parts)} named mesh parts: {output}')
