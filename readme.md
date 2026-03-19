```txt
[外部调度层 / 触发机制]
       │
       ▼ (1. 传递基础输入参数)
       │   - dtFetchTime (抓取基准时间：决定本次统计的日历批次)
       │   - sysNo (系统编号：标识数据来源，用于区分不同车间或系统)
       │
[C# 应用逻辑层 (ProductLineAnalyzer)]
       │
       ├─► (2. 连接本地库取基础配置与规则) ──► [本地 SQL Server]
       │                              │ - 读: 异常时间阈值 (abnormalTimeThreshold，默认 5 分钟)
       │                              │ - 读: 远程库连接串 (hzds_receive_address)
       │                              │ - 读: 产线白名单 tbPPL (非'ZP'类型，决定去哪张业务表取数)
       │                              │ - 读: 班次休息与计划停机表 (GetRestTimesFromLocalDB)
       │                              ◄── (返回配置参数与内存 List 集合)
       │
       ├─► (3. 跨库全量拉取业务数据) ─────► [远程 SQL Server (采集库)]
       │                              │ (执行 FetchRemoteRecords 纯粹搬运数据)
       │                              │ - 分流 A: 不在 tbPPL -> 查下线表 (tx02_assm_offline_record)
       │                              │ - 分流 B: 在 tbPPL   -> 查扫描表 (tx02_scan_record + 相机关联)
       │                              ◄── (返回 SqlDataReader 数据流，装载为 List<RawRecord>)
       │
       ▼ (4. C# 内存清洗与算法切割 - 核心性能飞跃点)
 ┌────────────────────────────────────────────────────────┐
 │  a. 分组聚合: 按 [产线号, 工站, 相机] 将 RawRecord 分组   │
 │  b. 时间排序: 各组内按 RecordTime 从早到晚严格按时间线排序 │
 │  c. 首段计算: 比对 早班起点(8:00) 与 第一笔打卡时间 的差值 │
 │  d. 遍历比对: for循环计算 list[i-1] 与 list[i] 之间的空白期│
 │  e. 线段切割: 传入空白期与休息时间集合，调用算法           │
 │               GetEffectiveDowntimes 自动扣除合法休息期   │
 │               (替代原 SQL 极其耗时的逐分钟 WHILE 循环)    │
 │  f. 格式转化: 调用 GetHourName 生成 "8:00~9:00" 等时段标识 │
 │  g. 结果装箱: 将 diff_time > 阈值 的有效停机填入虚拟      │
 │               内存表 (DataTable dt) 准备发车            │
 └────────────────────────────────────────────────────────┘
       │
       ▼ (5. 批量落盘回写)
[本地 SQL Server (datacollect_base)]
       │
       ├─► 执行 DELETE: 根据 input_date 清理今日旧数据，实现幂等性 (重复跑不死锁)
       │
       └─► 执行 SqlBulkCopy: 像大卡车卸货一样，将 DataTable 内存表
                             一次性极速倾倒至 T200_product_line_hour_diff_result 表
```