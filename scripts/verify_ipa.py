import sys, zipfile, plistlib, struct
with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None
    prefix='Payload/NezhnyRitm.app/'
    p=plistlib.loads(z.read(prefix+'Info.plist'))
    assert p['CFBundleIdentifier']=='app.nezhnyritm.NezhnyRitm'
    assert p['CFBundleSupportedPlatforms']==['iPhoneOS']
    assert p['MinimumOSVersion']=='16.0'
    binary=z.read(prefix+p['CFBundleExecutable'])
    assert binary[:4] == b'\xcf\xfa\xed\xfe', 'Expected arm64 Mach-O, not simulator/HTML'
    assert struct.unpack('<I', binary[4:8])[0] == 0x100000c, 'Expected ARM64'
    assert prefix+'Assets.car' in z.namelist()
    assert not any(n.endswith('embedded.mobileprovision') for n in z.namelist())
    print(f'IPA verified: {p["CFBundleIdentifier"]}, iOS {p["MinimumOSVersion"]}, ARM64, {len(binary):,} executable bytes')
