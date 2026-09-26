from pathlib import Path
import json
import numpy as np

root=Path(__file__).resolve().parents[1]
data=np.loadtxt(root/'reports/quality.txt',dtype=np.int64)
assert data.shape==(65536,2)
ph,y=data[:,0],data[:,1].astype(float)
ideal=32767*np.sin(2*np.pi*ph/2**32)*.5
old_wave=np.rint(32767*np.sin(2*np.pi*(ph>>22)/1024)).astype(np.int64)
old=(old_wave*32768)>>16
new_wave=np.rint(32767*np.sin(2*np.pi*(ph>>20)/4096)).astype(np.int64)
prod=new_wave*32768
expected=(prod+32768-(prod<0))>>16
assert np.array_equal(y,expected)
err=np.sqrt(np.mean((y-ideal)**2))
old_err=np.sqrt(np.mean((old-ideal)**2))
gain=20*np.log10(old_err/err)
assert gain>10, gain
assert np.max(np.abs(y))<=16384
steps=(0,2,4,5,7,9,11)
words=[int(x,16) for x in (root/'rom/notes.hex').read_text().split()]
fs=52500000/1024
cents=[]
for i,w in enumerate(words):
    f=440*2**((48+i//7*12+steps[i%7]-69)/12)
    cents.append(abs(1200*np.log2(w*fs/2**32/f)))
assert max(cents)<.0001
report={'nominal_fs_hz':fs,'voice_error_rms_lsb_before':float(old_err),
        'voice_error_rms_lsb_after':float(err),'digital_error_reduction_db':float(gain),
        'fixed_gain_db_increase':float(20*np.log10(1.5)),
        'max_21_voice_peak_fraction':21*3/64,
        'max_nominal_fcw_error_cent':float(max(cents)),
        'status':'PASS RTL and numeric comparison only; analog noise not measured'}
(root/'reports/quality.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS quality:',json.dumps(report))
