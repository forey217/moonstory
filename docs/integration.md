# 将 MoonStory 接入应用

## MoonBit SDK

```sh
moon add forey217/moonstory@0.1.1
```

在 `moon.pkg` 中导入 `"forey217/moonstory" @story`。可执行的外部模块示例位于 `examples/consumer`，它只依赖公开 API。

```moonbit
let story = @story.compile(source)
let first = @story.start(story)
// first.frame(): Line / Choices / Ended
let options = first.advance()
let selected = options.choose("accept")
for event in selected.events() {
  // 根据 event.name 与 event.value 接入物品栏、任务或评分系统。
  // 在自己的 session_id 命名空间内按 event.sequence 去重。
}
let saved = selected.save()
let resumed = @story.restore(story, saved)
// resumed.events() 为空；下一次推进只返回新增事件。
```

运行时不访问网络、文件、时钟或随机数。所有状态转移返回新的 Session；调用者必须接住返回值。失败时继续保留原 Session，不能把异常当作空选项或剧情结束。读取 `frame()`、`variables()`、`events()` 返回副本；重复读取 events 不会消费它。

变量初值由剧情的 var 声明指定，首版没有运行中宿主注入变量接口。一次会话的外部任务结果应先由宿主处理，再由剧情选项推进；异步任务、多人共享状态和事务性外部存储由集成方负责。emit 是通知，不是游戏任务管理器。

## JavaScript / 浏览器边界

`npm run build` 将相同 MoonBit 核心编译为 `_build/host/engine.mjs`，导出 `run_json(string) -> string`。Node 和浏览器都调用这个函数，不在前端重新实现表达式或剧情逻辑。

| command | 输入字段 | result |
| --- | --- | --- |
| check | source | id、title、nodes、instructions、diagnostics |
| start | source | state、save |
| advance | source、save | state、save |
| choose | source、save、choice | state、save |
| restore | source、save | state、save；events 为空 |

成功返回 `{ "ok": true, "result": ... }`；失败返回 `{ "ok": false, "code": "...", "line": 0, "column": 0, "error": "..." }`。语法错误位置为从 1 开始的 UTF-16 行列；无源位置的错误 line/column 为 0。state 包含 frame、node、line、variables、events 和 actions。宿主按 ok 判定成功，不解析英文错误文案。

## 命令行

```sh
npm run build
node scripts/cli.mjs check examples/harbor.mstory
node scripts/cli.mjs graph examples/harbor.mstory
node scripts/cli.mjs play examples/harbor.mstory --out progress.json
node scripts/cli.mjs play examples/harbor.mstory --save progress.json --out progress.json
node scripts/cli.mjs run examples/training.mstory --actions examples/training-pass.actions.json
```

play 输入稳定选项 id，空行推进对话，`:quit` 保存退出（需指定 --out）。graph 输出 DOT。run 接受动作文件：空字符串为 advance，非空字符串为 choose id，错误时进程返回非零退出码。CLI 只负责输入输出，决策仍由 MoonBit 执行。

## 存档成本与兼容性

存档保存原始源文本与动作序列，而不是信任未验证的游标与变量。恢复成本随已执行指令和动作增长，动作数组复制使最坏成本为二次量级；它适合本项目边界内的短到中篇对话。JSON 桥每次调用也会重放历史，长篇游戏应优先持有 SDK Session，避免每一步都走无状态桥。10,000 动作是安全上限，不是性能保证。

源文本任何改动都会拒绝旧存档。首次保存前请同时备份脚本；升级剧情应使用新会话，本版本不自动猜测迁移映射。存档可被修改为另一条合法路径，不能作为联网奖励发放的授权凭据。
