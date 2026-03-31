# FUXA 项目 JSON 结构与批量配置指南（基于 demo/fuxa-project (3).json）

本文用于回答两个核心问题：

1. 这个 FUXA 项目 JSON 的结构是什么、各块作用是什么。
2. 后续如何基于 JSON 做批量配置（历史数据表格列、多个 output/input、多条 alarm、邮件通知）。

源文件：`demo/fuxa-project (3).json`

---

## 1. 当前 Demo 文件的根结构

当前示例 JSON 根键如下：

- `devices`
- `hmi`
- `version`
- `projectFile`
- `charts`
- `server`

说明：

- 该 demo **已包含**设备、视图、图表、布局。
- 该 demo **已包含**根键：`alarms`。
- 该 demo **未包含**以下根键：`notifications`、`scripts`（以及 scheduler/schedules 相关配置）（如需使用需要新增）。

---

## 2. 每个根块的作用

### 2.1 `devices`（设备与 Tag 数据源）

作用：定义通讯设备、连接参数、轮询周期、Tag 列表。

关键字段：

- `devices.{deviceId}.name/type/enabled/polling`
- `devices.{deviceId}.property`（地址、端口、S7 rack/slot 等）
- `devices.{deviceId}.tags.{tagId}`（Tag 类型、地址）

Tag 扩展能力（模型定义）：

- `daq`（历史采集开关与间隔）
- `scale*`（读写缩放脚本）
- `deadband`（死区）

#### Modbus Tag `type` 必须使用 FUXA 原生类型

对于 `ModbusRTU` / `ModbusTCP` 设备，`devices.{deviceId}.tags.{tagId}.type` 不能写通用类型 `bool` / `number`，必须写 FUXA 当前支持的 Modbus 类型枚举。

当前仓库模型中可用值见 `client/src/app/_models/device.ts`，包括：

- `Bool`
- `Int16`
- `UInt16`
- `Int32`
- `UInt32`
- `Float32`
- `Float64`
- `Int64`
- `Int16LE`
- `UInt16LE`
- `Int32LE`
- `UInt32LE`
- `Float32LE`
- `Float64LE`
- `Float64MLE`
- `Int64LE`
- `Float32MLE`
- `Int32MLE`
- `UInt32MLE`

批量生成时建议：

- 开关量/状态量寄存器：使用 `Bool`
- 单个 16 位无符号寄存器：使用 `UInt16`
- 若只是通过 `divisor` 做 `x10/x100` 缩放，但底层仍是单寄存器整数，仍使用 `UInt16`
- 只有当 PLC 明确说明是 32 位/64 位/浮点/小端字节序时，才改用 `Int32`、`Float32`、`UInt32LE` 等对应类型

> 本次实测中，若 JSON 写成 `bool` / `number`，服务端虽然现在会做兼容处理，但最佳实践仍然是**在项目 JSON 里直接写 FUXA 原生 Modbus 类型**，避免导入后出现类型歧义。

### 2.2 `hmi`（画面与控件）

作用：定义 View（画面）和 Layout（导航、Header、启动页等）。

- `hmi.views[]`：每个页面
- `hmi.views[].items`：页面上的控件字典（核心批量修改区域）
- `hmi.layout`：导航/头部/缩放/输入对话框等界面行为

### 2.3 `charts`（图表数据定义）

作用：定义图表的数据线（line）与数据源绑定。

- `charts[].lines[]` 中每条线关联 `device + id(tag)`。
- 视图中的图表控件通过 `hmi.views[].items.{id}.property.id` 引用 `charts[].id`。

### 2.4 `server` / `version` / `projectFile`

- `server`：项目服务端相关元信息
- `version`：项目结构版本
- `projectFile`：工程文件标识/路径信息

---

## 3. 批量配置最重要的绑定规则

### 3.1 变量绑定三件套

控件通常通过以下字段绑定 Tag：

- `property.variable`
- `property.variableSrc`
- `property.variableId`

实践注意：

- `variableSrc` 通常是设备名（如 `Device A`）。
- `variableId` 在项目中可能出现两种形式：
  - `Device A^~^Tag Byte`
  - `Tag Byte`
- 为了批量生成稳定，建议统一使用：`设备名^~^Tag名`。

### 3.2 常见控件 ID 前缀（便于批量生成）

当前 demo 可见：

- `GXP_`：progress/gauge
- `VAL_`：value 显示
- `HXC_`：chart
- `SLI_`：slider
- `HXT_`：switch
- `BAG_`：bag/gauge
- `PIE_`：pipe
- `SHE_`：shape

建议新建项保持同类前缀 + 唯一 ID，避免冲突。

---

## 4. 你关心的 5 类批量配置：路径 + 作用 + 模板

## 4.1 历史数据表格列（history table columns）

### 路径

- 控件：`hmi.views[].items.{tableId}`
- 属性：`hmi.views[].items.{tableId}.property`

其中表格属性模型为：

- `property.type`：`data | history | alarms | alarmsHistory | reports`
- `property.options.columns[]`

### 最小模板（建议）

```json
{
  "id": "TBL_xxx",
  "type": "svg-ext-html_table",
  "name": "history_table_1",
  "property": {
    "id": "table_history_1",
    "type": "history",
    "options": {
      "realtime": true,
      "lastRange": "table.rangetype-last1h",
      "columns": [
        { "id": "ts", "label": "时间", "type": "timestamp", "align": "left", "width": 140 },
        { "id": "v1", "label": "Tag Byte", "type": "variable", "variableId": "Device A^~^Tag Byte", "align": "right", "width": 120 }
      ]
    },
    "events": []
  }
}
```

> 说明：当前 demo 中没有 `svg-ext-html_table` 实例，上面是按模型可用字段给出的可落地模板。

## 4.2 多个 Output / Input 控件

### 路径

- `hmi.views[].items.{controlId}`

### 已存在可复用类型（demo 中可见）

- Output：`svg-ext-value`、`svg-ext-gauge_progress`、`svg-ext-html_bag`
- Input：`svg-ext-html_slider`、`svg-ext-html_switch`

### 最小模板（Output）

```json
{
  "id": "VAL_xxx",
  "type": "svg-ext-value",
  "name": "output_1",
  "property": {
    "variable": "Tag Byte",
    "variableSrc": "Device A",
    "variableId": "Device A^~^Tag Byte",
    "events": [],
    "actions": [],
    "ranges": []
  }
}
```

### 最小模板（Input - slider）

```json
{
  "id": "SLI_xxx",
  "type": "svg-ext-html_slider",
  "name": "input_slider_1",
  "property": {
    "variable": "Tag Byte",
    "variableSrc": "Device A",
    "variableId": "Device A^~^Tag Byte",
    "options": { "range": { "min": 0, "max": 100 }, "step": 1 },
    "events": [],
    "actions": []
  }
}
```

## 4.3 多个 Alarm 配置

### 路径

- 根级：`alarms[]`（当前 demo 已存在）

### 结构关键字段

- `name`
- `property.variableId`
- `highhigh/high/low/info`
- `actions.values[]`

### 当前 demo 实例（来自 v3）

```json
{
  "name": "alarm1",
  "property": {
    "variableId": "Tag Bool"
  },
  "highhigh": {
    "enabled": true,
    "checkdelay": 60,
    "min": 1,
    "max": 100,
    "text": "alarm1 too high",
    "group": "group1",
    "ackmode": "ackactive",
    "bkcolor": "#FF4848",
    "color": "#FFF"
  },
  "high": {
    "enabled": false,
    "ackmode": "ackactive",
    "bkcolor": "#F9CF59",
    "color": "#000"
  },
  "low": {
    "enabled": false,
    "ackmode": "ackactive",
    "bkcolor": "#E5E5E5",
    "color": "#000"
  },
  "info": {
    "enabled": false,
    "ackmode": "float",
    "bkcolor": "#22A7F2",
    "color": "#FFF"
  },
  "actions": {
    "enabled": true,
    "values": [
      {
        "type": "toastMessage",
        "actoptions": {
          "type": "error"
        }
      }
    ]
  }
}
```

### 通用模板（跨项目扩展）

```json
{
  "name": "Alarm_TagByte_High",
  "property": {
    "variableId": "Device A^~^Tag Byte",
    "permission": 0,
    "permissionRoles": { "show": [], "enabled": [] }
  },
  "highhigh": { "enabled": false },
  "high": {
    "enabled": true,
    "min": 80,
    "max": 100,
    "text": "Tag Byte High",
    "group": "Process",
    "ackmode": "alarm.ack-float",
    "bkcolor": "#ffaa00",
    "color": "#000000",
    "checkdelay": 0,
    "timedelay": 0
  },
  "low": { "enabled": false },
  "info": { "enabled": false },
  "actions": { "enabled": false, "values": [] },
  "value": "0"
}
```

> 说明：上面的“通用模板”包含更完整字段（如权限、默认值等），不同项目导出时可能会省略部分字段；以实际工程导出格式为准。

### 常用枚举（模型）

- 级别：`highhigh/high/low/info`
- ack（模型值）：`alarm.ack-float | alarm.ack-active | alarm.ack-passive`
- ack（当前 demo 导出值）：`float | ackactive`
- 动作（模型值）：`alarm.action-popup | alarm.action-onsetview | alarm.action-onsetvalue | alarm.action-onRunScript | alarm.action-toastMessage`
- 动作（当前 demo 导出值）：`toastMessage`

## 4.4 邮件通知配置（notification/email）

### 路径

- 根级：`notifications[]`（当前 demo 没有，需要新增）

### 最小模板

```json
{
  "id": "n_xxx",
  "name": "Mail_Alarm_Default",
  "receiver": "ops@example.com",
  "delay": 1,
  "interval": 0,
  "enabled": true,
  "text": "Alarm triggered",
  "type": "notification.type-alarm",
  "subscriptions": { "alarms": ["Alarm_TagByte_High"] },
  "options": {},
  "mode": 0
}
```

模式：

- `mode=0`：全部发送
- `mode=1`：单次发送

### 与告警联动

- `notifications[].subscriptions.alarms[]` 填告警名称，完成告警到通知的关联。

## 4.5 事件与脚本绑定

### 路径

- 控件事件：`hmi.views[].items.{id}.property.events[]`
- 控件动作：`hmi.views[].items.{id}.property.actions[]`
- 脚本定义：`scripts[]`（当前 demo 没有，需要新增）

### 常用事件与动作值

- 事件：`shapes.event-click`、`shapes.event-onLoad` 等
- 动作：`shapes.event-onsetvalue`、`shapes.event-onrunscript` 等

---

## 5. 当前 demo 的实测摘要（可作为批量基线）

- 设备数：2
- View 数：2（`MainView` 有 11 个 item）
- 图表定义：1 个（`charts[0]`）
- 已有输入控件：slider/switch
- 已有输出控件：value/progress/bag
- 已有告警：1 条（`alarms[0]`）
- 当前仍缺失根模块：`notifications`、`scripts`、`scheduler`（及 `schedules`）

---

## 6. 批量生成建议流程（实操）

1. **先复制项目 JSON 做备份**。
2. 统一定义命名规范：
   - 设备名固定
   - `variableId` 统一 `Device^~^Tag`
   - 控件 ID 前缀统一
   - Modbus Tag `type` 统一使用 FUXA 原生枚举（如 `Bool` / `UInt16`），不要混入 `bool` / `number`
3. 批量生成 `hmi.views[目标页].items` 子项（input/output/table）。
4. 根级新增 `alarms[]` 与 `notifications[]`。
5. 若需脚本触发，再新增 `scripts[]` 并在 `events[]` 里引用脚本 ID。
6. 导入 FUXA 后先验证：
   - 变量是否绑定到正确设备/Tag
   - 表格列是否显示
   - 告警是否触发
   - 邮件是否按订阅发送

---

## 7. 易错点清单

- 同一个项目里 `variableId` 格式混用（建议统一）。
- Modbus Tag `type` 写成通用值 `bool` / `number`，而不是 FUXA 支持的 `Bool` / `UInt16` / `Float32` 等原生类型。
- 新增控件 ID 重复导致覆盖。
- `charts[].id` 与图表控件 `property.id` 未对齐。
- 告警名称与通知订阅中的告警名不一致。
- 只加了控件未加对应数据定义（如表格/脚本/告警根配置）。

---

## 8. 参考（本仓库模型定义）

- `client/src/app/_models/hmi.ts`
- `client/src/app/_models/alarm.ts`
- `client/src/app/_models/notification.ts`
- `client/src/app/_models/script.ts`
- `client/src/app/_models/chart.ts`
- `client/src/app/_models/device.ts`
