# 生态与原创性核对（2026-10-17）

MoonStory 的用途是为 MoonBit 应用提供独立的对话脚本执行层，以及可运行的创作、检查和集成工具。它不是 MoonConfig 的改名，也不依赖 JSON Patch 功能。

查询本地于 2026-10-16 同步的 Mooncakes 官方 registry index，读取 2,962 个最新未 yanked 模块的名称、描述、关键词与仓库信息。用 dialogue、dialog tree、narrative、interactive fiction、Yarn Spinner、Ink story、story、RenPy 等关键词未找到明显同类条目。另检索公开网页的 MoonBit dialogue/narrative/互动剧情关键词，未找到明显可替代的 MoonBit 运行库。GitHub 仓库搜索 API 当次受未登录频率限制，未将其计作查重结论。

这只说明在这些公开入口和时间范围内未检索到，无法覆盖未公开项目、未发布到 Mooncakes 的仓库或标题描述中不含关键词的实现；不作“首个/唯一”声明。

## 相邻项目

| 项目 | 已有能力与语言 | MoonStory 的关系 |
| --- | --- | --- |
| [Ink](https://github.com/inkle/ink) | C# 剧情编译器/运行库，完整叙事语言及集成生态 | 交互叙事的成熟参考；本仓库没有移植其编译器或复制其格式 |
| [Yarn Spinner](https://www.yarnspinner.dev/features/) | 对话脚本、选项、变量、游戏引擎集成与创作工具 | 功能概念相近；本仓库提供 MoonBit 中的独立语言与纯函数运行层 |

原创交付是 MoonStory 1 语法、类型检查、不可变会话、稳定选择标识、宿主事件序号、源文本绑定的重放存档，以及共享同一 MoonBit 核心的 CLI/网页工具。与成熟跨语言产品相比，首版能力小得多；价值在于 MoonBit 应用可直接引用的模块及清晰可验证的集成约定，而非宣称发明分支叙事。

本项目代码与示例按 MIT 许可发布。使用 MoonBit 标准库，无第三方运行库依赖；工具通过 Node 内置模块构建和服务。未复制 Ink/Yarn Spinner 源码、剧情或素材。
