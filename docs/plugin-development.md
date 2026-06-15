# 插件开发指南

OpenBob 插件是一个 `.bobplugin` 目录，包含 `info.json`（清单）与 `main.js`（实现）。插件运行在 JavaScriptCore 沙箱中，可接入任意 LLM 或词典服务。

安装位置：`~/Library/Application Support/OpenBob/Plugins/`，应用启动时自动加载。

## 目录结构

```
my-engine.bobplugin/
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
- `options`：用户可配置项；`secret: true` 的项通过钥匙串/`$option` 注入，不落盘。

## main.js（实现）

必须实现全局 `translate(query)` 函数（同步或返回 Promise）：

```js
function translate(query) {
  // query: { text, from, to }
  const key = $option.apiKey;
  const resp = $http.post({
    url: "https://api.example.com/v1/translate",
    header: { "Authorization": "Bearer " + key, "Content-Type": "application/json" },
    body: { text: query.text, target: query.to }
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

## 调试

- 加载失败的插件会被静默跳过；用 `$log` 排查。
- 网络被拒说明目标主机不在 `permissions.network` 白名单。

参考实现：`examples/echo.bobplugin`（最小回显）、`examples/openai.bobplugin`（接入 OpenAI）。
