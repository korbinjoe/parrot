import Foundation

struct CredentialFormIssue: Equatable {
    enum Field: Equatable {
        case secret
        case endpoint
        case model(String)
        case region
    }

    let field: Field
    let message: String
}

/// Checks only the draft's shape. A valid draft is not proof that a service is reachable.
enum CredentialDraftValidation {
    static func issues(
        descriptor: CredentialDescriptor,
        secret: String,
        models: [EngineModelConfig],
        endpoint: String,
        region: String? = nil
    ) -> [CredentialFormIssue] {
        var issues: [CredentialFormIssue] = []
        let secret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        if !secret.isEmpty, let credential = descriptor.credential,
           credential.account.hasSuffix(".credentials"),
           !hasCredentialPair(secret) {
            issues.append(.init(field: .secret, message: L("请按 %@ 格式填写，两部分都不能为空。", credential.placeholder)))
        }

        if descriptor.defaultModel != nil {
            let enabled = models.filter(\.enabled)
            if enabled.isEmpty {
                issues.append(.init(field: .model(models.first?.id ?? EngineModelConfig.primaryID), message: L("请至少启用一个模型。")))
            }
            var names = Set<String>()
            for model in enabled {
                if model.trimmedName.isEmpty {
                    issues.append(.init(field: .model(model.id), message: L("请输入已启用模型的名称。")))
                } else if !names.insert(model.trimmedName).inserted {
                    issues.append(.init(field: .model(model.id), message: L("这个模型已启用，请使用不同的模型名称或关闭重复项。")))
                }
            }
        }

        let endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !endpoint.isEmpty, !isValidEndpoint(endpoint) {
            issues.append(.init(field: .endpoint, message: L("请输入完整的 http:// 或 https:// 服务地址，不要在地址中包含用户名或密码。")))
        }

        if let region {
            let region = region.trimmingCharacters(in: .whitespacesAndNewlines)
            if region.isEmpty {
                issues.append(.init(field: .region, message: L("请输入云服务资源的区域。")))
            } else if region.range(of: "^[A-Za-z0-9-]+$", options: .regularExpression) == nil {
                issues.append(.init(field: .region, message: L("区域只能包含字母、数字和连字符。")))
            }
        }
        return issues
    }

    private static func hasCredentialPair(_ value: String) -> Bool {
        let parts = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        return parts.count == 2 && parts.allSatisfy {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private static func isValidEndpoint(_ value: String) -> Bool {
        guard !value.contains(where: \.isWhitespace),
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.fragment == nil,
              let url = components.url, url.host != nil else { return false }
        if let port = components.port, !(1...65535).contains(port) { return false }
        return true
    }
}
