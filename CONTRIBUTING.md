# 贡献指南

感谢参与 OpenBob！本项目使用 OpenSpec 变更流程驱动开发。

## 开发环境

- macOS 13+
- Xcode 16+（GUI 构建依赖完整 Xcode 工具链）

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build && swift test
```

## 工作流程

1. **提案**：非琐碎改动先在 `openspec/changes/<change-name>/` 下补充 `proposal.md` / `design.md` / `tasks.md`。
2. **实现**：按 `tasks.md` 顺序推进，逐项勾选。
3. **验证**：`swift build` 与 `swift test` 必须全绿后再提交 PR。
4. **归档**：变更合入后，将 delta specs 合并进 `openspec/specs/`。

## 代码规范

- Swift 6 并发模型：跨 actor 边界的类型需正确标注 `Sendable` / `@MainActor`。
- 引擎实现 `TranslationProvider` 协议；新引擎只需注册，无需改动编排层与 UI。
- 不要在日志、历史库、UserDefaults 写入任何密钥（见 SECURITY.md）。
- 用户可见文案使用中文。

## 提交信息

使用语义化前缀：`feat:` / `fix:` / `refactor:` / `docs:` / `test:` / `chore:`。

## 新增翻译引擎

1. 在 `Sources/OpenBobEngines/` 新建类型实现 `TranslationProvider`。
2. 在 `AppState.init()` 注册（按需经 `registerKeyed` 接入钥匙串密钥）。
3. 在 `Tests/OpenBobCoreTests/` 补充解析单测。

## 新增插件

无需改动主程序，见 [docs/plugin-development.md](./docs/plugin-development.md)。
