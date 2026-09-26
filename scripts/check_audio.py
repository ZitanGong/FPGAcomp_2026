from pathlib import Path
import json
import math
import numpy as np

root = Path(__file__).resolve().parents[1]
x = np.loadtxt(root / 'reports/four_tones.txt')
assert len(x) == 48000
fs = 52500000/1024
freq = np.fft.rfftfreq(len(x), 1/fs)
spec = np.abs(np.fft.rfft((x-x.mean()) * np.hanning(len(x))))
tones = [130.81278265, 329.62755691, 391.99543598, 987.76660251]
peaks = []
for hz in tones:
    near = np.where(abs(freq-hz) < 3)[0]
    k = near[np.argmax(spec[near])]
    logs = np.log(spec[k-1:k+2])
    delta = 0.5*(logs[0]-logs[2])/(logs[0]-2*logs[1]+logs[2])
    measured = freq[k] + delta
    assert abs(measured-hz) < .04, (hz, measured)
    assert spec[k] > spec.max()*.7
    peaks.append({'expected_hz': hz, 'fft_hz': float(measured)})
words = [int(t, 16) for t in (root/'rom/notes.hex').read_text().split()]
steps = [0, 2, 4, 5, 7, 9, 11]
switches = (5,6,7,1,2,3,4,12,13,14,8,9,10,11,19,20,21,15,16,17,18)
errors = []
for i, sw in enumerate(switches):
    word = words[sw-1]
    midi = 48 + (i//7)*12 + steps[i%7]
    hz = 440 * 2 ** ((midi-69)/12)
    errors.append(abs(1200*math.log2(word*fs/(2**32*hz))))
assert max(errors) < .0001
report = {'samples':len(x), 'sample_rate_hz':fs, 'four_peaks':peaks,
          'max_fcw_error_cent':max(errors), 'peak_pcm':int(max(abs(x))),
          'status':'PASS simulation only; no analog capture'}
(root/'reports/spectrum.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS spectrum:', json.dumps(report))
try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(10, 4), layout='constrained')
    ax.plot(freq, 20*np.log10(np.maximum(spec/spec.max(), 1e-7)), lw=.9)
    for i, hz in enumerate(tones):
        ax.axvline(hz, color='#c05a28', alpha=.3, lw=.8)
        ax.annotate(f'{hz:.3f} Hz', (hz, 0), (hz+15, -27 if i==1 else 5), fontsize=9,
                    arrowprops=dict(arrowstyle='-', color='#777', lw=.6),
                    bbox=dict(facecolor='white', edgecolor='none', alpha=.8))
    ax.set(xlim=(0, 1150), ylim=(-105, 15), xlabel='Frequency (Hz)',
           ylabel='Magnitude (dB relative to peak)',
           title='RTL simulation: four independent sine voices, nominal Fs = 51.2695 kHz')
    ax.grid(alpha=.2)
    fig.savefig(root/'reports/four_tones.png', dpi=160)
    plt.close(fig)
except ImportError:
    print('matplotlib unavailable; numerical spectrum check still passed')
