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

enum ClipperHost {
    // Retained as the signed containing app for the Safari share extension.
    // Normal launch creates no UI, touches no credentials and exits immediately.
    static func run() -> Int32 { 0 }
}
exit(ClipperHost.run())
