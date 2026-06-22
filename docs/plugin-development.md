# 插件开发指南

Parrot 插件是一个 `.parrotplugin` 目录，包含 `info.json`（清单）与 `main.js`（实现）。插件运行在 JavaScriptCore 沙箱中，可接入任意 LLM 或词典服务。

安装位置：`~/Library/Application Support/Parrot/Plugins/`，应用启动时自动加载。

## 目录结构

```
my-engine.parrotplugin/
  info.json
  main.js
```

## info.json（清单）

```json
{
  "identifier": "com.example.myengine",
  "name": "My Engine",
  "version": "1.0.0",
  "capabilities": ["translate"],
  "supportsTerminology": true,
  "permissions": {
    "network": ["api.example.com"]
  },
  "options": [
    { "key": "apiKey", "name": "API Key", "secret": true },
    { "key": "model", "name": "Model", "default": "gpt-4o-mini" }
  ]
}
```

- `permissions.network`：允许访问的主机白名单（后缀匹配）。不在此列表的请求会被拒绝。
- `supportsTerminology`：可选；声明插件会自己读取 `query.terminology` 并处理术语约束。未声明时，宿主仍可用占位符保护做兼容。
- `options`：用户可配置项；`secret: true` 的项通过本地 SecretStore/`$option` 注入，不写入历史库或日志。

## main.js（实现）

必须实现全局 `translate(query)` 函数（同步或返回 Promise）：

```js
function translate(query) {
  // query: { text, from, to, mode, terminology? }
  const key = $option.apiKey;
  const terms = query.terminology || [];
  const terminologyPrompt = terms.length
    ? "\nTerminology:\n" + terms.map(t => `- ${t.source} => ${t.target}`).join("\n")
    : "";
  const resp = $http.post({
    url: "https://api.example.com/v1/translate",
    header: { "Authorization": "Bearer " + key, "Content-Type": "application/json" },
    body: { text: query.text, target: query.to, instruction: terminologyPrompt }
  });
  if (resp.error) {
    return { error: { message: resp.error } };
  }
  return { result: { translated: resp.data.translation } };
}
```

### 返回格式（任一）

```js
{ result: { translated: "..." } }              // 单段译文
{ result: { toParagraphs: ["...", "..."] } }   // 多段
{ translated: "..." }                          // 简写
{ error: { message: "..." } }                  // 错误
```

## 注入的宿主 API

| API | 说明 |
|-----|------|
| `$http.get/post({url, header, body})` | HTTP 请求，受网络白名单限制 |
| `$option.<key>` | 读取清单中声明的配置项 |
| `$log(msg)` | 输出调试日志 |

## 术语表

当用户启用术语表且本次文本命中术语时，宿主会把命中项放在 `query.terminology`：

```js
[
  { source: "AI Agent", target: "AI Agent", from: "en", to: "zh" }
]
```

LLM 插件应把它拼进 system prompt，例如：

```js
var system = "Translate to " + query.to + ". Output only the translation.";
if (query.terminology && query.terminology.length) {
  system += "\n\nTerminology constraints:";
  query.terminology.forEach(function (term) {
    system += "\n- " + term.source + " => " + term.target;
  });
  system += "\nUse the exact target term whenever the source term appears.";
}
```

旧插件可以忽略 `query.terminology`；宿主会尽量通过占位符保护兼容。

## 调试

- 加载失败的插件会被静默跳过；用 `$log` 排查。
- 网络被拒说明目标主机不在 `permissions.network` 白名单。

参考实现：`examples/echo.parrotplugin`（最小回显）、`examples/openai.parrotplugin`（接入 OpenAI）。
