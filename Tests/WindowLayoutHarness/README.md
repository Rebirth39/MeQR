# Window layout regression

Uses the existing CoreUXHarness generator to compile production views with an isolated, in-memory fixture. Generate into /private/tmp; put logs and exported screenshots under Documents/TestsScreenshot. No real profiles or network submissions are used. The generator retains the existing optional BG.jpg fixture dependency documented by CoreUXHarness.

Example from the repository root:

```sh
python3 Tests/WindowLayoutHarness/generate.py /private/tmp/meqr-window-regression
xcodebuild test -project /private/tmp/meqr-window-regression/CoreUX.xcodeproj -scheme CoreUXHost -destination 'platform=iOS Simulator,id=<iPad simulator UUID>' -derivedDataPath /private/tmp/meqr-window-regression/derived -resultBundlePath /private/tmp/meqr-window-regression/results.xcresult -parallel-testing-enabled NO
```

Eight test methods exercise widths 320, 375, 480, 520, 620, 800 and 900pt, regular/compact size classes, 800/320pt heights, standard/Rhodes styles, a colored QR over a background image, and accessibility text size. The exchange page is also checked at 320/375pt with its synthetic offline session QR. They verify visible QR payloads, horizontal containment, scrolling to reach platform buttons, and selecting WeChat in a short window. Vision failures are logged and CoreImage remains available as a fallback. Decoding uses a crop of the actual viewport screenshot.

These are controlled same-size viewports inside an iPad simulator. They do not claim physical-camera scan reliability or actual Stage Manager window-resize coverage. iOS 27 may hang while collecting many attachments after the test cases finish; preserve the raw log and use per-method runs for readable result bundles, without restarting services or changing assertions.
