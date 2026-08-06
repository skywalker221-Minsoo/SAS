libname shop "/home/student/shop_db";

/* 주문번호, 주문금액, 주문평균, 주문금액이 주문평균보다 큰 주문내역만 */
proc sql outobs=10;
select
	order_id as 주문번호,
	total_amount as 주문금액,
	(select avg(total_amount) from shop.orders) as 주문평균
from shop.orders
/* where total_amount > 주문평균; */
where total_amount > (select avg(total_amount) from shop.orders);
quit;

proc sql outobs=10;
select
	order_id as 주문ID,
	total_amount format comma15. as 금액,
	(select avg(total_amount) from shop.orders) as 평균,
	total_amount - (select avg(total_amount) from shop.orders) as 차이
from shop.orders
where total_amount > (select avg(total_amount) from shop.orders)
order by 차이 desc;
quit;

proc sql outobs=15;
	select
		order_id, vip_grade, total_amount, (select avg(total_amount) from shop.orders
							where u.user_id in (select user_id from shop.users where u.vip_grade = vip_grade))
	from shop.orders o inner join shop.users u on o.user_id = u.user_id
/*	where o.total_amount > (고객 등급의 평균 주문액) */
	where o.total_amount > (select avg(total_amount) from shop.orders o2
							inner join shop.users u2 on o2.user_id = u2.user_id
							where u.vip_grade = u2.vip_grade);
quit;

/* 등급별 정상매출, 취소율을 구함 */
proc sql;
	select vip_grade as 등급별,
		sum(case when status = 'paid' then total_amount else 0 end) as 정상매출,
		sum(case when status = 'cancelled' then 1 else 0 end) / count(*) format percent8.2 as 취소율
	from shop.users u inner join shop.orders o
	on u.user_id = o.user_id
	group by vip_grade
	having 정상매출 > 100000000;
quit;

/* 등급별 지역별 정상매출, 캔슬매출액 */
proc sql;
	select vip_grade as 등급,
			city as 지역,
			sum(case when status = 'paid' then total_amount else 0 end) as 정상매출,
			sum(case when status = 'cancelled' then total_amount else 0 end) as 취소매출
	from shop.orders o inner join shop.users u on o.user_id = u.user_id
	group by city, vip_grade
	having 취소매출 > 0
	order by 취소매출 desc; 
quit;

/* 등급내 누적합 */
/* 1단계 테이블 조언 -> 테이블 생성 */
proc sql;
create table work.joined as
	select o.order_id, u.vip_grade, o.order_date, o.total_amount
	from shop.orders o inner join shop.users u on o.user_id = u.user_id;
quit;

/* 2단계 : work.joined 정렬 */
/* 기존 테이블 변경 후 바로 적용 */
proc sort data=work.joined;
	by vip_grade order_date;
run;

/* 3단계 : 등급내 누적합 -> data + retain */
data work.result;
	set work.joined;
	by vip_grade;
	retain 등급내누적 0;
	if first.vip_grade then 등급내누적 = 0;
	등급내누적 + total_amount;
run;

proc sql outobs=20;
select * from work.result;
quit;

/* 화면에 테이블데이터 출력7*/
proc print data=work.result(obs=20);
	var vip_grade order_date total_amount 등급내누적;
run;

/* 2개의 뷰 생성, vip_grade = 골드인 회원의 회원id total_amount > 50000 필터링*/
proc sql;
	create view vip_vw as
		select user_id from shop.users where vip_grade = 'gold';

	create view big_orders_vw as 
		select * from shop.orders where total_amount > 50000;
quit;

/* view를 활용해서 데이터 검색 */
proc sql outobs=20;
select * from big_orders_vw
where user_id in (select user_id from vip_vw)
order by total_amount desc;
quit;

/* 고객명, 등급, 주문수, 총매출, 평균주문
	1. 등급이 'gold'인 회원만 검색하는 view 생성
	2. 1단게에서 작성한 view와 orders를 조인해서 새로운 view 생성 */
proc sql;
	create view vip_users_vw as
		select user_id, name, vip_grade
		from shop.users
		where vip_grade = 'gold';

	create view vip_orders_vw as
		select vu.user_id, vu.vip_grade, o.total_amount
		from shop.orders o inner join vip_users_vw vu on o.user_id = vu.user_id;
quit;

/* 매출 최상위 5건, 최하위 5건의 주문번호, 주문금액
	1단계 : 정상거래인 주문의 주문번호, 주문금액으로 view 생성
	2단계 : 주문금액으로 정렬 후 5건만 가져옴 */
proc sql;
	create view paid_v as
		select order_id, total_amount
		from shop.orders
		where status = 'paid';
quit;

proc sort data=paid_v out=top_v_sorted;
	by descending total_amount;
run;

proc sort data=paid_v out=paid_v_sorted;
	by total_amount;
run;

data top5;
	set top_v_sorted (obs=5);
run;

data bot5;
	set paid_v_sorted (obs=5);
run;

proc sql;
	select 'Top' as 구분, order_id, total_amount from top5
	union all
	select 'Bot' as 구분, order_id, total_amount from bot5
	order by 1,2 desc;
quit;

proc sql noprint;
	select user_id into :vip_list
	separated by ','
	from shop.users
	where vip_grade = 'gold';
quit;

%let tbl = shop.users;
proc sql outobs=10;
	select user_id, vip_grade
	from &tbl
	where user_id in (&vip_list);
quit;

/* 202601 이후 주문한 내역만 출력 */
%let day = '01JAN26'd;
proc sql outobs=10;
	select * from shop.orders
	where order_date > &day;
quit;

%let year = 2026;
proc sql;
	create table shop.kpi_&year as
	select * from shop.orders
	where order_date > &day;
quit;

/* 고객명, 고객의 매출총합, 마지막주문일자, 주문건수를 출력
	1단계 : users에서 gold 또는 vip회원의 명단만 동적변수에 저장 후
	2단계 : 1단계에서 저장한 고객만 해당 자료 추출 */
proc sql noprint;
	select user_id into: vip_name_list
	seperated by ','
	from shop.users
	where vip_grade in ('gold')
	order by vip_grade;
quit;
%put &vip_name_list;

proc sql outobs=20;
	select
		u.user_id as 유저ID,
		u.name as 고객명,
		u.total_spent as 매출총합,
		(select max(order_date) from shop.orders where user_id = u.user_id group by user_id) format yymmdd8.2 as 마지막주문일자,
		(select count(*) from shop.orders where user_id = u.user_id group by user_id) as 주문건수
	from shop.users u
	where u.user_id in (&vip_name_list)
	order by 마지막주문일자 desc;
quit;

/* library 검색 */
/* 테이블의 정보 */
proc sql;
	select memname, nobs as 행수, crdate as 생성일
	from dictionary.tables;
	where libname = 'SHOP';
quit;

proc sql outobs=10;
	select * from dictionary.tables;
quit;

proc sql;
	select name as 컬럼명, type as 데이터타입, length as 길이
	from dictionary.columns
	where libname = 'SHOP'
	and memname = 'USERS';
quit;

proc sql;
	select * from dictionary.indexes
	where libname = 'SHOP';
quit;

proc sql;
	select * from dictionary.members;
quit;

proc sql;
	select memname as 테이블명, name as 컬럼명, type as 데이터타입
	from dictionary.columns
	where libname = 'SHOP'
	and upcase(name) like '%USER_ID%';
quit;

/* 전체 데이터의 사이즈 */
proc sql;
	select libname, count(*) as 테이블의개수, sum(nobs) as 총행의수
	from dictionary.tables
	group by libname;
quit;

/* 데이터카탈로그 자동 생성 */
proc sql;
	select
		t.memname as 테이블,
		t.nobs as 행수,
		t.crdate format yymmdd10. as 생성일,
		count(c.name) as 컬럼수
	from dictionary.tables as t
	left join dictionary.columns as c
	on t.libname = c.libname
	and t.memname = c.memname
	where t.libname = 'SHOP'
	group by t.memname, t.nobs, t.crdate
	order by t.memname;
quit;

OPTIONS FULLSTIMER MSGLEVEL=I;

proc sql;
	select * from shop.orders
	where user_id = 42;
quit;

proc sql _METHOD;
	select * from shop.orders
	where user_id = 42;
quit;

/* index 생성 -> orders의 user_id 컬럼 */
proc sql;
	create index user_id on shop.orders(user_id);
quit;

proc datasets lib=shop nolist;
	modify users;
	drop index user_id;
quit;

proc sql;
	select * from dictionary.indexes
	where libname = 'SHOP';
quit;

proc sql _METHOD;
	select * from shop.orders
	where user_id = 42;
quit;

/* 인덱스 생성 후 주문 ㅎ상품명, 총주문금액 출력 */
proc sql outobs=20 _method;
	select p.product_name as 상품명,
		sum(oi.line_total) as 주문총액
	from shop.order_items oi inner join shop.products p
	on oi.product_id = p.product_id
	group by p.product_name;
quit;

/* products(product_id) index */
proc sql;
	create index product_id on shop.products(product_id);
quit;

proc sql outobs=20 _method;
	select p.product_name as 상품명,
		sum(oi.line_total) as 주문총액
	from shop.order_items oi inner join shop.products p
	on oi.product_id = p.product_id
	group by p.product_name;
quit;

OPTIONS FULLSTIMER MSGLEVEL = I;

proc sql;
	select * from shop.users
	where user_id = 42;
quit;

proc sql;
	create index user_id on shop.orders(user_id);
quit;

/* orders -> user_id, order_date 복합 인덱스 생성 : idx_user_date
	고객명, 주문일자, 주문총액
	260101 이후 주문한 내용 중 고객id가 42인 고객의 주문만 */
proc sql;
	create index idx_user_date on shop.orders(order_date, user_id);
quit;

proc sql _method;
	select u.name, o.order_date, o.total_amount
	from shop.orders o inner join shop.users u
	on u.user_id = o.user_id
	where order_date >= '01JAN2026'd
	and o.user_id = 42;
quit;

/* SQL로 고객 매출을 집계한 뒤 DATA Step IF-ELSE로 4등급 분류
1. cust_sales 테이블 - user_iod, 주문수, 총매출
2. cust_seg 테이블 - 등급 + 캠페인 컬럼 추가
3. 등급 : VIP(100만 +) / Gold(50만 +) / Silver (10만 +) / Bronze
4. 캠페인 : 등급별 추천 메시지 자동 부여 */
proc sql;
	create table cust_sales as
	select User_id,
			count(*) as 주문수,
			sum(total_amount) as 총매출
	from shop.orders where status='paid'
	group by user_id;
quit;

data cust_seg;
	set cust_sales;
	length 등급 $10 캠페인 $30;
	if 총매출 >= 1000000 then do;
		등급='vip';	캠페인='vip 행사 초대'; end;
	else if 총매출 >= 500000 then do;
		등급='gold'; 캠페인='신상품 우선 안내'; end;
	else if 총매출 >= 100000 then do;
		등급='silver';	캠페인='10% 할인 쿠폰'; end;
	else do;
		등급='bronze';	캠페인='복귀 30% 쿠폰'; end;
run;

proc sql outobs=20;
	select * from cust_seg;
quit;

proc freq data=cust_seg;
	tables 등급;
run;

proc sort data=shop.orders
		out = sorted_orders;
	by user_id order_date;
run;

data first_orders;
	set work.sorted_orders;
	by user_id;
	if first.user_id;
run;

data cum_orders;
	set sorted_orders;
	by user_id;
	retain 누적매출 0;
	if first.user_id then 누적매출 = 0;
	누적매출 + total_amount;
	format 누적매출 dollar15.;
run;

proc sql outobs=20;
	select user_id, order_date, total_amount, 누적매출
	from cum_orders;
quit;


data last_orders;
	set work.sorted_orders;
	by user_id;
	if last.user_id;
run;

proc sql outobs=20;
	select f.user_id as 고객번호,
			f.order_date format yymmdd10. as 첫주문일자,
			f.total_amount format yymmdd12. as 첫주문금액,
			l.order_date format yymmdd10. as 마지막주문일,
			l.total_amount format comma12. as 마지막주문금액
	from first_orders f inner join last_orders l on f.user_id = l.user_id;
quit;

options fullstimer;

/* 디스크 기반 - 순차 처리 */
proc sql;
	select u.vip_grade,
		count(*) as 주문수
	from shop.orders o
	join shop.users u on o.user_id = u.user_id
	where o.status = 'paid'
	group by u.vip_grade
	order by 매출 desc;
quit;

/* cas 환경 */
cas mysession;
caslib _all_ assign;

proc cas;
	builtins.serverStatus;
quit;

/* sas data -> cas memory로 load */
proc casutil;
	load data=shop.orders outcaslib="casuser"
		casout = "orders" replace;
	load data=shop.users outcaslib="casuser"
		casout = "orders" replace;
quit;

/* cas 메모리 기반 - 병렬 처리 */
proc fedsql sessref=mysession;
	select u.vip_grade,
			count(*) as 주문수,
			sum(o.total_amount) as 매출,
			avg(o.total_amount) as 평균
	from casuser.orders o
	inner join casuser.users u
	on u.user_id = o.user_id
	where o.status = 'paid'
	group by u.vip_grade
	order by 매출 desc;
quit;