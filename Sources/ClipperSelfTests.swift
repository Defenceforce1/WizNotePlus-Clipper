// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import WebKit

func cloudClipperSelfTest() -> Int32 {
    var checks = 0, failures = 0
    func check(_ ok: Bool, _ title: String) { checks += 1; if !ok { failures += 1 }; print("\(ok ? "PASS" : "FAIL") \(title)") }
    let kb = "00000000-0000-0000-0000-000000000001", user = "00000000-0000-0000-0000-000000000002"
    let account = try! CloudClipAccount(["token": "synthetic-only-token", "kbGuid": kb, "userGuid": user, "userID": "synthetic@example.invalid"])
    check((try? CloudClipAccount(account.dictionary))?.kbGuid == kb, "own account roundtrip")
    var invalid = account.dictionary; invalid["token"] = "secret\r\nInjected: header"
    check((try? CloudClipAccount(invalid)) == nil, "reject token header injection")
    invalid = account.dictionary; invalid["kbGuid"] = "../../other"
    check((try? CloudClipAccount(invalid)) == nil, "reject arbitrary KB path")
    for folder in ["/../", "/Deleted Items/", "/a//b/", "/a\\b/", "missing slash"] {
        check(!CloudClipClient.folderIsValid(folder), "reject unsafe folder")
    }
    let id = UUID().uuidString.lowercased()
    let body = try! CloudClipClient.gatherBody(account: account, requestID: id, title: "公式测试", folder: "/网页剪藏/",
        sourceURL: "https://example.invalid/math", html: "<math><msup><mi>x</mi><mn>2</mn></msup></math><img src=\"data:image/png;base64,TEST\">")
    let frame = body["data"] as! String
    check(frame.contains("SaveResources='true'") && body["customId"] as? String == id, "HTML resource gather with stable document ID")
    let regex = try! NSRegularExpression(pattern: "0_FrameHtml='([^']+)'")
    let match = regex.firstMatch(in: frame, range: NSRange(frame.startIndex..., in: frame))!
    let encoded = String(frame[Range(match.range(at: 1), in: frame)!])
    let decoded = String(data: Data(base64Encoded: encoded)!, encoding: .utf8)!
    check(decoded.contains("<math>") && decoded.contains("data:image/png") && decoded.contains("<!DOCTYPE html>"), "upload retains HTML/math/images, not Markdown")
    check(decoded.contains("<title>公式测试</title>"), "edited title also appears in HTML document metadata")
    let renamed = "新标题 & </title><script>bad</script> 中文"
    let renamedBody = try! CloudClipClient.gatherBody(account: account, requestID: id, title: renamed, folder: "/网页剪藏/", sourceURL: "https://example.invalid/math", html: "<p>body</p>")
    let renamedFrame = renamedBody["data"] as! String
    let renamedMatch = regex.firstMatch(in: renamedFrame, range: NSRange(renamedFrame.startIndex..., in: renamedFrame))!
    let renamedHTML = String(data: Data(base64Encoded: String(renamedFrame[Range(renamedMatch.range(at: 1), in: renamedFrame)!]))!, encoding: .utf8)!
    check(renamedFrame.contains("param-title='" + Data(renamed.utf8).base64EncodedString() + "'"), "Unicode renamed title is preserved in the gather parameter")
    check(renamedHTML.contains("<title>新标题 &amp; &lt;/title&gt;&lt;script&gt;bad&lt;/script&gt; 中文</title>") && !renamedHTML.contains("<script>"), "renamed title cannot inject HTML or close its title element")
    var requests: [URLRequest] = [], uploadReply: [String: Any] = ["code": 200, "id": "synthetic-task"]
    let client = CloudClipClient(transport: { request, callback in
        requests.append(request)
        switch request.url!.path {
        case "/as/user/login": callback(.success(["code": 200, "result": account.dictionary]))
        case "/ks/category/all/" + kb: callback(.success(["code": 200, "result": ["/有效/", "/../", "/有效/"]]))
        case "/ks/gather": callback(.success(uploadReply))
        default: callback(.failure(ClipperError.message("Unexpected endpoint")))
        }
    })
    var logged = false
    client.login(userID: account.userID, password: "synthetic-password") { logged = (try? $0.get())?.kbGuid == kb }
    check(logged && requests[0].httpMethod == "POST", "independent login through injected transport only")
    check(requests[0].url!.scheme == "https" && requests[0].url!.host == "note.wiz.cn"
        && !requests[0].url!.absoluteString.contains("password"), "fixed official HTTPS; no secrets in URL")
    var folders: [String] = []
    client.folders(account: account) { folders = (try? $0.get()) ?? [] }
    check(folders == ["/有效/", "/网页剪藏/"], "destination folder validation and deduplication")
    var task: String?
    client.upload(body: body, account: account) { task = (try? $0.get())?.taskID }
    check(task == "synthetic-task" && requests.filter({ $0.httpMethod == "POST" && $0.url!.path == "/ks/gather" }).count == 1, "submit once, no automatic POST retry")
    check(requests.last!.value(forHTTPHeaderField: "X-Wiz-Token") == account.token, "cloud token scoped to official API")
    check(!requests.contains(where: { $0.url!.path.contains("status") }), "upload never queries task status")
    uploadReply = ["code": 200]; var acceptedWithoutID = false
    client.upload(body: body, account: account) { if case .success(let receipt) = $0 { acceptedWithoutID = receipt.taskID == nil } }
    check(acceptedWithoutID, "API acceptance without optional task ID is not retried or called saved")
    uploadReply = ["code": 500]; var rejected = false
    client.upload(body: body, account: account) { if case .failure = $0 { rejected = true } }
    check(rejected && requests.filter({ $0.url!.path == "/ks/gather" }).count == 3, "API errors are reported without automatic resubmission")
    for raw in ["http://example.invalid/a.png", "https://127.0.0.1/a.png", "https://example.local/a.png", "https://user:pass@example.invalid/a.png", "https://example.invalid:8849/a.png"] {
        check(!ClipResourcePolicy.urlIsAllowed(URL(string: raw)!), "reject unsafe image destination")
    }
    check(ClipResourcePolicy.ipv4IsPublic([8,8,8,8]) && !ClipResourcePolicy.ipv4IsPublic([10,1,2,3])
        && !ClipResourcePolicy.ipv4IsPublic([169,254,169,254]), "private and metadata IPs rejected")
    check(ClipResourcePolicy.pngData(Data("<script>not image</script>".utf8)) == nil, "reject non-image content before embedding")
    let resources = ClipResources(fetch: { url, completion in
        check(url.host == "example.invalid", "resource fetch is isolated from cloud transport")
        completion(Data([1,2,3])) // Prevalidated test transport result, not production image decoder.
    })
    var embedded = false
    resources.embed(html: "<p>文字</p><img src=\"https://example.invalid/a.png\" data-wiz-clip-resource=\"0\">", urls: ["https://example.invalid/a.png"], progress: { _,_ in }) { html, missing in
        embedded = html.contains("data:image/png;base64,") && !html.contains("data-wiz-clip-resource") && missing == 0
    }
    check(embedded, "captured remote resource replaced with embedded image")
    var skipped = false
    resources.embed(html: "<p>selected text only</p>", urls: ["https://example.invalid/a.png"], progress: { _,_ in }) { html, _ in skipped = !html.contains("img") }
    check(skipped, "selection does not fetch images from whole-page-only manifest entries")
    let failedResources = ClipResources(fetch: { _, completion in completion(nil) })
    var fallback = ""
    failedResources.embed(html: "<img alt=\"α\" src=\"https://example.invalid/m.svg\" data-wiz-clip-resource=\"0\">", urls: ["https://example.invalid/m.svg"], progress: { _,_ in }) { html, missing in fallback = html; check(missing == 1, "failed image counted once") }
    check(fallback.contains(">α</a>") && fallback.contains("href=\"https://example.invalid/m.svg\"") && !fallback.contains("未能嵌入，请查看原网页]"), "failed image keeps concise alt and original link without noisy placeholder")
    failedResources.embed(html: "<img alt=\"&lt;x&gt;\" src=\"javascript:alert(1)\" data-wiz-clip-resource=\"0\">", urls: ["javascript:alert(1)"], progress: { _,_ in }) { html, _ in fallback = html }
    check(!fallback.contains("href=") && !fallback.contains("<x>"), "fallback does not turn unsafe URLs or alt into active markup")
    resources.embed(html: "<img alt=\"diagram\" style=\"width:20px;height:10px\" src=\"https://example.invalid/a.png\" data-wiz-clip-resource=\"0\">", urls: ["https://example.invalid/a.png"], progress: { _,_ in }) { html, _ in fallback = html }
    check(fallback.contains("width:20px;height:10px") && fallback.contains("alt=\"diagram\"") && !fallback.contains("data-wiz-clip-resource"), "embedded image preserves sanitized sizing and alt")
    print("Independent cloud/resource checks: \(checks), failures: \(failures). No live account, keychain or network used.")
    return failures == 0 ? 0 : 1
}

private final class CaptureTestRunner: NSObject, WKNavigationDelegate {
    var done = false, code: Int32 = 1
    var contentCases: String?
    var publicWiki = false, rendering = false
    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 600), configuration: WKWebViewConfiguration())
    override init() { super.init(); web.navigationDelegate = self }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(navigationAction.request.url?.scheme == "about" ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("FAIL synthetic navigation: \(error.localizedDescription)"); done = true
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if rendering { renderWikiArtifacts(); return }
        guard let file = Bundle.main.url(forResource: "ClipPage", withExtension: "js"), let js = try? String(contentsOf: file, encoding: .utf8) else { done = true; return }
        web.evaluateJavaScript(js + "\nvar captured; ExtensionPreprocessingJS.run({completionFunction:function(x){captured=x}}); captured;") { result, error in
            guard error == nil, let data = result as? [String: Any], let html = data["pageHTML"] as? String else {
                print("FAIL WebKit snapshot: \(error?.localizedDescription ?? "no HTML")"); self.done = true; return
            }
            if self.publicWiki {
                let checks: [(String, Bool)] = [
                    ("public Wikipedia article opening retained", html.contains("homogeneous polynomial") && html.contains("quantic")),
                    ("public Wikipedia sidebar menus excluded", !html.contains("Main menu") && !html.contains("Create account") && !html.contains("Jump to content")),
                    ("public Wikipedia footer menus and badges excluded", !html.contains("footer-places") && !html.contains("footer-icons") && !html.contains("Edit preview settings")),
                    ("public Wikipedia notes and references retained", html.contains("cite_note-1") && html.contains("cite_note-5") && html.contains("References") && html.contains("Notes")),
                    ("public Wikipedia all article sections retained", html.contains("Homogenization") && html.contains("External links")),
                    ("public Wikipedia semantic formulas retained", html.components(separatedBy: "<math").count > 10 && html.contains("<mfrac") && html.contains("<msup")),
                    ("public Wikipedia license preserved without footer shell", html.contains("Creative Commons") && !html.contains("mw-footer-container")),
                    ("public Wikipedia no section-edit or related navigation", !html.contains("mw-editsection") && !html.contains("class=\"navbox")),
                    ("public Wikipedia scripts forms and handlers removed", !html.contains("<script") && !html.contains("<input") && !html.contains("onclick=")),
                    ("public Wikipedia no sidebar or footer icon downloads", !(data["resources"] as? [String] ?? []).contains(where: { $0.contains("wikipedia-wordmark") || $0.contains("wikimedia-button") }))]
                for (name, ok) in checks { print("\(ok ? "PASS" : "FAIL") \(name)") }
                self.code = checks.allSatisfy({ $0.1 }) ? 0 : 1
                print("Public Wikipedia local replay checks: \(checks.count), failures: \(checks.filter({ !$0.1 }).count). Network blocked, no cloud account.")
                if let path = ProcessInfo.processInfo.environment["WIZNOTE_CLIPPER_TEST_ARTIFACT_DIR"], path.hasPrefix("/") {
                    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                    try? html.write(toFile: path + "/wiki-captured.html", atomically: true, encoding: .utf8)
                    self.rendering = true
                    self.web.loadHTMLString("<!doctype html><meta charset='utf-8'><body style='margin:24px;font:16px/1.55 system-ui'>" + html, baseURL: nil)
                } else { self.done = true }
                return
            }
            let checks: [(String, Bool)] = [
                ("static MathJax/KaTeX/native MathML retained once", html.components(separatedBy: "wiz-clip-formula").count - 1 == 5),
                ("fractions and superscripts retained", html.contains("<mfrac>") && html.contains("<msup>")),
                ("hidden MathML made visible", !html.contains("position:absolute") && !html.contains("aria-hidden")),
                ("renderer-only content removed", !html.contains("renderer-only-text") && !html.contains("<svg")),
                ("remote image manifest created", (data["resources"] as? [String]) == ["https://example.invalid/image.png"]),
                ("unsafe scripts/events/forms removed", !html.contains("<script") && !html.contains("onclick") && !html.contains("private-form-value")),
                ("embedded image kept", html.contains("data:image/png;base64,")),
                ("no implicit CSS URLs", !html.contains("url(")),
                ("no phantom empty selection", data["selectionHTML"] as? String == ""),
                ("Wikipedia fallback formula image is removed with its duplicate layer", !html.contains("formula-fallback.svg") && !html.contains("duplicate-formula-marker")),
                ("MathJax preview duplicate removed", !html.contains("duplicate-preview-marker")),
                ("standalone hidden MathML is normalized", html.contains("<mi>w</mi>") && !html.contains("display:none") && !html.contains(" hidden")),
                ("hidden tracking image is not fetched", !(data["resources"] as? [String] ?? []).contains("https://example.invalid/hidden-tracker.png"))]
            for (name, ok) in checks { print("\(ok ? "PASS" : "FAIL") \(name)") }
            self.code = checks.allSatisfy({ $0.1 }) ? 0 : 1
            print("WebKit static capture checks: \(checks.count), failures: \(checks.filter({ !$0.1 }).count)")
            guard let cases = self.contentCases else { self.done = true; self.code = 1; print("FAIL missing content regression fixture"); return }
            self.web.evaluateJavaScript(cases) { result, error in
                guard error == nil, let checks = result as? [[String: Any]], !checks.isEmpty else {
                    print("FAIL content-boundary regression evaluation"); self.code = 1; self.done = true; return
                }
                var failed = 0
                for item in checks {
                    let ok = item["ok"] as? Bool == true
                    if !ok { failed += 1 }
                    print("\(ok ? "PASS" : "FAIL") \(item["name"] as? String ?? "unnamed content check")")
                }
                if failed > 0 { self.code = 1 }
                print("Content-boundary checks: \(checks.count), failures: \(failed)")
                self.done = true
            }
        }
    }
    func renderWikiArtifacts() {
        guard let path = ProcessInfo.processInfo.environment["WIZNOTE_CLIPPER_TEST_ARTIFACT_DIR"] else { done = true; return }
        web.takeSnapshot(with: nil) { image, error in
            if let image, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path + "/wiki-top.png"))
            } else { self.code = 1; print("FAIL Wikipedia top render") }
            self.web.evaluateJavaScript("window.scrollTo(0, document.documentElement.scrollHeight)") { _, _ in
                self.web.takeSnapshot(with: nil) { image, error in
                    if let image, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: path + "/wiki-bottom.png"))
                    } else { self.code = 1; print("FAIL Wikipedia bottom render") }
                    self.done = true
                }
            }
        }
    }
}
func captureClipperSelfTest(fixture: String, publicWiki: Bool = false) -> Int32 {
    // Only local named synthetic fixture; no credentials and no production endpoint.
    guard fixture.hasPrefix("/"), fixture.hasSuffix(publicWiki ? "/wiki-public-original.html" : "/clipper-cloud-page.html"),
          let html = try? String(contentsOfFile: fixture, encoding: .utf8) else { return 2 }
    let app = NSApplication.shared; app.setActivationPolicy(.accessory); app.finishLaunching()
    let runner = CaptureTestRunner()
    runner.publicWiki = publicWiki
    if !publicWiki { runner.contentCases = try? String(contentsOf: URL(fileURLWithPath: fixture).deletingLastPathComponent().appendingPathComponent("clipper-content-cases.js"), encoding: .utf8) }
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
    window.title = "剪藏静态捕获合成测试"; window.contentView = runner.web; window.orderFront(nil)
    WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "synthetic-no-network",
        encodedContentRuleList: "[{\"trigger\":{\"url-filter\":\"^https?://\"},\"action\":{\"type\":\"block\"}}]") { rules, error in
        guard let rules, error == nil else { runner.done = true; return }
        runner.web.configuration.userContentController.add(rules)
        runner.web.loadHTMLString(html, baseURL: nil)
    }
    let deadline = Date().addingTimeInterval(20)
    while !runner.done && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    window.close()
    if !runner.done { print("FAIL synthetic snapshot timed out") }
    return runner.code
}

func submissionClipperSelfTest() -> Int32 {
    var checks = 0, failures = 0
    func check(_ ok: Bool, _ name: String) { checks += 1; if !ok { failures += 1 }; print("\(ok ? "PASS" : "FAIL") \(name)") }
    let account = try! CloudClipAccount(["token": "synthetic-only-token", "kbGuid": "00000000-0000-0000-0000-000000000001",
        "userGuid": "00000000-0000-0000-0000-000000000002", "userID": "synthetic@example.invalid"])
    let input = try! ClipInput(dictionary: ["url": "https://example.invalid/page", "title": "测试", "pageHTML": "<p>whole-only</p>", "selectionHTML": "<p>chosen-only</p>"])
    var requests: [URLRequest] = []
    let client = CloudClipClient(transport: { request, completion in requests.append(request); completion(.success(["code": 200])) })
    let submission = CloudClipSubmission(client: client)
    var accepted = false
    submission.submit(account: account, input: input, title: "测试", folder: "/网页剪藏/", selection: true, progress: { _,_ in }) {
        if case .accepted(let receipt, _) = $0 { accepted = receipt.taskID == nil }
    }
    check(accepted && submission.phase == .accepted && requests.count == 1, "one POST ends at API acceptance without task ID or status query")
    let sent = try! JSONSerialization.jsonObject(with: requests[0].httpBody!) as! [String: Any]
    check((sent["data"] as! String).contains(Data("<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>测试</title></head><body><p>chosen-only</p></body></html>".utf8).base64EncodedString()), "selected HTML and title, not whole page or summary, reach upload")
    submission.submit(account: account, input: input, title: "again", folder: "/网页剪藏/", selection: false, progress: { _,_ in }) { _ in failures += 1 }
    check(requests.count == 1, "repeated click after acceptance cannot upload again")
    var uncertainPosts = 0, uncertain = false
    let failing = CloudClipClient(transport: { _, completion in uncertainPosts += 1; completion(.failure(ClipperError.message("synthetic timeout"))) })
    let failed = CloudClipSubmission(client: failing)
    failed.submit(account: account, input: input, title: "测试", folder: "/网页剪藏/", selection: false, progress: { _,_ in }) { if case .uncertain = $0 { uncertain = true } }
    failed.submit(account: account, input: input, title: "测试", folder: "/网页剪藏/", selection: false, progress: { _,_ in }) { _ in failures += 1 }
    check(uncertain && failed.phase == .uncertain && uncertainPosts == 1, "ambiguous response does not retry or falsely claim saved")
    let fresh = CloudClipSubmission(client: client)
    fresh.submit(account: account, input: input, title: "新分享", folder: "/网页剪藏/", selection: false, progress: { _,_ in }) { _ in }
    check(fresh.phase == .accepted && requests.count == 2, "fresh share is not blocked by an old uncertain task")
    let invalid = CloudClipSubmission(client: client); var preparationFailed = false
    invalid.submit(account: account, input: input, title: " ", folder: "/网页剪藏/", selection: false, progress: { _,_ in }) { if case .preparationFailed = $0 { preparationFailed = true } }
    check(preparationFailed && invalid.phase == .ready && requests.count == 2, "invalid title fails before network and remains editable")
    var later: ((Result<[String: Any], Error>) -> Void)?, inFlightPosts = 0, outcomes = 0
    let slow = CloudClipClient(transport: { _, completion in inFlightPosts += 1; later = completion })
    let active = CloudClipSubmission(client: slow)
    active.submit(account: account, input: input, title: "测试", folder: "/网页剪藏/", selection: false, progress: { _,_ in }) { _ in outcomes += 1 }
    active.submit(account: account, input: input, title: "测试", folder: "/网页剪藏/", selection: false, progress: { _,_ in }) { _ in outcomes += 1 }
    check(active.phase == .uploading && inFlightPosts == 1, "repeated click while uploading cannot issue a second POST")
    active.cancel(); later?(.success(["code": 200, "id": "late"]))
    check(active.phase == .cancelled && outcomes == 0, "cancelled share ignores late upload acknowledgement without claiming server cancellation")
    var imageCallback: ((Data?) -> Void)?
    let resources = ClipResources(fetch: { _, completion in imageCallback = completion })
    let imageInput = try! ClipInput(dictionary: ["url": "https://example.invalid/page", "title": "图片", "pageHTML": "<img src=\"https://example.invalid/a.png\" data-wiz-clip-resource=\"0\">", "resources": ["https://example.invalid/a.png"]])
    let preparing = CloudClipSubmission(client: client, resources: resources)
    preparing.submit(account: account, input: imageInput, title: "图片", folder: "/网页剪藏/", selection: false, progress: { _,_ in }) { _ in outcomes += 1 }
    check(preparing.phase == .preparing && imageCallback != nil, "resource work precedes POST")
    preparing.cancel(); imageCallback?(nil)
    check(preparing.phase == .cancelled && requests.count == 2 && outcomes == 0, "cancel during resource work prevents later upload")
    print("Push-only submission checks: \(checks), failures: \(failures). Synthetic transports only.")
    return failures == 0 ? 0 : 1
}

func shareUIClipperSelfTest() -> Int32 {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory); app.finishLaunching()
    let controller = ShareViewController(); let root = controller.view
    func descendants(_ view: NSView) -> [NSView] { view.subviews.flatMap { [$0] + descendants($0) } }
    let views = descendants(root), buttons = views.compactMap { $0 as? NSButton }.filter { !($0 is NSPopUpButton) }
    let text = views.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: "\n")
    let segments = views.compactMap { $0 as? NSSegmentedControl }
    let checks: [(String, Bool)] = [
        ("compact 460 by 340 native form", controller.preferredContentSize == NSSize(width: 460, height: 340)),
        ("no local destination or pairing fields", segments.count == 1 && !views.contains(where: { $0 is NSSecureTextField }) && !text.contains("本机客户端")),
        ("no summary or preview widgets", !views.contains(where: { $0 is NSTextView || $0 is WKWebView || $0 is NSScrollView }) && !buttons.contains(where: { $0.title.contains("预览") })),
        ("native cloud login upload cancel controls remain", Set(buttons.map { $0.title }) == Set(["登录账号", "上传", "取消"])),
        ("required metadata labels remain", ["标题", "账号", "文件夹", "内容"].allSatisfy({ text.contains($0) })),
        ("all controls remain inside compact form", root.subviews.allSatisfy({ root.bounds.contains($0.frame) })),
        ("only page and selection modes remain", segments.first?.segmentCount == 2 && segments.first?.label(forSegment: 0) == "保存整页" && segments.first?.label(forSegment: 1) == "保存选中"),
        ("upload disabled without input and account", buttons.first(where: { $0.title == "上传" })?.isEnabled == false)]
    for (name, ok) in checks { print("\(ok ? "PASS" : "FAIL") \(name)") }
    let window = NSWindow(contentRect: root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.title = "剪藏界面合成测试"; window.contentViewController = controller; window.orderFront(nil)
    if let path = ProcessInfo.processInfo.environment["WIZNOTE_CLIPPER_TEST_ARTIFACT_DIR"], path.hasPrefix("/") {
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
            root.appearance = NSAppearance(named: appearance); root.needsDisplay = true
            descendants(root).forEach { $0.needsDisplay = true }
            root.layoutSubtreeIfNeeded(); root.displayIfNeeded()
            if let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
                root.cacheDisplay(in: root.bounds, to: bitmap)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path).appendingPathComponent("share-" + name + ".png"))
            }
        }
    }
    window.close()
    var added = 0, failures = checks.filter { !$0.1 }.count
    func check(_ ok: Bool, _ name: String) { added += 1; if !ok { failures += 1 }; print("\(ok ? "PASS" : "FAIL") \(name)") }
    let synthetic = try! CloudClipAccount(["token": "synthetic-only-token", "kbGuid": "00000000-0000-0000-0000-000000000001", "userGuid": "00000000-0000-0000-0000-000000000002", "userID": "synthetic@example.invalid"])
    var uploads: [[String: Any]] = [], finished = 0
    let transport = CloudClipClient(transport: { request, callback in
        if request.url!.path == "/ks/gather" {
            uploads.append(try! JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]); callback(.success(["code": 200]))
        } else { callback(.success(["code": 200, "result": ["/网页剪藏/"]])) }
    })
    let editing = ShareViewController(cloud: transport, onAcceptedShare: { finished += 1 })
    let editorWindow = NSWindow(contentRect: editing.view.bounds, styleMask: [.titled], backing: .buffered, defer: false)
    editorWindow.isReleasedWhenClosed = false; editorWindow.contentViewController = editing; editorWindow.makeKeyAndOrderFront(nil)
    editing.configureShare(input: try! ClipInput(dictionary: ["url": "https://example.invalid/page", "title": "original-source-title", "pageHTML": "<p>body</p>"]), account: synthetic)
    let editViews = descendants(editing.view)
    let title = editViews.compactMap { $0 as? NSTextField }.first(where: { $0.isEditable })!
    editorWindow.makeFirstResponder(title)
    let fieldEditor = title.currentEditor() as? NSTextView
    let renamed = "重命名标题 α & <测试>"
    fieldEditor?.string = renamed
    check(fieldEditor != nil && editorWindow.firstResponder === fieldEditor, "rename test edits the live native field editor rather than setting the control value")
    let upload = editViews.compactMap { $0 as? NSButton }.first(where: { $0.title == "上传" })!
    upload.performClick(nil)
    let data = uploads.first?["data"] as? String ?? ""
    check(uploads.count == 1 && data.contains("param-title='" + Data(renamed.utf8).base64EncodedString() + "'"), "real upload button commits the active title edit before creating the request")
    check(data.contains(Data("<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>重命名标题 α &amp; &lt;测试&gt;</title></head><body><p>body</p></body></html>".utf8).base64EncodedString()), "real button carries renamed title consistently into HTML")
    check(finished == 1, "accepted push immediately finishes the share request without a timer")
    check(upload.isHidden && !editViews.compactMap({ $0 as? NSButton }).contains(where: { $0.title == "关闭" }), "accepted share has no close button")
    upload.performClick(nil)
    check(finished == 1 && uploads.count == 1, "repeated completion action cannot upload or finish twice")
    editorWindow.close()
    let host = ClipperHost(); let hostWindow = host.makeWindow(); hostWindow.isReleasedWhenClosed = false
    let hostButtons = descendants(hostWindow.contentView!).compactMap { $0 as? NSButton }
    let web = hostButtons.first(where: { $0.title == "打开网页版" })
    check(web != nil && web?.action == #selector(ClipperHost.openWebVersion(_:)) && (web?.target as? ClipperHost) === host, "startup page has a wired open-web-version button")
    check(ClipperHost.webVersionURL.absoluteString == "https://note.wiz.cn/" && ClipperHost.webVersionURL.query == nil, "web button uses only the official HTTPS URL without account tokens")
    hostWindow.close()
    print("Share UI checks: \(checks.count + added), failures: \(failures). Synthetic account only; no keychain accessed.")
    return failures == 0 ? 0 : 1
}
