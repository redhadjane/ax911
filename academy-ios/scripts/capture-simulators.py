import json,subprocess,time,os
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'build'/'screenshots';out.mkdir(parents=True,exist_ok=True)
def run(*args,check=True):
    # Keep simulator startup output attached to the runner. Only queries need pipes;
    # booted processes can retain inherited pipe handles after simctl itself exits.
    capture='list' in args or 'get_app_container' in args
    return subprocess.run(args,check=check,capture_output=capture,text=True,timeout=240)
devices=json.loads(run('xcrun','simctl','list','devices','available','--json').stdout)['devices']
available=[d for runtime,ds in devices.items() if 'iOS' in runtime for d in ds if d.get('isAvailable')]
app=root/'build'/'Simulator'/'Build'/'Products'/'Debug-iphonesimulator'/'HOPAcademy.app'
bundle='com.houseofpizza.academy.ios'
def capture(udid,name,args=(),appearance='light'):
    run('xcrun','simctl','terminate',udid,bundle,check=False)
    run('xcrun','simctl','ui',udid,'appearance',appearance)
    run('xcrun','simctl','launch',udid,bundle,*args)
    time.sleep(5)
    run('xcrun','simctl','io',udid,'screenshot',str(out/'warmup.png'))
    time.sleep(2)
    run('xcrun','simctl','io',udid,'screenshot',str(out/(name+'.png')))
    print('Captured '+name,flush=True)
for family in ['iPad','iPhone']:
    options=[d for d in available if d['name'].startswith(family)]
    device=next((d for d in options if ('Pro' in d['name'] and ('11-inch' in d['name'] if family=='iPad' else True))),options[0])
    udid=device['udid'];print('Booting '+device['name'],flush=True)
    run('open','-a','Simulator','--args','-CurrentDeviceUDID',udid,check=False)
    run('xcrun','simctl','boot',udid,check=False)
    try: run('xcrun','simctl','bootstatus',udid,'-b')
    except subprocess.TimeoutExpired:
        print('Startup exceeded four minutes; attempting app installation on the booted device.',flush=True)
    run('xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100')
    run('xcrun','simctl','install',udid,str(app))
    prefix=family.lower()
    capture(udid,prefix+'-today',('-snapshot-reset',))
    capture(udid,prefix+'-question',('-snapshot-reset','-snapshot-question'))
    capture(udid,prefix+'-dark-exam',('-snapshot-reset','-snapshot-exam'),'dark')
    run('xcrun','simctl','terminate',udid,bundle,check=False)
    container=Path(run('xcrun','simctl','get_app_container',udid,bundle,'data').stdout.strip())
    progress=container/'Library'/'Application Support'/'HOPAcademy'/'progress-v1.json'
    state=json.loads(progress.read_text())
    assert len(state['sessions'])==1 and state['sessions'][0]['mode']=='exam'
    deadline=state['sessions'][0]['deadline'];sid=state['sessions'][0]['id']
    run('xcrun','simctl','launch',udid,bundle)
    time.sleep(2)
    restored=json.loads(progress.read_text())
    assert restored['sessions'][0]['id']==sid and restored['sessions'][0]['deadline']==deadline
    print(f'{family}: simulator save/relaunch/deadline check passed',flush=True)
    if family=='iPhone': (root/'build'/'simulator-iphone.txt').write_text(udid)
    else: run('xcrun','simctl','shutdown',udid)
(out/'warmup.png').unlink(missing_ok=True)
