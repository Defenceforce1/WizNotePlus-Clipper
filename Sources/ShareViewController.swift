// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import UniformTypeIdentifiers

private final class ClipperFormView: NSView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); dirtyRect.fill()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay = true
    }
}

@objc(WizNotePlusShareViewController)
final class ShareViewController: NSViewController {
    private let status = NSTextField(wrappingLabelWithString: "正在读取 Safari 分享内容…")
    private let titleField = NSTextField(string: "")
    private let account = NSTextField(labelWithString: "未登录为知云端")
    private let folders = NSPopUpButton(frame: .zero, pullsDown: false)
    private let mode = NSSegmentedControl(labels: ["保存整页", "保存选中"], trackingMode: .selectOne, target: nil, action: nil)
    private let login = NSButton(title: "登录账号", target: nil, action: nil)
    private let save = NSButton(title: "上传", target: nil, action: nil)
    private let cancel = NSButton(title: "取消", target: nil, action: nil)
    private let activity = NSProgressIndicator()
    private let cloud = CloudClipClient()
    private lazy var submission = CloudClipSubmission(client: cloud)
    private var cloudAccount: CloudClipAccount?
    private var input: ClipInput?
    private var loaded = false
    private var completed = false

    override func loadView() {
        view = ClipperFormView(frame: NSRect(x: 0, y: 0, width: 460, height: 340))
        preferredContentSize = view.frame.size
        let heading = NSTextField(labelWithString: "网页剪藏")
        heading.font = .boldSystemFont(ofSize: 17)
        heading.frame = NSRect(x: 24, y: 298, width: 412, height: 24); view.addSubview(heading)
        let subtitle = NSTextField(labelWithString: "上传到为知云端，无需打开主 App")
        subtitle.font = .systemFont(ofSize: 11); subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 24, y: 275, width: 412, height: 18); view.addSubview(subtitle)
        let card = NSBox(frame: NSRect(x: 20, y: 103, width: 420, height: 158))
        card.boxType = .custom; card.borderWidth = 0; card.cornerRadius = 10
        card.fillColor = .controlBackgroundColor; view.addSubview(card)
        for (caption, y) in [("标题", 230.0), ("账号", 192.0), ("文件夹", 154.0), ("内容", 116.0)] {
            let label = NSTextField(labelWithString: caption); label.alignment = .right
            label.textColor = .secondaryLabelColor; label.frame = NSRect(x: 28, y: y, width: 60, height: 20); view.addSubview(label)
        }
        titleField.frame = NSRect(x: 102, y: 226, width: 326, height: 26)
        titleField.placeholderString = "笔记标题"; view.addSubview(titleField)
        account.frame = NSRect(x: 102, y: 190, width: 226, height: 22)
        account.lineBreakMode = .byTruncatingMiddle; view.addSubview(account)
        login.frame = NSRect(x: 334, y: 185, width: 94, height: 28)
        login.bezelStyle = .rounded; login.target = self; login.action = #selector(loginCloud); view.addSubview(login)
        folders.frame = NSRect(x: 102, y: 147, width: 326, height: 28); view.addSubview(folders)
        mode.frame = NSRect(x: 102, y: 109, width: 326, height: 28); mode.selectedSegment = 0; view.addSubview(mode)
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 24, y: 42, width: 412, height: 49); view.addSubview(status)
        activity.style = .spinning; activity.isDisplayedWhenStopped = false
        activity.frame = NSRect(x: 28, y: 17, width: 16, height: 16); view.addSubview(activity)
        save.frame = NSRect(x: 345, y: 10, width: 91, height: 30); save.bezelStyle = .rounded
        save.keyEquivalent = "\r"; save.target = self; save.action = #selector(saveNote)
        save.isEnabled = false; view.addSubview(save)
        cancel.frame = NSRect(x: 254, y: 10, width: 83, height: 30); cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"; cancel.target = self; cancel.action = #selector(cancelShare); view.addSubview(cancel)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if loaded { return }; loaded = true
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            status.stringValue = "未收到分享内容"; return
        }
        let providers = items.flatMap { $0.attachments ?? [] }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) }) else {
            status.stringValue = "只收到链接。请在 Safari 网页中使用分享入口。"; return
        }
        provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { [weak self] item, error in
            DispatchQueue.main.async {
                guard let self, !self.completed else { return }
                do {
                    guard error == nil, let dictionary = item as? [String: Any],
                          let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any] else {
                        throw ClipperError.message("Safari 未返回网页正文，请重试分享")
                    }
                    let input = try ClipInput(dictionary: results); self.input = input
                    self.titleField.stringValue = input.title
                    self.mode.setEnabled(!input.pageHTML.isEmpty, forSegment: 0)
                    self.mode.setEnabled(!input.selectionHTML.isEmpty, forSegment: 1)
                    self.mode.selectedSegment = input.pageHTML.isEmpty ? 1 : 0
                    self.cloudAccount = ClipCredentialStore.loadCloud()
                    self.account.stringValue = self.cloudAccount?.userID ?? "未登录为知云端"; self.account.toolTip = self.cloudAccount?.userID
                    self.status.stringValue = "请确认账号和文件夹；上传需要联网。"
                    if self.cloudAccount != nil { self.refreshCloudFolders() }
                } catch { self.status.stringValue = error.localizedDescription }
            }
        }
    }

    @objc private func loginCloud() {
        guard let window = view.window, submission.phase == .ready, !completed else { return }
        let alert = NSAlert(); alert.messageText = "登录为知笔记"
        alert.informativeText = "通过 HTTPS 登录 note.wiz.cn，不读取旧剪藏器账号。密码不保存。"
        alert.addButton(withTitle: "登录"); alert.addButton(withTitle: "取消")
        let fields = NSView(frame: NSRect(x: 0, y: 0, width: 310, height: 102))
        let user = NSTextField(frame: NSRect(x: 0, y: 70, width: 310, height: 26))
        user.placeholderString = "为知账号"; user.stringValue = cloudAccount?.userID ?? ""
        let password = NSSecureTextField(frame: NSRect(x: 0, y: 36, width: 310, height: 26)); password.placeholderString = "密码"
        let remember = NSButton(checkboxWithTitle: "记住登录（令牌保存在本扩展钥匙串）", target: nil, action: nil)
        remember.frame = NSRect(x: 0, y: 0, width: 310, height: 24); remember.state = .off
        fields.addSubview(user); fields.addSubview(password); fields.addSubview(remember); alert.accessoryView = fields
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn, !self.completed else { password.stringValue = ""; return }
            self.setEditing(false); self.activity.startAnimation(nil); self.status.stringValue = "正在登录…"
            let secret = password.stringValue; password.stringValue = ""
            self.cloud.login(userID: user.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), password: secret) { [weak self] result in
                guard let self, !self.completed else { return }
                self.activity.stopAnimation(nil); self.setEditing(true)
                switch result {
                case .success(let account):
                    self.cloudAccount = account; self.account.stringValue = account.userID; self.account.toolTip = account.userID
                    let saved = remember.state != .on || ClipCredentialStore.saveCloud(account)
                    if remember.state != .on { ClipCredentialStore.forgetCloud() }
                    self.refreshCloudFolders()
                    if !saved { self.status.stringValue = "本次已登录；记住登录失败，下次需重新登录。" }
                case .failure(let error): self.status.stringValue = error.localizedDescription
                }
            }
        }
    }

    private func refreshCloudFolders() {
        guard let account = cloudAccount else { return }
        login.title = "切换账号"; login.isEnabled = false; save.isEnabled = false; activity.startAnimation(nil)
        cloud.folders(account: account) { [weak self] result in
            guard let self, !self.completed else { return }
            self.login.isEnabled = true; self.activity.stopAnimation(nil)
            switch result {
            case .success(let items):
                self.folders.removeAllItems(); self.folders.addItems(withTitles: items)
                self.folders.selectItem(withTitle: "/网页剪藏/"); self.save.isEnabled = self.input != nil
                self.status.stringValue = "确认后上传；服务器接收后，由主 App 正常同步。"
            case .failure(let error): self.save.isEnabled = false; self.status.stringValue = error.localizedDescription
            }
        }
    }

    private func setEditing(_ enabled: Bool) {
        titleField.isEnabled = enabled; folders.isEnabled = enabled; mode.isEnabled = enabled; login.isEnabled = enabled
        save.isEnabled = enabled && input != nil && cloudAccount != nil && folders.selectedItem != nil
    }

    @objc private func saveNote() {
        guard !completed, let input, let account = cloudAccount, let folder = folders.selectedItem?.title,
              submission.phase == .ready else { return }
        setEditing(false); activity.startAnimation(nil); status.stringValue = "正在准备上传…"
        submission.submit(account: account, input: input, title: titleField.stringValue, folder: folder,
            selection: mode.selectedSegment == 1, progress: { [weak self] count, total in
                guard let self, !self.completed else { return }; self.status.stringValue = "正在处理图片 \(count)/\(total)…"
            }, uploading: { [weak self] in
                self?.status.stringValue = "正在上传到为知服务器…"
            }) { [weak self] outcome in
                guard let self, !self.completed else { return }; self.activity.stopAnimation(nil)
                switch outcome {
                case .accepted(_, let missing):
                    self.completed = true; self.save.title = "已推送"; self.cancel.title = "关闭"
                    self.status.stringValue = "服务器已接收，尚未确认最终保存。"
                        + (missing > 0 ? "\n\(missing) 处资源未嵌入，可对照原网页。" : "")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                case .preparationFailed(let error): self.setEditing(true); self.status.stringValue = error.localizedDescription
                case .uncertain(let error):
                    self.save.title = "未确认"; self.cancel.title = "关闭"
                    self.status.stringValue = error.localizedDescription + "\n请到网页版检查；不自动重传，可关闭此窗口。"
                }
            }
    }

    @objc private func cancelShare() {
        if completed { extensionContext?.completeRequest(returningItems: [], completionHandler: nil); return }
        completed = true; submission.cancel()
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}
