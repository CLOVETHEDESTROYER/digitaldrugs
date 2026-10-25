import AppKit
import WebKit

/// App-hosted WebKit integration review; no production history, exchange or audio.
@MainActor enum VisualLabReview {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task { @MainActor in
            do { try await verify(); print("Verified all six offline Butterchurn presets, frame input and transitions."); fflush(stdout); exit(0) }
            catch { fputs("Visual Lab verification failed: \(error)\n", stderr); exit(1) }
        }
        app.run()
    }
    static func verify() async throws {
        let config = WKWebViewConfiguration(), messages = Messages()
        config.userContentController.add(messages, name: "visualLab")
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 420, height: 850), configuration: config)
        let window = NSWindow(contentRect: web.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = web
        defer { web.stopLoading(); config.userContentController.removeScriptMessageHandler(forName: "visualLab"); window.close() }
        web.loadFileURL(VisualLabState.page, allowingReadAccessTo: VisualLabState.page.deletingLastPathComponent())
        let deadline = Date().addingTimeInterval(30)
        while !messages.ready && messages.error == nil && Date() < deadline { try await Task.sleep(nanoseconds: 100_000_000) }
        guard messages.ready, messages.error == nil else { throw StudioError.message(messages.error ?? "WebKit did not initialize the offline page.") }
        let root: URL
        if let index = CommandLine.arguments.firstIndex(of: "--output"), CommandLine.arguments.indices.contains(index + 1) {
            root = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        } else { root = FileManager.default.temporaryDirectory.appendingPathComponent("ZenWave-VisualLab-Review") }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let movie = CommandLine.arguments.contains("--with-movie")
        var background: VisualLabPCM?
        if let index = CommandLine.arguments.firstIndex(of: "--background"), CommandLine.arguments.indices.contains(index + 1) {
            background = try VisualLabPCM(backgroundURL: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }
        let frames = root.appendingPathComponent("Frames")
        if movie { try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true) }
        var hashes = Set<String>()
        for index in 0..<6 {
            _ = try await web.evaluateJavaScript("document.getElementById('quality').value='480'; document.getElementById('quality').onchange();document.getElementById('blend').value='3'; document.getElementById('preset').value='\(index)'; document.getElementById('preset').onchange();")
            if let error = messages.error { throw StudioError.message(error) }
            let count = movie ? 180 : 1
            for frame in 0..<count {
                let steps = movie ? 1 : 120
                let packet: String
                if let background {
                    let samples = try background.samples(at: Double(index * 180 + frame) / 30)
                    packet = "const mono=\(try ContentHistory.json(samples.mono)),left=\(try ContentHistory.json(samples.left)),right=\(try ContentHistory.json(samples.right));"
                } else {
                    packet = "const mono=Array.from({length:1024},(_,i)=>Math.round(128+(28+10*Math.sin(\(frame)/30))*Math.sin(i*.031)+14*Math.sin(i*.37))),left=mono,right=mono;"
                }
                let script = """
                (() => {
                  \(packet)
                  for(let f=0;f<\(steps);f++)window.ZenWaveLab.frame({time:\(index)*6+\(frame)/30+f/30,delta:1/30,generation:1,mono,left,right});
                  return document.getElementById('visual').toDataURL('image/png');
                })()
                """
                guard let encoded = try await web.evaluateJavaScript(script) as? String,
                      let bytes = encoded.split(separator: ",").last, let data = Data(base64Encoded: String(bytes)) else { throw StudioError.message("Could not capture the WebGL frame.") }
                if movie { try data.write(to: frames.appendingPathComponent(String(format: "%05d.png", index * 180 + frame))) }
                if frame == count - 1 {
                    try data.write(to: root.appendingPathComponent("preset-\(index + 1).png"))
                    guard hasVisibleDetail(data) else { throw StudioError.message("Preset \(index + 1) rendered an empty canvas (\(data.count) bytes).") }
                    hashes.insert(ContentHistory.hash(data)); try data.write(to: root.appendingPathComponent("preset-\(index + 1).png"))
                }
            }
            print("Rendered preset \(index + 1)/6"); fflush(stdout)
        }
        guard hashes.count == 6 else { throw StudioError.message("Presets must produce distinct visuals.") }
        let snapshot = try await web.takeSnapshot(configuration: nil)
        if let tiff = snapshot.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
            try png.write(to: root.appendingPathComponent("lab-window.png"))
        }
        print("Review: \(root.path)")
    }
    private static func hasVisibleDetail(_ data: Data) -> Bool {
        guard let bitmap = NSBitmapImageRep(data: data) else { return false }
        var colors = Set<Int>()
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: max(1, bitmap.pixelsHigh / 35)) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: max(1, bitmap.pixelsWide / 25)) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let r = Int(color.redComponent * 255), g = Int(color.greenComponent * 255), b = Int(color.blueComponent * 255)
                colors.insert((r << 16) | (g << 8) | b)
            }
        }
        return colors.count > 8
    }
    final class Messages: NSObject, WKScriptMessageHandler {
        var ready = false
        var error: String?
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let event = message.body as? [String: String] {
                if event["type"] == "ready" { ready = true }
                if event["type"] == "error" { error = event["message"] }
            }
        }
    }
}
