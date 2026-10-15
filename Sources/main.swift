// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit

if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--cloud-self-test" { exit(cloudClipperSelfTest()) }
if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--session-self-test" { exit(sessionClipperSelfTest()) }
if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--submission-self-test" { exit(submissionClipperSelfTest()) }
if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--share-ui-self-test" { exit(shareUIClipperSelfTest()) }
if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--public-image-self-test" {
    // One fixed public upstream PNG, no account/keychain and no arbitrary URL option.
    let capture = ClipResources(); var done = false, code: Int32 = 1
    let url = "https://raw.githubusercontent.com/WizTeam/WizQTClient/master/share/files/errorpage/load_error.png"
    capture.embed(html: "<img src=\"\(url)\" data-wiz-clip-resource=\"0\">", urls: [url], progress: { _,_ in }) { html, missing in
        let success = missing == 0 && html.contains("data:image/png;base64,")
        print("\(success ? "PASS" : "FAIL") production image download, validation and embedding; public PNG only, no cloud credentials")
        code = success ? 0 : 1; done = true
    }
    let deadline = Date().addingTimeInterval(16)
    while !done && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    exit(code)
}
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--capture-self-test" {
    exit(captureClipperSelfTest(fixture: CommandLine.arguments[2]))
}
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--wiki-capture-self-test" {
    exit(captureClipperSelfTest(fixture: CommandLine.arguments[2], publicWiki: true))
}

if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--input-self-test" {
    var checks = 0, failures = 0
    func check(_ ok: Bool, _ text: String) { checks += 1; if !ok { failures += 1 }; print("\(ok ? "PASS" : "FAIL") \(text)") }
    let input: [String: Any] = ["title": "中文网页", "url": "https://example.invalid/article", "pageHTML": "<p>正文</p>",
        "selectionHTML": "<blockquote>选中</blockquote>", "text": "正文", "selectionText": "选中"]
    let valid = try? ClipInput(dictionary: input)
    check(valid?.title == "中文网页" && valid?.text == "正文", "Unicode title and body retained")
    check(valid?.selectionHTML == "<blockquote>选中</blockquote>", "selection retained separately from whole page")
    for url in ["file:///private", "javascript:alert(1)", "https://user:password@example.invalid/", "https:///missing"] {
        var bad = input; bad["url"] = url
        check((try? ClipInput(dictionary: bad)) == nil, "reject unsafe source URL")
    }
    var empty = input; empty["pageHTML"] = ""; empty["selectionHTML"] = ""
    check((try? ClipInput(dictionary: empty)) == nil, "link-only sharing is not called full clipping")
    var huge = input; huge["pageHTML"] = String(repeating: "x", count: ClipInput.maximumBytes + 1)
    check((try? ClipInput(dictionary: huge)) == nil, "oversized content rejected without silent truncation")
    var tooMany = input; tooMany["resources"] = Array(repeating: "https://example.invalid/a.png", count: 49)
    check((try? ClipInput(dictionary: tooMany)) == nil, "excessive resource manifest rejected")
    var warning = input; warning["warnings"] = -4
    check((try? ClipInput(dictionary: warning))?.warnings == 0, "invalid warning count cannot become negative")
    print("Native clipper input checks: \(checks), failures: \(failures)")
    exit(failures == 0 ? 0 : 1)
}
if CommandLine.arguments.count > 1 {
    fputs("Unknown test option; normal startup refused.\n", stderr); exit(2)
}

final class ClipperHost: NSObject, NSApplicationDelegate {
    static let webVersionURL = ClipperLinks.webVersionURL
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = makeWindow(); window?.center(); window?.makeKeyAndOrderFront(nil)
        let menu = NSMenu(); let root = NSMenuItem(); menu.addItem(root)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "退出网页剪藏", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = appMenu; NSApp.mainMenu = menu
    }
    func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 570, height: 350),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "WizNotePlus 网页剪藏"
        let text = NSTextField(wrappingLabelWithString:
            "WizNotePlus 网页剪藏 0.3.3\n\n在 Safari 中打开网页，点击“分享 → WizNotePlus 网页剪藏”。\n\n登录为知账号，选择文件夹，即可保存正文或选中内容。\n支持保留图片和静态公式，无需运行主 App。\n\n上传需要联网；勾选“记住密码”后，下次可继续使用。")
        text.frame = NSRect(x: 24, y: 76, width: 520, height: 250); window.contentView?.addSubview(text)
        let web = NSButton(title: "打开网页版", target: self, action: #selector(openWebVersion(_:)))
        web.bezelStyle = .rounded; web.frame = NSRect(x: 24, y: 22, width: 126, height: 32)
        window.contentView?.addSubview(web)
        return window
    }
    @objc func openWebVersion(_ sender: Any?) {
        NSWorkspace.shared.open(Self.webVersionURL)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = ClipperHost(); application.delegate = delegate
application.run()
