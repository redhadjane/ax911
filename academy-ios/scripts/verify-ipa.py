import hashlib,json,plistlib,sys,zipfile
from pathlib import Path
p=Path(sys.argv[1]); base='Payload/HOPAcademy.app/'
with zipfile.ZipFile(p) as z:
    assert z.testzip() is None
    info=plistlib.loads(z.read(base+'Info.plist'))
    assert info['CFBundleIdentifier']=='com.houseofpizza.academy.ios'
    assert info['CFBundleShortVersionString']=='1.0.0'
    assert sorted(info['UIDeviceFamily'])==[1,2]
    assert info['MinimumOSVersion']=='17.0'
    assert info['CFBundleSupportedPlatforms']==['iPhoneOS']
    assert 'UIInterfaceOrientationLandscapeLeft' in info['UISupportedInterfaceOrientations~ipad']
    catalog=json.loads(z.read(base+'catalog.json'))
    assert len(catalog['questions'])==168 and len(catalog['objectives'])==64
    assert all(q['original'] for q in catalog['questions'])
    assert z.read(base+'HOPAcademy')[:4] in [b'\xcf\xfa\xed\xfe',b'\xca\xfe\xba\xbe']
    privacy=plistlib.loads(z.read(base+'PrivacyInfo.xcprivacy'))
    assert privacy['NSPrivacyTracking'] is False
    assert not privacy['NSPrivacyCollectedDataTypes']
    assert not any('/.env' in name or 'progress-v1.json' in name for name in z.namelist())
    print(json.dumps({'app':info['CFBundleDisplayName'],'bundle':info['CFBundleIdentifier'],'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],'devices':info['UIDeviceFamily'],'minimumOS':info['MinimumOSVersion'],'questions':len(catalog['questions']),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()},indent=2))
