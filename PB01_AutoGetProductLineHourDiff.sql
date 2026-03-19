Create proc PB01_AutoGetProductLineHourDiff(@dtFetchTime datetime,@strSysNo varchar(40))  
AS  
  
--declare @dtFetchTime datetime,@strSysNo varchar(40)  
--select @dtFetchTime = '2025-01-01 17:05:22',@strSysNo='660'  
  
declare @dtInputDate datetime  
select @dtInputDate = CONVERT(varchar(100), @dtFetchTime, 23)  
  
  
declare @strCollectConnstr varchar(500)    
 select @strCollectConnstr = ''    
 select @strCollectConnstr = IsNull( (select IsNull(spv.par_value,par.par_value) as par_value    
 from WBF_sys_par par    
 Left Join WBF_sys_par_value spv on par.par_name=spv.par_name    
 where par.par_name = 'hzds_receive_address'),'')    
 declare @abnormal_time varchar(500)    
 select @abnormal_time = '5'    
 select @abnormal_time = IsNull( (select IsNull(spv.par_value,par.par_value) as par_value    
 from WBF_sys_par par    
 Left Join WBF_sys_par_value spv on par.par_name=spv.par_name    
 where par.par_name = 'ProductLine_Abnormal_Diff_Time_Set'),'')    
  
 declare @strSQL1 varchar(max),@strSQL2 varchar(max)  
   
select @strSQL1 ='declare @SearchDate varchar(40),@EndDate varchar(40)  
select @SearchDate = dateadd(HOUR,8,'''+CONVERT(varchar(100), @dtFetchTime, 23)+''')  
select @EndDate = dateadd(day,1,dateadd(HOUR,8,'''+CONVERT(varchar(100), @dtFetchTime, 23)+'''))  
declare  @tbPPL table(product_line_no varchar(40))  
insert into @tbPPL(product_line_no) 
 
select plc.product_line_no 
from TA05_product_line_shift_start tt
inner join TA05_product_line_code plc on tt.product_line_no = plc.product_line_no
where plc.product_line_type_no<>''ZP''

 
select product_line_no,op_no,camera_note,start_time,end_time,diff_time,hour_name,'''' as batch_no  
from       
(select main.product_line_no,'''' as op_no,'''' as camera_note,@SearchDate as start_time,min(main.offline_time) as end_time,  
DATEDIFF(MINUTE,@SearchDate,min(main.offline_time)) as diff_time,''8:00~9:00'' as hour_name  
from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_assm_offline_record main  
where main.product_line_no not in (select product_line_no from  @tbPPL)  
and main.offline_time>=@SearchDate and main.offline_time< @EndDate  
group by main.product_line_no  
)main  
where diff_time>'+@abnormal_time+'  

union  
select product_line_no,op_no,camera_note,start_time,end_time,diff_time,hour_name,batch_no  
from       
(select main.product_line_no,main.op_no,isnull(cl.camera_note,'''') as camera_note,@SearchDate as start_time,min(main.edit_time) as end_time,  
DATEDIFF(MINUTE,@SearchDate,min(main.edit_time)) as diff_time,''8:00~9:00'' as hour_name,max(isnull(mr.user_field2,'''')) as batch_no  
from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_scan_record main  
inner join OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.TF11_product_line_scan_op op on op.product_line_no = main.product_line_no and op.op_no = main.op_no  
outer apply  
(  
 select top 1 camera_note  
 from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx01_camera_list cl  
 where cl.product_line_no = main.product_line_no  
 and cl.op_no = main.op_no  
 order by id desc  
)cl  
outer apply    
(    
 select top 1 user_field2    
 from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_marking_record mr    
 where mr.sn = main.sn  
 order by id desc    
)mr
where (1=1)  
and main.edit_time>=@SearchDate and main.edit_time< @EndDate 
and main.product_line_no in (select product_line_no from  @tbPPL)   
group by main.product_line_no,main.op_no,isnull(cl.camera_note,'''')  
)main  
where diff_time>'+@abnormal_time+'    
union  
select main.product_line_no,'''' as op_no,'''' as camera_note,vcds.offline_time as start_time,main.offline_time as end_time,  
DATEDIFF(MINUTE,vcds.offline_time,main.offline_time) as diff_time,  
case when vcds.offline_time>=@SearchDate and vcds.offline_time<dateadd(HOUR,1,@SearchDate)  
then ''8:00~9:00''  
when vcds.offline_time>=dateadd(HOUR,1,@SearchDate) and vcds.offline_time<dateadd(HOUR,2,@SearchDate)  
then ''9:00~10:00''  
when vcds.offline_time>=dateadd(HOUR,2,@SearchDate) and vcds.offline_time<dateadd(HOUR,3,@SearchDate)  
then ''10:00~11:00''  
when vcds.offline_time>=dateadd(HOUR,3,@SearchDate) and vcds.offline_time<dateadd(HOUR,4,@SearchDate)  
then ''11:00~12:00''  
when vcds.offline_time>=dateadd(HOUR,4,@SearchDate) and vcds.offline_time<dateadd(HOUR,5,@SearchDate)  
then ''12:00~13:00''  
when vcds.offline_time>=dateadd(HOUR,5,@SearchDate) and vcds.offline_time<dateadd(HOUR,6,@SearchDate)  
then ''13:00~14:00''  
when vcds.offline_time>=dateadd(HOUR,6,@SearchDate) and vcds.offline_time<dateadd(HOUR,7,@SearchDate)  
then ''14:00~15:00''  
when vcds.offline_time>=dateadd(HOUR,7,@SearchDate) and vcds.offline_time<dateadd(HOUR,8,@SearchDate)  
then ''15:00~16:00''  
when vcds.offline_time>=dateadd(HOUR,8,@SearchDate) and vcds.offline_time<dateadd(HOUR,9,@SearchDate)  
then ''16:00~17:00''  
when vcds.offline_time>=dateadd(HOUR,9,@SearchDate) and vcds.offline_time<dateadd(HOUR,10,@SearchDate)  
then ''17:00~18:00''  
when vcds.offline_time>=dateadd(HOUR,10,@SearchDate) and vcds.offline_time<dateadd(HOUR,11,@SearchDate)  
then ''18:00~19:00''  
when vcds.offline_time>=dateadd(HOUR,11,@SearchDate) and vcds.offline_time<dateadd(HOUR,12,@SearchDate)  
then ''19:00~20:00''  
when vcds.offline_time>=dateadd(HOUR,12,@SearchDate) and vcds.offline_time<dateadd(HOUR,13,@SearchDate)  
then ''20:00~21:00''  
when vcds.offline_time>=dateadd(HOUR,13,@SearchDate) and vcds.offline_time<dateadd(HOUR,14,@SearchDate)  
then ''21:00~22:00''  
when vcds.offline_time>=dateadd(HOUR,14,@SearchDate) and vcds.offline_time<dateadd(HOUR,15,@SearchDate)  
then ''22:00~23:00''  
when vcds.offline_time>=dateadd(HOUR,15,@SearchDate) and vcds.offline_time<dateadd(HOUR,16,@SearchDate)  
then ''23:00~00:00''  
when vcds.offline_time>=dateadd(HOUR,16,@SearchDate) and vcds.offline_time<dateadd(HOUR,17,@SearchDate)  
then ''00:00~01:00''  
when vcds.offline_time>=dateadd(HOUR,17,@SearchDate) and vcds.offline_time<dateadd(HOUR,18,@SearchDate)  
then ''01:00~02:00''  
when vcds.offline_time>=dateadd(HOUR,18,@SearchDate) and vcds.offline_time<dateadd(HOUR,19,@SearchDate)  
then ''02:00~03:00''  
when vcds.offline_time>=dateadd(HOUR,19,@SearchDate) and vcds.offline_time<dateadd(HOUR,20,@SearchDate)  
then ''03:00~04:00''  
when vcds.offline_time>=dateadd(HOUR,20,@SearchDate) and vcds.offline_time<dateadd(HOUR,21,@SearchDate)  
then ''04:00~05:00''  
when vcds.offline_time>=dateadd(HOUR,21,@SearchDate) and vcds.offline_time<dateadd(HOUR,22,@SearchDate)  
then ''05:00~06:00''  
when vcds.offline_time>=dateadd(HOUR,22,@SearchDate) and vcds.offline_time<dateadd(HOUR,23,@SearchDate)  
then ''06:00~07:00''  
when vcds.offline_time>=dateadd(HOUR,23,@SearchDate) and vcds.offline_time<dateadd(HOUR,24,@SearchDate)  
then ''07:00~08:00'' else '''' end as hour_name,'''' as batch_no  
from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_assm_offline_record main  
outer apply  
(  
 select top 1 *  
 from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_assm_offline_record vcds  
 where  vcds.offline_time>=@SearchDate and vcds.offline_time<@EndDate  
 and vcds.product_line_no = main.product_line_no  
 and vcds.offline_time <main.offline_time  
 and DATEDIFF(MINUTE,vcds.offline_time,main.offline_time)>'+@abnormal_time+'  
 order by vcds.offline_time desc  
   
)vcds  
outer apply  
(  
 select top 1 ck.product_line_no from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_assm_offline_record ck  
  where ck.product_line_no = main.product_line_no  
  and ck.offline_time>vcds.offline_time  
  and ck.offline_time<main.offline_time  
)vcds2  
where main.product_line_no not in (select product_line_no from  @tbPPL)  
and main.offline_time>=@SearchDate and main.offline_time< @EndDate  
and vcds.id is not null  
and vcds2.product_line_no is null  
'  
select @strSQL2=' union  
select main.product_line_no,main.op_no,isnull(cl.camera_note,'''') as camera_note,vcds.edit_time as start_time,main.edit_time as end_time,  
DATEDIFF(MINUTE,vcds.edit_time,main.edit_time) as diff_time,  
case when vcds.edit_time>=@SearchDate and vcds.edit_time<dateadd(HOUR,1,@SearchDate)  
then ''8:00~9:00''  
when vcds.edit_time>=dateadd(HOUR,1,@SearchDate) and vcds.edit_time<dateadd(HOUR,2,@SearchDate)  
then ''9:00~10:00''  
when vcds.edit_time>=dateadd(HOUR,2,@SearchDate) and vcds.edit_time<dateadd(HOUR,3,@SearchDate)  
then ''10:00~11:00''  
when vcds.edit_time>=dateadd(HOUR,3,@SearchDate) and vcds.edit_time<dateadd(HOUR,4,@SearchDate)  
then ''11:00~12:00''  
when vcds.edit_time>=dateadd(HOUR,4,@SearchDate) and vcds.edit_time<dateadd(HOUR,5,@SearchDate)  
then ''12:00~13:00''  
when vcds.edit_time>=dateadd(HOUR,5,@SearchDate) and vcds.edit_time<dateadd(HOUR,6,@SearchDate)  
then ''13:00~14:00''  
when vcds.edit_time>=dateadd(HOUR,6,@SearchDate) and vcds.edit_time<dateadd(HOUR,7,@SearchDate)  
then ''14:00~15:00''  
when vcds.edit_time>=dateadd(HOUR,7,@SearchDate) and vcds.edit_time<dateadd(HOUR,8,@SearchDate)  
then ''15:00~16:00''  
when vcds.edit_time>=dateadd(HOUR,8,@SearchDate) and vcds.edit_time<dateadd(HOUR,9,@SearchDate)  
then ''16:00~17:00''  
when vcds.edit_time>=dateadd(HOUR,9,@SearchDate) and vcds.edit_time<dateadd(HOUR,10,@SearchDate)  
then ''17:00~18:00''  
when vcds.edit_time>=dateadd(HOUR,10,@SearchDate) and vcds.edit_time<dateadd(HOUR,11,@SearchDate)  
then ''18:00~19:00''  
when vcds.edit_time>=dateadd(HOUR,11,@SearchDate) and vcds.edit_time<dateadd(HOUR,12,@SearchDate)  
then ''19:00~20:00''  
when vcds.edit_time>=dateadd(HOUR,12,@SearchDate) and vcds.edit_time<dateadd(HOUR,13,@SearchDate)  
then ''20:00~21:00''  
when vcds.edit_time>=dateadd(HOUR,13,@SearchDate) and vcds.edit_time<dateadd(HOUR,14,@SearchDate)  
then ''21:00~22:00''  
when vcds.edit_time>=dateadd(HOUR,14,@SearchDate) and vcds.edit_time<dateadd(HOUR,15,@SearchDate)  
then ''22:00~23:00''  
when vcds.edit_time>=dateadd(HOUR,15,@SearchDate) and vcds.edit_time<dateadd(HOUR,16,@SearchDate)  
then ''23:00~00:00''  
when vcds.edit_time>=dateadd(HOUR,16,@SearchDate) and vcds.edit_time<dateadd(HOUR,17,@SearchDate)  
then ''00:00~01:00''  
when vcds.edit_time>=dateadd(HOUR,17,@SearchDate) and vcds.edit_time<dateadd(HOUR,18,@SearchDate)  
then ''01:00~02:00''  
when vcds.edit_time>=dateadd(HOUR,18,@SearchDate) and vcds.edit_time<dateadd(HOUR,19,@SearchDate)  
then ''02:00~03:00''  
when vcds.edit_time>=dateadd(HOUR,19,@SearchDate) and vcds.edit_time<dateadd(HOUR,20,@SearchDate)  
then ''03:00~04:00''  
when vcds.edit_time>=dateadd(HOUR,20,@SearchDate) and vcds.edit_time<dateadd(HOUR,21,@SearchDate)  
then ''04:00~05:00''  
when vcds.edit_time>=dateadd(HOUR,21,@SearchDate) and vcds.edit_time<dateadd(HOUR,22,@SearchDate)  
then ''05:00~06:00''  
when vcds.edit_time>=dateadd(HOUR,22,@SearchDate) and vcds.edit_time<dateadd(HOUR,23,@SearchDate)  
then ''06:00~07:00''  
when vcds.edit_time>=dateadd(HOUR,23,@SearchDate) and vcds.edit_time<dateadd(HOUR,24,@SearchDate)  
then ''07:00~08:00'' else '''' end as hour_name,isnull(mr.user_field2,'''') as batch_no    
from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_scan_record main  
inner join OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.TF11_product_line_scan_op op on op.product_line_no = main.product_line_no and op.op_no = main.op_no  
outer apply  
(  
 select top 1 camera_note  
 from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx01_camera_list cl  
 where cl.product_line_no = main.product_line_no  
 and cl.op_no = main.op_no  
 order by id desc  
)cl  
outer apply    
(    
 select top 1 user_field2    
 from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_marking_record mr    
 where mr.sn = main.sn  
 order by id desc    
)mr
outer apply  
(  
 select top 1 *  
 from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_scan_record vcds  
 where  vcds.edit_time>=@SearchDate and vcds.edit_time< @EndDate  
 and vcds.product_line_no = main.product_line_no  
 and vcds.op_no = main.op_no  
 and vcds.edit_time <main.edit_time  
 and DATEDIFF(MINUTE,vcds.edit_time,main.edit_time)>'+@abnormal_time+'  
 order by vcds.edit_time desc  
   
)vcds  
outer apply  
(  
 select top 1 ck.product_line_no from OPENDATASOURCE(''SQLOLEDB'','''+@strCollectConnstr+''').[datacollect_base].dbo.tx02_scan_record ck  
  where ck.product_line_no = main.product_line_no  
  and ck.op_no = main.op_no  
  and ck.edit_time>vcds.edit_time  
  and ck.edit_time<main.edit_time  
)vcds2  
where (1=1)  
and main.product_line_no in (select product_line_no from  @tbPPL)  
and main.edit_time>=@SearchDate and main.edit_time< @EndDate  
and vcds.id is not null  
and vcds2.product_line_no is null  
'  


  
 if exists(select * from tempdb..sysobjects where id=object_id('tempdb..#tbTemp'))                                  
  drop table #tbTemp                                      
  create table #tbTemp(  
  product_line_no varchar(40),op_no varchar(40),camera_note varchar(100),start_time datetime,end_time datetime,diff_time float,hour_name varchar(100),id int identity(1,1),batch_no varchar(100)  
  )  
  insert into #tbTemp(product_line_no,op_no,camera_note,start_time,end_time,diff_time,hour_name,batch_no)  
  exec(@strSQL1+@strSQL2)  
print (@strSQL1)  
print (@strSQL2)  


 if exists(select * from tempdb..sysobjects where id=object_id('tempdb..#tbRest'))                                  
  drop table #tbRest                                       
  create table #tbRest(  
  product_line_no varchar(40),start_time datetime,end_time datetime
  )  
  insert into #tbRest(product_line_no,start_time,end_time)
  select product_line_no,
  case when tt.start_tomorrow_tag='T' then DATEADD(day,1,@dtInputDate+tt.start_time) else @dtInputDate+tt.start_time end as start_time,
 case when tt.end_tomorrow_tag='T' then DATEADD(day,1,@dtInputDate+tt.end_time) else @dtInputDate+tt.end_time end as  end_time
  from TA05_product_line_shift_rest tt
  where tt.product_line_no in (select distinct product_line_no from #tbTemp)
  
  
    

    




  --insert into #tbRest(product_line_no,start_time,end_time)
  --select product_line_no,
  --case when tt.start_tomorrow_tag='T' then DATEADD(day,1,@dtInputDate+tt.start_time) else @dtInputDate+tt.start_time end as start_time,
 --case when tt.end_tomorrow_tag='T' then DATEADD(day,1,@dtInputDate+tt.end_time) else @dtInputDate+tt.end_time end as  end_time
  --from TA05_product_line_shift_stop tt
  --where tt.product_line_no in (select distinct product_line_no from #tbTemp)
  
  --insert into #tbRest(product_line_no,start_time,end_time)
  --select vcds.product_line_no,main.start_time,main.end_time
    --from TA05_made_dept_product_line_stop_time_set main
    --inner join TA05_made_dept_product_line_work_hour_set vcds on main.detail_guid = vcds.detail_guid
  --where  vcds.product_line_no in (select distinct product_line_no from #tbTemp)
  --and vcds.work_date = @dtInputDate
  
  
  if exists(select * from tempdb..sysobjects where id=object_id('tempdb..#tbStop'))                                
  drop table #tbStop                                     
  create table #tbStop (product_line_no varchar(40),start_time datetime,end_time datetime)
  insert into #tbStop (product_line_no,start_time,end_time)
  select product_line_no,start_time,end_time
  from TA05_plan_stop_time_set
  where  DATEDIFF(MINUTE, 
             CASE 
                 WHEN dateadd(HOUR,8,CONVERT(varchar(100), @dtFetchTime, 23)) > start_time THEN dateadd(HOUR,8,CONVERT(varchar(100), @dtFetchTime, 23))
                 ELSE start_time 
             END, 
             CASE 
                 WHEN dateadd(day,1,dateadd(HOUR,8,CONVERT(varchar(100), @dtFetchTime, 23))) < end_time THEN dateadd(day,1,dateadd(HOUR,8,CONVERT(varchar(100), @dtFetchTime, 23)))
                 ELSE end_time 
             END)>0


update t set t.start_time = dateadd(HOUR,8,CONVERT(varchar(100), @dtFetchTime, 23))

from #tbStop t
where start_time < dateadd(HOUR,8,CONVERT(varchar(100), @dtFetchTime, 23))

update t set t.end_time = dateadd(day,1,dateadd(HOUR,8,CONVERT(varchar(100), @dtFetchTime, 23)))

from #tbStop t
where end_time > dateadd(day,1,dateadd(HOUR,8,CONVERT(varchar(100), @dtFetchTime, 23)))

insert into #tbRest(product_line_no,start_time,end_time)
select product_line_no,start_time,end_time
from #tbStop








  
  
  
  delete from T200_product_line_hour_diff_result where input_date = @dtInputDate  
   if exists(select * from tempdb..sysobjects where id=object_id('tempdb..#tbReturn'))                                  
  drop table #tbReturn                                      
  create table #tbReturn(  
  product_line_no varchar(40),op_no varchar(40),camera_note varchar(100),start_time datetime,end_time datetime,diff_time float,hour_name varchar(100)
  )  
  
  
  
  declare @intMin int,@intMax int,@bWorkTag varchar(40),@l_dtSaveStartTime datetime,@l_dtSaveEndTime datetime,@strProductLine varchar(40),@dtEndTime datetime
  
  select @bWorkTag = 'F',@l_dtSaveStartTime = '1900-01-01',@l_dtSaveEndTime = '1900-01-01',@strProductLine = ''
  
  select @intMin=1
  select @intMax = isnull(max(id),0) from #tbTemp
  
  while(@intMin<@intMax)
  begin
  select @l_dtSaveStartTime = start_time,@l_dtSaveEndTime = start_time,@strProductLine = product_line_no,@dtEndTime =end_time from #tbTemp where id = @intMin

  if(exists (select top 1 1 from #tbRest where product_line_no = @strProductLine and start_time<=@l_dtSaveStartTime and end_time>=@l_dtSaveEndTime))
  begin
  select @bWorkTag = 'F'
  select @l_dtSaveStartTime = max(end_time) from #tbRest where product_line_no = @strProductLine and start_time<=@l_dtSaveEndTime and end_time>=@l_dtSaveEndTime
  select @l_dtSaveEndTime = @l_dtSaveStartTime

  end 
  else

  begin
  select @bWorkTag = 'T'

  end

  while(@l_dtSaveEndTime<DATEADD(MINUTE,1,@dtEndTime))
  begin

  if(exists (select top 1 1 from #tbRest where product_line_no = @strProductLine and start_time<=@l_dtSaveEndTime and end_time>=@l_dtSaveEndTime)
  and @bWorkTag = 'T'
  )
  begin

  
INSERT INTO [dbo].[T200_product_line_hour_diff_result]  
           ([sys_no]  
           ,[input_date]  
           ,[product_line_no]  
           ,[op_no]  
           ,[camera_note]  
           ,[start_time]  
           ,[end_time]  
           ,[diff_time]  
           ,[hour_name]  
           ,[time_set]
           ,[batch_no])
SELECT @strSysNo[sys_no]  
      ,@dtInputDate[input_date]  
      ,[product_line_no]  
      ,[op_no]  
      ,[camera_note]  
      ,@l_dtSaveStartTime[start_time]  
      ,@l_dtSaveEndTime[end_time]  
      ,DATEDIFF(MINUTE,@l_dtSaveStartTime,@l_dtSaveEndTime) [diff_time]  
      ,[hour_name]  
      ,@abnormal_time[time_set]  
      ,[batch_no]
from #tbTemp  tt
where tt.id = @intMin
and DATEDIFF(MINUTE,@l_dtSaveStartTime,@l_dtSaveEndTime)>cast(@abnormal_time as int)

end


 if(exists (select top 1 1 from #tbRest where product_line_no = @strProductLine and start_time<=@l_dtSaveEndTime and end_time>=@l_dtSaveEndTime)
  )
  begin
  select @l_dtSaveStartTime =  max(end_time) from #tbRest where product_line_no = @strProductLine and start_time<=@l_dtSaveEndTime and end_time>=@l_dtSaveEndTime
select @l_dtSaveEndTime = @l_dtSaveStartTime
select @bWorkTag ='F'
  end



if(not exists (select top 1 1 from #tbRest where product_line_no = @strProductLine and start_time<=@l_dtSaveEndTime and end_time>=@l_dtSaveEndTime))
begin
select @bWorkTag ='T'
if(@l_dtSaveEndTime>@dtEndTime)
begin

INSERT INTO [dbo].[T200_product_line_hour_diff_result]  
           ([sys_no]  
           ,[input_date]  
           ,[product_line_no]  
           ,[op_no]  
           ,[camera_note]  
           ,[start_time]  
           ,[end_time]  
           ,[diff_time]  
           ,[hour_name]  
           ,[time_set]
           ,[batch_no])
SELECT @strSysNo[sys_no]  
      ,@dtInputDate[input_date]  
      ,[product_line_no]  
      ,[op_no]  
      ,[camera_note]  
      ,@l_dtSaveStartTime[start_time]  
      ,@dtEndTime[end_time]  
      ,DATEDIFF(MINUTE,@l_dtSaveStartTime,@dtEndTime) [diff_time]  
      ,[hour_name]  
      ,@abnormal_time[time_set]
      ,[batch_no]
from #tbTemp  tt
where tt.id = @intMin
and DATEDIFF(MINUTE,@l_dtSaveStartTime,@dtEndTime)>cast(@abnormal_time as int)



end


  end



  select @l_dtSaveEndTime = DATEADD(MINUTE,1,@l_dtSaveEndTime)
  end




  
  
  
  select @intMin = @intMin+1
  end 
   
  
  
  
  
  
  
  
  
  
  
  

  
  
select * from #tbTemp  
select @dtFetchTime  
select @dtInputDate  
select @strCollectConnstr  
select @abnormal_time  
  