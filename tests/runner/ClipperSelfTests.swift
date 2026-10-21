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
    check(folders == ["/有效/"], "destination folders contain only validated deduplicated server entries")
    for items in [[], ["/../"], ["/网页剪藏/", "/网页剪藏/"]] as [[String]] {
        let folderClient = CloudClipClient(transport: { _, callback in callback(.success(["code": 200, "result": items])) })
        var received: [String]?
        folderClient.folders(account: account) { received = try? $0.get() }
        check(received == Array(Set(items.filter(CloudClipClient.folderIsValid))).sorted(), "empty or existing clip folder is not supplemented with an invented destination")
    }
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

func sessionClipperSelfTest() -> Int32 {
    var checks = 0, failures = 0
    func check(_ ok: Bool, _ name: String) { checks += 1; if !ok { failures += 1 }; print("\(ok ? "PASS" : "FAIL") \(name)") }
    let account = try! CloudClipAccount(["token": "synthetic-old-token", "kbGuid": "00000000-0000-0000-0000-000000000001", "userGuid": "00000000-0000-0000-0000-000000000002", "userID": "saved@example.invalid"])
    var renewedValue = account.dictionary; renewedValue["token"] = "synthetic-renewed-token"
    let renewed = try! CloudClipAccount(renewedValue)
    let secret = ClipLoginSecret(userID: account.userID, password: "synthetic-not-real")
    struct Trace {
        var requests: [URLRequest] = [], read = 0, stored = 0, done = 0, ok = false
        var token = "", error: Error?
    }
    func scenario(folderCode: Int = 301, saved: ClipLoginSecret? = secret, loginOK: Bool = true,
                  returned: CloudClipAccount = renewed, secondCode: Int = 200, saveOK: Bool = true,
                  networkError: Bool = false) -> Trace {
        var t = Trace(), gets = 0
        let client = CloudClipClient(transport: { request, callback in
            t.requests.append(request)
            if request.url!.path == "/as/user/login" {
                callback(.success(loginOK ? ["code": 200, "result": returned.dictionary] : ["code": 401]))
            } else {
                gets += 1
                if networkError { callback(.failure(ClipperError.message("synthetic offline"))); return }
                callback(.success(["code": gets == 1 ? folderCode : secondCode, "result": ["/网页剪藏/"]]))
            }
        })
        let storage = ClipLoginStorage(loadSecret: { _ in t.read += 1; return saved },
            saveAccount: { a in t.stored += 1; t.token = a.token; return saveOK }, saveSecret: { _ in false }, forget: {})
        let session = CloudClipSession(client: client, storage: storage)
        session.folders(account: account) { result in
            t.done += 1
            switch result { case .success(let (a, _)): t.ok = true; t.token = a.token
            case .failure(let error): t.error = error }
        }
        return t
    }
    let valid = scenario(folderCode: 200)
    check(valid.ok && valid.requests.count == 1 && valid.read == 0, "valid remembered token needs no password lookup or login")
    let refreshed = scenario()
    check(refreshed.ok && refreshed.done == 1 && refreshed.requests.count == 3, "expired session renews once then retries folder GET once")
    check(refreshed.requests.map { $0.httpMethod! } == ["GET", "POST", "GET"] && !refreshed.requests.contains(where: { $0.url!.path == "/ks/gather" }), "session renewal cannot upload or retry a clipped note")
    check(refreshed.token == renewed.token && refreshed.stored == 1 && refreshed.requests.last!.value(forHTTPHeaderField: "X-Wiz-Token") == renewed.token, "renewed token is stored and used for the folder retry")
    let loginBody = try! JSONSerialization.jsonObject(with: refreshed.requests[1].httpBody!) as! [String: String]
    check(loginBody["userId"] == secret.userID && loginBody["password"] == secret.password && refreshed.requests[1].url!.host == "note.wiz.cn" && refreshed.requests[1].url!.query!.contains("password") == false, "remembered password goes only in fixed official HTTPS login body")
    let missing = scenario(saved: nil)
    check(!missing.ok && missing.requests.count == 1 && CloudClipAPIError.requiresLogin(missing.error!), "missing remembered password requests manual login without retries")
    let other = scenario(saved: ClipLoginSecret(userID: "other@example.invalid", password: "synthetic-other"))
    check(!other.ok && other.requests.count == 1, "stored password for another account is never submitted")
    let denied = scenario(loginOK: false)
    check(!denied.ok && denied.requests.count == 2 && denied.stored == 0, "failed automatic login stops without storing or retrying")
    let twice = scenario(secondCode: 301)
    check(!twice.ok && twice.requests.count == 3 && twice.done == 1, "repeated expiry cannot cause an infinite login loop")
    let server = scenario(folderCode: 500), offline = scenario(networkError: true)
    check(!server.ok && server.requests.count == 1 && server.read == 0, "non-auth API errors do not read saved password or relogin")
    check(!offline.ok && offline.requests.count == 1 && offline.read == 0, "offline requests do not relogin or erase remembered credentials")
    var different = renewed.dictionary; different["kbGuid"] = "00000000-0000-0000-0000-000000000003"
    let mismatch = scenario(returned: try! CloudClipAccount(different))
    check(!mismatch.ok && mismatch.stored == 0 && mismatch.requests.count == 2, "unexpected KB from relogin cannot switch upload destination")
    let storeFail = scenario(saveOK: false)
    check(!storeFail.ok && storeFail.requests.count == 2, "keychain update failure is visible instead of silently looping")
    var accountWrites = 0, passwordWrites = 0, forgotten = 0
    var allowPasswordWrite = true
    let memory = ClipLoginStorage(loadSecret: { _ in nil }, saveAccount: { _ in accountWrites += 1; return true },
        saveSecret: { s in passwordWrites += 1; return allowPasswordWrite && s.userID == account.userID && s.password == secret.password }, forget: { forgotten += 1 })
    check(memory.persist(account: account, password: secret.password, remember: true) && accountWrites == 1 && passwordWrites == 1 && forgotten == 0, "remember choice persists account and password through injected store")
    check(memory.persist(account: account, password: secret.password, remember: false) && forgotten == 1 && passwordWrites == 1, "unchecking remember removes saved login without writing password")
    allowPasswordWrite = false
    check(!memory.persist(account: account, password: secret.password, remember: true) && forgotten == 2, "partial credential persistence failure clears inconsistent saved state")
    var uploads = 0
    let uploadClient = CloudClipClient(transport: { _, completion in uploads += 1; completion(.success(["code": 301])) })
    var uploadFailed = false
    uploadClient.upload(body: [:], account: account) { if case .failure(let error) = $0 { uploadFailed = CloudClipAPIError.requiresLogin(error) } }
    check(uploadFailed && uploads == 1, "API 301 from upload never automatically resends POST")
    print("Remembered session checks: \(checks), failures: \(failures). Memory store only; no real keychain, password or cloud.")
    return failures == 0 ? 0 : 1
}

private final class CaptureTestRunner: NSObject, WKNavigationDelegate {
    var done = false, code: Int32 = 1
    var contentCases: String?
    var publicWiki = false, publicForum = false, codeOnly = false, rendering = false
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
            if self.codeOnly { self.checkCodeOnly(wholeHTML: html); return }
            if self.publicForum {
                let checks: [(String, Bool)] = [
                    ("public esoTalk title and all four loaded posts retained", html.contains("conversationTitle") && ["p103809", "p103810", "p103811", "p103832"].allSatisfy { html.contains($0) }),
                    ("public esoTalk post opening and final reply retained", html.contains("群里看到的数论难题") && html.contains("验证代码")),
                    ("public esoTalk sidebar search channels and footer excluded", !html.contains("scrubberColumn") && !html.contains("只看楼主") && !html.contains("友情链接") && !html.contains("Powered by")),
                    ("public esoTalk avatars signatures and reply login removed", !html.contains("uploads/avatars") && !html.contains("Glory's") && !html.contains("后才能发言")),
                    ("public esoTalk ten semantic formulas retained once", html.components(separatedBy: "<math").count - 1 == 10 && !html.contains("<mjx-container")),
                    ("public esoTalk code blocks and cross-site article link retained", html.contains("factorial_mod_prime") && html.contains("https://zenodo.org/records/23119159")),
                    ("public esoTalk no hidden controls or active scripting", !html.contains("<script") && !html.contains("<input") && !html.contains("onclick=")),
                    ("public esoTalk no avatar downloads", !(data["resources"] as? [String] ?? []).contains(where: { $0.contains("/avatars/") }))]
                for (name, ok) in checks { print("\(ok ? "PASS" : "FAIL") \(name)") }
                self.code = checks.allSatisfy({ $0.1 }) ? 0 : 1
                print("Public esoTalk local replay checks: \(checks.count), failures: \(checks.filter({ !$0.1 }).count). Network blocked.")
                self.checkForumSelections(wholeHTML: html)
                return
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
    func checkCodeOnly(wholeHTML: String) {
        let js = #"""
        (function(){
          var checks=[], selection=window.getSelection(), originals=Array.from(document.querySelectorAll('pre'));
          function check(name,ok){checks.push({name:name,ok:!!ok});}
          var whole=new DOMParser().parseFromString(captured.pageHTML,'text/html'), blocks=Array.from(whole.querySelectorAll('pre'));
          check('code-only replay includes both public code blocks',blocks.length===2&&originals.length===2);
          check('whole code has identical characters whitespace and line breaks',blocks.length===originals.length&&blocks.every(function(p,i){return p.textContent===originals[i].textContent;}));
          check('whole code has no dashed borders or nested padding',blocks.every(function(p){var c=p.querySelector('code');return c&&p.style.borderStyle==='none'&&c.style.borderStyle==='none'&&c.style.padding==='0px'&&c.style.display==='block';}));
          check('code keeps source monospace size and leading',blocks.every(function(p,i){var s=getComputedStyle(originals[i]);return p.style.fontFamily.includes('Menlo')&&p.style.fontSize===s.fontSize&&p.style.lineHeight===s.lineHeight;}));
          check('code canvas retains readable source highlighting',blocks.every(function(p){return p.style.backgroundColor==='rgb(0, 0, 0)'&&p.querySelector('.hljs-keyword').style.color==='rgb(195, 151, 216)';}));
          var previews=[], exact=true, clean=true;
          originals.forEach(function(p){selection.removeAllRanges();var range=document.createRange();range.selectNodeContents(p);selection.addRange(range);var r;ExtensionPreprocessingJS.run({completionFunction:function(x){r=x;}});var doc=new DOMParser().parseFromString(r.selectionHTML,'text/html'),saved=doc.querySelector('pre'),c=saved&&saved.querySelector('code');exact=exact&&saved&&saved.textContent===p.textContent;clean=clean&&c&&c.style.display==='block'&&c.style.borderStyle==='none'&&saved.style.borderStyle==='none';previews.push(r.selectionHTML);});
          selection.removeAllRanges();
          check('both selected code blocks retain exact source text',exact);
          check('both selected code blocks eliminate fragmented dashed decoration',clean);
          check('code-only fixture never includes article prose or formula markup',!whole.querySelector('math,.postHeader,.scrubberColumn'));
          return {checks:checks,preview:previews.join('<hr>')};
        }());
        """#
        web.evaluateJavaScript(js) { result, error in
            guard error == nil, let value = result as? [String: Any], let checks = value["checks"] as? [[String: Any]], checks.count == 8 else {
                print("FAIL public code-only replay: \(error?.localizedDescription ?? "no result")"); self.code = 1; self.done = true; return
            }
            self.code = 0
            for item in checks {
                let ok = item["ok"] as? Bool == true
                print("\(ok ? "PASS" : "FAIL") \(item["name"] as? String ?? "code check")")
                if !ok { self.code = 1 }
            }
            if let path = ProcessInfo.processInfo.environment["WIZNOTE_CLIPPER_TEST_ARTIFACT_DIR"], path.hasPrefix("/"), let preview = value["preview"] as? String {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                try? preview.write(toFile: path + "/code-selected.html", atomically: true, encoding: .utf8)
                try? wholeHTML.write(toFile: path + "/code-whole.html", atomically: true, encoding: .utf8)
                self.rendering = true
                self.web.loadHTMLString("<!doctype html><meta charset='utf-8'><body style='margin:24px;font:16px/1.55 system-ui'>" + preview, baseURL: nil)
            } else { self.done = true }
        }
    }
    func checkForumSelections(wholeHTML: String) {
        let js = #"""
        (function(){
          var checks=[], r, selection=window.getSelection();
          function check(name,ok){checks.push({name:name,ok:!!ok});}
          var atom=document.querySelector('#conversationPosts .postBody .MathJax,#conversationPosts .postBody .MathJax_SVG,#conversationPosts .postBody mjx-container');
          var walker=document.createTreeWalker(atom,NodeFilter.SHOW_TEXT), t;
          while((t=walker.nextNode())) if(t.data.trim()&&!t.parentElement.closest('math,.MJX_Assistive_MathML,mjx-assistive-mml')) break;
          selection.removeAllRanges(); var range=document.createRange(); range.setStart(t,0); range.setEnd(t,Math.min(1,t.length)); selection.addRange(range);
          ExtensionPreprocessingJS.run({completionFunction:function(x){r=x;}});
          var formula=r.selectionHTML, doc=new DOMParser().parseFromString(formula,'text/html');
          check('public partial formula selection retains one complete semantic expression',doc.querySelectorAll('math').length===1&&!!doc.querySelector('msup'));
          check('public partial formula selection excludes adjacent prose and renderer duplicates',!doc.querySelector('pre,svg')&&!formula.includes('postHeader')&&doc.querySelectorAll('.wiz-clip-formula').length===1);
          var pre=Array.from(document.querySelectorAll('#conversationPosts .postBody pre')).pop(), expected=pre.textContent;
          selection.removeAllRanges(); range=document.createRange(); range.selectNodeContents(pre); selection.addRange(range);
          ExtensionPreprocessingJS.run({completionFunction:function(x){r=x;}});
          doc=new DOMParser().parseFromString(r.selectionHTML,'text/html'); var code=doc.querySelector('pre');
          check('public selected code preserves every newline tab and indentation',code&&code.textContent===expected);
          check('public selected code has monospace type soft wrapping and stable tab stops',code&&code.style.fontFamily.includes('Menlo')&&code.style.whiteSpace==='pre-wrap'&&code.style.tabSize==='4');
          check('public selected code excludes forum shell and unrelated replies',!r.selectionHTML.includes('postHeader')&&!r.selectionHTML.includes('scrubberColumn')&&!r.selectionHTML.includes('conversationReply')&&doc.querySelectorAll('pre').length===1);
          selection.removeAllRanges(); return {checks:checks,preview:'<h2>选中公式</h2>'+formula+'<h2>选中代码</h2>'+r.selectionHTML};
        }());
        """#
        web.evaluateJavaScript(js) { result, error in
            guard error == nil, let value = result as? [String: Any], let checks = value["checks"] as? [[String: Any]], checks.count == 5 else {
                print("FAIL public forum selection replay: \(error?.localizedDescription ?? "no result")"); self.code = 1; self.done = true; return
            }
            for item in checks {
                let ok = item["ok"] as? Bool == true
                print("\(ok ? "PASS" : "FAIL") \(item["name"] as? String ?? "selection check")")
                if !ok { self.code = 1 }
            }
            if let path = ProcessInfo.processInfo.environment["WIZNOTE_CLIPPER_TEST_ARTIFACT_DIR"], path.hasPrefix("/"), let preview = value["preview"] as? String {
                try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
                try? wholeHTML.write(toFile: path + "/forum-captured.html", atomically: true, encoding: .utf8)
                try? preview.write(toFile: path + "/forum-selections.html", atomically: true, encoding: .utf8)
                self.rendering = true
                self.web.loadHTMLString("<!doctype html><meta charset='utf-8'><body style='margin:24px;font:16px/1.55 system-ui'>" + preview, baseURL: nil)
            } else { self.done = true }
        }
    }
    func renderWikiArtifacts() {
        guard let path = ProcessInfo.processInfo.environment["WIZNOTE_CLIPPER_TEST_ARTIFACT_DIR"] else { done = true; return }
        web.takeSnapshot(with: nil) { image, error in
            if let image, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path + (self.publicForum ? "/forum-top.png" : "/wiki-top.png")))
            } else { self.code = 1; print("FAIL Wikipedia top render") }
            self.web.evaluateJavaScript("window.scrollTo(0, document.documentElement.scrollHeight)") { _, _ in
                self.web.takeSnapshot(with: nil) { image, error in
                    if let image, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: path + (self.publicForum ? "/forum-bottom.png" : "/wiki-bottom.png")))
                    } else { self.code = 1; print("FAIL Wikipedia bottom render") }
                    self.done = true
                }
            }
        }
    }
}
func captureClipperSelfTest(fixture: String, publicWiki: Bool = false, publicForum: Bool = false, codeOnly: Bool = false) -> Int32 {
    // Only local named synthetic fixture; no credentials and no production endpoint.
    guard fixture.hasPrefix("/"), fixture.hasSuffix(codeOnly ? "/chaoli-code-original.html" : publicWiki ? "/wiki-public-original.html" : publicForum ? "/chaoli-12353-original.html" : "/clipper-cloud-page.html"),
          let html = try? String(contentsOfFile: fixture, encoding: .utf8) else { return 2 }
    let app = NSApplication.shared; app.setActivationPolicy(.accessory); app.finishLaunching()
    let runner = CaptureTestRunner()
    runner.publicWiki = publicWiki
    runner.publicForum = publicForum
    runner.codeOnly = codeOnly
    if !publicWiki && !publicForum && !codeOnly { runner.contentCases = try? String(contentsOf: URL(fileURLWithPath: fixture).deletingLastPathComponent().appendingPathComponent("clipper-content-cases.js"), encoding: .utf8) }
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
    let screenshotAccount = try! CloudClipAccount(["token": "synthetic-only-token", "kbGuid": "00000000-0000-0000-0000-000000000001", "userGuid": "00000000-0000-0000-0000-000000000002", "userID": "synthetic@example.invalid"])
    let screenshotInput = try! ClipInput(dictionary: ["url": "https://example.invalid/page", "title": "Homogeneous polynomial — 示例", "pageHTML": "<p>body</p>"])
    let memoryOnly = ClipLoginStorage(loadSecret: { _ in nil }, saveAccount: { _ in true }, saveSecret: { _ in true }, forget: {})
    let screenshotClient = CloudClipClient(transport: { _, callback in callback(.success(["code": 200, "result": ["/网页剪藏/"]])) })
    let controller = ShareViewController(cloud: screenshotClient, credentials: memoryOnly, onAcceptedShare: {})
    let root = controller.view
    func descendants(_ view: NSView) -> [NSView] { view.subviews.flatMap { [$0] + descendants($0) } }
    let views = descendants(root), buttons = views.compactMap { $0 as? NSButton }.filter { !($0 is NSPopUpButton) }
    let text = views.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: "\n")
    let segments = views.compactMap { $0 as? NSSegmentedControl }
    let checks: [(String, Bool)] = [
        ("compact 460 by 300 native form", controller.preferredContentSize == NSSize(width: 460, height: 300)),
        ("no local destination or pairing fields", segments.count == 1 && !views.contains(where: { $0 is NSSecureTextField }) && !text.contains("本机客户端")),
        ("no summary or preview widgets", !views.contains(where: { $0 is NSTextView || $0 is WKWebView || $0 is NSScrollView }) && !buttons.contains(where: { $0.title.contains("预览") })),
        ("native cloud login upload cancel and web controls remain", Set(buttons.map { $0.title }) == Set(["登录账号", "上传", "取消", "为知笔记网页版"])),
        ("required metadata labels remain", ["标题", "账号", "文件夹", "内容"].allSatisfy({ text.contains($0) })),
        ("all controls remain inside compact form", root.subviews.allSatisfy({ root.bounds.contains($0.frame) })),
        ("only page and selection modes remain", segments.first?.segmentCount == 2 && segments.first?.label(forSegment: 0) == "保存整页" && segments.first?.label(forSegment: 1) == "保存选中"),
        ("upload disabled without input and account", buttons.first(where: { $0.title == "上传" })?.isEnabled == false)]
    for (name, ok) in checks { print("\(ok ? "PASS" : "FAIL") \(name)") }
    let window = NSWindow(contentRect: root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.title = "剪藏界面合成测试"; window.contentViewController = controller; window.orderFront(nil)
    controller.configureShare(input: screenshotInput, account: screenshotAccount)
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
    var folderReplies: [(Result<[String: Any], Error>) -> Void] = [], pendingUploads = 0
    let delayedClient = CloudClipClient(transport: { request, callback in
        if request.url!.path == "/ks/gather" { pendingUploads += 1; callback(.success(["code": 200])) }
        else { folderReplies.append(callback) }
    })
    let pending = ShareViewController(cloud: delayedClient, credentials: memoryOnly, onAcceptedShare: {})
    let pendingViews = descendants(pending.view)
    let folderMenu = pendingViews.compactMap { $0 as? NSPopUpButton }.first!
    let pendingSave = pendingViews.compactMap { $0 as? NSButton }.first(where: { $0.title == "上传" })!
    check(folderMenu.selectedItem == nil && !folderMenu.isEnabled && !pendingSave.isEnabled, "initial folder selection is empty and disabled")
    pending.configureShare(input: screenshotInput, account: screenshotAccount)
    check(folderReplies.count == 1 && folderMenu.numberOfItems == 0 && folderMenu.selectedItem == nil
        && !folderMenu.isEnabled && !pendingSave.isEnabled, "pending account folder GET has no destination or upload")
    pendingSave.performClick(nil)
    check(pendingUploads == 0, "clicking upload before folders arrive cannot submit")
    folderReplies[0](.success(["code": 200, "result": ["/研究/", "/研究/"]]))
    check(folderMenu.itemTitles == ["/研究/"] && folderMenu.selectedItem?.title == "/研究/"
        && folderMenu.isEnabled && pendingSave.isEnabled, "successful GET selects only a real account folder, never a synthetic clip folder")
    pending.configureShare(input: screenshotInput, account: screenshotAccount)
    check(folderMenu.numberOfItems == 0 && !folderMenu.isEnabled && !pendingSave.isEnabled, "refresh clears the previous destination before fetching")
    folderReplies[1](.failure(ClipperError.message("synthetic offline")))
    check(folderMenu.selectedItem == nil && !folderMenu.isEnabled && !pendingSave.isEnabled, "failed GET leaves no stale folder or upload")
    pending.configureShare(input: screenshotInput, account: screenshotAccount)
    folderReplies[2](.success(["code": 200, "result": []]))
    check(folderMenu.numberOfItems == 0 && folderMenu.selectedItem == nil && !folderMenu.isEnabled
        && !pendingSave.isEnabled, "empty account folders never invent a destination or enable upload")
    pending.configureShare(input: screenshotInput, account: screenshotAccount)
    pending.configureShare(input: screenshotInput, account: screenshotAccount)
    folderReplies[3](.success(["code": 200, "result": ["/旧目录/"]]))
    check(folderMenu.selectedItem == nil && !pendingSave.isEnabled, "superseded GET cannot restore stale folders")
    folderReplies[4](.success(["code": 200, "result": ["/当前目录/"]]))
    check(folderMenu.itemTitles == ["/当前目录/"] && pendingSave.isEnabled, "current GET still enables an existing destination")
    pending.configureShare(input: screenshotInput, account: nil)
    check(folderMenu.numberOfItems == 0 && folderMenu.selectedItem == nil && !folderMenu.isEnabled
        && !pendingSave.isEnabled && pendingUploads == 0, "no account clears existing destinations without an upload")
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
    let windowsBeforeLaunch = app.windows.count
    check(ClipperHost.run() == 0 && app.windows.count == windowsBeforeLaunch, "containing app normal launch exits without creating any window")
    check(ClipperLinks.webVersionURL.absoluteString == "https://www.wiz.cn/xapp" && ClipperLinks.webVersionURL.query == nil, "share web button keeps the requested official HTTPS URL without tokens")
    let shareWeb = buttons.first(where: { $0.title == "为知笔记网页版" })
    check(shareWeb?.action == #selector(ShareViewController.openWebVersion(_:)) && (shareWeb?.target as? ShareViewController) === controller, "share form web button is wired to the controller")
    check(shareWeb?.frame.minX == 24 && shareWeb!.frame.maxY < 42 && shareWeb!.frame.maxX < 254, "web button sits at lower left without overlapping upload or status")
    let form = ClipLoginForm(userID: "saved@example.invalid", secret: ClipLoginSecret(userID: "saved@example.invalid", password: "synthetic-not-real"))
    check(form.password.cell is NSSecureTextFieldCell && form.password.stringValue == "synthetic-not-real" && form.remember.state == .on, "remembered password prefills a secure field with visible opt-out")
    form.user.stringValue = "other@example.invalid"; form.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    check(form.password.stringValue.isEmpty, "changing account clears another account's remembered password")
    let otherForm = ClipLoginForm(userID: "other@example.invalid", secret: ClipLoginSecret(userID: "saved@example.invalid", password: "synthetic-not-real"))
    check(otherForm.password.stringValue.isEmpty, "mismatched account never receives saved password")
    check(!text.contains("API") && !text.contains("未公证") && !text.contains("无需打开主 App"), "share form removes redundant implementation notices")
    let heading = views.compactMap { $0 as? NSTextField }.first(where: { $0.stringValue == "添加到为知笔记" })
    check(heading != nil && heading?.alignment == .center && heading?.font?.pointSize == 20
        && NSFontManager.shared.traits(of: heading!.font!).contains(.boldFontMask), "single centered bold add-to-WizNote heading")
    check(!text.contains("保存网页到为知笔记") && !text.contains("请选择文件夹") && !text.contains("上传到为知云端"), "subtitle and routine instruction copy are removed")
    let readyStrings = descendants(root).compactMap { ($0 as? NSTextField)?.stringValue }
    check(readyStrings.contains(screenshotAccount.userID) && !readyStrings.contains(where: { $0.contains("请选择") || $0.contains("正在") }), "ready share keeps the account but no routine status prompt")
    check(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true, "containing app is configured without a normal Dock or menu-bar presence")
    let failedClient = CloudClipClient(transport: { _, callback in callback(.success(["code": 301])) })
    let failedView = ShareViewController(cloud: failedClient, credentials: memoryOnly, onAcceptedShare: {})
    _ = failedView.view; failedView.configureShare(input: screenshotInput, account: screenshotAccount)
    let failedViews = descendants(failedView.view)
    check(failedViews.compactMap { ($0 as? NSTextField)?.stringValue }.contains(where: { $0.contains("301") }), "real API errors remain visible despite quiet idle state")
    check(failedViews.compactMap { $0 as? NSButton }.contains(where: { $0.title == "切换账号" && $0.isEnabled })
        && failedViews.compactMap { $0 as? NSButton }.contains(where: { $0.title == "上传" && !$0.isEnabled }), "failed authentication keeps in-share account controls and blocks upload")
    print("Share UI checks: \(checks.count + added), failures: \(failures). Synthetic account only; no keychain accessed.")
    return failures == 0 ? 0 : 1
}
