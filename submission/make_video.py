#!/usr/bin/env python3
"""Renders the Wisp Gym promo video from real emulator captures (submission/assets).

Pipeline: PIL draws every frame, macOS `say` narrates, ffmpeg encodes. Output: submission/wisp-gym-demo.mp4
Needs: pillow, ffmpeg + ffprobe on PATH (or FFMPEG env), macOS `say`.
"""
import glob, os, subprocess, sys, math
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(ROOT, 'assets')
OUT = os.path.join(ROOT, 'wisp-gym-demo.mp4')
TMP = os.path.join(ROOT, '.video-tmp')
FFMPEG = os.environ.get('FFMPEG', 'ffmpeg')
FFPROBE = os.environ.get('FFPROBE', 'ffprobe')
FONT_B = os.path.join(ROOT, '..', 'entry/src/main/resources/rawfile/fonts/Nunito-ExtraBold.ttf')
FONT_R = os.path.join(ROOT, '..', 'entry/src/main/resources/rawfile/fonts/Nunito-Medium.ttf')
W, H, FPS = 1920, 1080, 24
BG, ACC, TXT, DIM, MUTE = (10, 10, 12), (255, 138, 91), (244, 244, 245), (161, 161, 170), (113, 113, 122)
os.makedirs(TMP, exist_ok=True)

def font(path, size): return ImageFont.truetype(path, size)
def ease(t): t = max(0, min(1, t)); return 1 - (1 - t) ** 3

def load(p): return Image.open(p).convert('RGB')
def seq(d): return [load(f) for f in sorted(glob.glob(os.path.join(A, d, '*.jpg')))]

def phone(shot, scale=1.32):
    sw, sh = int(360 * scale), int(720 * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    pad, r = 16, 56
    bw, bh = sw + pad * 2, sh + pad * 2
    ss = 3  # supersample the bezel for smooth corners
    body = Image.new('RGBA', (bw * ss, bh * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, bw * ss - 1, bh * ss - 1), r * ss, fill=(34, 35, 40, 255), outline=(70, 71, 78, 255), width=3 * ss)
    body = body.resize((bw, bh), Image.LANCZOS)
    mask = Image.new('L', (sw * ss, sh * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw * ss - 1, sh * ss - 1), (r - 14) * ss, fill=255)
    mask = mask.resize((sw, sh), Image.LANCZOS)
    body.paste(shot, (pad, pad), mask)
    return body

def mix(a, b, k): return Image.blend(a, b, max(0, min(1, k)))

def pick(frames, p):
    n = len(frames)
    if n == 1: return frames[0]
    x = p * (n - 1); i = int(math.floor(x)); k = x - i
    if i >= n - 1: return frames[-1]
    return mix(frames[i], frames[i + 1], ease(k))

def text_block(d, x, y, head, sub, fade, hw=900):
    c = lambda col: tuple(int(BG[j] + (col[j] - BG[j]) * fade) for j in range(3))
    f1, f2 = font(FONT_B, 76), font(FONT_R, 34)
    words, lines, line = head.split(), [], ''
    for w in words:
        t = (line + ' ' + w).strip()
        if d.textlength(t, font=f1) > hw and line: lines.append(line); line = w
        else: line = t
    lines.append(line)
    d.rounded_rectangle((x, y, x + 64, y + 8), 4, fill=c(ACC))
    y += 36
    for ln in lines:
        d.text((x, y), ln, font=f1, fill=c(TXT)); y += 88
    y += 12
    words, line = sub.split(), ''
    for w in words:
        t = (line + ' ' + w).strip()
        if d.textlength(t, font=f2) > hw and line: d.text((x, y), line, font=f2, fill=c(DIM)); y += 46; line = w
        else: line = t
    d.text((x, y), line, font=f2, fill=c(DIM))

def badge(d, fade):
    f = font(FONT_R, 24)
    s = 'Emulator capture  |  Demo mode: simulated sensor stream'
    c = tuple(int(BG[j] + (MUTE[j] - BG[j]) * fade) for j in range(3))
    d.text((120, H - 84), s, font=f, fill=c)

def scene_frame(sc, t, dur):
    img = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(img)
    fade_in = ease(t / 0.5)
    fade_out = ease((dur - t) / 0.4)
    f = min(fade_in, fade_out)
    kind = sc['kind']
    if kind == 'title':
        icon = Image.open(os.path.join(A, 'icon.png')).convert('RGBA').resize((300, 300), Image.LANCZOS)
        m = Image.new('L', (300, 300), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, 299, 299), 68, fill=255)
        img.paste(icon.convert('RGB'), (W // 2 - 150, 250), m)
        f1, f2 = font(FONT_B, 110), font(FONT_R, 40)
        c1 = tuple(int(BG[j] + (TXT[j] - BG[j]) * f) for j in range(3)); c2 = tuple(int(BG[j] + (DIM[j] - BG[j]) * f) for j in range(3))
        d.text((W // 2, 640), 'Wisp Gym', font=f1, fill=c1, anchor='mm')
        d.text((W // 2, 740), sc['sub'], font=f2, fill=c2, anchor='mm')
        d.text((W // 2, 900), 'HackYeah 2026  |  Huawei Challenge: Imagine What\'s Next', font=font(FONT_R, 28), fill=tuple(int(BG[j] + (MUTE[j] - BG[j]) * f) for j in range(3)), anchor='mm')
    elif kind == 'list':
        f1, f2 = font(FONT_B, 84), font(FONT_R, 40)
        d.text((W // 2, 170), sc['head'], font=f1, fill=tuple(int(BG[j] + (TXT[j] - BG[j]) * f) for j in range(3)), anchor='mm')
        for i, (a, b) in enumerate(sc['items']):
            x = 280 + (i % 2) * 760; y = 340 + (i // 2) * 190
            k = ease((t - 0.4 - i * 0.18) / 0.4) * f
            d.rounded_rectangle((x, y, x + 700, y + 150), 30, fill=tuple(int(BG[j] + ((21, 22, 25)[j] - BG[j]) * k) for j in range(3)), outline=tuple(int(BG[j] + ((48, 49, 54)[j] - BG[j]) * k) for j in range(3)), width=2)
            d.text((x + 36, y + 30), a, font=font(FONT_B, 40), fill=tuple(int(BG[j] + (TXT[j] - BG[j]) * k) for j in range(3)))
            d.text((x + 36, y + 88), b, font=font(FONT_R, 28), fill=tuple(int(BG[j] + (DIM[j] - BG[j]) * k) for j in range(3)))
    elif kind == 'close':
        f1, f2 = font(FONT_B, 96), font(FONT_R, 38)
        c1 = tuple(int(BG[j] + (TXT[j] - BG[j]) * f) for j in range(3)); c2 = tuple(int(BG[j] + (DIM[j] - BG[j]) * f) for j in range(3))
        d.text((W // 2, 440), sc['head'], font=f1, fill=c1, anchor='mm')
        for i, ln in enumerate(sc['sub'].split('|')):
            d.text((W // 2, 570 + i * 56), ln.strip(), font=f2, fill=c2, anchor='mm')
        d.rounded_rectangle((W // 2 - 40, 700, W // 2 + 40, 708), 4, fill=tuple(int(BG[j] + (ACC[j] - BG[j]) * f) for j in range(3)))
    else:
        text_block(d, 120, 250, sc['head'], sc['sub'], f)
        shot = pick(sc['frames'], t / dur * sc.get('span', 1.0)) if 'frames' in sc else sc['shot']
        ph = phone(shot)
        slide = (1 - ease(t / 0.8)) * 90
        x, y = 1190, (H - ph.height) // 2 + int(slide)
        img.paste(ph.convert('RGB'), (x, y), ph.split()[3].point(lambda v: int(v * f)))
        if sc.get('badge', True): badge(d, f)
    return img

def narrate(i, text):
    aiff, wav = os.path.join(TMP, f's{i}.aiff'), os.path.join(TMP, f's{i}.wav')
    subprocess.run(['say', '-v', 'Samantha', '-r', '168', '-o', aiff, text], check=True)
    subprocess.run([FFMPEG, '-y', '-loglevel', 'error', '-i', aiff, '-ar', '44100', '-ac', '2', wav], check=True)
    out = subprocess.run([FFPROBE, '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', wav], capture_output=True, text=True).stdout
    return wav, float(out.strip())

SET, EVO = seq('set'), seq('evo')
S = lambda n: load(os.path.join(A, n))
SCENES = [
    dict(kind='title', sub='A creature that grows from your real training', min=4.0,
         say='Meet Wisp Gym. A creature that grows from your real training.'),
    dict(kind='phone', head='Logging reps by hand is broken', sub='Typing in the middle of a set. Streaks that punish a missed day. Wisp Gym flips both.', shot=S('home_curious.jpg'), badge=False, min=6.0,
         say='Most training apps make you log reps by hand, and punish you with streaks. Wisp Gym works the other way: your phone does the counting, and rest is part of the game.'),
    dict(kind='phone', head='Set up in a minute', sub='Pick a starter creature, set your goals, and add height and weight for BMI. Everything stays on the phone.', frames=[S('onb_creature.jpg'), S('onb_body.jpg')], min=7.0,
         say='Setup takes a minute. Pick your creature, set your goals, and add your height and weight for B M I. It all stays on the phone.'),
    dict(kind='phone', head='It lives on your training', sub='Every muscle group you train grows a part of it. Its mood comes from recovery and daily movement.', shot=S('home_pumped.jpg'), min=6.0,
         say='Your creature lives on your phone. Every muscle group you train grows a part of it, and its mood comes from recovery and daily movement.'),
    dict(kind='phone', head='Reps counted from motion alone', sub='Phone in your pocket, any orientation. Walking and sensor noise are filtered out.', frames=SET[:8], min=9.0,
         say='Put the phone in your pocket and start a set. Reps are counted from motion alone, whatever the orientation of the phone. Walking and sensor noise are filtered out.'),
    dict(kind='phone', head='It tells you when to stop', sub='When reps slow down and lose drive, the ring turns orange and Wisp says: rack it. The numbers are on screen.', frames=SET[8:], min=8.0,
         say='As reps slow down and lose drive, the ring fills, and Wisp tells you to rack it, with the numbers to back it up.'),
    dict(kind='phone', head='Loads, volume and records', sub='Log the weight per exercise. The summary shows volume, new personal records and what grew.', frames=[S('load.jpg'), S('summary.jpg')], min=7.0,
         say='Log the load for each exercise. The summary shows your volume, new personal records, and what grew.'),
    dict(kind='phone', head='Body weight and BMI', sub='Log weigh-ins, see the trend against your goal, and a BMI gauge with a healthy range.', frames=[S('body.jpg'), S('body_bmi.jpg')], min=7.0,
         say='Track your body weight with a chart, a goal, and a B M I gauge with your healthy range.'),
    dict(kind='phone', head='Rest is part of the game', sub='A coach times your rest. Train too often and your creature asks for a rest day. It never dies.', shot=S('coach_rest.jpg'), min=6.0,
         say='A coach times your rest. Train too often, and your creature asks for a rest day. It never dies, and never loses progress.'),
    dict(kind='phone', head='Six creatures, fourteen badges', sub='Three starters, three more hatch from real milestones. Eleven expressions each.', shot=S('collection.jpg'), min=6.0,
         say='Three starters, and three more creatures hatch from real milestones, with fourteen badges to earn.'),
    dict(kind='phone', head='Everything is explainable', sub='Every value comes from your sessions, computed on the phone. No account. No cloud. No AI model.', shot=S('insights.jpg'), min=6.0,
         say='Everything is explainable. Every value comes from your real sessions, computed on the phone.'),
    dict(kind='phone', head='Two weeks, one creature', sub='A simulated fortnight, clearly labelled. Each muscle group grows its own part.', frames=EVO[:5] + [EVO[-1]], min=7.0,
         say='Over two weeks, your training shapes it. This is a simulated fortnight, clearly labelled.'),
    dict(kind='phone', head='On your home screen', sub='Two service widgets show your creature and status without opening the app.', shot=S('widget.jpg'), min=5.0,
         say='Two home screen widgets show it without opening the app.'),
    dict(kind='list', head='Built natively for OpenHarmony', min=8.0,
         items=[('ArkTS + ArkUI', 'API 20 minimum, compiled on API 23'), ('Accelerometer + pedometer', 'SensorServiceKit'), ('Service widgets', 'FormExtensionAbility, 2x2 and 2x4'), ('Local only', 'Preferences, no network permission'),
                ('74 unit tests', 'incl. 300 randomised sweeps'), ('Runs on OpenHarmony 6.1', 'emulator-verified build')],
         say='Native ArkTS and ArkUI for OpenHarmony, API twenty and up. Accelerometer, pedometer, service widgets and local storage. Seventy-four unit tests, and it runs on the OpenHarmony six point one emulator.'),
    dict(kind='close', head='Wisp Gym', sub='No cloud. No account. Your data stays on your phone.', min=4.0,
         say='Wisp Gym. Built for HackYeah twenty twenty-six. No cloud, no account, and your data stays on your phone.'),
]

def render_scene(i, sc):
    wav, adur = narrate(i, sc['say'])
    dur = max(sc['min'], adur + 0.9)
    mp4 = os.path.join(TMP, f'scene{i}.mp4')
    cmd = [FFMPEG, '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-i', wav,
           '-af', 'adelay=500|500,apad', '-t', f'{dur:.3f}', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '17', '-preset', 'medium', '-c:a', 'aac', '-b:a', '160k', '-ar', '44100', '-ac', '2', mp4]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    n = int(dur * FPS)
    for k in range(n):
        p.stdin.write(scene_frame(sc, k / FPS, dur).tobytes())
    p.stdin.close(); p.wait()
    return mp4, dur

if __name__ == '__main__':
    parts, total = [], 0
    for i, sc in enumerate(SCENES):
        mp4, dur = render_scene(i, sc); parts.append(mp4); total += dur
        print(f'scene {i} {dur:.1f}s', flush=True)
    lst = os.path.join(TMP, 'list.txt')
    open(lst, 'w').write(''.join(f"file '{p}'\n" for p in parts))
    subprocess.run([FFMPEG, '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', lst, '-c', 'copy', '-movflags', '+faststart', OUT], check=True)
    print(f'done {total:.0f}s -> {OUT}')
