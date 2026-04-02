# FUXA 打包、分发与排障说明（中文）

本文聚焦 3 件事：

1. 如何按当前仓库实际配置打包 FUXA Electron
2. 除 Electron 外，还有哪些更适合交付客户的方式
3. 出问题后去哪里看日志、怎么排查

本文基于以下仓库内容整理：

- `docs/Installing-and-Running.md`
- `README.md`
- `.github/workflows/electron_latest.yml`
- `.github/workflows/headless_packaging.yml`
- `app/electron/package.json`
- `app/electron/main.js`
- `app/headless/headless-entry.js`
- `server/main.js`
- `server/runtime/logger.js`
- `server/api/diagnose/index.js`

## 1. 先给结论：推荐怎么交付

按客户场景，建议优先级如下：

| 场景 | 推荐方式 | 说明 |
| --- | --- | --- |
| 客户希望双击桌面程序直接运行，适合本机 HMI 全屏展示 | Electron 桌面版 | 有桌面窗口，启动后自动拉起本地 FUXA 服务并打开 `http://localhost:1881` |
| 客户现场只需要一个服务程序，通过浏览器访问 | Headless 单文件版 | 不带桌面窗口，适合工控机、边缘网关、服务器 |
| 客户已经有 Docker 体系，重视可维护性和升级 | Docker / Docker Compose | 最容易标准化部署和备份 |
| 客户自己具备 Node.js 运行环境，需要可改源码 | 源码 / NPM 安装 | 更适合内部研发或实施团队，不是最省心的客户交付方式 |

如果目标是“发给客户就能跑”，通常建议：

- 有本地操作员界面：`Electron 安装包 + 完整项目目录`
- 无本地桌面界面：`Headless 可执行文件 + 完整数据目录`
- 集中式部署：`Docker Compose + 挂载的数据卷目录`

## 2. 官方现成产物

当前仓库已经提供 GitHub Actions 打包流程：

- Electron 桌面版：`https://github.com/frangoteam/FUXA/actions/workflows/electron_latest.yml`
- Headless 单文件版：`https://github.com/frangoteam/FUXA/actions/workflows/headless_packaging.yml`

`docs/Installing-and-Running.md` 和 README 都优先建议从 Actions 的 Artifacts 下载预构建产物。优点是：

- 不需要客户现场安装 Node.js、Electron、构建工具
- 产物命名比较固定，便于交付
- 能避免本地构建环境差异

当前 workflow 产物命名如下：

- Electron Windows：`FUXA-windows-x64.exe`
- Electron Linux：`FUXA-linux-x64.AppImage`、`FUXA-linux-arm64.AppImage`
- Electron macOS：`FUXA-macos-x64.dmg`、`FUXA-macos-arm64.dmg`
- Headless Windows：`FUXA-headless-windows-x64.exe`
- Headless Linux：`FUXA-headless-linux-x64`、`FUXA-headless-linux-arm64`
- Headless macOS：`FUXA-headless-macos-x64`、`FUXA-headless-macos-arm64`

## 3. 从源码本地打包 Electron

### 3.1 当前仓库的真实入口

这里有一个容易踩坑的点：

- README 里有一段较早的简化示例写的是 `cd ./app`
- 当前仓库真实 Electron 配置目录是 `app/electron`

真正参与打包的配置在：

- Electron 入口：`app/electron/main.js`
- Electron 打包配置：`app/electron/package.json`

### 3.2 Electron 当前打包目标

`app/electron/package.json` 里已经配置好：

- Windows：`nsis`，`x64`
- Linux：`appimage`，`x64` / `arm64`
- macOS：`dmg`，`x64` / `arm64`

输出目录默认是：

```text
app/electron/dist/
```

### 3.3 本地打包前提

建议按官方 workflow 保持一致：

- Electron 打包环境：Node.js `18`
- Linux 下如果要本地打包，先安装构建依赖：

```bash
sudo apt-get update
sudo apt-get install -y build-essential unixodbc unixodbc-dev
```

### 3.4 本地打包步骤

按当前 `.github/workflows/electron_latest.yml`，本地步骤可以整理为：

```bash
cd server
npm install

cd ../client
npm install
npm run build -- --configuration=production

cd ../app/electron
npm install

cd ../..
mkdir -p app/electron/server
mkdir -p app/electron/client/dist
cp -r server/. app/electron/server/
cp -r client/dist/. app/electron/client/dist/

cd app/electron
npx electron-builder install-app-deps
```

然后按目标平台执行：

Windows x64:

```bash
npx electron-builder --win nsis --x64
```

Linux x64:

```bash
npx electron-builder --linux appimage --x64
```

Linux arm64:

```bash
npx electron-builder --linux appimage --arm64
```

macOS x64:

```bash
npx electron-builder --mac dmg --x64
```

macOS arm64:

```bash
npx electron-builder --mac dmg --arm64
```

如果你只关心 `Electron + Windows x64`，当前仓库里已经补了一个本地一键脚本：

```bash
scripts/package-electron-win-x64.sh
```

Windows 机器上也可以直接使用 PowerShell 版本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-electron-win-x64.ps1
```

常用示例：

```bash
scripts/package-electron-win-x64.sh --dry-run
scripts/package-electron-win-x64.sh
scripts/package-electron-win-x64.sh --skip-install
```

PowerShell 示例：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-electron-win-x64.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\scripts\package-electron-win-x64.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\package-electron-win-x64.ps1 -SkipInstall
```

当前支持参数：

- `--dry-run`：只打印命令，不实际执行
- `--skip-install`：跳过所有 `npm install`
- `--skip-build`：跳过 Angular 生产构建
- `--skip-app-deps`：跳过 `electron-builder install-app-deps`
- PowerShell 版本对应参数：`-DryRun`、`-SkipInstall`、`-SkipBuild`、`-SkipAppDeps`

这个脚本本质上是在本地重放官方 Windows x64 workflow，适合实施和交付前自助出包。

### 3.5 Electron 打包产物里包含什么

`app/electron/package.json` 当前会把这些内容打进去：

- `main.js`
- HTML 页面
- `server/**/*`
- `client/dist/**/*`
- `icons/**/*`

同时 `server/node_modules` 会作为 `extraResources` 复制进应用资源中。

这也是为什么本地打包前，必须先：

- 安装 `server` 依赖
- 构建 `client/dist`
- 把 `server/` 和 `client/dist/` 复制进 `app/electron/`

少任何一步，打包都很容易成功但运行失败。

## 4. Electron 运行方式与客户交付建议

### 4.1 Electron 实际运行逻辑

`app/electron/main.js` 的逻辑不是“只打开一个网页壳”，而是：

1. 先选择项目目录
2. 读取项目目录下的 `data/`
3. 通过 `fork()` 启动内置 `server/main.js`
4. 传入环境变量 `userDir=<项目目录>/data`
5. 固定访问 `http://localhost:1881`

因此 Electron 运行时依赖的不只是 `exe`，还依赖一个可写的数据目录。

### 4.2 推荐交付内容

推荐把下面两部分一起交付给客户：

1. Electron 安装包或可执行文件
2. 完整项目目录，例如：

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

其中：

- `data/_appdata/`：必需，项目配置、用户、设置都在这里
- `data/_db/`：如果要保留历史数据和告警历史，建议一起交付
- `data/_images/`：项目引用了图片就必须带上
- `data/_widgets/`：用了自定义 widgets 就必须带上
- `data/_reports/`：用了报表模板或预生成报表建议带上
- `data/_logs/`：不是启动必需，但建议保留，便于现场排障

### 4.3 不建议只交付 JSON

只给项目导出的 `json` 适合：

- 模板导入
- 版本备份
- 已有 FUXA 现场环境上的增量交付

如果客户需要“拿到就能跑”，不建议只给 `json`，因为它不包含：

- 历史库数据
- 图片资源
- 自定义 widgets
- 报表目录
- 既有日志

## 5. Headless 单文件版

### 5.1 适合什么场景

Headless 版更适合：

- 工控机后台运行
- 服务器部署
- 边缘设备
- 不需要桌面窗口，只需要浏览器访问

### 5.2 当前仓库的真实打包方式

当前 `.github/workflows/headless_packaging.yml` 使用：

- Node.js `20`
- `@yao-pkg/pkg`
- 入口文件：`app/headless/headless-entry.js`

本质步骤是：

1. 安装 `server` 依赖
2. 安装 `client` 依赖并构建 `client/dist`
3. 组装 `fuxa-headless/server`
4. 组装 `fuxa-headless/client/dist`
5. 复制 `app/headless/headless-entry.js` 为 `fuxa-headless/main.js`
6. 生成一个临时的 `fuxa-headless/package.json`
7. 执行 `pkg --targets ...`

### 5.3 Headless 数据目录在哪里

`app/headless/headless-entry.js` 会把运行数据目录固定到用户主目录下：

- Linux / macOS：`~/fuxa-headless-data`
- Windows：`%USERPROFILE%\fuxa-headless-data`

这意味着 Headless 交付也不仅仅是给一个可执行文件。

### 5.4 推荐交付方式

最稳妥的交付方式是：

1. 交付 `Headless` 可执行文件
2. 同时交付一个预制好的 `fuxa-headless-data/` 目录

目录通常至少包括：

```text
fuxa-headless-data/
├── _appdata/
├── _db/
├── _images/
├── _widgets/
├── _reports/
└── _logs/
```

这样客户拿到后二次配置最少，启动后直接浏览器访问：

```text
http://localhost:1881
```

## 6. Docker / Docker Compose / 源码 / NPM

### 6.1 Docker / Docker Compose

这是除了 Electron / Headless 之外，最适合标准化交付的方式。

优点：

- 升级、回滚、迁移方便
- 宿主机依赖少
- 便于统一备份 `_appdata`、`_db`、`_logs`

建议最少挂载：

- `_appdata`
- `_db`
- `_logs`
- `_images`

如果是需要直接访问 PLC、串口、现场数据库的场景，Linux 上通常优先考虑 `host` 网络模式；如果是 Windows 或更强调隔离，可以用 `bridge`。

### 6.2 源码安装

适合：

- 开发团队
- 二次开发
- 现场具备 Node.js 环境的技术人员

不太适合：

- 普通最终客户
- 希望双击即用的交付方式

### 6.3 NPM 安装

适合有 Node.js 环境的内部部署。优点是安装简单，缺点是：

- 仍依赖运行机的 Node.js
- Linux 下原生模块可能遇到编译问题
- 客户环境越杂，问题越多

## 7. 日志目录、日志种类与查询方式

### 7.1 日志文件有哪些

当前 FUXA 运行期重点看这 3 类日志：

- `fuxa.log`：应用运行日志
- `fuxa-err.log`：错误日志
- `api.log`：HTTP 访问日志

### 7.2 日志落盘规则

`server/runtime/logger.js` 当前实现：

- `fuxa.log`：记录 `info` 及以上
- `fuxa-err.log`：记录 `error`
- 单个文件最大约 `1MB`
- 每类最多保留 `5` 个轮转文件

补充说明：

- `debug` / `trace` 更多是控制台输出，不保证写入日志文件
- `api.log` 由 `server/main.js` 里的 `morgan` 生成
- HTTP `>= 400` 的请求会写入 `api.log`

### 7.3 各部署方式的日志目录

Electron:

- 日志目录在项目目录下的 `data/_logs/`
- 例如：`CustomerProject/data/_logs/`

Headless:

- Linux / macOS：`~/fuxa-headless-data/_logs/`
- Windows：`%USERPROFILE%\fuxa-headless-data\_logs\`

Docker:

- 容器内默认是 `server/_logs`
- 实际排障应看你挂载到宿主机的目录

源码 / NPM:

- 默认由 `server/settings.default.js` 的 `logDir` 控制，默认是 `_logs`
- 启动时 `server/main.js` 会把它解析到实际 `userDir` 或工作目录

### 7.4 页面内查询日志

FUXA 已内置日志查询接口：

- `GET /api/logsdir`：列出日志目录文件
- `GET /api/logs?file=<文件名>`：下载指定日志

限制：

- 需要管理员权限
- 接口做了路径规范化和目录边界检查，不能随意跨目录读取

### 7.5 命令行查询日志

Linux / macOS:

```bash
tail -f /path/to/_logs/fuxa.log
tail -f /path/to/_logs/fuxa-err.log
tail -f /path/to/_logs/api.log
grep -ni "error\\|unauthorized\\|EADDRINUSE" /path/to/_logs/*
```

Windows PowerShell:

```powershell
Get-Content C:\path\to\_logs\fuxa.log -Wait
Get-Content C:\path\to\_logs\fuxa-err.log -Wait
Get-Content C:\path\to\_logs\api.log -Wait
Select-String -Path C:\path\to\_logs\* -Pattern "error","unauthorized","EADDRINUSE"
```

调用接口下载日志示例：

```bash
curl -L -o fuxa.log "http://localhost:1881/api/logs?file=fuxa.log"
curl -L -o fuxa-err.log "http://localhost:1881/api/logs?file=fuxa-err.log"
curl -L -o api.log "http://localhost:1881/api/logs?file=api.log"
```

## 8. 常见问题排查

### 8.1 打包时报错：`client/dist` 不存在

原因：

- 还没执行前端构建
- 构建后没有把 `client/dist` 复制到 `app/electron/client/dist`

处理：

```bash
cd client
npm install
npm run build -- --configuration=production
```

然后重新复制并打包。

### 8.2 打包成功，但运行后白屏或打不开页面

优先检查：

1. Electron 是否成功拉起了 `server/main.js`
2. 本机 `1881` 端口是否被占用
3. 项目目录是否是有效结构，尤其是 `data/_appdata`
4. `app/electron/main.js` 启动后等待 `http://localhost:1881` 超时

建议先看：

- Electron 启动控制台
- 项目目录下 `data/_logs/fuxa-err.log`
- 项目目录下 `data/_logs/api.log`

### 8.3 打开项目时报“不是有效的项目目录”

Electron 打开已有项目时，会校验：

- `<项目目录>/data`
- `<项目目录>/data/_appdata`

缺任何一个目录，都会被认定为无效项目。

### 8.4 启动时报端口冲突

默认访问端口是 `1881`。如果端口被其他服务占用，常见现象是：

- Electron 页面打不开
- Headless 启动后浏览器访问失败
- `api.log` / 控制台里出现绑定失败

Linux / macOS 可检查：

```bash
ss -ltnp | grep 1881
```

Windows PowerShell 可检查：

```powershell
netstat -ano | findstr 1881
```

### 8.5 Linux 打包时原生依赖失败

当前官方 workflow 在 Linux 下额外安装了：

```bash
sudo apt-get install -y build-essential unixodbc unixodbc-dev
```

如果你本地没有这些依赖，常见问题会出现在：

- `npm install`
- `electron-builder install-app-deps`

### 8.6 Node 版本不一致导致构建异常

当前仓库实际使用：

- Electron workflow：Node.js `18`
- Headless workflow：Node.js `20`

本地构建建议严格对齐，否则容易遇到：

- 原生模块重编译失败
- `pkg` 目标不一致
- Electron 依赖安装异常

### 8.7 Docker 部署后能打开页面，但设备连不上

优先看：

- 是否用了 `bridge` 网络导致无法直接访问 PLC 网段
- 容器是否具备目标网络访问权限
- 端口、路由、防火墙是否放通

需要直接打现场设备时，Linux 环境通常优先评估 `host` 网络。

### 8.8 日志里没有你想看的调试信息

要注意当前实现里：

- `debug` / `trace` 更偏向控制台输出
- 文件里更稳定能看到的是 `info`、`warn`、`error`

如果你现场只拿到了日志文件，没有拿到控制台输出，就要优先从：

- `fuxa-err.log`
- `fuxa.log`
- `api.log`

三个文件交叉定位。

## 9. 交付清单建议

### 9.1 Electron 版

- `FUXA-windows-x64.exe` 或对应平台安装包
- 完整项目目录 `CustomerProject/`
- 一份启动说明
- 一份日志导出说明

### 9.2 Headless 版

- `FUXA-headless-...` 可执行文件
- 完整 `fuxa-headless-data/`
- 浏览器访问地址说明：`http://localhost:1881`
- 日志目录说明

### 9.3 Docker 版

- `compose.yml`
- 宿主机挂载目录结构
- 镜像版本说明
- 升级 / 回滚步骤
- 日志和备份路径说明

## 10. 建议的实施策略

如果你现在要给客户做交付，建议直接按下面方式选：

- 单机 HMI 一体机：Electron
- 后台服务 + 浏览器访问：Headless
- 多现场统一运维：Docker Compose

如果客户要求“到现场后尽量少配置”，无论 Electron 还是 Headless，都尽量不要只交付一个安装包或一个 `json`，而是交付：

- 可执行程序
- 完整运行数据目录
- 一页纸排障说明
- 日志导出路径

这样后续远程支持成本会低很多。
