# 安全策略

## 凭据存储

- **API Key**：仅存储于 macOS 钥匙串（`KeychainStore`，`kSecClassGenericPassword`，`kSecAttrAccessibleAfterFirstUnlock`）。绝不写入 UserDefaults、历史库（`history.json`）或日志。
- **插件密钥**：通过 `$option` 在运行时注入插件 JSContext，不做持久化。
- **环境变量回退**：`DEEPL_API_KEY` / `OPENAI_API_KEY` 仅作开发期回退，生产使用建议走设置面板录入钥匙串。

## 插件沙箱

- 每个插件运行在独立的 `JSContext`（串行队列），无文件系统、无任意网络访问。
- 网络请求经 `$http` 注入，**仅允许 manifest `permissions.network` 白名单内的主机**（后缀匹配）。
- 翻译调用带超时，避免插件挂起阻塞主流程。

## 数据落盘

- 历史记录默认存储于 `~/Library/Application Support/OpenBob/history.json`，仅含原文/译文/引擎 ID/语言/时间戳，**不含密钥**。

## 权限

- 划词依赖「辅助功能」权限（Accessibility API + ⌘C 回退）。
- 截图依赖「屏幕录制」权限（系统 `screencapture` + Vision OCR）。

## 漏洞报告

请通过私有渠道（GitHub Security Advisory）报告安全问题，勿在公开 issue 中披露细节。我们会在确认后尽快修复并致谢。
