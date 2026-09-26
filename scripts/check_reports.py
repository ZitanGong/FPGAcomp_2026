from pathlib import Path
import re
import html
import json
import hashlib
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
report = root/'reports'

project = ET.parse(root/'fpga_project1.gprj')
expected = {(root/f.attrib['path']).resolve() for f in project.findall('.//File')
            if f.attrib.get('enable') == '1' and f.attrib['type'] == 'file.verilog'}
compiled = {Path(f.attrib['path']).resolve()
            for f in ET.parse(root/'impl/gwsynthesis/synth21.prj').findall('.//File')}
assert expected == compiled, ('Project/synthesis source mismatch', expected-compiled, compiled-expected)
syn_log = (root/'impl/gwsynthesis/synth21.log').read_text(errors='replace')
assert 'ERROR (' not in syn_log and 'Generate netlist file' in syn_log, 'Latest synthesis failed or incomplete'
assert "Compiling module 'top'" in syn_log, 'Missing top compilation'

def clean(s):
    return ' '.join(html.unescape(re.sub('<[^>]*>', ' ', s)).split())

def timing(name):
    raw = (root/f'impl/pnr/{name}_tr_content.html').read_text(errors='replace')
    rows = [[clean(c) for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.S)]
            for row in re.findall(r'<tr[^>]*>(.*?)</tr>', raw, re.S)]
    rows = [r for r in rows if r]
    for label in ['Numbers of Setup Violated Endpoints', 'Numbers of Hold Violated Endpoints']:
        assert int(next(r[1] for r in rows if r[0] == label)) == 0, (name, label)
    fm = next(r for r in rows if len(r)>4 and r[1]=='sys_clk' and '(MHz)' in r[2])
    fmax = float(fm[3].replace('(MHz)', ''))
    assert fmax >= 49.152, (name, fmax)
    if name == 'synth21':
        (report/'timing.txt').write_text('\n'.join(' | '.join(r) for r in rows)+'\n', encoding='utf8')
    return {'fmax_mhz': fmax, 'setup_violations': 0, 'hold_violations': 0}

pins = {'rst_n':'AA13','test_n':'AB13','shld':'AA21','key_clk':'AB20',
        'key_in[0]':'AA19','key_in[1]':'D19','key_in[2]':'D16',
        'hp_bclk':'Y17','hp_ws':'AB17','hp_sd':'AA16','pa_n':'AB16',
        'dbg_frame':'R17','dbg_key':'R18','dbg_err':'T18',
        'dbg_ref':'Y21','dbg_lock':'Y22','dbg_rst':'AB21'}

def structure(name):
    vg = (root/f'impl/gwsynthesis/{name}.vg').read_text()
    counts = {
        'phase_bits': len(re.findall(r'DFF\w+\s+phase_\d+_', vg)),
        'voice_instances': len(re.findall(r'\\V\[\d+\]\.u_voice', vg)),
        'rom_blocks': len(re.findall(r'^\s+pROM\s', vg, re.M)),
        'dsp_instances': len(re.findall(r'^\s+MULTALU27X18\s', vg, re.M)),
        'osc_instances': len(re.findall(r'^\s+OSC\s', vg, re.M)),
        'pll_instances': len(re.findall(r'^\s+PLL\s', vg, re.M)),
    }
    assert counts == dict(phase_bits=672, voice_instances=21, rom_blocks=84,
                          dsp_instances=21, osc_instances=1, pll_instances=0), (name, counts)
    assert 'module i2s_tx' not in vg
    pnr = (root/f'impl/pnr/{name}.rpt.txt').read_text()
    assert 'i2s_bclk' not in pnr
    for port, pin in pins.items():
        assert re.search(r'^'+re.escape(port)+r'\s*\|[^\n]*\|\s*'+pin+r'/',pnr,re.M), (name,port,pin)
    return counts

checks = {'synth21': timing('synth21')}
counts = structure('synth21')
tests = ['tb_key','tb_map','tb_env','tb_mix','tb_i2s','tb_synth','tb_core','tb_pt','tb_div',
         'tb_pt_core','tb_board','tb_key_fault','tb_quality']
for tb in tests:
    log = (report/f'{tb}.log').read_text(errors='replace')
    assert f'PASS {tb}' in log and not re.search(r'\bFatal:|\bFATAL:', log), tb
for name in ['spectrum', 'quality']:
    data = json.loads((report/f'{name}.json').read_text())
    assert data['status'].startswith('PASS'), name
pnr = (root/'impl/pnr/synth21.rpt.txt').read_text()
resources = {}
for name in ['Logic','Register','BSRAM','DSP']:
    m = re.search(r'^\s*'+name+r'\s*\|\s*(\d+)/(\d+)',pnr,re.M)
    assert m, name
    resources[name] = {'used':int(m[1]),'available':int(m[2])}
pnr_log = (root/'impl/pnr/synth21.log').read_text(errors='replace')
result = {
    'device':'GW5AST-LV138PG484AC1/I0 B', 'mode':'PT8211 only',
    'clock':'internal OSC divided by 4', 'external_clock_required':False,
    'target_clock_mhz':52.5, 'target_sample_rate_hz':51269.53125,
    'reference_clock_measured':False,
    'parallel_structure':counts, 'resources':resources, 'builds':checks,
    'tests_passed':tests, 'pins':pins,
    'pnr_warnings':[l for l in pnr_log.splitlines() if 'WARN' in l],
    'current_bitstream_hardware_verified':False,
    'digital_test_latency_ns':int(re.search(r'latency=(\d+) ns', (report/'tb_board.log').read_text()).group(1)),
    'previous_hardware_result':{
        'user_observation':'2026-09-26: prior OSC version compiles and plays correctly; user reports reduced noise',
        'analog_latency_measured':False, 'sample_rate_measured':False},
    'input_clock_configuration':'none; internal OSC only',
    'synthesis_warnings':[l for l in syn_log.splitlines() if 'WARN' in l]
}
(report/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
files = sorted([p for folder in ['src','rom','constraints','sim','scripts']
                for p in (root/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts])
files += [root/'fpga_project1.gprj', root/'impl/fpga_project1_process_config.json']
files += [root/f'impl/pnr/{n}.fs' for n in checks]
(report/'manifest.sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(root).as_posix()+'\n' for p in files))
print(json.dumps(result,indent=2))
print('PASS check_reports: netlist structure, STA, simulation logs; latest hardware unverified')
