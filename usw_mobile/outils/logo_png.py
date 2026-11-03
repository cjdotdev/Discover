"""Le logo de Discover (assets/logo/usw.svg) en PNG, sur une plaque opaque :
l icone de l e-mail du code et la photo de profil de l expediteur (Gmail).
Une plaque, parce qu un fond transparent devient noir chez Gmail ou Google :
la partie encre du logo y disparaissait.

python outils/logo_png.py ../usw_api/public/marque
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ici = Path(__file__).resolve().parent
sortie = Path(sys.argv[1])
sortie.mkdir(parents=True, exist_ok=True)

FOND = (227, 230, 242)  # le fond lavande de l application (jetons.dart)


def chemins(svg):
    """(couleur, d) de chaque forme du SVG."""
    for m in re.finditer(r'<path d="([^"]+)" fill="([^"]+)"', svg):
        yield m.group(2), m.group(1)


def polygone(d, echelle, dx, dy, pas=24):
    """Les commandes absolues M, L, H, V, C, Z du logo, en points."""
    jetons = re.findall(r'[MLHVCZ]|-?\d*\.?\d+(?:e-?\d+)?', d)
    pts, x, y, i, cmd = [], 0.0, 0.0, 0, None
    while i < len(jetons):
        if jetons[i] in 'MLHVCZ':
            cmd = jetons[i]
            i += 1
            if cmd == 'Z':
                continue
        n = lambda k: float(jetons[i + k])
        if cmd in 'ML':
            x, y = n(0), n(1)
            pts.append((x, y))
            i += 2
        elif cmd == 'H':
            x = n(0)
            pts.append((x, y))
            i += 1
        elif cmd == 'V':
            y = n(0)
            pts.append((x, y))
            i += 1
        elif cmd == 'C':
            x1, y1, x2, y2, x3, y3 = (n(k) for k in range(6))
            for s in range(1, pas + 1):
                t = s / pas
                u = 1 - t
                pts.append((
                    u**3 * x + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t**3 * x3,
                    u**3 * y + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t**3 * y3,
                ))
            x, y = x3, y3
            i += 6
        else:
            i += 1
    return [(px * echelle + dx, py * echelle + dy) for px, py in pts]


def dessiner(taille, logo):
    """La plaque carree (Gmail et Google la coupent en rond) et le logo au centre, a 4x puis reduit."""
    k = 4
    n = taille * k
    image = Image.new('RGB', (n, n), FOND)
    trait = ImageDraw.Draw(image)
    svg = (ici.parent / 'assets' / 'logo' / logo).read_text(encoding='utf-8')
    # Le logo occupe 56 % de la plaque, comme dans l icone de l application.
    cote = n * 0.56
    echelle = cote / 100
    for couleur, d in chemins(svg):
        trait.polygon(polygone(d, echelle, (n - cote) / 2, (n - cote * 1.01) / 2), fill=couleur)
    return image.resize((taille, taille), Image.LANCZOS)


# L e-mail : 96 px, montre a 48 ; l avatar de l expediteur : 512 px.
dessiner(96, 'usw.svg').save(sortie / 'discover.png', optimize=True)
dessiner(512, 'usw.svg').save(sortie / 'discover-avatar.png', optimize=True)
for f in ('discover.png', 'discover-avatar.png'):
    print('ecrit', sortie / f, (sortie / f).stat().st_size, 'octets')
