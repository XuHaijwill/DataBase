# sybase存储过程

## 1.创建存储过程

```sql
create procedure [procedure_name]
as begin
     SQL_statements [return]
end
```

在存储过程中可以包含SQL语句，但是不能包含：use, create view, create rule, create default, create proc, create trigger

## 2.执行存储过程

```sql
exec [procedure_name] [参数]
```

## 3.查看自建的存储过程

```sql
select name from sysobjects where type="P"
go
```

## 4.查看创建的存储过程源代码

```sql
sp_helptext [procedure_name]
```

## 5.创建带参数的存储过程 例：

```sql
create proc sp_show_stu1 (@sno char(7)) as 
begin 
    select * from STUDENT where SNO = @sno return
end
go
```

```sql
exec sp_show_stu1 @sno='9302303'
go
drop proc sp_show_stu
go
```

## 5.1带有返回参数的存储过程

```sql
if exists ( select 1 from sysobjects where name = 'test_proc' )
drop proc test_proc
go
 
if exists ( select 1 from sysobjects where name = 't123')
drop table t123
go

create table t123(
    id int primary key not null, 
    col2 varchar(32) not null
)

insert into t123 values(1, 'iihero')
insert into t123 values(2, 'Sybase')
insert into t123 values(3, 'ASE')
go

-- create procdure
create proc test_proc (@id_min int, @num_t123 int output) with recompile
as
select @num_t123 = count( a.id ) from t123 a where a.id > = @id_min   //计算id大于等于参数@id_min的id数量存入参数@num_123中返回
go 

```

调用：
```sql
1> declare @num_t123 int
2> exec test_proc 1, @num_t123 output
3> go
(return status = 0)

Return parameters:

             
 ----------- 
           3 
(1 row affected)
```

```sql
use pubs2
go

create proc proc_num_sales (@book_id char(6) = null/* 输入参数 */,
@tot_sales int output/* 输出参数 */)
as
begin
/* 过程将返回对于给定书号的书的总销售量 */
 select @tot_sales = sum(qty) 
  from salesdetail 
  where title_id = @book_id 
 return 
end
go
```

调用：

```sql
1> declare @tot_sales int 
2> exec proc_num_sales 'TC7777', @tot_sales output
3> go
```

## 6 存储过程返回状态值

```sql
create proc procedure_name ( …… ) 
as begin 
    SQL_statements 
    return [ integer ] 
```

> endinteger为一整数。如果不指定，系统将自动返回一个 整数值。系统使用0表示该过程执行成功；-1至¨C14 表示该 过程执行有错，-15至 -99为系统保留值。用户一般使用大于 0的整数，或小于 -100的负整数。

## 7.局部变量,全局变量

> 局部变量由用户定义 初值为null

```
DECLARE @var_name data_type [, @var_name data_type] …… 举例 declare @msg varchar(40) declare @myqty int, @myid char(4)
使用SELECT语句将指定值赋给局部变量。 
语法 select @var = expression [,@var = expression ] [from… [where…]… 举例 declare @var1 int select @var1=99
/*　　
在一个赋值给局部变量的select 语句中， 可以使用常数、 从表中取值、或使用表达式给局部变量赋值。 　　
不能使用同一SELECT 语句既给局部变量赋值，又检索 数据返回给客户。 — 一个赋值给局部变量的SELECT 语句，不向用户显示任 何值。
*/
```

> 局部变量必须先用DECLARE定义，再用SELECT语句赋值后才能使用。 局部变量只能使用在T－SQL语句中使用常量的地方。 
> 局部变量不能使用在表名、列名、其它数据库对象名、保留字使用的地方。 局部变量是标量，它们拥有一个确切的值。 
> 赋值给局部变量的SELECT语句应该返回单个值。如果赋值的SELECT语句没有返 回值，则该局部变量的值保持不变；如果赋值的SELECT语句返回多个值，则该局 部变量取最后一个返回的值。

## 8.全局变量

> 全局变量由sql server系统提供并赋值，用户不能创建或赋值，由@@开头

> 可使用系统存储过程sp_monitor显示当前全局变量的值。

> 常用全局变量

> @@error :由最近一个语句产生的错误号

> @@rowcount : 被最近一个语句影响的行数

> @@version : sql server版本号

> @@max_connections :　允许最大用户连接量

> ＠＠Servername ： 该sql_server的名字

例:

```sql
select @@version declare @book_price money select @book_price = price from titles where title_id = 'BU1032' 
                                                                                  if @@rowcount = 0 print 'no such title_id' else begin print 'title_id exists with' select 'price of' = @book_price end

```

## 9. 存储过程流程控制

```sql
IF ELSE:<br>部分语法(ASE)
 if boolean_expression statement [else [if boolean_expression1] statement1 ]
部分语法(IQ)
 if boolean_expression then statement [else [if boolean_expression1] statement1 ] End if

     
IF EXISTS 和 IF NOT EXISTS
语法(ASE) 
if [not] exists (select statement) statement block
 
 举例(ASE) 举例 /* 是否存在姓“Smith”的作者 */
declare @lname varchar(40)
select @lname = 'Smith' if exists ( select * from authors where au_lname = @lname)
select 'here is a ' + @lname else select 'here is no author called'+@lname
```

```
BEGIN ... END
功能 
当需要将一个以上的SQL 语句作为一组语句对待时，可以使用BEGIN和END将它们括起来形成一个SQL语句块。
从语法上看，一个SQL 语句块相当于一个SQL 语句。在流控制语言中，允许用一个SQL语句块替代单个SQL语句出现的地 方。
语法 BEGIN statement block END
statement block 为一个以上的sql语句
```

```
WHILE
语法(ASE) 语法 
while boolean exprission statement block 
语法(IQ) 语法 
while boolean exprission loop statement block end loop

例：
while (select avg(price) from titles) < $40 
begin 
select title_id, price from titles where price > $20 update titles set price = price + $2 
end 
select title_id, price from titles 
print "Too much for the market to bear"
```

## 10.嵌套事务

```
嵌套事务 是指在存储过程中的事务的间接嵌套， 即嵌套事务的形成是因为调用 含有事务的过程。@@trancount 记录了事务嵌套级次。@@trancount在第一个 begin tran语句后值为1，
以后每遇到一个 begin tran 语句，不论是否在嵌套 过程中，@@trancount的值增加1；每遇到 一个commit，@@trancount的值就减少 1。
若@@trancount的 值 等于 零，表示当前没有事务；若@@trancount的值不等 于零，其值 假定为i，表明当前处于第 i 级嵌套事务中。
对于嵌套事务，直 到 使用@@trancount 的值为零的那个 commit语句被执行,整个 事务才被提交。 select @@trancount
```

## 11.存储过程中的游标

```
语法 
create proc procedure_name as SQL_statements containing cursor processing 
其中：SQL_statements containing cursor processing 
是指包含游标处理的SQL语句。
```

举例：

```sql
CREATE proc proc_fetch_book 
As BEGIN 
    DECLARE @book_title char(30), @book_id char(6) 
    DECLARE biz_book CURSOR for SECLET title, title_id from titles WHERE type = "business" OPEN biz_book FETCH biz_book INTO @book_title, @book_id …… -- 在这里做某些处理 
CLOSE biz_book DEALLOCATE CURSOR biz_book 
RETURN 
END
```

## 12.带参数的函数

```sql
create function func_test(@id_min int)
returns int
as
begin
    declare @num_t123 int
    select @num_t123 = count( a.id ) from t123 a where a.id > = @id_min
    return @num_t123
end
go
```

```sql
1> select dbo.func_test(1)
2> go
             
 ----------- 
           5
```

> 12.@@error 语句执行成功时 @@error值为0；
> select  @@error
> --------------------
> 0
