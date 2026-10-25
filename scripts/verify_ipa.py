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
    # Older SideSign versions send this name directly to Apple's ASCII-only
    # appIdName field (SideStore issue #1489), reported as error 10.
    assert p['CFBundleDisplayName'] == 'Ritm'
    assert p['CFBundleDisplayName'].isascii()
    assert p['CFBundleShortVersionString'] == '2.0.1'
    assert p['CFBundleVersion'] == '3'
    extensions = [n for n in z.namelist() if n.endswith('.appex/Info.plist')]
    if 'Full' in sys.argv[1]:
        assert len(extensions) == 1
        assert p['NRAppGroup'] == 'group.app.nezhnyritm.shared'
        ep = plistlib.loads(z.read(extensions[0]))
        assert ep['CFBundleDisplayName'] == 'Ritm'
        assert ep['CFBundleShortVersionString'] == p['CFBundleShortVersionString']
        assert ep['CFBundleVersion'] == p['CFBundleVersion']
        assert ep['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.widgetkit-extension'
        assert ep['NRAppGroup'] == p['NRAppGroup']
        executable = extensions[0].removesuffix('Info.plist') + ep['CFBundleExecutable']
        eb = z.read(executable)
        assert eb[:4] == b'\xcf\xfa\xed\xfe' and struct.unpack('<I', eb[4:8])[0] == 0x100000c
    else:
        assert not extensions, 'Base and HealthKit variants must not embed extensions'
        assert 'NRAppGroup' not in p
    print(f'IPA verified: {p["CFBundleIdentifier"]}, iOS {p["MinimumOSVersion"]}, ARM64, {len(binary):,} executable bytes')
