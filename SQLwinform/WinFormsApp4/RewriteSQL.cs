using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;

// 1. 定义数据承接模型 (POCO)
public class RawRecord
{
    public string ProductLineNo { get; set; }
    public string OpNo { get; set; }
    public string CameraNote { get; set; }
    public string BatchNo { get; set; }
    public DateTime RecordTime { get; set; }
}

public class RestTimeRecord
{
    public string ProductLineNo { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
}

public class ValidDowntimeSegment
{
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public double DiffMinutes { get; set; }
}

public class ProductLineAnalyzer
{
    private readonly string _localConnectionString;

    public ProductLineAnalyzer(string localConnectionString)
    {
        _localConnectionString = localConnectionString;
    }

    public void ExecuteAnalysis(DateTime dtFetchTime, string sysNo)
    {
        // 参数解释：
        // dtFetchTime: 外部传入的抓取时间基准（例如 2025-01-01 17:05:22）
        // searchDate: 实际业务上的“班次起点”。工厂通常早上 8 点算一天的开始，所以这里加 8 小时。
        // endDate: 班次终点，起点加 1 天（次日 8 点）。
        DateTime searchDate = dtFetchTime.Date.AddHours(8);
        DateTime endDate = searchDate.AddDays(1);
        DateTime inputDate = dtFetchTime.Date;

        string remoteConnString = "";
        int abnormalTimeThreshold = 5;

        // ==========================================
        // 第一步：获取本地配置、休息时间与产线白名单
        // ==========================================
        List<RestTimeRecord> allRestTimes = new List<RestTimeRecord>();
        List<string> tbPPL = new List<string>();

        using (SqlConnection localConn = new SqlConnection(_localConnectionString))
        {
            localConn.Open();
            //remoteConnString = GetSysParameter(localConn, "hzds_receive_address");
			remoteConnString = @"Data Source=172.31.10.251\server; Database=datacollect_base; Uid=sa; Pwd=system; pooling=true; min pool size=5; max pool size=512;";
            string timeStr = GetSysParameter(localConn, "ProductLine_Abnormal_Diff_Time_Set");

			// 1. 先声明一个整型变量来作为容器接收结果
			int timeVal;
			
			// 2. 在方法调用中传入该变量，保留 out 关键字但不加类型
			if (int.TryParse(timeStr, out timeVal))
			{
			    abnormalTimeThreshold = timeVal;
			}

            allRestTimes = GetRestTimesFromLocalDB(localConn, inputDate, searchDate, endDate);

            // 获取非 ZP 类型的产线名单 (等同于 SQL 中的 @tbPPL)
            string pplSql = @"
                SELECT plc.product_line_no 
                FROM TA05_product_line_shift_start tt
                INNER JOIN TA05_product_line_code plc ON tt.product_line_no = plc.product_line_no
                WHERE plc.product_line_type_no <> 'ZP'";
            using (SqlCommand cmd = new SqlCommand(pplSql, localConn))
            using (SqlDataReader reader = cmd.ExecuteReader())
            {
                while (reader.Read()) tbPPL.Add(reader["product_line_no"].ToString());
            }
        }

        if (string.IsNullOrEmpty(remoteConnString))
            throw new Exception("未获取到远程数据采集库的连接字符串！");

        // ==========================================
        // 第二步：连接远程库拉取原始打卡/下线数据
        // ==========================================
        List<RawRecord> rawRecords = FetchRemoteRecords(remoteConnString, searchDate, endDate, tbPPL);

        // ==========================================
        // 第三步：在内存中进行清洗、计算时间差并扣除休息时间
        // ==========================================
        DataTable resultTable = CreateResultTableSchema();

        // 业务场景：扫描表(tx02_scan_record)不仅按产线，还按工站(op_no)和相机(camera_note)区分。
        // 所以我们用这三个字段作为联合主键进行分组。
        var groupedRecords = rawRecords.GroupBy(r => new { r.ProductLineNo, r.OpNo, r.CameraNote });

        foreach (var group in groupedRecords)
        {
            var sortedList = group.OrderBy(r => r.RecordTime).ToList();
            var currentLineRestTimes = allRestTimes.Where(r => r.ProductLineNo == group.Key.ProductLineNo).ToList();

            if (sortedList.Count == 0) continue;

            // 1. 处理班次开始 (@SearchDate) 到第一条记录之间的异常停机
            // 对应 SQL 中的第一部分和第二部分 (UNION 的上半部分)
            ProcessSegmentAndFillTable(
                sysNo, inputDate, group.Key.ProductLineNo, group.Key.OpNo, group.Key.CameraNote,
                sortedList[0].BatchNo, // 批次号取结束点的
                searchDate,            // 班次起点
                sortedList[0].RecordTime, // 第一条记录的时间
                currentLineRestTimes, abnormalTimeThreshold, resultTable, searchDate, true);

            // 2. 处理连续两条记录之间的异常停机
            // 对应 SQL 中的 vcds 和 vcds2 自连接找间隔部分 (UNION 的下半部分)
            for (int i = 1; i < sortedList.Count; i++)
            {
                var prev = sortedList[i - 1];
                var curr = sortedList[i];

                ProcessSegmentAndFillTable(
                    sysNo, inputDate, group.Key.ProductLineNo, group.Key.OpNo, group.Key.CameraNote,
                    curr.BatchNo,
                    prev.RecordTime, // 上一次打卡时间
                    curr.RecordTime, // 本次打卡时间
                    currentLineRestTimes, abnormalTimeThreshold, resultTable, searchDate, false);
            }
        }

        // ==========================================
        // 第四步：批量写回本地数据库
        // ==========================================
        using (SqlConnection localConn = new SqlConnection(_localConnectionString))
        {
            localConn.Open();
            using (SqlCommand cmd = new SqlCommand("DELETE FROM T200_product_line_hour_diff_result_Csharp WHERE input_date = @InputDate", localConn))
            {
                cmd.Parameters.AddWithValue("@InputDate", inputDate);
                cmd.ExecuteNonQuery();
            }

            using (SqlBulkCopy bulkCopy = new SqlBulkCopy(localConn))
            {
                bulkCopy.DestinationTableName = "T200_product_line_hour_diff_result_Csharp";
                bulkCopy.BatchSize = 1000;
                bulkCopy.WriteToServer(resultTable);
            }
        }
    }

    // --- 核心业务逻辑方法 ---

    private void ProcessSegmentAndFillTable(
        string sysNo, DateTime inputDate, string productLineNo, string opNo, string cameraNote, string batchNo,
        DateTime startT, DateTime endT,
        List<RestTimeRecord> restTimes, int abnormalThreshold, DataTable dt, DateTime searchDate, bool isFirstSegmentOfDay)
    {
        // 核心算法：扣除休息时间后，获取真正有效的停机时段
        List<ValidDowntimeSegment> validSegments = GetEffectiveDowntimes(startT, endT, restTimes, abnormalThreshold);

        foreach (var segment in validSegments)
        {
            DataRow row = dt.NewRow();
            row["sys_no"] = sysNo;
            row["input_date"] = inputDate;
            row["product_line_no"] = productLineNo;
            row["op_no"] = opNo ?? "";
            row["camera_note"] = cameraNote ?? "";
            row["start_time"] = segment.StartTime;
            row["end_time"] = segment.EndTime;
            row["diff_time"] = segment.DiffMinutes;
            row["time_set"] = abnormalThreshold;
            row["batch_no"] = batchNo ?? "";

            // 业务场景：根据停机发生的起始时间，判断属于哪个时间段。
            // 原 SQL 中对第一段强制设为 '8:00~9:00'，后续段用大段 CASE WHEN 判断。
            if (isFirstSegmentOfDay)
            {
                row["hour_name"] = "8:00~9:00";
            }
            else
            {
                row["hour_name"] = GetHourName(startT, searchDate);
            }

            dt.Rows.Add(row);
        }
    }

    /// <summary>
    /// 扣除休息时间的核心算法 (替代原 SQL 的逐分钟 WHILE 循环)
    /// </summary>
    private List<ValidDowntimeSegment> GetEffectiveDowntimes(DateTime eventStart, DateTime eventEnd, List<RestTimeRecord> restTimes, int abnormalThreshold)
    {
        List<ValidDowntimeSegment> validSegments = new List<ValidDowntimeSegment>();
        DateTime currentStart = eventStart;

        // 确保休息时间按先后顺序排列，便于进行线段切割
        var sortedRests = restTimes.OrderBy(r => r.StartTime).ToList();

        foreach (var rest in sortedRests)
        {
            if (rest.EndTime <= currentStart) continue; // 休息时间在当前检查点之前，跳过
            if (rest.StartTime >= eventEnd) break;      // 休息时间在当前事件之后，直接结束比对

            // 如果当前检查点到休息开始前，有一段纯工作时间
            if (currentStart < rest.StartTime)
            {
                double diff = (rest.StartTime - currentStart).TotalMinutes;
                if (diff > abnormalThreshold) // 超过异常阈值才算停机
                {
                    validSegments.Add(new ValidDowntimeSegment { StartTime = currentStart, EndTime = rest.StartTime, DiffMinutes = diff });
                }
            }
            // 将检查点移动到休息结束的时间，跳过休息期
            currentStart = new DateTime(Math.Max(currentStart.Ticks, rest.EndTime.Ticks));
        }

        // 检查最后一段休息结束到事件结束之间的时间
        if (currentStart < eventEnd)
        {
            double finalDiff = (eventEnd - currentStart).TotalMinutes;
            if (finalDiff > abnormalThreshold)
            {
                validSegments.Add(new ValidDowntimeSegment { StartTime = currentStart, EndTime = eventEnd, DiffMinutes = finalDiff });
            }
        }
        return validSegments;
    }

    private List<RawRecord> FetchRemoteRecords(string connStr, DateTime searchDate, DateTime endDate, List<string> tbPPL)
    {
        List<RawRecord> records = new List<RawRecord>();
        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            // 1. 获取 assm_offline_record (不在白名单内的产线)
            string assmQuery = @"
                SELECT product_line_no, '' AS op_no, '' AS camera_note, '' AS batch_no, offline_time AS record_time 
                FROM tx02_assm_offline_record 
                WHERE offline_time >= @SearchDate AND offline_time < @EndDate";

            using (SqlCommand cmd = new SqlCommand(assmQuery, conn))
            {
                cmd.CommandTimeout = 120;
                cmd.Parameters.AddWithValue("@SearchDate", searchDate);
                cmd.Parameters.AddWithValue("@EndDate", endDate);
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        string pLineNo = reader["product_line_no"].ToString();
                        // 相当于 SQL 里的 NOT IN (@tbPPL)
                        if (!tbPPL.Contains(pLineNo))
                        {
                            records.Add(new RawRecord
                            {
                                ProductLineNo = pLineNo,
                                OpNo = reader["op_no"].ToString(),
                                CameraNote = reader["camera_note"].ToString(),
                                BatchNo = reader["batch_no"].ToString(),
                                RecordTime = Convert.ToDateTime(reader["record_time"])
                            });
                        }
                    }
                }
            }

            // 2. 获取 scan_record 及关联信息 (在白名单内的产线)
            string scanQuery = @"
                SELECT main.product_line_no, main.op_no, main.edit_time AS record_time, main.sn,
                       ISNULL(cl.camera_note, '') AS camera_note,
                       ISNULL(mr.user_field2, '') AS batch_no
                FROM tx02_scan_record main
                -- 严格还原 SQL 中的 OUTER APPLY 逻辑，取最新的一笔关联记录
                OUTER APPLY (
                    SELECT TOP 1 camera_note 
                    FROM tx01_camera_list cl 
                    WHERE cl.product_line_no = main.product_line_no AND cl.op_no = main.op_no 
                    ORDER BY id DESC
                ) cl
                OUTER APPLY (
                    SELECT TOP 1 user_field2 
                    FROM tx02_marking_record mr 
                    WHERE mr.sn = main.sn 
                    ORDER BY id DESC
                ) mr
                WHERE main.edit_time >= @SearchDate AND main.edit_time < @EndDate";

            using (SqlCommand cmd = new SqlCommand(scanQuery, conn))
            {
                cmd.CommandTimeout = 300; // 关联查询较慢，适当增加超时时间
                cmd.Parameters.AddWithValue("@SearchDate", searchDate);
                cmd.Parameters.AddWithValue("@EndDate", endDate);
                using (SqlDataReader reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        string pLineNo = reader["product_line_no"].ToString();
                        // 相当于 SQL 里的 IN (@tbPPL)
                        if (tbPPL.Contains(pLineNo))
                        {
                            records.Add(new RawRecord
                            {
                                ProductLineNo = pLineNo,
                                OpNo = reader["op_no"].ToString(),
                                CameraNote = reader["camera_note"].ToString(),
                                BatchNo = reader["batch_no"].ToString(),
                                RecordTime = Convert.ToDateTime(reader["record_time"])
                            });
                        }
                    }
                }
            }
        }
        return records;
    }

    /// <summary>
    /// 还原 SQL 中的巨型 CASE WHEN，根据停机发生时间判断属于哪个小时段
    /// </summary>
    private string GetHourName(DateTime time, DateTime searchDate)
	{
	    int hoursDiff = (int)Math.Floor((time - searchDate).TotalHours);
	    if (hoursDiff < 0) hoursDiff = 0;
	    if (hoursDiff > 23) hoursDiff = 23;
	
	    int startHour = (8 + hoursDiff) % 24;
	    int endHour = (startHour + 1) % 24;
	
	    // 针对原 SQL 中对凌晨时段带前导零 (00:00~07:00)，而白天不带 (8:00~9:00) 的特殊脾气进行精确适配
	    string startHourStr = (startHour >= 0 && startHour <= 7) ? startHour.ToString("D2") : startHour.ToString();
	    string endHourStr = (endHour >= 0 && endHour <= 8) ? endHour.ToString("D2") : endHour.ToString();
	    
	    // 处理特例：如果是 23点到0点，结尾应该是 00:00
	    if (endHour == 0) endHourStr = "00";
	
	    return string.Format("{0}:00~{1}:00", startHourStr, endHourStr);
	}

    private string GetSysParameter(SqlConnection conn, string parName)
    {
        string sql = "SELECT ISNULL((SELECT par_value FROM WBF_sys_par_value WHERE par_name = @p), (SELECT par_value FROM WBF_sys_par WHERE par_name = @p))";
        using (SqlCommand cmd = new SqlCommand(sql, conn))
        {
            cmd.Parameters.AddWithValue("@p", parName);
            object res = cmd.ExecuteScalar();
            return res == null ? "" : res.ToString();
        }
    }

    private List<RestTimeRecord> GetRestTimesFromLocalDB(SqlConnection conn, DateTime inputDate, DateTime searchDate, DateTime endDate)
    {
        List<RestTimeRecord> restTimes = new List<RestTimeRecord>();

        // 1. 获取班次休息时间
        string restSql = @"
            SELECT product_line_no,
                   CASE WHEN start_tomorrow_tag = 'T' 
                        THEN DATEADD(day, 1, CAST(@InputDate AS DATETIME) + CAST(start_time AS DATETIME)) 
                        ELSE CAST(@InputDate AS DATETIME) + CAST(start_time AS DATETIME) END AS calc_start_time,
                   CASE WHEN end_tomorrow_tag = 'T' 
                        THEN DATEADD(day, 1, CAST(@InputDate AS DATETIME) + CAST(end_time AS DATETIME)) 
                        ELSE CAST(@InputDate AS DATETIME) + CAST(end_time AS DATETIME) END AS calc_end_time
            FROM TA05_product_line_shift_rest";

        using (SqlCommand cmd = new SqlCommand(restSql, conn))
        {
            cmd.Parameters.AddWithValue("@InputDate", inputDate);
            using (SqlDataReader reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    restTimes.Add(new RestTimeRecord
                    {
                        ProductLineNo = reader["product_line_no"].ToString(),
                        StartTime = Convert.ToDateTime(reader["calc_start_time"]),
                        EndTime = Convert.ToDateTime(reader["calc_end_time"])
                    });
                }
            }
        }

        // 2. 获取计划停机时间，并在内存中做边界限制 (Clamp)
        string stopSql = @"
            SELECT product_line_no, start_time, end_time
            FROM TA05_plan_stop_time_set
            WHERE end_time > @SearchDate AND start_time < @EndDate";

        using (SqlCommand cmd = new SqlCommand(stopSql, conn))
        {
            cmd.Parameters.AddWithValue("@SearchDate", searchDate);
            cmd.Parameters.AddWithValue("@EndDate", endDate);
            using (SqlDataReader reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    DateTime st = Convert.ToDateTime(reader["start_time"]);
                    DateTime et = Convert.ToDateTime(reader["end_time"]);

                    if (st < searchDate) st = searchDate;
                    if (et > endDate) et = endDate;

                    restTimes.Add(new RestTimeRecord
                    {
                        ProductLineNo = reader["product_line_no"].ToString(),
                        StartTime = st,
                        EndTime = et
                    });
                }
            }
        }
        return restTimes;
    }

    private DataTable CreateResultTableSchema()
    {
        DataTable dt = new DataTable();
        dt.Columns.Add("sys_no", typeof(string));
        dt.Columns.Add("input_date", typeof(DateTime));
        dt.Columns.Add("product_line_no", typeof(string));
        dt.Columns.Add("op_no", typeof(string));
        dt.Columns.Add("camera_note", typeof(string));
        dt.Columns.Add("start_time", typeof(DateTime));
        dt.Columns.Add("end_time", typeof(DateTime));
        dt.Columns.Add("diff_time", typeof(double));
        dt.Columns.Add("hour_name", typeof(string));
        dt.Columns.Add("time_set", typeof(int));
        dt.Columns.Add("batch_no", typeof(string));
        return dt;
    }
}