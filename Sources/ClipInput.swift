// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

struct ClipInput {
    let title: String
    let url: String
    let pageHTML: String
    let selectionHTML: String
    let text: String
    let selectionText: String
    let resources: [String]
    let warnings: Int
    static let maximumBytes = 8 * 1024 * 1024

    init(dictionary: [String: Any]) throws {
        guard let url = dictionary["url"] as? String, let address = URLComponents(string: url),
              ["http", "https"].contains(address.scheme?.lowercased() ?? ""),
              let host = address.host, !host.isEmpty, address.user == nil, address.password == nil,
              url.utf8.count <= 4096 else { throw ClipperError.message("无法获取有效的网页地址") }
        let page = dictionary["pageHTML"] as? String ?? ""
        let selection = dictionary["selectionHTML"] as? String ?? ""
        guard (!page.isEmpty || !selection.isEmpty), page.utf8.count <= Self.maximumBytes,
              selection.utf8.count <= Self.maximumBytes else {
            throw ClipperError.message("未收到可保存的正文，或正文过大。请尝试选中段落后重新分享。")
        }
        let title = dictionary["title"] as? String ?? host
        self.title = String(title.prefix(512)); self.url = url
        pageHTML = page; selectionHTML = selection
        text = String((dictionary["text"] as? String ?? "").prefix(50000))
        selectionText = String((dictionary["selectionText"] as? String ?? "").prefix(50000))
        let images = dictionary["resources"] as? [String] ?? []
        guard images.count <= 48, images.allSatisfy({ $0.utf8.count <= 4096 }) else {
            throw ClipperError.message("图片资源过多，请改用选区")
        }
        resources = images
        warnings = max(0, min(dictionary["warnings"] as? Int ?? 0, 100000))
    }
}

enum ClipperError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}
