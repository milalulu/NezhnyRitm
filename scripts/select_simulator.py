"""Prefer an XR; fall back to iPhone 11 with the same 414×896 pt screen."""
import json
import os
import subprocess


def simctl(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True)


runtimes = [r for r in json.loads(simctl('list', 'runtimes', '-j'))['runtimes']
            if r.get('isAvailable') and 'iOS' in r['name']]
runtimes.sort(key=lambda r: tuple(map(int, r['version'].split('.'))), reverse=True)
selected = None
for device in ['iPhone-XR', 'iPhone-11']:
    for runtime in runtimes:
        # XR supports iOS 16–18; iPhone 11 also supports newer runtimes.
        if device == 'iPhone-XR' and int(runtime['version'].split('.')[0]) > 18:
            continue
        result = subprocess.run(['xcrun', 'simctl', 'create', 'NezhnyRitm ' + device,
                                 'com.apple.CoreSimulator.SimDeviceType.' + device, runtime['identifier']],
                                capture_output=True, text=True)
        if result.returncode == 0:
            selected = result.stdout.strip()
            print(device, runtime['name'], selected)
            break
    if selected:
        break
if not selected:
    groups = json.loads(simctl('list', 'devices', 'available', '-j'))['devices']
    selected = next(d['udid'] for runtime, devices in groups.items() if 'iOS' in runtime
                    for d in devices if 'iPhone' in d['name'] and d.get('isAvailable'))
    print('Fallback available iPhone:', selected)
with open(os.environ['GITHUB_ENV'], 'a') as f:
    f.write('SIMULATOR_ID=' + selected + '\n')
