// Deterministic project generation; no business data or credentials.
const fs=require('node:fs'),path=require('node:path'),root=path.resolve(__dirname,'..');
const sources=['AcademyCore','AcademyStore','AcademyDesign','AcademyApp','AcademyHome','AcademyLibrary','AcademyStudy'].map(n=>`Sources/${n}.swift`);
const resources=['Resources/Assets.xcassets','Resources/PrivacyInfo.xcprivacy','Resources/catalog.json'],files=[...sources,...resources];
const id=n=>'A'+String(n).padStart(23,'0'),obj=[];function put(n,value){obj.push(`${id(n)} = {${value}};`)}
put(1,`isa=PBXProject;buildConfigurationList=${id(10)};compatibilityVersion="Xcode 14.0";developmentRegion=en;knownRegions=(en,Base);mainGroup=${id(2)};productRefGroup=${id(3)};projectDirPath="";projectRoot="";targets=(${id(4)},${id(75)});attributes={LastUpgradeCheck=1640;};`);
put(2,`isa=PBXGroup;children=(${files.map((_,i)=>id(100+i)).join(',')},${id(70)},${id(3)});sourceTree="<group>";`);
put(3,`isa=PBXGroup;children=(${id(5)},${id(76)});name=Products;sourceTree="<group>";`);
put(4,`isa=PBXNativeTarget;buildConfigurationList=${id(11)};buildPhases=(${id(6)},${id(7)},${id(8)});buildRules=();dependencies=();name=HOPAcademy;productName=HOPAcademy;productReference=${id(5)};productType="com.apple.product-type.application";`);
put(5,'isa=PBXFileReference;explicitFileType=wrapper.application;includeInIndex=0;path=HOPAcademy.app;sourceTree=BUILT_PRODUCTS_DIR;');
put(6,`isa=PBXSourcesBuildPhase;buildActionMask=2147483647;files=(${sources.map((_,i)=>id(200+i)).join(',')});runOnlyForDeploymentPostprocessing=0;`);
put(7,'isa=PBXFrameworksBuildPhase;buildActionMask=2147483647;files=();runOnlyForDeploymentPostprocessing=0;');
put(8,`isa=PBXResourcesBuildPhase;buildActionMask=2147483647;files=(${resources.map((_,i)=>id(200+sources.length+i)).join(',')});runOnlyForDeploymentPostprocessing=0;`);
put(10,`isa=XCConfigurationList;buildConfigurations=(${id(40)},${id(41)});defaultConfigurationIsVisible=0;defaultConfigurationName=Release;`);
put(11,`isa=XCConfigurationList;buildConfigurations=(${id(42)},${id(43)});defaultConfigurationIsVisible=0;defaultConfigurationName=Release;`);
files.forEach((file,i)=>{put(100+i,`isa=PBXFileReference;lastKnownFileType=${file.endsWith('.swift')?'sourcecode.swift':file.endsWith('.xcassets')?'folder.assetcatalog':file.endsWith('.json')?'text.json':'text.xml'};path="${file}";sourceTree="<group>";`);put(200+i,`isa=PBXBuildFile;fileRef=${id(100+i)};`)});
['Debug','Release'].forEach((name,i)=>{put(40+i,`isa=XCBuildConfiguration;name=${name};buildSettings={CLANG_ENABLE_MODULES=YES;SDKROOT=iphoneos;IPHONEOS_DEPLOYMENT_TARGET=17.0;SWIFT_VERSION=5.0;OTHER_SWIFT_FLAGS="-Xfrontend -solver-expression-time-threshold=15";${i?'SWIFT_COMPILATION_MODE=singlefile;SWIFT_OPTIMIZATION_LEVEL="-O";':''}};`);put(42+i,`isa=XCBuildConfiguration;name=${name};buildSettings={ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon;CODE_SIGN_STYLE=Automatic;CURRENT_PROJECT_VERSION=1;GENERATE_INFOPLIST_FILE=NO;INFOPLIST_FILE=Info.plist;MARKETING_VERSION=1.0.0;PRODUCT_BUNDLE_IDENTIFIER=com.houseofpizza.academy.ios;PRODUCT_NAME="$(TARGET_NAME)";TARGETED_DEVICE_FAMILY="1,2";SUPPORTS_MACCATALYST=NO;SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD=NO;};`)});

put(70,'isa=PBXFileReference;lastKnownFileType=sourcecode.swift;path="UITests/AcademyUITests.swift";sourceTree="<group>";');
put(71,`isa=PBXBuildFile;fileRef=${id(70)};`);
put(72,`isa=PBXSourcesBuildPhase;buildActionMask=2147483647;files=(${id(71)});runOnlyForDeploymentPostprocessing=0;`);
put(73,'isa=PBXFrameworksBuildPhase;buildActionMask=2147483647;files=();runOnlyForDeploymentPostprocessing=0;');
put(74,'isa=PBXResourcesBuildPhase;buildActionMask=2147483647;files=();runOnlyForDeploymentPostprocessing=0;');
put(75,`isa=PBXNativeTarget;buildConfigurationList=${id(77)};buildPhases=(${id(72)},${id(73)},${id(74)});buildRules=();dependencies=(${id(80)});name=HOPAcademyUITests;productName=HOPAcademyUITests;productReference=${id(76)};productType="com.apple.product-type.bundle.ui-testing";`);
put(76,'isa=PBXFileReference;explicitFileType=wrapper.cfbundle;includeInIndex=0;path=HOPAcademyUITests.xctest;sourceTree=BUILT_PRODUCTS_DIR;');
put(77,`isa=XCConfigurationList;buildConfigurations=(${id(78)},${id(79)});defaultConfigurationIsVisible=0;defaultConfigurationName=Release;`);
['Debug','Release'].forEach((name,i)=>put(78+i,`isa=XCBuildConfiguration;name=${name};buildSettings={CODE_SIGN_STYLE=Automatic;GENERATE_INFOPLIST_FILE=YES;PRODUCT_BUNDLE_IDENTIFIER=com.houseofpizza.academy.uitests;PRODUCT_NAME="$(TARGET_NAME)";TARGETED_DEVICE_FAMILY="1,2";TEST_TARGET_NAME=HOPAcademy;SWIFT_VERSION=5.0;};`));
put(80,`isa=PBXTargetDependency;target=${id(4)};targetProxy=${id(81)};`);
put(81,`isa=PBXContainerItemProxy;containerPortal=${id(1)};proxyType=1;remoteGlobalIDString=${id(4)};remoteInfo=HOPAcademy;`);

fs.writeFileSync(path.join(root,'HOPAcademy.xcodeproj/project.pbxproj'),`// !$*UTF8*$!\n{archiveVersion=1;classes={};objectVersion=56;objects={\n${obj.join('\n')}\n};rootObject=${id(1)};}\n`);
console.log(`Native target: ${sources.length} Swift files, ${resources.length} resources, no web workspace.`);
