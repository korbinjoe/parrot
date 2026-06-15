# Spec: Screen Capture & OCR

## 目的

从屏幕选区截图中识别文字（含图片/PDF/视频画面等不可复制文本），输出结构化文本供翻译编排消费。

## 流程

1. 用户按截图快捷键（默认 ⌥S）。
2. `ScreenCaptureKit` 进入选区模式，用户框选区域 → 得到 `CGImage`。
3. `OCRCoordinator` 调用启用的 `OCRProvider` 识别。
4. 按版面排序还原文本（行/段重排），输出 `OCRResult`。
5. 结果送 `TranslationCoordinator` 翻译，悬浮窗展示原文+译文。

## OCRProvider 协议

```swift
struct OCRResult {
    let fullText: String
    let blocks: [OCRBlock]        // 位置+文本块，用于版面还原
    let detectedLanguages: [Language]
    let confidence: Float
}

struct OCRBlock { let text: String; let boundingBox: CGRect; let confidence: Float }

protocol OCRProvider {
    var id: String { get }
    var isAvailable: Bool { get }
    func recognize(_ image: CGImage, languageHints: [Language]) async throws -> OCRResult
}
```

## 内置实现：Apple Vision

- `VNRecognizeTextRequest`，`recognitionLevel = .accurate`，`usesLanguageCorrection = true`。
- `recognitionLanguages` 由 `languageHints` + 用户常用语言配置。
- 离线、免费、无次数限制。

## 版面还原规则

- 按 `boundingBox` 的 Y（顶→底）、同行内 X（左→右）排序。
- 行间距阈值判断换行 vs 同段；保留段落结构以提升翻译质量。

## 行为要求

- **权限**：首次需「屏幕录制」授权；未授权时引导。
- **兜底**：`confidence < 阈值(默认0.3)` 或空结果 → 提示「未识别到文字，请重截」。
- **可扩展**：插件可注册第三方 `OCRProvider`（更强 PDF/手写/公式），用户可在设置中切换默认 OCR 引擎。

## 验收标准

- [ ] ⌥S 框选含中/英文图片可正确识别并翻译
- [ ] 多行文本版面还原合理（段落不错乱）
- [ ] 屏幕录制未授权时给出明确引导
- [ ] 低置信度给出重截提示，不静默失败
