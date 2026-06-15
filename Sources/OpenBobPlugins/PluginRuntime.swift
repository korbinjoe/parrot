import Foundation
@preconcurrency import JavaScriptCore

/// Sandboxed JavaScriptCore runtime for one plugin.
///
/// Security boundaries (see specs/plugin-system/spec.md):
/// - Each plugin gets its own `JSContext` on a dedicated serial queue (no shared state).
/// - No filesystem access is exposed to JS.
/// - Network is only reachable through the injected `$http`, which rejects any host not
///   declared in the manifest's `permissions.network` whitelist.
/// - Per-call timeout guards against hangs.
public final class PluginRuntime: @unchecked Sendable {
    private let context: JSContext
    private let queue: DispatchQueue
    private let allowedHosts: [String]
    private let options: [String: String]
    private let session: URLSession
    private let timeout: TimeInterval

    public init(script: String,
                allowedHosts: [String],
                options: [String: String],
                session: URLSession = .shared,
                timeout: TimeInterval = 20) throws {
        guard let ctx = JSContext() else { throw PluginError.scriptLoadFailed("no JSContext") }
        self.context = ctx
        self.queue = DispatchQueue(label: "openbob.plugin.\(UUID().uuidString)")
        self.allowedHosts = allowedHosts
        self.options = options
        self.session = session
        self.timeout = timeout

        var thrown: Error?
        queue.sync {
            installEnvironment()
            ctx.exceptionHandler = { _, value in
                thrown = PluginError.runtime(value?.toString() ?? "unknown JS exception")
            }
            ctx.evaluateScript(script)
            if ctx.objectForKeyedSubscript("translate")?.isUndefined ?? true {
                thrown = thrown ?? PluginError.noTranslateFunction
            }
        }
        if let thrown { throw thrown }
    }

    /// Inject `$option`, `$log`, and the whitelisted `$http`.
    private func installEnvironment() {
        context.setObject(options, forKeyedSubscript: "$option" as NSString)

        let log: @convention(block) (String) -> Void = { msg in
            #if DEBUG
            print("[plugin] \(msg)")
            #endif
        }
        context.setObject(log, forKeyedSubscript: "$log" as NSString)

        // $http.request({ url, method, header, body, handler })
        let http = JSValue(object: [:], in: context)
        let request: @convention(block) (JSValue) -> Void = { [weak self] arg in
            self?.performHTTP(arg)
        }
        http?.setObject(request, forKeyedSubscript: "request" as NSString)
        // convenience get/post route to request with method set.
        context.setObject(http, forKeyedSubscript: "$http" as NSString)
        context.evaluateScript("""
        $http.get = function(o){ o.method = 'GET'; return $http.request(o); };
        $http.post = function(o){ o.method = 'POST'; return $http.request(o); };
        """)
    }

    /// Whitelisted network bridge. Runs the URLSession task off-queue, then re-enters the
    /// plugin queue to invoke the JS handler (JSContext is not thread-safe).
    private func performHTTP(_ arg: JSValue) {
        guard let urlString = arg.objectForKeyedSubscript("url")?.toString(),
              let url = URL(string: urlString),
              let host = url.host else {
            invokeHandler(arg, error: "invalid url"); return
        }
        guard isHostAllowed(host) else {
            invokeHandler(arg, error: "network not permitted: \(host)"); return
        }

        var req = URLRequest(url: url)
        req.httpMethod = (arg.objectForKeyedSubscript("method")?.toString() ?? "GET").uppercased()
        if let header = arg.objectForKeyedSubscript("header")?.toDictionary() as? [String: Any] {
            for (k, v) in header { req.setValue("\(v)", forHTTPHeaderField: k) }
        }
        if let body = arg.objectForKeyedSubscript("body"), !body.isUndefined, !body.isNull {
            if let dict = body.toDictionary(), let data = try? JSONSerialization.data(withJSONObject: dict) {
                req.httpBody = data
                if req.value(forHTTPHeaderField: "Content-Type") == nil {
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } else if let s = body.toString() {
                req.httpBody = s.data(using: .utf8)
            }
        }

        let handler = arg.objectForKeyedSubscript("handler")
        session.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            self.queue.async {
                guard let handler, !handler.isUndefined else { return }
                if let error {
                    _ = handler.call(withArguments: [["error": error.localizedDescription]])
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                // Provide both raw string and parsed JSON (if any) as `data`.
                var payload: [String: Any] = ["statusCode": status, "rawData": text]
                if let data, let json = try? JSONSerialization.jsonObject(with: data) {
                    payload["data"] = json
                }
                _ = handler.call(withArguments: [payload])
            }
        }.resume()
    }

    private func invokeHandler(_ arg: JSValue, error: String) {
        queue.async {
            let handler = arg.objectForKeyedSubscript("handler")
            if let handler, !handler.isUndefined {
                _ = handler.call(withArguments: [["error": error]])
            }
        }
    }

    private func isHostAllowed(_ host: String) -> Bool {
        allowedHosts.contains { allowed in
            host == allowed || host.hasSuffix("." + allowed)
        }
    }

    /// Call JS `translate(query, completion)` and await the completion payload.
    /// Returns the dictionary the plugin passed to `completion(...)`.
    public func callTranslate(query: [String: Any]) async throws -> [String: Any] {
        try await withThrowingTaskGroup(of: [String: Any].self) { group in
            group.addTask { [queue, context, timeout] in
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[String: Any], Error>) in
                    queue.async {
                        let resumed = ResumeGuard()
                        let completion: @convention(block) (JSValue) -> Void = { result in
                            guard resumed.tryResume() else { return }
                            cont.resume(returning: result.toDictionary() as? [String: Any] ?? [:])
                        }
                        guard let translate = context.objectForKeyedSubscript("translate"),
                              !translate.isUndefined else {
                            if resumed.tryResume() { cont.resume(throwing: PluginError.noTranslateFunction) }
                            return
                        }
                        let completionValue = JSValue(object: completion, in: context)
                        translate.call(withArguments: [query, completionValue as Any])
                        // Timeout fallback for plugins that never call completion.
                        queue.asyncAfter(deadline: .now() + timeout) {
                            if resumed.tryResume() { cont.resume(throwing: PluginError.timeout) }
                        }
                    }
                }
            }
            guard let result = try await group.next() else { throw PluginError.timeout }
            group.cancelAll()
            return result
        }
    }
}

/// Ensures a continuation is resumed exactly once across async callbacks.
private final class ResumeGuard: @unchecked Sendable {
    private var done = false
    private let lock = NSLock()
    func tryResume() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
