import SwiftUI
import AppKit

@MainActor
final class Downloader: ObservableObject {
    @Published var url = ""
    @Published var resolution = "최고 화질"
    @Published var outputFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
    @Published var status = "치지직 다시보기 주소를 붙여넣으세요."
    @Published var log = ""
    @Published var isRunning = false

    private var process: Process?

    private var supportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChzzkDownloaderMac", isDirectory: true)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "저장 폴더 선택"
        if panel.runModal() == .OK, let url = panel.url { outputFolder = url.path }
    }

    func start() {
        guard !isRunning else { return }
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: trimmed),
              ["http", "https"].contains(parsed.scheme?.lowercased() ?? ""),
              parsed.host?.contains("chzzk.naver.com") == true else {
            status = "chzzk.naver.com 다시보기 또는 클립 주소를 입력해 주세요."
            return
        }
        guard FileManager.default.fileExists(atPath: outputFolder) else {
            status = "저장 폴더를 찾을 수 없습니다. 저장 위치를 다시 선택해 주세요."
            return
        }

        isRunning = true
        log = ""
        status = "다운로더 준비 중… 첫 실행은 구성 요소 설치로 시간이 걸릴 수 있습니다."
        Task.detached { [weak self] in
            await self?.runDownload(url: trimmed)
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
        status = "중지 요청을 보냈습니다."
    }

    private func append(_ text: String) {
        Task { @MainActor in self.log += text }
    }

    private func setStatus(_ text: String) {
        Task { @MainActor in self.status = text }
    }

    private func finish(_ success: Bool, message: String) {
        Task { @MainActor in
            self.isRunning = false
            self.status = message
            self.process = nil
        }
    }

    private func runShell(_ command: String, workingDirectory: URL? = nil) async -> Int32 {
        await withCheckedContinuation { continuation in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-lc", command]
            if let workingDirectory { p.currentDirectoryURL = workingDirectory }
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = pipe
            p.terminationHandler = { proc in continuation.resume(returning: proc.terminationStatus) }
            do {
                try p.run()
                Task.detached {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let s = String(data: data, encoding: .utf8), !s.isEmpty {
                        await MainActor.run { self.log += s }
                    }
                }
                await MainActor.run { self.process = p }
            } catch {
                append("실행 오류: \(error.localizedDescription)\n")
                continuation.resume(returning: -1)
            }
        }
    }

    private func runDownload(url: String) async {
        do {
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            let repo = supportDir.appendingPathComponent("engine", isDirectory: true)
            let repoPath = repo.path.replacingOccurrences(of: "'", with: "'\\''")
            let supportPath = supportDir.path.replacingOccurrences(of: "'", with: "'\\''")

            if !FileManager.default.fileExists(atPath: repo.appendingPathComponent("scripts/headless_download.py").path) {
                setStatus("다운로드 엔진 받는 중…")
                let clone = "git clone --depth 1 https://github.com/honey720/chzzk-vod-downloader-v2.git '\(repoPath)'"
                let code = await runShell(clone)
                guard code == 0 else { finish(false, message: "다운로드 엔진을 가져오지 못했습니다. 인터넷 연결을 확인해 주세요."); return }
            }

            setStatus("필요한 구성 요소 확인 중…")
            let uvPath = supportDir.appendingPathComponent("uv").path
            let uvEscaped = uvPath.replacingOccurrences(of: "'", with: "'\\''")
            if !FileManager.default.fileExists(atPath: uvPath) {
                let install = "curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR='\(supportPath)' sh"
                let code = await runShell(install)
                guard code == 0 else { finish(false, message: "필요한 구성 요소 설치에 실패했습니다."); return }
            }

            let resolutionArg = resolution == "최고 화질" ? "" : " --resolution \(resolution)"
            let safeURL = url.replacingOccurrences(of: "'", with: "'\\''")
            let safeOutput = outputFolder.replacingOccurrences(of: "'", with: "'\\''")
            let cmd = "'\(uvEscaped)' run --project '\(repoPath)' python scripts/headless_download.py '\(safeURL)'\(resolutionArg) --output '\(safeOutput)'"
            setStatus("영상 정보 확인 및 다운로드 중…")
            let result = await runShell(cmd, workingDirectory: repo)
            if result == 0 {
                finish(true, message: "완료! 선택한 폴더에서 영상을 확인하세요.")
            } else {
                finish(false, message: "다운로드에 실패했습니다. 아래 로그를 확인해 주세요. 로그인/멤버십 제한 영상은 지원 쿠키가 필요할 수 있습니다.")
            }
        } catch {
            finish(false, message: "오류: \(error.localizedDescription)")
        }
    }
}

struct ContentView: View {
    @StateObject private var downloader = Downloader()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("치지직 풀영상 다운로더").font(.title2.bold())
                    Text("macOS · Apple Silicon").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("비공식 도구").font(.caption2).padding(.horizontal, 9).padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }

            Group {
                Text("다시보기 / 클립 주소")
                    .font(.headline)
                TextField("https://chzzk.naver.com/video/…", text: $downloader.url)
                    .textFieldStyle(.roundedBorder)
                    .disabled(downloader.isRunning)

                HStack {
                    Text("화질")
                    Picker("화질", selection: $downloader.resolution) {
                        Text("최고 화질").tag("최고 화질")
                        Text("1080").tag("1080")
                        Text("720").tag("720")
                        Text("480").tag("480")
                    }
                    .frame(width: 170)
                    Spacer()
                }

                Text("저장 위치").font(.headline)
                HStack {
                    Text(downloader.outputFolder).lineLimit(1).truncationMode(.middle)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Button("폴더 선택…") { downloader.chooseFolder() }
                        .disabled(downloader.isRunning)
                }
            }

            HStack {
                Button {
                    downloader.start()
                } label: {
                    Label("다운로드 시작", systemImage: "arrow.down.to.line")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .disabled(downloader.isRunning)
                Button("중지") { downloader.stop() }
                    .disabled(!downloader.isRunning)
                Spacer()
                if downloader.isRunning { ProgressView().controlSize(.small) }
            }

            Text(downloader.status)
                .font(.callout)
                .foregroundStyle(downloader.status.hasPrefix("완료") ? .green : .secondary)

            Text("작업 로그").font(.headline)
            ScrollView {
                Text(downloader.log.isEmpty ? "다운로드 상태와 오류가 여기에 표시됩니다." : downloader.log)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(minHeight: 130)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

            Text("본인 소유이거나 다운로드 권한이 있는 영상에만 사용하세요. 첫 실행 시 인터넷을 통해 오픈소스 다운로드 엔진과 실행 구성 요소를 설치합니다.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(minWidth: 560, minHeight: 590)
    }
}

@main
struct ChzzkDownloaderMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
