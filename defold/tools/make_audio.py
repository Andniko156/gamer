"""Rebuild the original synthesized effects and loops. Requires NumPy, SciPy and ffmpeg."""
from pathlib import Path
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "audio"
RATE = 22050
rng = np.random.default_rng(94201)
cues = {}


def time(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def noise(t, low, high):
    return sosfilt(butter(2, [low, high], btype="bandpass", fs=RATE, output="sos"),
                   rng.standard_normal(t.size))


def sweep(t, start, end):
    return np.sin(2 * np.pi * (start * t + (end - start) * t**2 / (2 * t.size / RATE)))


def envelope(t, attack, decay):
    return np.minimum(t / attack, 1) * np.exp(-t / decay)


def clang(t, hz, decay=.13):
    return sum(np.sin(2 * np.pi * hz * ratio * t) * amp * envelope(t, .006, decay / ratio**.6)
               for ratio, amp in ((1, .63), (1.51, .26), (2.13, .21), (3.18, .115), (5.01, .09)))


def hit(t, hz, decay=.10):
    return clang(t, hz, decay) + .38 * noise(t, 470, 4300) * envelope(t, .003, .017)


def write(name, samples, peak=.68, loop=False):
    samples = np.array(samples)
    if not loop:
        edge = np.linspace(0, 1, round(.004 * RATE))
        samples[:len(edge)] *= edge
        end = np.linspace(1, 0, min(round(.035 * RATE), len(samples)//2))
        samples[-len(end):] *= end
    samples *= peak / (np.max(np.abs(samples)) or 1)
    raw = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    file_name = name + (".ogg" if loop else ".wav")
    with tempfile.TemporaryDirectory() as temporary:
        target = Path(temporary) / "loop.wav" if loop else OUT / file_name
        with wave.open(str(target), "wb") as writer:
            writer.setparams((1, 2, RATE, 0, "NONE", ""))
            writer.writeframes(raw.tobytes())
        if loop:
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(target),
                            "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", str(OUT / file_name)], check=True)
    cues[name] = (file_name, loop)


def sequence(name, duration, notes):
    t = time(duration)
    result = np.zeros(t.size)
    for offset, hz, power, decay in notes:
        start = round(offset * RATE)
        result[start:] += power * clang(t[:t.size-start], hz, decay)
    write(name, result)


for name, hz, seconds in (("ui", 525, .085), ("latch", 205, .23), ("reel", 430, .065),
                          ("reel_stop", 281, .22), ("disk", 647, .19), ("impact", 236, .19),
                          ("coupling", 136, .35), ("shut", 118, .37)):
    t = time(seconds)
    write(name, hit(t, hz, seconds * .37))

t = time(.145)
write("rivet", .8 * hit(t, 470, .053) + .5 * sweep(t, 410, 140) * envelope(t, .004, .026))
t = time(.30)
write("coil", (.34 * sweep(t, 1090, 270) + noise(t, 900, 5100) * (.66 + .34*np.cos(2*np.pi*51*t)))
      * envelope(t, .013, .093))
t = time(.49)
write("flame", .9*noise(t, 160, 1700)*envelope(t, .040, .19)
      + .49*sweep(t, 275, 75)*envelope(t, .022, .082))
t = time(.47)
write("steam", noise(t, 700, 4900)*envelope(t, .025, .17) + .3*sweep(t, 970, 390)*envelope(t, .055, .12))
t = time(.38)
write("rail", .42*sweep(t, 310, 1160)*envelope(t, .026, .13)
      + .7*noise(t, 430, 4800)*envelope(t, .042, .082) + hit(t, 126, .11))
t = time(.42)
write("pendulum", np.roll(hit(t, 176, .11), round(.115*RATE)) + .45*noise(t, 300, 1550)*envelope(t, .046, .115))
t = time(.42)
write("acid", (.42*sweep(t, 183, 89) + noise(t, 790, 4400))*envelope(t, .016, .124) *
      (.65 + .35*np.cos(2*np.pi*23*t)))
t = time(.27)
write("hurt", hit(t, 132, .094)+.78*sweep(t, 265, 78)*envelope(t, .006, .061))
t = time(.66)
write("dash_warn", .55*clang(t, 550, .14) + .55*sweep(t, 427, 1050)*envelope(t, .17, .44)
      * (.8 + .2*np.cos(2*np.pi*15*t)))
t = time(.84)
write("area_warn", (.55*sweep(t, 290, 570)+.26*sweep(t, 482, 905))*envelope(t, .14, .53)
      * (.77+.23*np.cos(2*np.pi*7*t)))
t = time(1.35)
write("vent_warn", (.27*sweep(t, 570, 1200)+.48*noise(t, 830, 2600))*envelope(t, .29, .7))
t = time(1.43)
write("gate", (.6*noise(t, 145, 1500)+.33*sweep(t, 96, 154)+.17*sweep(t, 209, 250))
      * np.sin(np.pi*t/1.43)**.72 * (.8+.2*np.cos(2*np.pi*13*t)))

sequence("boss_dock",1.24,[(0,117,1,.31),(.38,156,.71,.30)])
sequence("boss_alley",1.29,[(0,404,.93,.21),(.29,351,.75,.23),(.62,271,.85,.30)])
sequence("boss_train",1.29,[(0,104,1,.24),(.31,109,1,.27),(.58,148,.34,.24)])
sequence("boss_bastion",1.32,[(0,149,.94,.23),(.14,231,.67,.24),(.24,301,.41,.27)])
sequence("level",.72,[(0,349,1,.14),(.106,466,.8,.16),(.22,587,.9,.18)])
sequence("reward",.73,[(0,392,1,.18),(.133,523,.66,.21),(.23,658,.7,.23)])
sequence("evolution",1.14,[(0,260,.77,.21),(.078,392,.78,.19),(.18,523,.73,.24),
                           (.29,659,.77,.28),(.49,784,.73,.20)])
sequence("victory",1.27,[(0,262,1,.27),(.2,392,.82,.23),(.37,523,.72,.29),(.64,659,.67,.30)])
sequence("defeat",1.0,[(0,350,.87,.20),(.18,294,.74,.23),(.37,196,.70,.24)])

# Crossfade a preroll into the tail to keep the air and motor texture continuous.
def ambience(name, low, high, hz, beat, mechanical):
    seconds, overlap = 8, .6
    t = time(seconds+overlap)
    raw = (.62*noise(t, low, high)+.38*noise(t, low*2, high*1.25)) * (
        .78+.15*np.sin(2*np.pi*t*.375)+.07*np.sin(2*np.pi*t*.625))
    hum = .16*np.sin(2*np.pi*hz*t)+.065*np.sin(2*np.pi*hz*2*t)
    rhythm = (.5+.5*np.cos(2*np.pi*beat*t))**7
    raw += hum + mechanical * rhythm * (.5*np.sin(2*np.pi*171*t)+noise(t, 210, 1800))
    size, blend = round(seconds*RATE), round(overlap*RATE)
    weight = .5-.5*np.cos(np.linspace(0, np.pi, blend))
    raw[:blend] = raw[size:size+blend]*(1-weight) + raw[:blend]*weight
    write(name, raw[:size], .53, loop=True)


ambience("night", 90, 630, 78, .375, .06)
ambience("factory", 140, 850, 89, 1.125, .10)
ambience("interior", 110, 560, 96, 1.75, .16)
ambience("hangar", 130, 780, 113, .875, .08)
ambience("dock", 120, 810, 104, 1.125, .21)
ambience("alley", 230, 1240, 126, .50, .09)
ambience("express", 130, 1200, 96, 3.75, .44)
ambience("bastion", 105, 970, 134, 2.375, .20)

components = []
for name, (file_name, loop) in sorted(cues.items()):
    group = "ambience" if loop else "effects"
    (OUT / (name + ".sound")).write_text(
        f'sound: "/audio/{file_name}"\nlooping: {int(loop)}\ngroup: "{group}"\ngain: 1.0\n',
        encoding="utf-8")
    components.append(
        f'components {{\n  id: "{name}"\n  component: "/audio/{name}.sound"\n'
        '  position { x: 0.0 y: 0.0 z: 0.0 }\n  rotation { x: 0.0 y: 0.0 z: 0.0 w: 1.0 }\n}\n')
(OUT / "audio.go").write_text("".join(components), encoding="utf-8")
