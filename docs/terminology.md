# Parrot 术语表

术语表用于固定专业名词、产品名和团队约定译法。典型例子：

| 源词 | 译法 | 场景 |
|------|------|------|
| AI Agent | AI Agent | 保留英文术语 |
| LLM | LLM | 缩写不翻译 |
| prompt engineering | 提示词工程 | 固定行业译法 |

## 工作方式

- 机器翻译：Parrot 会先把命中的源词替换为稳定占位符，翻译后再恢复为目标译法。
- LLM：Parrot 会把术语约束加入 system prompt；当源词和译法相同（例如 `Agent -> Agent`）时，也会叠加占位符保护，确保产品名、缩写和英文术语不被本地化。
- 严格术语模式：LLM 会对所有命中术语叠加占位符保护，牺牲一点自然度来换取更稳定的术语保留。
- 插件：新插件可读取 `query.terminology`；旧插件保持兼容。

结果卡会显示术语状态：

- `术语已应用 · 2`：命中并恢复成功。
- `术语约束 · 2`：LLM 收到了术语 prompt，未使用占位符强制恢复。
- `术语未命中`：术语表开启，但当前文本没有匹配。
- `术语恢复失败`：引擎改写了占位符，Parrot 无法可靠恢复。

## CSV 格式

导入/导出字段固定为：

```csv
source,target,from,to,caseSensitive,note,enabled
AI Agent,AI Agent,en,zh,true,AI/product term,true
LLM,LLM,en,zh,true,model abbreviation,true
prompt engineering,提示词工程,en,zh,false,AI terminology,true
```

字段说明：

- `source`：源词或短语，必填。
- `target`：固定译法，必填。
- `from`：源语言，使用 ISO 代码；`auto` 表示任意源语言。
- `to`：目标语言，使用 ISO 代码。
- `caseSensitive`：`true`/`false`。
- `note`：可选备注。
- `enabled`：`true`/`false`。
