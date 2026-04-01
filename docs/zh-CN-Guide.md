# FUXA 中文整理指南（安装、配置与常用操作）

本文基于当前仓库 `docs/` 下的英文文档整理翻译，目标是帮助你更快上手 FUXA，并降低配置门槛。

---

## 1. FUXA 是什么

FUXA 是一个基于 Web 的 SCADA/HMI/Dashboard 平台，可用于工业可视化与 IIoT 场景。核心特点：

- 前后端架构：Node.js（服务端）+ Angular/HTML5/SVG（前端）
- 常见协议支持：OPC UA、S7、Modbus、BACnet、MQTT、Ethernet/IP、WebAPI 等
- 工程与运行分离：
  - 编辑器：`/editor`（工程设计）
  - 运行视图：`/home`（最终用户界面）

默认地址：`http://localhost:1881`

---

## 2. 安装与启动（推荐顺序）

### 2.1 方式 A：Docker（最推荐）

优点：依赖相对完整，尤其是 ODBC 驱动场景更省心。

```bash
docker pull frangoteam/fuxa:latest
docker run -d -p 1881:1881 frangoteam/fuxa:latest
```

建议加持久化卷（项目、历史数据、日志、资源）：

```bash
docker run -d -p 1881:1881 \
  -v fuxa_appdata:/usr/src/app/FUXA/server/_appdata \
  -v fuxa_db:/usr/src/app/FUXA/server/_db \
  -v fuxa_logs:/usr/src/app/FUXA/server/_logs \
  -v fuxa_shapes:/usr/src/app/FUXA/client/assets/lib/svgeditor/shapes \
  -v fuxa_images:/usr/src/app/FUXA/server/_images \
  frangoteam/fuxa:latest
```

### 2.2 方式 B：Docker Compose

- Linux 场景常用 `host` 网络，便于 PLC/数据库直连
- Windows 更建议 `bridge` 网络

核心点：挂载 `_appdata/_db/_logs`，并按需配置时区 `TZ`。

### 2.3 方式 C：NPM 全局安装

```bash
npm install -g --unsafe-perm @frangoteam/fuxa
fuxa
```

要求 Node.js 18。若不需要 S7，可考虑轻量包：`@frangoteam/fuxa-min`。

### 2.4 方式 D：源码运行

```bash
cd ./server
npm install
npm start
```

同样建议 Node.js 18。Linux 某些依赖（如 `node-snap7`、`odbc`）可能需要额外编译环境。

### 2.5 方式 E：Electron 预构建包 / 自行打包

适合做桌面 HMI 全屏运行。Electron 本质是桌面壳，访问的是 FUXA Web 服务。

#### 2.5.1 直接下载官方预构建包

官方仓库已经提供 GitHub Actions 构建产物，适合不想自己配环境时直接下载：

- 桌面版 Electron：`https://github.com/frangoteam/FUXA/actions/workflows/electron_latest.yml`
- Headless 单文件版：`https://github.com/frangoteam/FUXA/actions/workflows/headless_packaging.yml`
- 官方 Release 页面：`https://github.com/frangoteam/FUXA/releases`

下载方式：

1. 登录 GitHub
2. 打开对应 workflow 页面
3. 进入最近一次成功构建
4. 在页面底部 `Artifacts` 下载对应平台产物

Windows 常见产物名：

- Electron 桌面版：`FUXA-windows-x64.exe`
- Headless 单文件版：`FUXA-headless-windows-x64.exe`

说明：

- Electron 版适合本机直接全屏运行 HMI，带桌面窗口
- Headless 版适合作为服务程序运行，启动后通过浏览器访问 `http://localhost:1881`

#### 2.5.2 从源码本地打包 Electron Windows exe

当前仓库已经包含 Electron 打包配置：

- Workflow：`.github/workflows/electron_latest.yml`
- Electron 配置：`app/electron/package.json`

官方 workflow 的实际步骤如下：

1. 安装 `server` 依赖
2. 安装 `client` 依赖
3. 构建 `client/dist`
4. 安装 `app/electron` 依赖
5. 将 `server/` 和 `client/dist/` 复制到 `app/electron/`
6. 执行 `electron-builder install-app-deps`
7. 打包 Windows NSIS 安装包

对应命令顺序可整理为：

```bash
cd server
npm install

cd ../client
npm install
npm run build -- --configuration=production

cd ../app/electron
npm install
npx electron-builder install-app-deps
npx electron-builder --win nsis --x64
```

补充说明：

- `app/electron/package.json` 已配置 `win.target = nsis`
- 默认输出目录是 `app/electron/dist/`
- Windows 产物通常是 `.exe` 安装包
- 官方 workflow 当前使用 Node.js 18

如果你希望完全按官方 workflow 复制，还需要在打包前把构建结果复制进 `app/electron`：

```bash
mkdir -p app/electron/server
mkdir -p app/electron/client/dist
cp -r server/. app/electron/server/
cp -r client/dist/. app/electron/client/dist/
```

#### 2.5.3 从源码本地打包 Headless 单文件 exe

当前仓库也包含 headless 打包 workflow：

- Workflow：`.github/workflows/headless_packaging.yml`
- 入口文件：`app/headless/headless-entry.js`

Headless 版的核心特点：

- 不依赖 Electron 桌面窗口
- 将服务端和前端静态资源打成一个独立可执行文件
- Windows 下产物是单个 `.exe`

官方 workflow 的核心步骤：

1. 安装 `server` 与 `client` 依赖
2. 构建 `client/dist`
3. 组装 `fuxa-headless/server` 和 `fuxa-headless/client/dist`
4. 复制 `app/headless/headless-entry.js` 为 `fuxa-headless/main.js`
5. 安装 `@yao-pkg/pkg`
6. 执行 `pkg --targets node20-win-x64`

可参考命令：

```bash
cd server
npm install

cd ../client
npm install
npm run build -- --configuration=production

cd ..
mkdir -p fuxa-headless/server
mkdir -p fuxa-headless/client/dist
cp -r server/. fuxa-headless/server/
cp -r client/dist/. fuxa-headless/client/dist/
cp app/headless/headless-entry.js fuxa-headless/main.js
```

然后在 `fuxa-headless/package.json` 中声明 `pkg` 配置，再执行：

```bash
npm install -g @yao-pkg/pkg
pkg fuxa-headless/package.json --targets node20-win-x64 --out-path artifacts
```

补充说明：

- 官方 workflow 当前使用 Node.js 20
- Windows 产物会被整理为 `FUXA-headless-windows-x64.exe`
- 更适合“部署到工控机后用浏览器访问”的场景，不适合替代桌面全屏壳

#### 2.5.4 交付给客户时应附带哪些文件

这部分非常重要。当前 FUXA 的 `Electron exe` 和 `Headless exe` 都不是“把整个项目永久封装在 exe 内部再直接运行”的模式，运行时仍然依赖外部可写的数据目录。

##### A. 交付 Electron 桌面版 exe

Electron 版启动后会自动拉起本地 FUXA 服务，并在 Electron 窗口中打开 `http://localhost:1881`。对客户来说，通常**不需要再手工打开浏览器**。

但项目文件建议不要只交付一个导出的 `json`，更推荐交付一个完整项目目录，例如：

```text
CustomerProject/
└── data/
    ├── _appdata/
    ├── _db/
    ├── _images/
    ├── _widgets/
    ├── _reports/
    └── _logs/
```

建议交付内容：

- `FUXA-windows-x64.exe`
- 一个完整项目目录，例如 `CustomerProject/`
- 目录中的 `data/_appdata/`：必需，保存项目配置、设置、用户等
- 目录中的 `data/_db/`：如果需要保留历史数据、报警历史，建议一起交付
- 目录中的 `data/_images/`：如果项目引用了自定义图片，必须一起交付
- 目录中的 `data/_widgets/`：如果项目使用了自定义 widgets，必须一起交付
- 目录中的 `data/_reports/`：如果项目依赖预生成报表或报表模板，建议一起交付
- `data/_logs/`：不是启动必需，但如果要保留既有运行日志，可一起交付

交付建议：

- **最佳实践**：交付 `exe + 完整项目目录`
- **不建议**：只交付 `json` 备份文件。因为 `json` 更适合导入/备份，不包含完整运行期目录状态
- 如果客户希望双击后直接进入固定项目，可进一步定制 Electron 启动参数或自动启动配置

##### B. 交付 Headless 单文件 exe

Headless 版没有桌面窗口。客户启动 `FUXA-headless-windows-x64.exe` 后，需要通过浏览器访问：

```text
http://localhost:1881
```

当前 headless 启动入口会默认把数据目录放到用户主目录下：

- Linux/macOS：`~/fuxa-headless-data`
- Windows 可理解为：`%USERPROFILE%\\fuxa-headless-data`

因此，Headless 版交付时有两种常见方式：

1. 交付 `exe`，客户首次启动后再手工导入项目 `json`
2. 交付 `exe + 预制的 fuxa-headless-data 目录`，让客户复制到自己的用户主目录下

如果希望客户拿到后直接可用，推荐第二种。建议目录内容至少包括：

```text
fuxa-headless-data/
├── _appdata/
├── _db/
├── _images/
├── _widgets/
├── _reports/
└── _logs/
```

说明：

- `Headless exe` 本身已经包含程序代码，不需要再附带 `server/`、`client/` 源码目录
- 但如果要附带一个“现成工程”，仍然建议交付完整数据目录，而不是只给 `json`
- 如果仅提供 `json`，客户还需要自己进入 FUXA 页面执行导入

##### C. 什么时候只给 json 就够了

只有在以下场景下，单独给 `json` 才比较合适：

- 客户现场已经有一套正在运行的 FUXA
- 你的目标只是导入一个新项目模板
- 不需要保留历史数据、报警历史、运行日志
- 不依赖外部图片、widgets、报表等附加资源

如果是完整交付、现场上线、或希望客户“开箱即用”，优先交付完整数据目录。

---

## 3. 快速上手路径（官方入门流程中文化）

建议按下面顺序完成第一个可运行项目：

1. **连接设备并配置标签（Tags）**
2. **创建视图（View）并放置控件/图形**
3. **配置布局（导航栏、侧边栏、首页、缩放）**
4. **配置报警（阈值、历史、确认）**
5. **启用用户认证并创建用户**

---

## 4. 核心配置说明

### 4.1 服务端设置文件

配置文件位置：`server/_appdata/settings.js`

修改后需要重启服务生效。

### 4.2 认证配置

```js
secureEnabled: true,
secretCode: '<strong-random-secret>',
tokenExpiresIn: '1h'
```

- `secureEnabled`：是否启用认证
- `secretCode`：JWT 等安全令牌签名密钥（务必替换为高强度随机值）
- `tokenExpiresIn`：过期时间（如 `1h`、`1d`、`60`）

默认管理员常见为 `admin / 123456`，生产环境请立即修改。

### 4.3 日志系统（输出、存储与查询）

FUXA 的日志主要分成 3 类：

- 应用运行日志：`fuxa.log`
- 错误日志：`fuxa-err.log`
- HTTP 访问日志：`api.log`

#### 默认输出位置

- 默认日志目录由 `server/settings.default.js` 中的 `logDir` 决定，默认值是 `_logs`
- 启动时 `server/main.js` 会把它解析到实际工作目录，并在目录不存在时自动创建
- Docker 场景建议挂载 `_logs`，这样重启容器后日志不会丢失

#### 应用日志如何输出

- FUXA 服务端日志由 `server/runtime/logger.js` 统一封装，底层使用 `winston`
- 代码里常见调用方式是 `logger.info(...)`、`logger.warn(...)`、`logger.error(...)`、`logger.debug(...)`
- 控制台输出会带彩色前缀，如 `[INF]`、`[WAR]`、`[ERR]`、`[DBG]`、`[TRA]`
- 文件输出格式统一为：`时间戳 [level] 消息内容`，其中 `level` 为小写（如 `info`、`error`）

典型示例：

```text
2026-03-31T03:40:32.518Z [error] 'Cdu' _readMemory error! RangeError ...
```

#### 文件落盘与轮转规则

- `fuxa.log`：记录 `info` 及以上级别日志
- `fuxa-err.log`：记录 `error` 级别日志
- `debug` / `trace` 默认主要用于控制台输出，不会按当前 File transport 配置写入日志文件
- 当前代码里每个文件最大约 `1MB`
- 当前代码里每类日志最多保留 `5` 个轮转文件

也就是说，FUXA 现在的文件日志轮转主要由 `winston File transport` 的 `maxsize` / `maxFiles` 控制。

#### HTTP 访问日志如何输出

- `server/main.js` 中通过 `morgan` 生成 HTTP 访问日志
- 失败请求（HTTP `>= 400`）会追加写入 `api.log`
- 同时终端里还会把成功请求输出到 `stdout`，失败请求输出到 `stderr`

`api.log` 示例：

```text
127.0.0.1 - - [31/Mar/2026:03:05:11 +0000] "GET /assets/lib/svg/svg.min.js.map HTTP/1.1" 404 168 "-" "Mozilla/..."
```

#### 如何查询 / 查看日志

FUXA 内置了诊断接口和前端日志查看页：

- `GET /api/logsdir`：列出日志目录中的文件
- `GET /api/logs?file=<文件名>`：下载指定日志文件内容

前端对应实现：

- `client/src/app/_services/diagnose.service.ts`
- `client/src/app/logs-view/logs-view.component.ts`

这意味着你可以：

- 在前端日志页面选择 `fuxa.log`、`fuxa-err.log`、`api.log`
- 也可以直接到服务器 `_logs/` 目录里查看原始文件

#### 权限与安全限制

- 日志接口走 `server/api/diagnose/index.js`
- `logsdir` / `logs` 接口要求管理员权限
- 下载日志文件时会经过 `server/api/path-helper.js` 的路径规范化与目录边界检查，防止通过 `../` 读取日志目录外的文件

#### 配置项说明（当前实现的真实行为）

- `logDir`：控制日志目录位置
- `logApiLevel`：当前实现中主要用于控制是否启用 HTTP 访问日志；当值为 `none` 时禁用 `morgan` 日志
- `logFull`：会影响部分 `logger.info(..., ..., onlyFull)` 这类“仅完整日志模式写入”的记录是否落盘
- `logs.retention`：配置项存在于默认设置中，但当前代码里没有看到它直接参与 `winston` 文件日志清理；实际轮转仍以 `maxsize` / `maxFiles` 为准

#### 实际排查建议

- 看设备通信或脚本异常：优先查 `fuxa-err.log`
- 看系统启动、模块初始化、普通运行状态：查 `fuxa.log`
- 看接口 404/401/500、静态资源访问失败：查 `api.log`
- 若是 Docker 部署，先确认 `_logs` 是否已做卷挂载，否则重建容器后历史日志会消失

---

## 5. 编辑器常见操作（HowTo 中文速览）

### 5.1 设备与标签（Devices and Tags）

- 入口：编辑器 `Connections`
- 可添加 OPC UA、Modbus、MQTT、WebAPI 等设备
- 某些类型（如 Modbus）需要先在 `Plugins` 安装驱动
- Tag 支持类型处理与缩放脚本（例如 TIME 转换）
- 脚本参数名需使用 `value`（用于脚本过滤匹配）

### 5.2 创建视图（View）

- 在编辑器左上角 `+` 新建 `Canvas/SVG`
- 在 `Property` 中设置画布尺寸与背景

### 5.3 绑定控件（Controls）

支持将以下控件绑定到设备 Tag：

- Output
- Input
- Select
- Slider

### 5.4 绑定图形（Shapes）

- 基础图形和工艺图元（如 Tank）都可直接绑定 Tag

### 5.5 图表控件（Chart）

- 在 View 中添加 Chart
- 在 `Line charts` 中定义曲线并绑定数据来源

### 5.6 布局（UI Layout）

入口：`Layout settings`

可配置：

- Start View（首页）
- 视图缩放
- 输入弹窗模式
- 是否显示 Header/导航菜单
- 侧边菜单样式
- 顶部报警提示与样式

### 5.7 报警（Alarms）

- 入口：`Alarms`
- 报警绑定到 Tag，可设置高高、高、低、消息等条件
- 支持活动报警和历史展示
- 可配置报警动作（弹窗、写 Tag 等）

### 5.8 项目保存与导入导出

- 日常编辑会自动保存到内部数据库
- `Save Project` 可手动触发保存
- `Save Project As...` 导出 JSON 备份
- 可从 JSON 文件重新导入项目

### 5.9 事件（Events）

图形/按钮可绑定鼠标事件（click/mouseDown/mouseUp），常用动作：

- Open Page / Open Card / Open Dialog
- Open iframe / Open Window
- Set Value / Toggle Value
- Set from Input and Close

### 5.10 脚本（Scripts）

- 脚本是 JavaScript 函数，参数支持 Tag ID 或常量
- 常用系统调用：`$setTag`、`$getTag`
- 可在事件中触发脚本
- 使用 `setInterval` 时要自行防重入/清理（否则重复执行）

### 5.11 管道动画（Animate Pipe）

- 先绘制管道图形，再将动画状态绑定到设备 Tag

### 5.12 复用同一视图（Reuse View）

- 可通过内部设备/内部 Tag 做可复用弹窗或详情页模板
- 通过 `Target Device` + `@[tag_name]` 占位符实现多设备共用详情页
- 图表同样支持占位符绑定

### 5.13 自定义 Shapes

- 目录：`client/dist/assets/lib/svgeditor/shapes`（调试时见 `client/src/...`）
- 可基于 `my-shapes.js` 新建图元
- 新文件需加入 `shapesLoader.js`
- 如定义新 `typeId`，需同步实现对应 Angular 组件

### 5.14 自定义 Widgets（SVG + JS）

- Widget 本质是带脚本的 SVG
- 可用导出变量与 FUXA 互通（`_pb_/_pn_/_ps_/_pc_`）
- 变量声明需放在 `//!export-start` 与 `//!export-end` 之间
- 双向通信函数：
  - `postValue(id, value)`：SVG -> FUXA
  - `putValue(id, value)`：FUXA -> SVG
- 若使用定时器，页面切换时需清理；建议使用 `MutationObserver` 防止重复定时器导致组件异常

---

## 6. 高级主题

### 6.1 WebSocket 集成

- 可在 FUXA 脚本中做 WebSocket 客户端，与外部系统（例如 Node-RED）双向同步数据
- 建议将脚本设为服务端脚本并在启动时运行
- 注意断线重连、JSON 解析错误处理、周期任务防重入

### 6.2 Node-RED 集成

- FUXA 内置 Node-RED 集成能力
- Dashboard 2 需单独安装：`@flowfuse/node-red-dashboard`
- 可通过 iframe 将 `/dashboard` 嵌入 FUXA 页面
- 安全模式由 `nodeRedAuthMode` 控制：
  - `secure`（默认）
  - `legacy-open`
- `node-red-contrib-fuxa` 提供大量节点（tag/device/alarm/view/script/daq/event/message）

### 6.3 ODBC 数据库接入

- 推荐 Docker 方式（驱动通常已准备）
- NPM 安装场景需手动安装 unixODBC 和对应驱动
- 在 FUXA 中添加 ODBC 设备后，可在服务端脚本中通过 `$getDevice(..., true)` 拿连接池执行 SQL
- 高频轮询示例可行，但应注意系统负载与 SQL 安全性

### 6.4 调度器（Scheduler）

- 支持按周、按月日组合进行时间调度
- 支持 Timer Mode（起止时间）与 Event Mode（持续时长）
- 可附加设备动作（设值、执行脚本）
- 对被调度设备有主控优先级与权限要求

---

## 7. 实用快捷键（编辑器）

- `Ctrl + Left/Right`：旋转选中项
- `Ctrl + Shift + Left/Right`：大步长旋转
- `Tab / Shift + Tab`：切换选中项
- `Ctrl + Up/Down`：中心缩放
- `Shift + 滚轮`：按鼠标位置缩放
- `Ctrl + Z / Y`：撤销 / 重做
- `Ctrl + G`：编组 / 取消编组
- `Ctrl + D`：复制项
- `Ctrl + C / V / X`：复制 / 粘贴 / 剪切

---

## 8. 建议的学习顺序（中文实践版）

1. 完成 Docker 启动 + 能访问 `1881`
2. 建立 1 个设备连接 + 3~5 个基础 Tag
3. 建 1 个 View：放 Input/Output/Chart，并完成绑定
4. 配置 Layout：首页、导航、报警入口
5. 配置 1 条报警并验证触发
6. 添加 1 个脚本（读写 Tag）并通过按钮事件触发
7. 再进入 Node-RED / ODBC / Scheduler 等高级功能

---

## 9. 英文原文对照索引（按 docs 文件）

基础与总览：

- `docs/index.md`
- `docs/Getting-Started.md`
- `docs/Installing-and-Running.md`
- `docs/Settings.md`
- `docs/Tips-and-Tricks.md`

编辑器与页面：

- `docs/HowTo-Devices-and-Tags.md`
- `docs/HowTo-View.md`
- `docs/HowTo-bind-Controls.md`
- `docs/HowTo-bind-Shapes.md`
- `docs/HowTo-Chart-Control.md`
- `docs/HowTo-UI-Layout.md`
- `docs/HowTo-setup-Alarms.md`
- `docs/HowTo-save-load-Project.md`
- `docs/HowTo-configure-events.md`
- `docs/HowTo-configure-Script.md`
- `docs/HowTo-animate-Pipe.md`
- `docs/HowTo-use-same-view.md`

扩展能力：

- `docs/HowTo-define-Shapes.md`
- `docs/HowTo-Widgets.md`
- `docs/HowTo-WebSockets.md`
- `docs/HowTo-Node-Red.md`
- `docs/HowTo-ODBC.md`
- `docs/HowTo-Scheduler.md`

---

## 10. 迁移到生产环境前的检查清单

- 已启用认证并更改默认管理员密码
- `secretCode` 已替换为高强度随机值
- 项目导出 JSON 备份已完成
- Docker/NPM 启动方式与系统环境匹配
- 关键脚本的定时器与异常处理已检查
- ODBC/Node-RED 的外部连接安全策略已确认

如果你愿意，我下一步可以基于这个总文档再拆出 2 份更细的中文版：

1. `docs/zh-CN-Install.md`（仅安装部署）
2. `docs/zh-CN-HowTo.md`（仅编辑器操作和案例）

这样后续查阅会更快。
