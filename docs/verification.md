# 验证方法与边界

固定工具链：moon 0.1.20261012，moonc/core 0.10.15+943464bfa，Node.js 24。CI 配置运行 JS、Wasm、Wasm-GC、native；本地 Windows 在没有 C 编译器时只运行前三个目标，native 结果以公开 CI 为准。

- 25 项核心测试：词法位置、Unicode/转义、表达式类型/优先级/短路、Int32 边界、非法引用/节点、条件选项、错误回滚、防御性副本、控制流分析、存档绑定与事件抑制、资源限制、JSON 边界。
- 2 项独立 MoonBit 模块集成测试：宿主接收物品事件、保存恢复、教学评分读取；只调用导出的 SDK。
- 7 项 Node 集成测试：三个完整示例、10 个结局状态空间枚举、真实 CLI 动作文件、200 份生成剧情逐步对照独立 JS 状态模型、存档版本拒绝、文本注入边界和本地服务器资源白名单。

生成核对器直接操作 JS 对象中的整数、布尔、字符串、事件计数和选择规则；它不复用 MoonStory 的 token、AST 或存档内部实现。它覆盖一个有界的生成语法族，不能证明整个语言的所有程序均正确。结构检查忽略条件真假，因此“没有警告”不代表所有运行状态都可通关。

```sh
moon info
moon fmt --check
moon check --target js --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target wasm --deny-warn
moon test --target native --deny-warn
npm run build
npm test
```

网页另做人工自动化验收：打开示例、推进到选项、接下任务、保存、重开与读取，检查恢复状态及历史事件抑制；检查编译错误、文本渲染、脚本修改后的预览隔离和小屏横向溢出。

提交包不包含凭据、编译缓存、node_modules。软件包发布后还应在不含本仓库源码的全新 consumer 目录下载指定版本并运行安装测试，避免把本地 workspace 测试当成注册表安装成功。
