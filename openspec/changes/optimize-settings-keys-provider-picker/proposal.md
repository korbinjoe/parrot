# 优化 Settings Keys Provider 选择交互

## Summary

产出一份高保真、可交互 HTML 视觉稿，用于验证 iOS「Settings > Keys」页从完全平铺 provider 列表，优化为「状态卡片 + 搜索式 provider picker」的混合交互。

## Motivation

当前 Keys 页把 provider 以分组列表平铺展示，优点是状态可见，但 provider 数量增长后会带来三个问题：

1. 需要处理的缺 Key 服务容易被大量低频 provider 稀释。
2. 用户想新增一个 provider 时，需要先滚动和筛选，再进入具体表单。
3. 已配置、环境变量、无需 Key、OCR/TTS 等状态同时平铺，信息密度偏高。

纯下拉框可以减少页面长度，但会隐藏缺 Key / 已配置 / 环境变量状态，不适合作为主交互。因此本变更验证混合结构：默认保留任务相关状态卡片，provider 目录通过可搜索 picker 渐进展开。

## Goals

- 默认首屏聚焦「需要处理」和「已配置」服务。
- 用「添加服务」打开 provider picker，按常用、LLM、OCR/TTS、云厂商分组选择。
- 选中 provider 后展开对应配置表单，支持保存、验证、清除、显示 Keychain/环境变量状态。
- 保留搜索和状态筛选，但把它们从主页面的长期噪音降为辅助入口。
- 原型可在浏览器中直接交互验证。

## Non-goals

- 不改 SwiftUI 生产代码。
- 不改 Keychain account 映射、provider 配置模型或翻译引擎行为。
- 不接入真实在线验证。

## Approach

- 新增 `mockups/index.html`，实现 iPhone 视觉框架、Settings 页、Keys 主列表、provider picker bottom sheet、provider 表单、状态切换和搜索过滤。
- 新增设计说明和规格，记录推荐交互和未来 SwiftUI 落地边界。

## Risks

- 如果 picker 过深，会降低快速修复失败服务的效率；通过默认展示「需处理」卡片规避。
- 如果只展示少量卡片，用户可能误以为 provider 支持变少；通过「添加服务」和分组目录明确完整服务列表。
