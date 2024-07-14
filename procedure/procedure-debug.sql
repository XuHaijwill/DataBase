--如何在Sybase ASE中调试存储过程？
--set noexec on
set noexec on

--使用set statistics命令查看存储过程的执行统计信息。
set statistics io on
set statistics time on
--使用dbcc traceon命令启用跟踪标志。
dbcc traceon (3204)

exec sp_dba_largetable

--使用set statistics命令关闭存储过程的执行统计信息。
set statistics io off
set statistics time off

--使用dbcc traceoff命令关闭跟踪标志。
dbcc traceoff (3204)
--使用set noexec命令在存储过程执行后恢复执行。
set noexec off

-- 使用sp_helptext命令查看存储过程的源代码。
sp_helptext 'sp_dba_largetable'

-- 使用print语句在存储过程中添加调试信息。
print '调试信息'