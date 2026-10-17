# MoonStory

MoonBit 互动剧情与对话引擎。写一份文本剧情，将对话、条件选择和状态变化嵌入游戏、互动小说或情景教学应用。MIT 许可。

核心是可独立引用的 MoonBit 模块；命令行和网页预览器使用同一份编译后的核心，不在 JavaScript 中重新实现剧情逻辑。

```text
story "harbor" "归航"
var accepted = false
:: start
line guide "愿意帮灯塔送一份灯芯吗？"
choice accept "接下委托" -> quest if !accepted
choice leave "离开" -> finish
:: quest
set accepted = true
emit "quest.accepted" "lighthouse"
line guide "请在涨潮前送到。"
jump start
:: finish
end "departed"
```

## 本地试玩与开发

需要 MoonBit 工具链和 Node.js 24+，无 npm 第三方依赖。验证工具链为 moonc/core `0.10.15+943464bfa`。

```sh
moon test --target js --deny-warn
npm run build
npm test
npm run demo
```

在浏览器打开 `http://127.0.0.1:4175/`。左侧修改脚本，点击“检查剧情”和“重新开始”，右侧观察变量、节点与宿主事件。可以保存到此浏览器或导出 JSON 存档；存档要求完全相同的脚本版本。服务只绑定本机，只提供指定公开资源。

## 安装运行库

```sh
moon add forey217/moonstory@0.1.0
```

在 `moon.pkg` 中导入 `"forey217/moonstory" @story`。`compile` 检查完整脚本；`start` 创建会话；`frame()` 返回 Line、Choices 或 Ended；`advance()`/`choose(id)` 返回新会话。`events()` 交付这次推进新增的宿主事件。`save()`/`restore()` 保存和恢复进度。可执行的独立模块见 [examples/consumer](examples/consumer)。

## 三个可完整游玩的场景

| 示例 | 可验证的完整流程 |
| --- | --- |
| [归航](examples/harbor.mstory) | 接受委托、按金币解锁地图选项、送达灯芯、领取奖励，三种结局 |
| [零点观测站](examples/observatory.mstory) | 有限时间探索、组合线索、决定应答方式，三种结局 |
| [失物招领](examples/training.mstory) | 身份核实、沟通选择、输出风险或评分事件，四种结局 |

```sh
node scripts/cli.mjs check examples/harbor.mstory
node scripts/cli.mjs play examples/harbor.mstory --out progress.json
node scripts/cli.mjs run examples/training.mstory --actions examples/training-pass.actions.json
node scripts/cli.mjs graph examples/harbor.mstory
```

## 语义与验证

类型检查覆盖变量、表达式、条件和插值引用；整数运算溢出报错。按稳定 id 选择，不依赖可见列表位置。推进失败保持原会话。自动指令、表达式、源文本与会话动作数均有上限。

存档通过精确源文本与玩家动作重放重建状态，恢复时抑制历史事件。宿主自行执行并去重外部副作用；这不替代游戏事务或联网奖励鉴权。结构检查忽略条件真假，不承诺所有状态都有可用选择。首版没有随机数、并发剧情、函数、Ink/Yarn 导入或旧剧情自动迁移。

26 项 MoonBit 测试包含 2 项独立模块集成测试；7 项 Node 测试枚举全部 10 个示例结局，并将 200 份生成剧情与单独实现的 JS 状态模型逐步核对。CI 运行 JS、Wasm、Wasm-GC、native。方法与局限见 [验证说明](docs/verification.md)。

- [语言、执行约定与资源限制](docs/language.md)
- [SDK、宿主事件、JSON 边界与 CLI 接入](docs/integration.md)
- [生态核对与原创性范围](docs/ecosystem.md)
- [项目申报书](docs/proposal.md)

MoonStory 1 是本仓库独立定义的语言，不宣称兼容成熟叙事语言。代码与示例均在此实现，未移植或复制 Ink/Yarn Spinner；相邻项目来源见生态核对文档。
