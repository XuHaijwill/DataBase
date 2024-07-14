## 背景
```
SYBASE 自带不少排查问题用的存储过程和MDA表,但是在排查问题时这些存储过程要么输出太详实太专业不容易聚焦问题，
要么需要联查多张表在转瞬即逝的性能问题面前不能捕获有效的信息。
编写整理几个存储过程，希望对大家排查问题有所帮助，同时不足之处还请大家指正！
```

### 一、排查全局超大表

过程名称：sp_dba_largetable

排查场景：随着业务系统发展，生产环境的大表已经不是规划时的实体主表，而是一些意料之外附属表，包括日志表、历史表、备份表、临时表等。超大表严重占用数据库系统资源，影响核心业务流程。

SQL代码:
```sql
use sybsystemprocs 
go 

if object_id('sp_dba_largetable') is not null 
	drop procedure sp_dba_largetable 
GO
create procedure sp_dba_largetable
AS
--查看超大数据对象
--add by wangzhen 2017-07-11
--v1.0.0
begin 
    declare @temp_sql varchar(500)
    declare @sql varchar(1000)
    declare @dbname varchar(100)
    declare dbname_cursor cursor for select name from master..sysdatabases
    create table #objectinfo (
	dbname varchar(300),
	objid int,
	objname varchar(300),
	pagecnt bigint,
	leafcnt bigint,
	rowcnt bigint
    )
	set @temp_sql = 'insert into #objectinfo select  ''@dbname#'' as dbname,ind.id,ind.name,stat.pagecnt,stat.leafcnt,stat.rowcnt from @dbname#..systabstats stat left join @dbname#..sysindexes ind on stat.id = ind.id and stat.indid = ind.indid' 	
	open dbname_cursor
	while @@sqlstatus =0 
	BEGIN
		FETCH  dbname_cursor into @dbname
		set @sql =  str_replace(@temp_sql,'@dbname#',@dbname) 
		EXECUTE(@sql)
	END 
	close dbname_cursor
	select top 100  t.dbname as "库名",t.objid as "对象ID",t.objname as "对象名",
                        t.rowcnt as "行数",t.datasize as  "数据大小(KB)",
                        t.indexsize as "索引大小(KB)"  from 
                        (select dbname ,max(objname) objname,objid ,
                               max(rowcnt) rowcnt,(sum(pagecnt) * @@maxpagesize/1024) as datasize,
                               (sum(leafcnt) * @@maxpagesize/1024)  as indexsize  
                        from #objectinfo group by dbname,objid ) t order by t.rowcnt desc
      drop table #objectinfo
end  

go

```

### 二、排查全局聚簇索引表

过程名称：sp_dba_citable

排查场景：很多项目使用UUID做为主键，如NP。这种情况下默认的聚簇索引主键会造成一定的性能问题，NP项目开发规范要求及SMD默认生成的SYBASE主键都是非聚簇索引。因为一些历史原因实际生产环境中可能存在不少聚簇索引，需要排查矫正。

SQL代码：

```sql
use sybsystemprocs 
go

if object_id('sp_dba_citable') is not null 
	drop procedure sp_dba_citable
go
create procedure sp_dba_citable
AS
--查看聚簇索引表
--add by wangzhen 2017-07-17
--v1.0.0
begin 
    declare @temp_sql varchar(500)
    declare @sql varchar(1000)
	declare @dbname varchar(100)
	declare dbname_cursor cursor for select name from master..sysdatabases
	create table #objectinfo (
	dbname varchar(100),
	objid int,
	tablename varchar(300),
	indexid int,
	indexname varchar(300),
	keycnt int,
	indextype varchar(100)
	)
	create table #objectinfo2 (
	dbname varchar(100),
	objid int,
	tablename varchar(300),
	indexid int,
	indexname varchar(300),
	keycnt int,
	indexkey varchar(1000) null,
	indextype varchar(100)
	)
	set @temp_sql = 'insert into #objectinfo '
                         + 'select ''@dbname#'' , '
                         + 'obj.id , '
                         + 'obj.name , '
                         + 'ind.indid , '
                         + 'ind.name , '
                         + 'ind.keycnt , '
                         + '''culster index''  '
                         +' from @dbname#..sysindexes ind left join  @dbname#..sysobjects obj on ind.id = obj.id '
                         +' where (ind.status2 & 512 = 512 or ind.indid = 1) and obj.type = ''U'' ' 	
	open dbname_cursor
	while @@sqlstatus =0 
	BEGIN
		FETCH  dbname_cursor into @dbname
		set @sql =  str_replace(@temp_sql,'@dbname#',@dbname) 
		EXECUTE(@sql)
	END 
	close dbname_cursor
	insert into #objectinfo2 (t.dbname,objid,tablename,indexid,indexname,keycnt,indextype,indexkey)  
	select 
		t.dbname ,
		t.objid ,
		t.tablename ,
		max(t.indexid) ,
		t.indexname ,
		max(t.keycnt) ,
		t.indextype ,
		case when max(t.keycnt) =2 then
		  index_col(t.dbname+'..'+t.tablename,max(t.indexid),1)+' '+index_colorder(t.dbname+'..'+t.tablename,max(t.indexid),1)
		when max(t.keycnt) =3 then
		  index_col(t.dbname+'..'+t.tablename,max(t.indexid),1)+' '+index_colorder(t.dbname+'..'+t.tablename,max(t.indexid),1)
		  +','+
		  index_col(t.dbname+'..'+t.tablename,max(t.indexid),2)+' '+index_colorder(t.dbname+'..'+t.tablename,max(t.indexid),2)
		when max(t.keycnt) =4 then
		  index_col(t.dbname+'..'+t.tablename,max(t.indexid),1)+' '+index_colorder(t.dbname+'..'+t.tablename,max(t.indexid),1)
		  +','+
		  index_col(t.dbname+'..'+t.tablename,max(t.indexid),2)+' '+index_colorder(t.dbname+'..'+t.tablename,max(t.indexid),2)
		  +','+
		  index_col(t.dbname+'..'+t.tablename,max(t.indexid),3)+' '+index_colorder(t.dbname+'..'+t.tablename,max(t.indexid),3)
		  else 
		  null 
		end   		  
	from #objectinfo t 
        where t.dbname not in ('master','tempdb','sybsecurity','sybsystemdb','sybsystemprocs') 
        group by t.dbname,t.objid,t.tablename,t.indexname,t.indextype  order by t.dbname asc,t.objid asc
	

	select 
		t.dbname as "库名",
		t.objid as "对象ID",
		t.tablename as "表名", 
		t.indexname as "索引名",
		t.indexkey as "索引键",
		t.keycnt -1 as "索引键数量",
		t.indextype as  "索引描述"  
	from #objectinfo2 t group by t.dbname,t.objid,t.tablename,t.indexname,t.keycnt,t.indextype  order by t.dbname asc,t.tablename asc
end 

go

```

### 三、排查数据库表分析
过程名称: sp_dba_statistics

排查场景： 数据库表分析是否及时更新极大影响着数据库SQL的执行效率。每隔一段时间、数据矫正完成、数据迁移完成后都应该及时更新数据库表分析，超过一个月未更新，要引起注意。

SQL代码：

```sql
use sybsystemprocs 
go

if object_id('sp_dba_statistics') is not null 
    drop procedure sp_dba_statistics
go 

create procedure sp_dba_statistics
AS
--查看超过一个月未更新的统计值
--add by wangzhen 2017-08-08
--v1.0.0
begin 
    declare @temp_sql varchar(500)
    declare @sql varchar(1000)
    declare @dbname varchar(100)
    declare dbname_cursor cursor for select name from master..sysdatabases
    create table #objectinfo (
        dbname varchar(100),
        objid int,
        tablename varchar(100),
        moddate datetime,
        curdate datetime
    )
   set @temp_sql = 'insert into #objectinfo '
                             + 'select ''@dbname#'' , '
                             + 'obj.id , '
                             + 'obj.name , '
                             + 'stat.moddate,'
                             + 'getdate() '
                             +' from  @dbname#..sysstatistics stat left join @dbname#..sysobjects obj on stat.id = obj.id '
                             +' where obj.type = ''U'' and stat.moddate < dateadd(day,-60,getdate()) '
open dbname_cursor
while @@sqlstatus =0 
  BEGIN
     FETCH  dbname_cursor into @dbname
     set @sql =  str_replace(@temp_sql,'@dbname#',@dbname) 
     EXECUTE(@sql)
  END 
close dbname_cursor
select 
      t.dbname as "库名",
      t.tablename as "表名", 
      max(t.moddate) as "更改时间",
      max(t.curdate) as "当前时间"
      from #objectinfo t  where t.dbname not in ('master','tempdb','sybsecurity','sybsystemdb','sybsystemprocs') 
      group by t.dbname,t.tablename
      having max(t.moddate)  < dateadd(day,-60,getdate())
      order by t.dbname asc,max(t.moddate) desc
end 

go

```

### 四、排查全局库空间信息

过程名称：sp_dba_dbspaceinfo

排查场景：生产环境中数据增长速度很快，数据库空间不足会引起不少问题，需要经常排查。

SQL代码:

```sql
use sybsystemprocs 
go

if object_id('sp_dba_dbspaceinfo') is not null 
	drop procedure sp_dba_dbspaceinfo
GO
create procedure sp_dba_dbspaceinfo
AS
--查看数据库的空间信息
--add by wangzhen 2017-07-11
--v1.0.0
begin 
select 
	convert(char(16),db_name(data_segment.dbid)) as "库名",
	str(round(total_data_pages / ((1024.0 * 1024) / @@maxpagesize),2),10,2) "总数据空间(MB)",
	str(round(free_data_pages / ((1024.0 * 1024) / @@maxpagesize),2),10,2) "剩余数据空间(MB)",
	str(round(total_log_pages / ((1024.0 * 1024) / @@maxpagesize),2),10,2) "总日志空间(MB)",
	str(round(free_log_pages / ((1024.0 * 1024) / @@maxpagesize),2),10,2) "剩余日志空间(MB)",
	str( round(100.0 * free_data_pages / total_data_pages ,2),10,2) "剩余数据百分比%",
	str( round(100.0 * free_log_pages / total_log_pages,2),10,2) "剩余日志百分比%"
from
(select dbid,
		sum(size) total_log_pages,
		lct_admin('logsegment_freepages', dbid ) free_log_pages
  from master.dbo.sysusages
    where segmap & 4 = 4 
    group by dbid
) log_segment
,
(select dbid,
		sum(size) total_data_pages ,
		sum(curunreservedpgs(dbid, lstart, unreservedpgs)) free_data_pages
  from master.dbo.sysusages
    where segmap <> 4	
    group by dbid 
) data_segment
where data_segment.dbid = log_segment.dbid 
order by str( round(100.0 * free_data_pages / total_data_pages ,2),10,2) asc
end

GO

```

### 五、排查锁信息

过程名称：sp_dba_lock

排查场景：锁是数据库问题排查的一个必要步骤，默认的sp_lock显示的信息不够详细，不能很好判断问题。

SQL代码:

```sql
create procedure sp_dba_lock
AS
--查看锁
--add by dba team   
--2017-07-12
begin
declare @temp_sql varchar(500)
declare @sql varchar(10000)
declare @unionsql varchar(10000)
declare @unionsql2 varchar(10000)
declare @dbname varchar(100)
declare dbname_cursor cursor for select name from master..sysdatabases
set @temp_sql = ' select id as objid,name as objname,db_id(''@dbname'') as dbid from @dbname..sysobjects '
set @sql = ' select lc.spid as spid,pr.spid as "进程ID" , '
             +'  pr.ipaddr as "IP地址", '
             +'  pr.program_name as "应用名称", '
             +'  pr.cmd AS "执行命令", '
             +'  db_name(lc.dbid) as "数据库名", '
             +'  obj.objname as "对象名", '
             +' (case when lc.type = 1 then ''排他表锁'' '
             +'       when lc.type = 2 then ''共享表锁'' ' 
             +'       when lc.type = 3 then ''排他意向锁'' '
             +'       when lc.type = 4 then ''共享意图锁'' '
             +'       when lc.type = 5 then ''排他⻚锁'' '
             +'       when lc.type = 6 then ''共享⻚锁'' '
             +'       when lc.type = 7 then ''更新⻚锁'' '
             +'       when lc.type = 8 then ''排他行锁'' '
             +'       when lc.type = 9 then ''共享行锁'' '
             +'       when lc.type = 10 then ''更新行锁'' '
             +'       when lc.type = 11 then ''共享下一键锁'' '
             +'       when lc.type = 256 then ''锁阻塞另一进程'' '
             +'       when lc.type = 512 then ''请求锁'' '
             +' end) as "锁类型名称", '
             +'  lc.type as "锁类型", '
             +'  pr.blocked as "被阻塞进程ID",'
             +'  bl.program_name as "被阻塞应用名称", '
             +'  bl.ipaddr as "被阻塞IP地址" '
             +' from master..syslocks lc  '
             +'      left join master..sysprocesses pr on lc.spid = pr.spid '
             +'      left join master..sysprocesses bl on bl.spid = pr.blocked '
             +'      left join ( '
open dbname_cursor
	while @@sqlstatus = 0 
	begin
		FETCH  dbname_cursor into @dbname
		set @unionsql = @unionsql +  str_replace(@temp_sql,'@dbname',@dbname)  
		set @unionsql = @unionsql + 'union all'
	end 
	close dbname_cursor	
set @unionsql2 = substring(@unionsql,1,char_length(@unionsql) - 9)	

set @sql = @sql + @unionsql2  + '	) obj on lc.id = obj.objid and lc.dbid = obj.dbid '
set @sql = 'select * from ('+@sql+') t where t.spid !=@@spid'
execute(@sql)
end 




```

### 排查耗费CPU资源的SQL

过程名称:sp_dba_cpu

排查场景：数据库CPU高时，需要排查的一个方面是正在耗费CPU资源的SQL。

SQL代码:

```sql
 use sybsystemprocs
GO

if object_id('sp_dba_cpu') is not null 
	drop procedure sp_dba_cpu
GO

create proc sp_dba_cpu
as
begin
--add by wangzhen  2016-01-18
--v1.0.0
 select top 100 s.SPID,p.ipaddr,p.program_name,s.CpuTime,t.LineNumber,t.SQLText
from
    master..monProcessStatement s,
    master..monProcessSQLText t,
    master..sysprocesses p
where 
    s.SPID=t.SPID
    and s.SPID = p.spid
    and p.spid != @@spid
order by 
     s.CpuTime DESC

end

 

```