import AppKit
import CryptoKit
import PingCore

@MainActor final class Updater {
    private struct Release: Decodable {
        struct Asset: Decodable { let name: String; let size: Int; let browser_download_url: URL; let digest: String? }
        let tag_name: String; let draft: Bool; let prerelease: Bool; let assets: [Asset]
    }
    private let store: Store
    private var checking = false
    private var downloading = false
    private var available: Release?
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    init(store: Store) { self.store = store }
    func start() {
        observer = NotificationCenter.default.addObserver(forName: .init("SuperPingCheckUpdate"), object: nil, queue: .main) { [weak self] _ in Task { @MainActor in await self?.check(manual: true) } }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self, self.store.configuration.options.autoUpdateCheck else { return }
            await self.check(manual: false)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in Task { @MainActor in
            guard let self, self.store.configuration.options.autoUpdateCheck else { return }
            await self.check(manual: false)
        } }
    }
    func check(manual: Bool) async {
        if manual, let available { offer(available); return }
        guard !checking else { return }; checking = true; defer { checking = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/norvancc/super-ping/releases/latest")!)
            request.timeoutInterval = 20; request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ActionFailure(message: Localized.text("Could not check GitHub releases.", "无法查询 GitHub 发布版本。")) }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.7.0"
            guard !release.draft, !release.prerelease, ReleaseVersion.isNewer(release.tag_name, than: current) else {
                if manual { store.status = Localized.text("Super Ping is up to date.", "Super Ping 已是最新版本。") }; return
            }
            available = release
            store.status = Localized.text("Update available: ", "发现新版本：") + release.tag_name
            if manual { offer(release) }
            else if store.configuration.options.updateNotifiedVersion != release.tag_name {
                store.configuration.options.updateNotifiedVersion = release.tag_name
                showNotice(release.tag_name)
            }
        } catch { if manual { store.status = error.localizedDescription } }
    }
    private var notice: NSPanel?
    private func showNotice(_ version: String) {
        guard let screen = NSScreen.main else { return }
        let p = NSPanel(contentRect: NSRect(x: screen.visibleFrame.maxX-340, y: screen.visibleFrame.maxY-100, width: 320, height: 80), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .floating; p.isFloatingPanel = true
        let button = NSButton(title: Localized.text("Super Ping \(version) available — View", "Super Ping \(version) 已发布 · 查看"), target: self, action: #selector(viewUpdate))
        button.frame = NSRect(x: 15, y: 20, width: 290, height: 40); p.contentView?.addSubview(button)
        p.orderFrontRegardless(); notice = p
        DispatchQueue.main.asyncAfter(deadline: .now()+8) { [weak self, weak p] in p?.orderOut(nil); self?.notice = nil }
    }
    @objc private func viewUpdate() { notice?.orderOut(nil); if let available { offer(available) } }
    private func offer(_ release: Release) {
        guard !downloading else { return }
        let alert = NSAlert(); alert.messageText = "Super Ping \(release.tag_name)"
        alert.informativeText = Localized.text("Download the new installer to Downloads? The download will be verified before opening.", "是否将新版安装包下载到“下载”文件夹？下载完成后会校验，再打开安装包。")
        alert.addButton(withTitle: Localized.text("Download", "下载")); alert.addButton(withTitle: Localized.text("Later", "稍后"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { Task { await download(release) } }
    }
    private func download(_ release: Release) async {
        guard let asset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") }),
              asset.browser_download_url.scheme == "https", asset.browser_download_url.host == "github.com",
              asset.browser_download_url.path.hasPrefix("/norvancc/super-ping/releases/download/"),
              let expected = ReleaseVersion.validDigest(asset.digest), asset.size > 0, asset.size < 1_000_000_000 else {
            store.status = Localized.text("The release has no verifiable macOS installer. Visit GitHub Releases.", "此版本缺少可校验的 Mac 安装包，请前往 GitHub Releases。"); return
        }
        downloading = true; store.updateProgress = 0
        defer { downloading = false; store.updateProgress = nil }
        store.status = Localized.text("Downloading update…", "正在下载更新…")
        do {
            let progress = DownloadProgress { [weak self] value in Task { @MainActor in self?.store.updateProgress = value } }
            let (temp, response) = try await URLSession.shared.download(from: asset.browser_download_url, delegate: progress)
            defer { try? FileManager.default.removeItem(at: temp) }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ActionFailure(message: "Download failed") }
            let data = try Data(contentsOf: temp, options: .mappedIfSafe)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard data.count == asset.size, digest == expected else { throw ActionFailure(message: Localized.text("Installer verification failed.", "安装包校验失败。")) }
            let name = URL(fileURLWithPath: asset.name).lastPathComponent
            let destination = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent("\(UUID().uuidString.prefix(8))-\(name)")
            try FileManager.default.copyItem(at: temp, to: destination)
            let alert = NSAlert(); alert.messageText = Localized.text("Update downloaded and verified", "更新已下载并通过校验")
            alert.informativeText = Localized.text("Open the installer and quit Super Ping, then replace the app in Applications.", "打开安装包并退出 Super Ping 后，将新应用拖入“应用程序”替换旧版。")
            alert.addButton(withTitle: Localized.text("Open and quit", "打开并退出")); alert.addButton(withTitle: Localized.text("Later", "稍后"))
            if alert.runModal() == .alertFirstButtonReturn, NSWorkspace.shared.open(destination) { NSApp.terminate(nil) }
            store.status = destination.path
        } catch { store.status = error.localizedDescription }
    }
}

private final class DownloadProgress: NSObject, URLSessionDownloadDelegate {
    let update: (Double) -> Void
    init(update: @escaping (Double) -> Void) { self.update = update }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        update(min(1, Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)))
    }
}
