// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

// One explicit share action, at most one POST. No status polling, persisted
// pending task or account/keychain reads; uncertainty never triggers a retry.
final class CloudClipSubmission {
    enum Phase { case ready, preparing, uploading, accepted, uncertain, cancelled }
    enum Outcome {
        case accepted(CloudClipReceipt, missingImages: Int)
        case preparationFailed(Error)
        case uncertain(Error)
    }
    private(set) var phase: Phase = .ready
    private let client: CloudClipClient
    private let resources: ClipResources
    init(client: CloudClipClient, resources: ClipResources = ClipResources()) { self.client = client; self.resources = resources }
    func submit(account: CloudClipAccount, input: ClipInput, title: String, folder: String, selection: Bool,
                progress: @escaping (Int, Int) -> Void, uploading: @escaping () -> Void = {}, completion: @escaping (Outcome) -> Void) {
        guard phase == .ready else { return }
        let html = selection ? input.selectionHTML : input.pageHTML
        let requestID = UUID().uuidString.lowercased()
        do {
            _ = try CloudClipClient.gatherBody(account: account, requestID: requestID, title: title, folder: folder, sourceURL: input.url, html: html)
        } catch { completion(.preparationFailed(error)); return }
        phase = .preparing
        resources.embed(html: html, urls: input.resources, progress: progress) { [weak self] html, missing in
            guard let self, self.phase == .preparing else { return }
            do {
                let body = try CloudClipClient.gatherBody(account: account, requestID: requestID, title: title, folder: folder, sourceURL: input.url, html: html)
                self.phase = .uploading
                uploading()
                guard self.phase == .uploading else { return }
                self.client.upload(body: body, account: account) { [weak self] result in
                    guard let self, self.phase == .uploading else { return }
                    switch result {
                    case .success(let receipt): self.phase = .accepted; completion(.accepted(receipt, missingImages: missing + input.warnings))
                    case .failure(let error): self.phase = .uncertain; completion(.uncertain(error))
                    }
                }
            } catch { self.phase = .ready; completion(.preparationFailed(error)) }
        }
    }
    func cancel() { if phase != .accepted { phase = .cancelled } }
}
