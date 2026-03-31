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
