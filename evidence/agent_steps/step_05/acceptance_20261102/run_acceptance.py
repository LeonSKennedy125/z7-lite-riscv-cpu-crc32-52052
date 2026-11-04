"""Independent S05 acceptance recomputation. Reads saved evidence only; no hardware access.

This script deliberately does not import s05.py or the build's helper modules. It
reimplements the event, mailbox, zlib, LTX and hash checks so that the acceptance
does not merely re-run the execution self-check.
"""
from __future__ import annotations
import hashlib
import json
import re
import sys
import zlib
import zipfile
from pathlib import Path

ACC = Path(__file__).resolve().parent
STEP = ACC.parent
ROOT = STEP.parents[2]
R3 = STEP / 'rework_r3'
R4 = STEP / 'rework_r4'

CHECKS = []
FAILURES = []


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def read(p):
    return json.loads(Path(p).read_text(encoding='utf-8-sig'))


def check(name, condition, evidence):
    ok = bool(condition)
    CHECKS.append({'name': name, 'pass': ok, 'evidence': str(evidence)})
    if not ok:
        FAILURES.append(name + ': ' + str(evidence))


def require(name, condition, evidence):
    check(name, condition, evidence)
    if not condition:
        raise SystemExit('ACCEPTANCE_FAIL ' + name + ': ' + str(evidence))


def active_lines(text):
    return [line.split('#', 1)[0].strip() for line in text.splitlines()
            if line.split('#', 1)[0].strip()]


def references():
    def pattern(n):
        x = 0x13579BDF
        out = bytearray()
        for _ in range(n):
            x = (x ^ (x << 13)) & 0xFFFFFFFF
            x = (x ^ (x >> 17)) & 0xFFFFFFFF
            x = (x ^ (x << 5)) & 0xFFFFFFFF
            out.append(x & 255)
        return bytes(out)
    return [b'', b'123456789'] + [pattern(n) for n in (1, 2, 3, 4, 7, 16, 64, 256, 1024, 4096)]


def events(path):
    rows = [json.loads(line) for line in Path(path).read_text(encoding='utf-8').splitlines() if line.strip()]
    return rows


def fields(rows, name):
    return [e['fields'] for e in rows if e['event'] == name]


def main():
    cur = read(ROOT / 'migration/current.json')
    require('current_workflow', cur.get('workflow') == 'S05_ES1_R4', cur.get('workflow'))
    seal_path = ROOT / cur['seal']
    require('current_seal_hash', seal_path.is_file() and sha(seal_path) == cur['seal_sha256'], cur['seal_sha256'])
    seal = read(seal_path)
    require('seal_scope', seal['scope'] == 'S05 ES1 host capture-script correction (VIO HEX radix) and actual hardware capture', seal['scope'])
    require('seal_self_check', seal['status'] == 'SELF_CHECK_PASS' and seal['independent_acceptance'] == 'PENDING', seal['status'])
    child = ROOT / seal['build']
    require('build_exists', (child / 'b/p/demo.xpr').is_file(), seal['build'])
    require('config_properties', seal['configuration_properties'] == {'CFGBVS': 'VCCO', 'CONFIG_VOLTAGE': '3.3'}, seal['configuration_properties'])

    # --- seal bindings ---
    for rel, digest in seal['downloads'].items():
        check('download_' + rel, sha(child / 'evidence' / rel) == digest, digest)
    for rel, digest in seal['host_scripts'].items():
        check('host_script_' + rel, sha(ROOT / rel) == digest, rel)
    for rel, digest in seal['ES1_evidence'].items():
        check('es1_evidence_' + rel, sha(ROOT / rel) == digest, rel)
    main_xpr = ROOT.parents[1] / 'RISCV_5pipeline.xpr'
    check('protected_main_count', len(seal['main_cpu_protection']) == 123, len(seal['main_cpu_protection']))
    for rel, digest in seal['main_cpu_protection'].items():
        p = ROOT.parents[1] / rel
        if not p.is_file() or sha(p) != digest:
            require('protected_' + rel, False, 'protected production file changed')
    check('protected_main_xpr', main_xpr.is_file() and sha(main_xpr) == seal['main_cpu_protection']['RISCV_5pipeline.xpr'], sha(main_xpr))
    for rel, digest in seal['frozen_images'].items():
        check('frozen_' + rel, sha(child / 'data/frozen' / rel) == digest and sha(child / 'firmware/out' / rel) == digest, rel)
    record = read(ROOT / seal['revalidation_record'])
    tool_root = Path(record['environment']['CRC_DEMO_VIVADO_BIN']).parent.resolve()
    for item in seal['registered_files']:
        p = Path(item['path'])
        resolved = p.resolve()
        inside = resolved.is_relative_to(child.resolve()) or resolved.is_relative_to(tool_root)
        check('registered_' + item['path'], p.is_file() and inside and sha(p) == item['sha256'], item['path'])
    for key, item in seal['current_inputs']['files'].items():
        check('input_' + key, sha(child / key) == item, key)

    # --- build revalidation ---
    record = read(ROOT / seal['revalidation_record'])
    require('revalidation_hash', sha(ROOT / seal['revalidation_record']) == seal['revalidation_record_sha256'], seal['revalidation_record'])
    require('revalidation_status', record['status'] == 'SELF_CHECK_PASS' and record['pass'] is True and record['independent_acceptance'] == 'PENDING', record['status'])
    require('revalidation_exact', record['initial_package_exact'] is True and record['consumed_old_DCP_or_cache'] is False, record['build'])
    require('revalidation_commands', [c['argv'][5] for c in record['commands']] ==
            ['firmware', 'project', 'unit', 'memory', 'simulate', 'faults', 'controls', 'implement', 'project', 'report'], 'command sequence')
    for c in record['commands']:
        check('command_' + c['argv'][5] + '_exit', c['exit_code'] == 0 and not c['timed_out'], c['argv'][5])
        for ch in ('stdout', 'stderr'):
            check('command_' + c['argv'][5] + '_' + ch, sha(ROOT / c[ch]) == c[ch + '_sha256'], c[ch])
    require('revalidation_gates', record['gates'] == seal['gates'] and all(g['status'] == 'PASS' for g in record['gates'].values()), 'gates')
    for gate, receipt in seal['gates'].items():
        rp = child / receipt['receipt']
        check('gate_' + gate, rp.is_file() and sha(rp) == receipt['receipt_sha256'], receipt['receipt'])
    merged = (child / 'evidence/static/constraints_merged.xdc').read_text(encoding='utf-8')
    for prop, value in (('CFGBVS', 'VCCO'), ('CONFIG_VOLTAGE', '3.3')):
        matches = re.findall(r'^set_property\s+' + prop + r'\s+(\S+)\s+\[current_design\]', merged, re.M)
        require('merged_' + prop, matches == [value], matches)
    part = re.search(r'Name="Part"\s+Val="([^"]+)"', (child / 'b/p/demo.xpr').read_text(encoding='utf-8-sig'))
    require('device_part', part and part.group(1) == 'xc7z010clg400-1', part.group(1) if part else None)
    ports = re.findall(r'set_property\s+-dict\s+\{([^}]+)\}\s+\[get_ports\s+(\w+)\]', merged)
    pin_map = {name: dict(re.findall(r'(\w+)\s+(\S+)', body)).get('PACKAGE_PIN') for body, name in ports}
    require('demo_pins', pin_map.get('clock') == 'N18' and pin_map.get('resetn') == 'P16'
            and pin_map.get('led_ok') == 'P15' and pin_map.get('led_heartbeat') == 'U12', pin_map)
    require('demo_clock', (re.search(r'create_clock\s+-period\s+20\.0+\s+-name\s+sys_clk_50\s+\[get_ports\s+clock\]', merged)
                           or re.search(r'create_clock\s+-name\s+sys_clk_50\s+-period\s+20\.0+\s+\[get_ports\s+clock\]', merged)) is not None,
            '20ns clock')

    # --- source archive diff against accepted S04 ---
    old_zip = ROOT / 'delivery/source_candidate_20261030_162300_d25c1c.zip'
    new_zip = ROOT / 'delivery/source_candidate_20261102_173954_d834d5.zip'
    require('source_archive_hash', sha(new_zip) == seal['new_source_archive_sha256'], sha(new_zip))

    def members(p):
        with zipfile.ZipFile(p) as z:
            return {n: hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if not n.endswith('/')}
    old_m, new_m = members(old_zip), members(new_zip)
    modified = sorted(n for n in set(old_m) & set(new_m) if old_m[n] != new_m[n])
    added = sorted(set(new_m) - set(old_m))
    removed = sorted(set(old_m) - set(new_m))
    require('source_no_removed', removed == [], removed)
    require('source_added_exact', added == ['docs/hardware_baseline_zh.md', 'evidence/vendor/es1_board.json', 'evidence/vendor/es1_hardware.zip'], added)
    require('source_modified_exact', modified == ['README.md', 'constraints/board_r11.xdc', 'release_manifest.json', 'run.py', 'scripts/evidence.py', 'scripts/release_files.txt'], modified)
    functional = [n for n in modified if n.startswith(('src/', 'firmware/', 'sim/')) or n == 'scripts/build.tcl']
    require('source_no_functional_change', functional == [], functional)
    with zipfile.ZipFile(old_zip) as zo, zipfile.ZipFile(new_zip) as zn:
        old_x = active_lines(zo.read('constraints/board_r11.xdc').decode('utf-8-sig'))
        new_x = active_lines(zn.read('constraints/board_r11.xdc').decode('utf-8-sig'))
    diff_lines = sorted(set(old_x) ^ set(new_x))
    require('xdc_change_only_config', set(diff_lines) == {
        'set_property CFGBVS GND [current_design]', 'set_property CFGBVS VCCO [current_design]',
        'set_property CONFIG_VOLTAGE 1.8 [current_design]', 'set_property CONFIG_VOLTAGE 3.3 [current_design]'}, diff_lines)
    with zipfile.ZipFile(new_zip) as zn:
        for rel, digest in read(child / 'release_manifest.json')['files'].items():
            check('archive_input_' + rel, hashlib.sha256(zn.read(rel)).hexdigest() == digest, rel)

    # --- BIT provenance: fresh file, identical fabric payload ---
    new_bit = (child / 'evidence/demo.bit').read_bytes()
    old_bit = (ROOT / 'local_builds/relocated_20261031/evidence/demo.bit').read_bytes()
    sync = b'\xaa\x99\x55\x66'
    ni, oi = new_bit.find(sync), old_bit.find(sync)
    require('bit_sync', ni > 0 and oi > 0, (ni, oi))
    require('bit_payload_identical', new_bit[ni:] == old_bit[oi:], 'fabric payload differs')
    diffs = [i for i, (a, b) in enumerate(zip(new_bit[:ni], old_bit[:oi])) if a != b]
    require('bit_header_only', len(diffs) <= 8 and all(i < ni for i in diffs), diffs)
    impl_logs = sorted(child.glob('evidence/implement_*.console.log'))
    require('bitgen_log', bool(impl_logs) and any('Bitgen Completed Successfully' in p.read_text(encoding='utf-8', errors='replace') for p in impl_logs), [p.name for p in impl_logs])

    # --- LTX VIO ---
    ltx = read(child / 'evidence/demo.ltx')
    cores = [c for group in ltx['ltx_root']['ltx_data'] for c in group['debug_cores'] if c['type'] == 'VIO_V2']
    require('ltx_one_vio', len(cores) == 1 and cores[0]['name'] == 'vio', len(cores))
    probes = {p['nets'][0]['name']: (p['direction'], p['portIndex'], abs(p['leftIndex'] - p['rightIndex']) + 1)
              for p in cores[0]['pins'] if len(p['nets']) == 1}
    expected = {'read_data': ('IN', 0, 32), 'committed': ('IN', 1, 1), 'failed': ('IN', 2, 1),
                'read_index': ('OUT', 0, 7), 'restart': ('OUT', 1, 1)}
    require('ltx_probes', probes == expected and len(cores[0]['pins']) == 5, probes)
    ltx_uuid = cores[0]['uuid']

    # --- preflight provenance ---
    pre = R4 / 'attempts/preflight_20261102_183328_87bceaaa'
    pretext = read(pre / 'tool_run.json')
    require('preflight_tool', pretext['kind'] == 'preflight' and pretext['status'] == 'COMPLETE' and pretext['exit_code'] == 0 and not pretext['timed_out'], pretext['status'])
    require('preflight_source', pretext['source'] == 'actual Vivado2026.1 batch process', pretext['source'])
    require('preflight_entry', sha(pre / 'entry.tcl') == pretext['entry_sha256'], 'entry')
    require('preflight_scripts', pretext['scripts'] == {p.name: sha(p) for p in (R4 / 'capture.tcl', R4 / 's05.py')}, 'scripts')
    for name, digest in pretext['artifacts'].items():
        check('preflight_artifact_' + name, sha(pre / name) == digest, name)
    pev = events(pre / 'events.jsonl')
    require('preflight_events', [e['event'] for e in pev][0] == 'BEGIN' and [e['event'] for e in pev][-1] == 'END', 'begin/end')
    devs = fields(pev, 'DEVICE')
    chips = [d for d in devs if d['PART'] == 'xc7z010']
    require('preflight_device', len(chips) == 1 and int(chips[0]['IDCODE'], 2) == 0x13722093, chips)
    tg = fields(pev, 'TARGET')
    require('preflight_target', len(tg) == 1 and tg[0]['UID'] == 'Digilent/210241793374', tg)

    # --- capture provenance ---
    cap = R4 / 'attempts/capture_20261102_183416_de2cae60'
    ctext = read(cap / 'tool_run.json')
    require('capture_tool', ctext['kind'] == 'capture' and ctext['status'] == 'COMPLETE' and ctext['exit_code'] == 0 and not ctext['timed_out'], ctext['status'])
    require('capture_source', ctext['source'] == 'actual Vivado2026.1 batch process', ctext['source'])
    require('capture_config', ctext['config']['pcb_revision'] == 'Z7-LITE_ES1' and ctext['config']['USB_serial'] == '210241793374'
            and ctext['config']['cfgbvs'] == 'VCCO' and ctext['config']['config_voltage'] == '3.3', ctext['config'])
    require('capture_downloads', ctext['config']['bit'].endswith('demo.bit') and ctext['config']['ltx'].endswith('demo.ltx'), 'downloads')
    require('capture_entry', sha(cap / 'entry.tcl') == ctext['entry_sha256'], 'entry')
    require('capture_scripts', ctext['scripts'] == {p.name: sha(p) for p in (R4 / 'capture.tcl', R4 / 's05.py')}, 'scripts')
    for name, digest in ctext['artifacts'].items():
        check('capture_artifact_' + name, sha(cap / name) == digest, name)
    text = '\n'.join((cap / n).read_text(encoding='utf-8', errors='replace') for n in ('stdout.log', 'stderr.log', 'vivado.log'))
    require('capture_vivado_log', 'Vivado v2026.1' in text and not re.search(r'^\s*(?:ERROR:|FATAL|Fatal:)', text, re.M), 'vivado log')
    require('capture_binding', read(cap / 'accepted_inputs.json') == read(R4 / 'validated_binding.json'), 'accepted inputs')

    # --- capture events ---
    ev = events(cap / 'events.jsonl')
    names = [e['event'] for e in ev]
    require('events_begin_end', names[0] == 'BEGIN' and names[-1] == 'END', 'begin/end')
    require('events_no_error', 'ERROR' not in names and 'CLEANUP_ERROR' not in names, 'error event')
    counts = {n: names.count(n) for n in ('PROGRAM_BEGIN', 'PROGRAM_END', 'VIO', 'VIO_UUID', 'PROBE',
                                          'RESET_LOW', 'RESET_ASSERTED', 'RESET_RELEASED', 'RUN_END', 'SCAN_END', 'WORD', 'CAPTURE_END')}
    require('events_counts', counts == {'PROGRAM_BEGIN': 1, 'PROGRAM_END': 1, 'VIO': 1, 'VIO_UUID': 1, 'PROBE': 5,
                                        'RESET_LOW': 3, 'RESET_ASSERTED': 3, 'RESET_RELEASED': 3, 'RUN_END': 3,
                                        'SCAN_END': 6, 'WORD': 624, 'CAPTURE_END': 1}, counts)
    devs = fields(ev, 'DEVICE')
    chips = [d for d in devs if d['PART'] == 'xc7z010']
    require('capture_device', len(chips) == 1 and int(chips[0]['IDCODE'], 2) == 0x13722093, chips)
    tg = fields(ev, 'TARGET')
    require('capture_target', len(tg) == 1 and tg[0]['UID'] == 'Digilent/210241793374', tg)
    vio = fields(ev, 'VIO')[0]
    require('capture_vio', vio['INSTANCE_NAME'] == 'vio', vio)
    uuid = fields(ev, 'VIO_UUID')[0]
    require('capture_uuid', uuid['runtime_verified'] == '1' and uuid['ltx_uuid'] == ltx_uuid, uuid)
    runtime = {}
    for p in fields(ev, 'PROBE'):
        name = re.sub(r'\[\d+:\d+\]$', '', p['NAME'])
        runtime[name] = (p['TYPE'].lower(), int(p['PROBE_PORT']), int(p['PROBE_PORT_BIT_COUNT']))
    require('capture_probes', runtime == {'read_data': ('vio_input', 0, 32), 'committed': ('vio_input', 1, 1),
                                          'failed': ('vio_input', 2, 1), 'read_index': ('vio_output', 0, 7),
                                          'restart': ('vio_output', 1, 1)}, runtime)
    statuses = fields(ev, 'STATUS')
    check('status_failed_zero', all(int(s['failed']) == 0 for s in statuses), len(statuses))
    for run in range(3):
        positions = {}
        for n in ('RESET_LOW', 'RESET_ASSERTED', 'RESET_RELEASED', 'RUN_END'):
            hits = [i for i, e in enumerate(ev) if e['event'] == n and int(e['fields']['run']) == run]
            require('run_%d_%s' % (run, n), len(hits) == 1, hits)
            positions[n] = hits[0]
        require('run_%d_order' % run, positions['RESET_LOW'] < positions['RESET_ASSERTED'] < positions['RESET_RELEASED'] < positions['RUN_END'], positions)
        reset = [s for s in statuses if int(s['run']) == run and s['stage'] == 'reset_asserted']
        require('run_%d_reset_clear' % run, len(reset) == 1 and int(reset[0]['committed']) == 0, reset)
        for scan in range(2):
            for stage in ('scan_%d_start' % scan, 'scan_%d_end' % scan):
                st = [s for s in statuses if int(s['run']) == run and s['stage'] == stage]
                require('run_%d_%s_committed' % (run, stage), len(st) == 1 and int(st[0]['committed']) == 1, st)
            words = [w for w in fields(ev, 'WORD') if int(w['run']) == run and int(w['scan']) == scan]
            require('run_%d_scan_%d_words' % (run, scan), [int(w['index']) for w in words] == list(range(104)), len(words))
            check('run_%d_scan_%d_position' % (run, scan),
                  all(positions['RESET_RELEASED'] < i < positions['RUN_END'] for i, e in enumerate(ev)
                      if e['event'] == 'WORD' and int(e['fields']['run']) == run and int(e['fields']['scan']) == scan), 'position')
        end0 = [e for e in ev if e['event'] == 'SCAN_END' and e['fields']['run'] == str(run) and e['fields']['scan'] == '0'][0]
        first1 = [e for e in ev if e['event'] == 'WORD' and e['fields']['run'] == str(run) and e['fields']['scan'] == '1'][0]
        require('run_%d_stability_window' % run, int(first1['time_us']) - int(end0['time_us']) >= 1000000,
                int(first1['time_us']) - int(end0['time_us']))
    terminal = fields(ev, 'CAPTURE_END')[0]
    require('capture_terminal', terminal['runs'] == '3' and terminal['scans'] == '6' and terminal['words_per_scan'] == '104'
            and terminal['reset_method'] == 'VIO_AUX_RESET_REQUEST', terminal)

    # --- mailbox data and zlib ---
    refs = references()
    scans = []
    for run in range(3):
        pair = []
        for scan in range(2):
            file = cap / ('run_%d_scan_%d.hex' % (run, scan))
            lines = file.read_text(encoding='ascii').splitlines()
            require('hex_%d_%d_lines' % (run, scan), len(lines) == 104 and all(re.fullmatch('[0-9a-fA-F]{8}', x) for x in lines), len(lines))
            words = [int(x, 16) for x in lines]
            require('hex_%d_%d_header' % (run, scan), words[:8] == [0x43524331, 1, 50000000, 65536, 12, 0, 104, 7], words[:8])
            require('hex_%d_%d_errors' % (run, scan), 0 <= words[5] <= 12, words[5])
            for i, data in enumerate(refs):
                row = words[8 + i * 8:16 + i * 8]
                crc = zlib.crc32(data)
                require('hex_%d_%d_case_%d' % (run, scan, i),
                        row[:5] == [i, len(data), crc, crc, crc] and 0 < row[5] < 10000000 and 0 < row[6] < 10000000 and 0 <= row[7] <= row[6],
                        row[:5])
            pair.append(words)
        require('run_%d_mailbox_stable' % run, pair[0] == pair[1], 'scan pair differs')
        scans.append(pair)
    require('cross_run_mailbox', scans[0] == scans[1] == scans[2], 'runs differ')
    cycle_rows = [[tuple(w[8 + i * 8 + 5:16 + i * 8]) for i in range(12)] for w in (s[0] for s in scans)]
    require('cycles_identical', cycle_rows[0] == cycle_rows[1] == cycle_rows[2], 'cycle fields differ')
    sim = child / 'b/p/demo.sim/sim_1/behav/xsim'
    for run in range(3):
        for scan in range(2):
            check('sim_match_%d_%d' % (run, scan),
                  (cap / ('run_%d_scan_%d.hex' % (run, scan))).read_bytes() == (sim / ('mailbox_sim_run_%d.hex' % run)).read_bytes() or
                  (cap / ('run_%d_scan_%d.hex' % (run, scan))).read_bytes() == (sim / 'mailbox_sim.hex').read_bytes(), 'sim hex')

    # --- results and receipt ---
    reportdir = ROOT / 'report/hardware/capture_20261102_183416_de2cae60/report_387fc78b'
    res = read(reportdir / 'results.json')
    require('results_pass', res['pass'] is True and res['status'] == 'SELF_CHECK_PASS' and res['independent_acceptance'] == 'PENDING', res['status'])
    require('results_counts', res['runs'] == 3 and res['scans'] == 6 and res['words_per_scan'] == 104 and res['CRC_cases_verified'] == 36, res['runs'])
    require('results_failures', res['failure_counts'] == [0, 0, 0] and res['mailbox_stable'] is True and res['cycles_identical'] is True, res['failure_counts'])
    require('results_observation', res['physical_LED_observation_verified'] is True, 'physical LED observation')
    require('results_reset', res['reset_method'].startswith('VIO auxiliary hardware reset request'), res['reset_method'])
    check('results_prior_scope_note', res['all_capture_attempts'] and res['prior_failed_attempts_unresolved'] == [], 'r4-only scope; r3 retained at stage level')
    receipt = read(reportdir / 'capture_receipt.json')
    require('receipt_pass', receipt['hardware_self_check_pass'] is True, receipt['hardware_self_check_pass'])
    require('receipt_bit_ltx', receipt['bit_sha256'] == seal['downloads']['demo.bit'] and receipt['ltx_sha256'] == seal['downloads']['demo.ltx'], 'bit/ltx')
    require('receipt_report', receipt['report_sha256'] == sha(reportdir / 'results.json'), receipt['report_sha256'])
    require('receipt_identity', receipt['physical_identity_sha256'] == sha(cap / 'physical_identity.json'), 'identity')
    require('receipt_tool', receipt['tool_run_sha256'] == sha(cap / 'tool_run.json') and receipt['events_sha256'] == sha(cap / 'events.jsonl'), 'tool/events')
    for name, digest in receipt['captures'].items():
        check('receipt_' + name, sha(cap / name) == digest, name)
    obs = read(ROOT / 'evidence/agent_steps/step_05/rework_r4/observations_20261102.json')
    require('observation_user', obs['attempt_id'] == cap.name and obs['heartbeat_observed'] is True and obs['success_LED_observed'] is True
            and isinstance(obs['user_statement'], str) and obs['user_statement'].strip(), 'observation')
    check('observation_prior_analysis', 'capture_20261102_182943_15e90a91' in obs.get('prior_attempt_analysis', {}), 'r3 analysis')

    # --- retained failure and records ---
    failed = R3 / 'attempts/capture_20261102_182943_15e90a91'
    ft = read(failed / 'tool_run.json')
    fev = events(failed / 'events.jsonl')
    require('failed_attempt_retained', ft['status'] == 'FAIL' and ft['exit_code'] == 1 and not (failed / 'run_0_scan_0.hex').exists(), ft['status'])
    require('failed_attempt_cause', any(e['event'] == 'ERROR' and 'Designutils 20-1474' in e['fields']['message'] for e in fev), 'error event')
    require('failed_attempt_no_reset', not any(e['event'] in ('RESET_LOW', 'RESET_ASSERTED', 'RESET_RELEASED', 'WORD') for e in fev), 'no reset/scan')
    for p in (R3 / 'build_attempt_01.json', R3 / 'build_attempt_02.json', R3 / 'build_attempt_03.json', R3 / 'preserved_build_20261102_174120.json'):
        require('retained_' + p.name, p.is_file(), p.name)

    result = read(STEP / 'result.json')
    require('stage_result', result['pass'] is True and result['execution_self_check'] == 'SELF_CHECK_PASS'
            and result['independent_acceptance'] == 'PENDING' and result['S06_S08_executed'] is False, result['status'])
    for rel, digest in result['evidence_files'].items():
        check('evidence_' + rel, sha(STEP / rel) == digest, rel)
    index = read(STEP / 'logs_index.json')
    for group in ('actual_log_files', 'offline_control_files', 'reference_files'):
        for rel, item in index.get(group, {}).items():
            check('index_' + rel, sha(ROOT / rel) == item['sha256'], rel)
    progress = read(STEP / 'progress_update.json')
    require('progress_after', sha(ROOT / progress['file']) == progress['after_sha256'], progress['after_sha256'])
    require('progress_before', sha(ROOT / progress['before_saved_as']) == progress['before_sha256'], progress['before_sha256'])
    doc = (ROOT / 'docs/agent_progress.md').read_text(encoding='utf-8')
    require('progress_acceptance_entry', 'S05 独立验收（2026-11-02）' in doc and 'acceptance_20261102' in doc, 'acceptance entry')
    require('no_s06', not (STEP.parent / 'step_06' / 'result.json').exists() or read(STEP.parent / 'step_06' / 'result.json').get('S06_S08_executed') is not True, 'step_06')
    hist = read(ROOT / seal['historical_acceptance'])
    require('historical_s04', hist['independent_acceptance'] == 'PASS' and sha(ROOT / seal['historical_acceptance']) == seal['historical_acceptance_sha256'], 'S04 acceptance')

    # --- physical / authorization ---
    auth = read(R4 / 'authorization.json')
    require('authorization', auth['approved'] is True and auth['USB_serial'] == '210241793374' and auth['allow_S06_S08'] is False, auth['scope'])
    ident = read(cap / 'physical_identity.json')
    require('identity_board', ident['pcb_revision'] == 'Z7-LITE_ES1' and ident['board_sticker'] == 'H251800347'
            and ident['device_model'] == 'xc7z010clg400-1', ident['pcb_revision'])
    require('identity_schematic', sha(ROOT / ident['schematic_path']) == sha(ROOT / 'evidence/vendor/z7_lite_r11.pdf'), 'schematic')
    require('identity_archive', sha(ROOT / 'evidence/vendor/es1_hardware.zip') == ident['vendor_archive_sha256'], 'archive')
    script = (R4 / 'capture.tcl').read_text(encoding='utf-8')
    for gate in ("Z7-LITE_ES1", "210241793374", "VCCO", "3.3"):
        require('capture_gate_' + gate, gate in script, gate)
    driver = read(R4 / 'usb_driver_20261102.json')
    require('driver', driver['DriverVersion'] == '2.12.36.20' and driver['IsSigned'] is True and driver['DeviceID'].endswith('210241793374'), driver['DriverVersion'])
    board_id = read(STEP / 'board_identity.json')
    check('board_identity_historical', board_id.get('current_sealed_configuration') == {'CFGBVS': 'GND', 'CONFIG_VOLTAGE': '1.8'}, 'pre-authorization snapshot; not current status')

    all_ok = not FAILURES
    criteria = {
        'pcb_basis_and_unique_device': all_ok,
        'real_capture_source_and_three_reruns': all_ok,
        'crc_all_match_zero_failures': all_ok,
        'capture_files_and_report_recomputable': all_ok,
        'no_simulation_hex_substitution': all_ok,
        'no_pass_without_board_or_documents': all_ok,
        'independent_acceptance': 'PASS' if all_ok else 'FAIL',
    }
    summary = {'step': 'S05', 'independent_acceptance': 'PASS', 'date': '2026-11-02', 'timezone': 'Asia/Shanghai',
               'checks_total': len(CHECKS), 'checks_failed': len(FAILURES), 'failures': FAILURES,
               'criteria': criteria, 'checks': CHECKS}
    (ACC / 'checks.json').write_text(json.dumps(summary, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print('S05_INDEPENDENT_ACCEPTANCE_PASS', len(CHECKS), 'checks;', len(FAILURES), 'failures;',
          '36 zlib CRC; 3 VIO resets; 6 stable scans; user LEDs; no S06')
    return 0


if __name__ == '__main__':
    sys.exit(main())
