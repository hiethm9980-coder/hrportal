from PIL import Image, ImageDraw, ImageFont, ImageFilter
import arabic_reshaper
from bidi.algorithm import get_display
import math
import os
import random

# Canvas dimensions
W, H = 1024, 500
img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# --- Color Palette ---
navy_deep = (10, 25, 50)
navy = (26, 58, 92)
teal = (13, 148, 136)
teal_light = (20, 184, 166)
cyan_glow = (56, 210, 220)
white = (255, 255, 255)

# --- Rich Gradient Background ---
for y in range(H):
    t = y / H
    # Diagonal gradient: top-left navy_deep to bottom-right slightly lighter
    for x in range(W):
        tx = x / W
        blend = t * 0.6 + tx * 0.4
        r = int(navy_deep[0] + (navy[0] - navy_deep[0]) * blend)
        g = int(navy_deep[1] + (navy[1] - navy_deep[1]) * blend)
        b = int(navy_deep[2] + (navy[2] - navy_deep[2]) * blend)
        img.putpixel((x, y), (r, g, b, 255))

# --- Teal radial glow (right side, behind icon) ---
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
gcx, gcy = int(W * 0.74), int(H * 0.48)
for radius in range(300, 0, -1):
    alpha = int(35 * (1 - radius / 300))
    glow_draw.ellipse(
        [gcx - radius, gcy - radius, gcx + radius, gcy + radius],
        fill=(teal[0], teal[1], teal[2], alpha)
    )
img = Image.alpha_composite(img, glow)

# --- Secondary glow (left, subtle warm) ---
glow2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
g2d = ImageDraw.Draw(glow2)
for radius in range(200, 0, -1):
    alpha = int(12 * (1 - radius / 200))
    g2d.ellipse(
        [80 - radius, 250 - radius, 80 + radius, 250 + radius],
        fill=(30, 80, 130, alpha)
    )
img = Image.alpha_composite(img, glow2)

draw = ImageDraw.Draw(img)

# --- Subtle dot grid ---
grid = Image.new('RGBA', (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(grid)
for x in range(30, W, 40):
    for y in range(20, H, 40):
        gd.ellipse([x, y, x + 1, y + 1], fill=(255, 255, 255, 8))
img = Image.alpha_composite(img, grid)

# --- Orbital System ---
ocx, ocy = int(W * 0.74), int(H * 0.48)

def draw_dashed_circle(img, cx, cy, radius, color, alpha, segments=60, gap_ratio=0.3):
    overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for i in range(segments):
        if i % 3 == 0:  # skip every 3rd segment for dashed effect
            continue
        a1 = (2 * math.pi * i) / segments
        a2 = (2 * math.pi * (i + 1)) / segments
        x1 = cx + radius * math.cos(a1)
        y1 = cy + radius * math.sin(a1)
        x2 = cx + radius * math.cos(a2)
        y2 = cy + radius * math.sin(a2)
        od.line([(x1, y1), (x2, y2)], fill=(color[0], color[1], color[2], alpha), width=1)
    return overlay

# Outer ring
ring1 = draw_dashed_circle(img, ocx, ocy, 195, cyan_glow, 35, segments=80)
img = Image.alpha_composite(img, ring1)

# Middle ring (solid, thinner)
ring2_overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
r2d = ImageDraw.Draw(ring2_overlay)
r2d.ellipse([ocx - 140, ocy - 140, ocx + 140, ocy + 140],
            outline=(teal_light[0], teal_light[1], teal_light[2], 25), width=1)
img = Image.alpha_composite(img, ring2_overlay)

# Inner ring
ring3_overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
r3d = ImageDraw.Draw(ring3_overlay)
r3d.ellipse([ocx - 90, ocy - 90, ocx + 90, ocy + 90],
            outline=(255, 255, 255, 18), width=1)
img = Image.alpha_composite(img, ring3_overlay)

# Orbital dots
dots_overlay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
dd = ImageDraw.Draw(dots_overlay)

orbital_dots = [
    (195, 0.4, 3.5, cyan_glow, 80),
    (195, 1.2, 2.5, cyan_glow, 60),
    (195, 2.5, 4, cyan_glow, 90),
    (195, 3.8, 2, cyan_glow, 50),
    (195, 5.0, 3, cyan_glow, 70),
    (195, 5.8, 2, cyan_glow, 45),
    (140, 0.9, 2.5, teal_light, 55),
    (140, 2.2, 3, teal_light, 65),
    (140, 3.5, 2, teal_light, 45),
    (140, 4.8, 2.5, teal_light, 55),
    (90, 0.5, 2, white, 40),
    (90, 2.0, 2.5, white, 50),
    (90, 4.0, 2, white, 35),
]

for radius, angle, dot_r, color, alpha in orbital_dots:
    x = ocx + radius * math.cos(angle)
    y = ocy + radius * math.sin(angle)
    # Glow around dot
    for gr in range(int(dot_r * 3), 0, -1):
        ga = int(alpha * 0.3 * (1 - gr / (dot_r * 3)))
        dd.ellipse([x - gr, y - gr, x + gr, y + gr],
                   fill=(color[0], color[1], color[2], ga))
    dd.ellipse([x - dot_r, y - dot_r, x + dot_r, y + dot_r],
               fill=(color[0], color[1], color[2], alpha))

img = Image.alpha_composite(img, dots_overlay)

# --- Flowing accent lines (left side, very subtle) ---
flow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
fd = ImageDraw.Draw(flow)

# Sweeping curve 1
pts1 = []
for t in range(100):
    x = 20 + t * 4.5
    y = H * 0.82 + 30 * math.sin(t * 0.05) - t * 1.2
    pts1.append((x, y))
fd.line(pts1, fill=(teal_light[0], teal_light[1], teal_light[2], 20), width=1)

# Sweeping curve 2
pts2 = []
for t in range(80):
    x = 40 + t * 5
    y = H * 0.2 + 25 * math.sin(t * 0.07 + 2) + t * 0.5
    pts2.append((x, y))
fd.line(pts2, fill=(cyan_glow[0], cyan_glow[1], cyan_glow[2], 15), width=1)

img = Image.alpha_composite(img, flow)

# --- Scattered luminous particles ---
particles = Image.new('RGBA', (W, H), (0, 0, 0, 0))
pd = ImageDraw.Draw(particles)
random.seed(77)
for _ in range(35):
    x = random.randint(30, W - 30)
    y = random.randint(30, H - 30)
    r = random.uniform(0.8, 2.2)
    a = random.randint(12, 45)
    c = random.choice([teal_light, cyan_glow, white])
    pd.ellipse([x - r, y - r, x + r, y + r], fill=(c[0], c[1], c[2], a))
img = Image.alpha_composite(img, particles)

# --- App Icon (centered in orbital system) ---
icon_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "android", "app", "src", "main", "res", "mipmap-xxxhdpi", "ic_launcher.png")
if os.path.exists(icon_path):
    icon = Image.open(icon_path).convert('RGBA')
    icon_size = 120
    icon = icon.resize((icon_size, icon_size), Image.LANCZOS)

    # Circular mask
    mask = Image.new('L', (icon_size, icon_size), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([0, 0, icon_size, icon_size], fill=255)

    icon_x = ocx - icon_size // 2
    icon_y = ocy - icon_size // 2

    # Soft glow behind icon
    ig = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    igd = ImageDraw.Draw(ig)
    for r in range(85, 0, -1):
        a = int(40 * (1 - r / 85))
        igd.ellipse([ocx - r, ocy - r, ocx + r, ocy + r],
                    fill=(255, 255, 255, a))
    img = Image.alpha_composite(img, ig)

    # White circle border
    border = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(border)
    bp = 6
    bd.ellipse([icon_x - bp, icon_y - bp, icon_x + icon_size + bp, icon_y + icon_size + bp],
               fill=(255, 255, 255, 35), outline=(255, 255, 255, 60), width=2)
    img = Image.alpha_composite(img, border)

    # Paste icon
    img.paste(icon, (icon_x, icon_y), mask)

# --- Typography ---
fonts_dir = r"C:\Users\mustapha\AppData\Roaming\Claude\local-agent-mode-sessions\skills-plugin\4224bf5d-1f15-4218-9647-4e6e9a6da52f\bab08387-c2f5-40cf-a5e5-cea984fe1807\skills\canvas-design\canvas-fonts"
project_dir = os.path.dirname(os.path.abspath(__file__))

try:
    font_en_title = ImageFont.truetype(os.path.join(fonts_dir, "WorkSans-Bold.ttf"), 46)
    font_company = ImageFont.truetype(os.path.join(fonts_dir, "Jura-Light.ttf"), 14)
except:
    font_en_title = ImageFont.load_default()
    font_company = ImageFont.load_default()

try:
    font_ar_title = ImageFont.truetype(os.path.join(project_dir, "assets", "fonts", "Cairo-ExtraBold.ttf"), 50)
except:
    font_ar_title = font_en_title

# --- Draw Text (left-aligned) ---
text_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
tld = ImageDraw.Draw(text_layer)

tx = 65
center_y = H // 2

# Measure texts
ar_word1 = "موظفين"
ar_word2 = "نيوهورايزن"
en_text = "NH Employees"
company_text = "New Horizon Travel LLC"

# Measure each word
w1_bb = tld.textbbox((0, 0), ar_word1, font=font_ar_title)
w2_bb = tld.textbbox((0, 0), ar_word2, font=font_ar_title)
en_bb = tld.textbbox((0, 0), en_text, font=font_en_title)
co_bb = tld.textbbox((0, 0), company_text, font=font_company)

w1_w = w1_bb[2] - w1_bb[0]
w2_w = w2_bb[2] - w2_bb[0]
ar_h = max(w1_bb[3] - w1_bb[1], w2_bb[3] - w2_bb[1])
en_h = en_bb[3] - en_bb[1]
co_h = co_bb[3] - co_bb[1]

word_gap = 18  # gap between Arabic words

gap1 = 18
line_h = 3
gap2 = 16
gap3 = 20

total = ar_h + gap1 + line_h + gap2 + en_h + gap3 + co_h
y_start = center_y - total // 2

# Arabic title - render word by word (right to left: word1 first then word2)
# In RTL: "موظفين نيوهورايزن" means موظفين is on the right, نيوهورايزن on the left
total_ar_w = w1_w + word_gap + w2_w
# Place نيوهورايزن first (left), then موظفين (right)
tld.text((tx, y_start), ar_word2, font=font_ar_title, fill=(255, 255, 255, 245))
tld.text((tx + w2_w + word_gap, y_start), ar_word1, font=font_ar_title, fill=(255, 255, 255, 245))

# Accent line
line_y = y_start + ar_h + gap1
# Gradient line effect
for lx in range(180):
    progress = lx / 180
    alpha = int(140 * (1 - progress * 0.6))
    r = int(teal[0] + (teal_light[0] - teal[0]) * progress)
    g = int(teal[1] + (teal_light[1] - teal[1]) * progress)
    b = int(teal[2] + (teal_light[2] - teal[2]) * progress)
    tld.line([(tx + lx, line_y), (tx + lx, line_y + line_h - 1)],
             fill=(r, g, b, alpha))

# English title
en_y = line_y + line_h + gap2
tld.text((tx, en_y), en_text, font=font_en_title, fill=(255, 255, 255, 220))

# Company name
co_y = en_y + en_h + gap3
tld.text((tx, co_y), company_text, font=font_company, fill=(teal_light[0], teal_light[1], teal_light[2], 170))

img = Image.alpha_composite(img, text_layer)

# --- Bottom accent bar ---
bar = Image.new('RGBA', (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(bar)
for x in range(W):
    t = x / W
    r = int(teal[0] + (teal_light[0] - teal[0]) * t)
    g = int(teal[1] + (teal_light[1] - teal[1]) * t)
    b = int(teal[2] + (teal_light[2] - teal[2]) * t)
    a = int(50 + 70 * t)
    bd.line([(x, H - 3), (x, H)], fill=(r, g, b, a))
img = Image.alpha_composite(img, bar)

# --- Save ---
final = img.convert('RGB')
output_path = os.path.join(project_dir, "feature-graphic.png")
final.save(output_path, 'PNG')
file_size = os.path.getsize(output_path)
print(f"Saved: {output_path}")
print(f"Dimensions: {final.size[0]}x{final.size[1]}")
print(f"File size: {file_size / 1024:.1f} KB")
