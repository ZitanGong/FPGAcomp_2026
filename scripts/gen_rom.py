from pathlib import Path
import math

root = Path(__file__).resolve().parents[1]
out = root / 'rom'
out.mkdir(exist_ok=True)
wave4k = [round(32767 * math.sin(2 * math.pi * n / 4096)) for n in range(4096)]
(out / 'sine4k.hex').write_text(''.join(f'{x & 65535:04x}\n' for x in wave4k), encoding='ascii')
notes = [(octave, step) for octave in range(3, 6) for step in (0, 2, 4, 5, 7, 9, 11)]
switches = (5,6,7,1,2,3,4,12,13,14,8,9,10,11,19,20,21,15,16,17,18)
sample_hz = 52500000 / 1024
fcw = [round(440 * 2 ** (((o+1)*12+s-69)/12) * 2**32 / sample_hz) for o, s in notes]
phys_fcw = [0] * 21
for word, sw in zip(fcw, switches):
    phys_fcw[sw-1] = word
(out / 'notes.hex').write_text(''.join(f'{x:08x}\n' for x in phys_fcw), encoding='ascii')
lines = ['# 音符映射', '', '主工程使用内部 OSC，按标称 52.5MHz/1024=51.26953125kHz 采样率计算。A4=440Hz，十二平均律七个自然音。实际音高随内部 OSC 误差变化。', '', '| Voice | Switch | Note | Hz | FCW |', '|---:|---:|---|---:|---:|']
for i, ((o, s), word) in enumerate(zip(notes, fcw)):
    hz = 440 * 2 ** (((o+1)*12+s-69)/12)
    lines.append(f'| {i} | SW{switches[i]} | {"CDEFGAB"[i%7]}{o} | {hz:.9f} | {word} |')
(root / 'docs' / 'notes.md').write_text('\n'.join(lines)+'\n', encoding='utf8')
