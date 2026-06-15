# Spec: Plugin System

## 目的

允许第三方/社区用 JavaScript 编写翻译插件，接入任意 LLM 或翻译服务，热加载、可配置、沙箱安全；接口尽量贴近 Bob 插件以降低社区迁移成本（不承诺 100% 兼容）。

## 插件包结构

```
my-plugin.bobplugin/  (zip 或目录)
├── info.json     # manifest
└── main.js       # 实现 translate 接口
```

### info.json (manifest)

```json
{
  "identifier": "com.author.gpt-translate",
  "name": "GPT Translate",
  "version": "1.0.0",
  "author": "name",
  "minOpenBobVersion": "1.0.0",
  "capabilities": ["translate", "lookup"],
  "permissions": {
    "network": ["api.openai.com"]      // 域名白名单
  },
  "options": [                          // 用户可配置项 → 注入 $option
    { "key": "apiKey", "type": "secret", "label": "API Key", "required": true },
    { "key": "model", "type": "string", "default": "gpt-4o-mini" },
    { "key": "prompt", "type": "text", "label": "System Prompt" }
  ]
}
```

### main.js 接口

```js
// 宿主注入：$http、$option、$log、支持回调或 Promise
function translate(query, completion) {
  // query: { text, from, to, mode }
  // $option: 用户配置（secret 类型由宿主从 Keychain 注入，用后即焚）
  $http.post({
    url: "https://api.openai.com/v1/chat/completions",
    header: { "Authorization": "Bearer " + $option.apiKey },
    body: { /* ... */ },
    handler: (resp) => {
      completion({ result: { translated: resp.data.choices[0].message.content } });
    }
  });
}
```

## 安全沙箱（强约束）

| 维度 | 约束 |
|------|------|
| 运行时 | JavaScriptCore，独立 `JSContext` per 插件 |
| 文件系统 | 无任何 fs 访问 |
| 网络 | 仅通过宿主 `$http`；URL host 必须在 manifest `permissions.network` 白名单内，否则拒绝 |
| 密钥 | `secret` 类型 option 存 Keychain；注入到 JS 时不持久化，调用结束清理 |
| 资源 | 单次调用超时（默认 20s）+ JS 内存上限 + CPU watchdog |
| 安装 | 展示权限清单（网络域名、能力）需用户确认 |

## 生命周期

- **安装**：导入 `.bobplugin` → 校验 manifest schema → 展示权限 → 落地到插件目录。
- **配置**：UI 按 `options` 渲染表单；`secret` 写 Keychain。
- **启用/禁用**：即时生效，禁用的插件不参与聚合。
- **热加载**：监听插件目录变化，无需重启。
- **适配**：每个启用插件包装为 `PluginProvider: TranslationProvider`，与内置引擎一同参与聚合对比。

## 错误处理

- manifest 非法 / 缺必填 option → 安装或调用前报错，不进入聚合。
- JS 抛错 / 超时 / 越权网络 → 转 `ProviderError.plugin(msg)`，该卡片错误态，不影响其它引擎。

## 验收标准

- [ ] 可安装示例 GPT 插件并接入聚合对比
- [ ] 越白名单的网络请求被拒绝
- [ ] secret 配置仅存 Keychain，JS 上下文/日志无明文
- [ ] 插件超时/抛错被隔离，不影响宿主与其它引擎
- [ ] 启用/禁用/卸载无需重启 App
