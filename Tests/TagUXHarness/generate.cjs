const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '../..');
const source = path.join(root, 'QRID/QRID');
const files = ['Models/QRCluster.swift', 'Helpers/RemoteTagCatalog.swift', 'Helpers/CardTagReference.swift',
  'Helpers/CardTagUsageStore.swift', 'Helpers/CardTagOutbox.swift', 'Helpers/Localization.swift', 'Helpers/ColorExtensions.swift',
  'Views/CardTagColorEditor.swift', 'Views/CardTagCatalogBrowser.swift', 'Views/CardTagReorderView.swift', 'Views/CardTagReportView.swift'];
fs.writeFileSync(path.join(__dirname, 'Production.swift'), '// Generated from production sources by generate.cjs.\n' + files.map(file => fs.readFileSync(path.join(source, file), 'utf8')).join('\n'));
fs.copyFileSync(path.join(source, 'tags-v1.json'), path.join(__dirname, 'tags-v1.json'));
let project = fs.readFileSync(path.join(root, 'Tests/TagLayoutHarness/TagLayout.xcodeproj/project.pbxproj'), 'utf8');
project = project.replaceAll('TagLayoutHost', 'TagUXHost').replaceAll('taglayouthost', 'taguxhost').replaceAll('taglayouttests', 'taguxtests')
  .replace('path = LayoutTests.swift', 'path = UXTests.swift')
  .replace('path = ../../QRID/QRID/Views/CardTagReorderView.swift', 'path = Production.swift')
  .replace('lastKnownFileType = sourcecode.swift; path = ../../QRID/QRID/Helpers/ColorExtensions.swift', 'lastKnownFileType = text.json; path = tags-v1.json')
  .replace('S001 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (B001, B003, B004, B005, B006, B007);', 'S001 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (B001, B003);')
  .replace('buildPhases = (S001);', 'buildPhases = (S001, R001);')
  .replace(' S002 =', ' R001 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (B004); runOnlyForDeploymentPostprocessing = 0; };\n S002 =');
const projectDir = path.join(__dirname, 'TagUX.xcodeproj');
fs.mkdirSync(path.join(projectDir, 'xcshareddata/xcschemes'), {recursive:true});
fs.writeFileSync(path.join(projectDir, 'project.pbxproj'), project);
const scheme = fs.readFileSync(path.join(root, 'Tests/TagLayoutHarness/TagLayout.xcodeproj/xcshareddata/xcschemes/TagLayoutHost.xcscheme'), 'utf8')
  .replaceAll('TagLayoutHost','TagUXHost').replaceAll('TagLayout.xcodeproj','TagUX.xcodeproj');
fs.writeFileSync(path.join(projectDir, 'xcshareddata/xcschemes/TagUXHost.xcscheme'), scheme);
