const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const catalog=JSON.parse(read('Resources/catalog.json'));
assert.equal(catalog.questions.length,168);assert.equal(catalog.objectives.length,64);
const project=read('HOPAcademy.xcodeproj/project.pbxproj');
assert.match(project,/TARGETED_DEVICE_FAMILY="1,2"/);assert.match(project,/IPHONEOS_DEPLOYMENT_TARGET=17.0/);
const files=fs.readdirSync(path.join(root,'Sources')).filter(f=>f.endsWith('.swift'));
for(const file of files){assert.ok(project.includes(`Sources/${file}`));assert.doesNotMatch(read(`Sources/${file}`),/WKWebView|URLSession|api\/|AVCaptureSession|CLLocationManager/);}
assert.match(read('Sources/AcademyApp.swift'),/NavigationSplitView/);assert.match(read('Sources/AcademyApp.swift'),/TabView/);
assert.match(read('Sources/AcademyStore.swift'),/\.atomic/);assert.match(read('Sources/AcademyStore.swift'),/completeFileProtectionUntilFirstUserAuthentication/);
for(const s of catalog.sources)assert.ok(new URL(s.url).protocol==='https:');
for(const q of catalog.questions)assert.equal(q.original,true);
const icon=fs.readFileSync(path.join(root,'Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png'));assert.equal(icon.readUInt32BE(16),1024);assert.equal(icon.readUInt32BE(20),1024);
console.log(`Native iPhone/iPad source and package checks passed; ${files.length} Swift files, ${catalog.questions.length} original questions.`);
