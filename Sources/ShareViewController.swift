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

final class ClipLoginForm: NSView, NSTextFieldDelegate {
    let user = NSTextField(frame: NSRect(x: 0, y: 70, width: 310, height: 26))
    let password = NSSecureTextField(frame: NSRect(x: 0, y: 36, width: 310, height: 26))
    let remember = NSButton(checkboxWithTitle: "记住密码（仅存于本机钥匙串）", target: nil, action: nil)
    private let loadedUser: String?
    init(userID: String, secret: ClipLoginSecret?) {
        loadedUser = secret?.userID
        super.init(frame: NSRect(x: 0, y: 0, width: 310, height: 102))
        user.placeholderString = "为知账号"; user.stringValue = userID; user.delegate = self
        password.placeholderString = "密码"
        if secret?.userID == userID { password.stringValue = secret?.password ?? "" }
        remember.frame = NSRect(x: 0, y: 0, width: 310, height: 24); remember.state = .on
        addSubview(user); addSubview(password); addSubview(remember)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func controlTextDidChange(_ obj: Notification) {
        if user.stringValue != loadedUser { password.stringValue = "" }
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
    private let web = NSButton(title: "为知笔记网页版", target: nil, action: nil)
    private let activity = NSProgressIndicator()
    private var cloud = CloudClipClient()
    private var credentials = ClipLoginStorage.keychain
    private lazy var session = CloudClipSession(client: cloud, storage: credentials)
    private lazy var submission = CloudClipSubmission(client: cloud)
    private var cloudAccount: CloudClipAccount?
    private var input: ClipInput?
    private var loaded = false
    private var completed = false
    private var requestFinished = false
    private var onAcceptedShare: (() -> Void)?
    private var persistenceWarning: String?

    // Injected transport/completion also lets isolated UI tests exercise the
    // actual button action without credentials or a live extension request.
    convenience init(cloud: CloudClipClient, credentials: ClipLoginStorage = .keychain, onAcceptedShare: @escaping () -> Void) {
        self.init(nibName: nil, bundle: nil)
        self.cloud = cloud; self.credentials = credentials; self.onAcceptedShare = onAcceptedShare
    }

    override func loadView() {
        view = ClipperFormView(frame: NSRect(x: 0, y: 0, width: 460, height: 340))
        preferredContentSize = view.frame.size
        let heading = NSTextField(labelWithString: "网页剪藏")
        heading.font = .boldSystemFont(ofSize: 17)
        heading.frame = NSRect(x: 24, y: 298, width: 412, height: 24); view.addSubview(heading)
        let subtitle = NSTextField(labelWithString: "保存网页到为知笔记")
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
        titleField.placeholderString = "笔记标题"; titleField.isEnabled = false; view.addSubview(titleField)
        account.frame = NSRect(x: 102, y: 190, width: 226, height: 22)
        account.lineBreakMode = .byTruncatingMiddle; view.addSubview(account)
        login.frame = NSRect(x: 334, y: 185, width: 94, height: 28)
        login.bezelStyle = .rounded; login.target = self; login.action = #selector(loginCloud); view.addSubview(login)
        folders.frame = NSRect(x: 102, y: 147, width: 326, height: 28); view.addSubview(folders)
        mode.frame = NSRect(x: 102, y: 109, width: 326, height: 28); mode.selectedSegment = 0; view.addSubview(mode)
        status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor
        status.frame = NSRect(x: 24, y: 42, width: 412, height: 49); view.addSubview(status)
        activity.style = .spinning; activity.isDisplayedWhenStopped = false
        activity.frame = NSRect(x: 188, y: 17, width: 16, height: 16); view.addSubview(activity)
        web.frame = NSRect(x: 24, y: 10, width: 145, height: 30); web.bezelStyle = .rounded
        web.target = self; web.action = #selector(openWebVersion(_:)); view.addSubview(web)
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
                    self.configureShare(input: try ClipInput(dictionary: results), account: ClipCredentialStore.loadCloud())
                } catch { self.status.stringValue = error.localizedDescription }
            }
        }
    }

    func configureShare(input: ClipInput, account: CloudClipAccount?) {
        self.input = input; cloudAccount = account
        titleField.stringValue = input.title; titleField.isEnabled = true
        mode.setEnabled(!input.pageHTML.isEmpty, forSegment: 0)
        mode.setEnabled(!input.selectionHTML.isEmpty, forSegment: 1)
        mode.selectedSegment = input.pageHTML.isEmpty ? 1 : 0
        self.account.stringValue = account?.userID ?? "未登录为知云端"; self.account.toolTip = account?.userID
        status.stringValue = account == nil ? "请先登录为知账号。" : "正在读取文件夹…"
        if account != nil { refreshCloudFolders() }
    }

    @objc private func loginCloud() {
        guard let window = view.window, submission.phase == .ready, !completed else { return }
        let alert = NSAlert(); alert.messageText = "登录为知笔记"
        alert.informativeText = "登录后可直接剪藏。记住的密码仅保存在系统钥匙串中。"
        alert.addButton(withTitle: "登录"); alert.addButton(withTitle: "取消")
        let stored = credentials.loadSecret(cloudAccount?.userID)
        let fields = ClipLoginForm(userID: cloudAccount?.userID ?? stored?.userID ?? "", secret: stored)
        let user = fields.user, password = fields.password, remember = fields.remember
        alert.accessoryView = fields
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .alertFirstButtonReturn, !self.completed else { password.stringValue = ""; return }
            if let window = fields.window, !window.makeFirstResponder(nil) {
                password.stringValue = ""; self.status.stringValue = "请完成账号和密码输入后重新登录。"; return
            }
            self.setEditing(false); self.activity.startAnimation(nil); self.status.stringValue = "正在登录…"
            let secret = password.stringValue; password.stringValue = ""
            self.cloud.login(userID: user.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), password: secret) { [weak self] result in
                guard let self, !self.completed else { return }
                self.activity.stopAnimation(nil); self.setEditing(true)
                switch result {
                case .success(let account):
                    self.cloudAccount = account; self.account.stringValue = account.userID; self.account.toolTip = account.userID
                    let saved = self.credentials.persist(account: account, password: secret, remember: remember.state == .on)
                    self.persistenceWarning = saved ? nil : "已登录，但无法记住密码；下次需重新输入。"
                    self.refreshCloudFolders()
                case .failure(let error): self.status.stringValue = error.localizedDescription
                }
            }
        }
    }

    private func refreshCloudFolders() {
        guard let account = cloudAccount else { return }
        login.title = "切换账号"; login.isEnabled = false; save.isEnabled = false; activity.startAnimation(nil)
        session.folders(account: account) { [weak self] result in
            guard let self, !self.completed else { return }
            self.login.isEnabled = true; self.activity.stopAnimation(nil)
            switch result {
            case .success(let (renewed, items)):
                self.cloudAccount = renewed
                self.folders.removeAllItems(); self.folders.addItems(withTitles: items)
                self.folders.selectItem(withTitle: "/网页剪藏/"); self.save.isEnabled = self.input != nil
                self.status.stringValue = self.persistenceWarning ?? "请选择文件夹，然后上传。"
            case .failure(let error): self.save.isEnabled = false; self.status.stringValue = error.localizedDescription
            }
        }
    }

    @objc func openWebVersion(_ sender: Any?) { NSWorkspace.shared.open(ClipperLinks.webVersionURL) }

    private func setEditing(_ enabled: Bool) {
        titleField.isEnabled = enabled; folders.isEnabled = enabled; mode.isEnabled = enabled; login.isEnabled = enabled
        save.isEnabled = enabled && input != nil && cloudAccount != nil && folders.selectedItem != nil
    }

    @objc private func saveNote() {
        guard !completed, let input, let account = cloudAccount, let folder = folders.selectedItem?.title,
              submission.phase == .ready else { return }
        // NSTextField can still be using the shared field editor when a button
        // is clicked. Commit that edit before snapshotting metadata for async work.
        if let window = view.window, !window.makeFirstResponder(nil) {
            status.stringValue = "请先完成标题编辑，再上传。"; return
        }
        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        setEditing(false); activity.startAnimation(nil); status.stringValue = "正在准备上传…"
        submission.submit(account: account, input: input, title: title, folder: folder,
            selection: mode.selectedSegment == 1, progress: { [weak self] count, total in
                guard let self, !self.completed else { return }; self.status.stringValue = "正在处理图片 \(count)/\(total)…"
            }, uploading: { [weak self] in
                self?.status.stringValue = "正在上传到为知服务器…"
            }) { [weak self] outcome in
                guard let self, !self.completed else { return }; self.activity.stopAnimation(nil)
                switch outcome {
                case .accepted(_, let missing):
                    self.completed = true; self.save.isHidden = true; self.cancel.isHidden = true
                    self.status.stringValue = "服务器已接收，尚未确认最终保存。"
                        + (missing > 0 ? "\n\(missing) 处资源未嵌入，可对照原网页。" : "")
                    self.finishAcceptedShare()
                case .preparationFailed(let error): self.setEditing(true); self.status.stringValue = error.localizedDescription
                case .uncertain(let error):
                    self.save.title = "未确认"
                    self.status.stringValue = error.localizedDescription + "\n请到网页版检查；不自动重传，可取消此窗口。"
                }
            }
    }

    private func finishAcceptedShare() {
        guard !requestFinished else { return }; requestFinished = true
        if let onAcceptedShare { onAcceptedShare() }
        else { extensionContext?.completeRequest(returningItems: [], completionHandler: nil) }
    }

    @objc private func cancelShare() {
        if completed { finishAcceptedShare(); return }
        completed = true; submission.cancel()
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
}
