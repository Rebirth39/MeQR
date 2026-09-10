const fs = require('fs');
const path = require('path');
const {execFileSync} = require('child_process');
const root = path.resolve(__dirname, '../..');
const output = process.env.CARD_LAYOUT_OUTPUT || __dirname;
fs.mkdirSync(output, {recursive: true});
if (output !== __dirname) {
  for (const file of ['Host.swift', 'LayoutTests.swift']) fs.copyFileSync(path.join(__dirname, file), path.join(output, file));
}
const source = path.join(root, 'QRID/QRID');
const files = ['Models/QRCluster.swift', 'Models/QRProfile.swift', 'Helpers/RemoteTagCatalog.swift',
  'Helpers/CardTagReference.swift', 'Helpers/CardTagUsageStore.swift', 'Helpers/CardTagOutbox.swift',
  'Helpers/Localization.swift', 'Helpers/ColorExtensions.swift', 'Helpers/QRCodeGenerator.swift',
  'Helpers/QRLinkPolicy.swift', 'Views/CardTagColorEditor.swift', 'Views/CardTagCatalogBrowser.swift',
  'Views/CardTagReorderView.swift', 'Views/CardTagReportView.swift', 'Views/ClusterCardView.swift',
  'Views/ClusterCardPager.swift', 'Helpers/MeQRExchange.swift', 'Helpers/MeQRExchangeCodeStore.swift',
  'Helpers/MeQRRemoteService.swift', 'Helpers/EncounterStore.swift', 'Views/MeQRProfileCodeView.swift',
  'Views/EncountersView.swift', 'Views/QRLinkReviewView.swift'];
fs.writeFileSync(path.join(output, 'Production.swift'), files.map(file => {
  const content = fs.readFileSync(path.join(source, file), 'utf8');
  return content.replaceAll('tagGradientStops(', path.basename(file, '.swift') + 'TagGradientStops(');
}).join('\n'));
// Exercise the exact App Store 1.1.0 decoder against today's confirmation JSON.
const releaseSource = file => execFileSync('git', ['show', '2313ac7:QRID/QRID/' + file], {cwd: root, encoding: 'utf8'});
const releaseExchange = releaseSource('Helpers/MeQRExchange.swift').split('enum MeQRExchangeCodec')[0]
  .replaceAll('MeQRExchangeProfile', 'Release110ExchangeProfile').replaceAll('MeQRExchangePlatform', 'Release110ExchangePlatform');
const releaseRemote = releaseSource('Helpers/MeQRRemoteService.swift');
const releaseSession = releaseRemote.slice(releaseRemote.indexOf('struct MeQREncounterSession:'), releaseRemote.indexOf('private struct EncounterSessionCreationRequest'))
  .replaceAll('MeQREncounterSession', 'Release110EncounterSession').replaceAll('MeQRExchangeProfile', 'Release110ExchangeProfile');
const scanner = fs.readFileSync(path.join(source, 'Views/MeQRScannerView.swift'), 'utf8');
const cameraStart = scanner.indexOf('    private func requestCameraAccessIfNeeded()');
const cameraEnd = scanner.indexOf('    private var canPresentScanResult', cameraStart);
fs.appendFileSync(path.join(output, 'Production.swift'), '\n' + scanner.slice(0, cameraStart) +
  '    private func requestCameraAccessIfNeeded() { cameraAuthorized = true }\n' + scanner.slice(cameraEnd, scanner.indexOf('private struct QRScannerRepresentable:')));
const replyStart = scanner.indexOf('    private func localProfile(');
const redirectStart = scanner.indexOf('    private static func xiaohongshuUserID(');
const redirectEnd = scanner.indexOf('    @MainActor', redirectStart);
fs.appendFileSync(path.join(output, 'Production.swift'), '\n@MainActor enum ScannerRedirectFixture {\n' +
  scanner.slice(redirectStart, redirectEnd).replaceAll('private static', 'static')
    .replace('let config = URLSessionConfiguration.ephemeral', 'let config = URLSessionConfiguration.ephemeral\n            config.protocolClasses = [ExchangeTransport.self]') + '\n}\n');
const reply = scanner.slice(replyStart, scanner.indexOf('    @MainActor', replyStart)).replace('private func', 'func');
fs.appendFileSync(path.join(output, 'Production.swift'), '\n' + releaseExchange + '\n' + releaseSession +
  '\n@MainActor struct ScannerReplyFixture { let localCluster: QRCluster?;\n' + reply + '\n}\n');
fs.copyFileSync(path.join(source, 'tags-v1.json'), path.join(output, 'tags-v1.json'));
// Record requested App launches without opening other apps from UI tests.
const production = path.join(output, 'Production.swift');
fs.writeFileSync(production, fs.readFileSync(production, 'utf8').replaceAll('await UIApplication.shared.open(', 'await PlatformOpenProbe.open('));
fs.copyFileSync('/Users/lucasli/Documents/debug/BG.jpg', path.join(output, 'BG.jpg'));
let project = fs.readFileSync(path.join(root, 'Tests/TagLayoutHarness/TagLayout.xcodeproj/project.pbxproj'), 'utf8');
project = project.replaceAll('TagLayoutHost', 'CardLayoutHost').replaceAll('taglayouthost', 'cardlayouthost').replaceAll('taglayouttests', 'cardlayouttests')
  .replace('path = ../../QRID/QRID/Views/CardTagReorderView.swift', 'path = Production.swift')
  .replace('lastKnownFileType = sourcecode.swift; path = ../../QRID/QRID/Helpers/ColorExtensions.swift', 'lastKnownFileType = text.json; path = tags-v1.json')
  .replace('files = (B001, B003, B004, B005, B006, B007);', 'files = (B001, B003);')
  .replace('buildPhases = (S001);', 'buildPhases = (S001, R001);')
  .replace(' S002 =', ' R001 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (B004); runOnlyForDeploymentPostprocessing = 0; };\n S002 =');
project = project.replace('files = (B004);', 'files = (B004, B008);')
  .replace(' F001 =', ' F008 = {isa = PBXFileReference; lastKnownFileType = image.jpeg; path = BG.jpg; sourceTree = "<group>"; };\n B008 = {isa = PBXBuildFile; fileRef = F008; };\n F001 =');
const projectDir = path.join(output, 'CardLayout.xcodeproj');
fs.mkdirSync(path.join(projectDir, 'xcshareddata/xcschemes'), {recursive:true});
fs.writeFileSync(path.join(projectDir, 'project.pbxproj'), project);
const scheme = fs.readFileSync(path.join(root, 'Tests/TagLayoutHarness/TagLayout.xcodeproj/xcshareddata/xcschemes/TagLayoutHost.xcscheme'), 'utf8')
  .replaceAll('TagLayoutHost', 'CardLayoutHost').replaceAll('TagLayout.xcodeproj', 'CardLayout.xcodeproj');
fs.writeFileSync(path.join(projectDir, 'xcshareddata/xcschemes/CardLayoutHost.xcscheme'), scheme);
