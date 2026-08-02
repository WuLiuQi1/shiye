# 书源引擎边界

书源引擎是独立模块，导入、校验、匹配、请求、解析和缓存不能混入阅读页。所有耗时解析将由后续 Use Case 放入后台 Isolate；UI 只接收已处理的结果。

## 首批兼容范围

导入器接受三类 JSON：

- 阅读 / Legado：识别 `bookSourceUrl`、`bookSourceName` 和 `ruleSearch` 等声明式字段。
- ORSP：识别 `id`、`name` 与 `baseUrl` / `url` 字段。
- 包装格式：`{ "sources": [ ... ] }`。

书源地址只能使用 `http` 或 `https`。阅读 / Legado `bookSourceUrl` 后附带的头信息仅用于识别地址，不会被自动发送；尤其不会携带 Cookie。导入后会保留原始规则数据用于管理与兼容性标记，但运行链路只读取声明式 CSS Selector、简单 XPath 和正则替换规则。

## 兼容状态

拾页允许导入带脚本字段的书源，但脚本永远不会在应用内运行。导入器会为每个书源标记状态：

- `可用`：未发现脚本、登录或 Cookie 依赖，可参与搜索、详情、目录和正文解析。
- `部分可用`：包含非关键脚本辅助字段；脚本会被忽略，只使用声明式规则。
- `需要脚本`：搜索、目录或正文依赖 `@js`、`<js>`、Java、`eval`、动态执行等规则；书源可保存和查看，但不会参与搜索、换源或阅读。
- `需要登录或 Cookie`：包含登录、Cookie、鉴权或令牌依赖；书源可保存和查看，但默认禁用。

这个策略用于兼容大型合集：不会因为一个复杂源导致整包失败，也不会把第三方脚本带进拾页执行环境。

## 当前浏览链路

`BrowseBookSource` 已把搜索、书籍详情、目录、正文解析统一为同一组领域模型。它只依赖 `BookSourceGateway`，所以页面不会直接联网；网关已包含 HTTP/HTTPS 限制、超时与 5 MiB 响应上限。

当前规则解释器支持首批安全选择器：标签、`.class`、`#id`、`tag.class`，以及等价的简单 XPath 形式；`@text`、`@html`、`@href`/`@src` 提取；`{{key}}` 和 `%s` 搜索关键词模板；正文 `replaceRegex` 清理以及 `selector##regex##replacement` 的正则替换。复杂 CSS/XPath 语法会在兼容性测试后逐项扩展，不会以执行脚本来补齐。

## 明确不支持

- JavaScript、Java、脚本、动态执行、下载并执行代码。
- 自动 Cookie、加密破解或任何需要执行书源自带代码的规则。
- 未校验书源的自动联网请求。

这样书源文件始终只是数据，符合闭源应用的安全与商店发布边界。后续搜索、同书匹配和阅读中手动换源，都只能建立在已导入、已验证的书源之上。
# Matched sources and reader switching

When a book is added to the shelf, 拾页 may search other enabled sources and
stores only strict title-and-author matches as that book's alternate sources.
The reader exposes those stored matches through a user-initiated action sheet.
It never searches for a replacement or switches automatically while reading.

After the user chooses a source, the reader resolves the saved detail link and
tries to retain the reading location by matching the chapter title first, then
falling back to the saved chapter index. A failed source is kept out of the
selection rather than silently changing the active source.
