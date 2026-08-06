libname shop "/home/student/shop_csv";

/* users.csv to users.sasdat 로 변환 */
PROC IMPORT DATAFILE="/home/student/shop_csv/users.csv"
	 OUT=shop.users
	DBMS=csv
	REPLACE;
	GETNAMES=YES;
	GUESSINGROWS=1000;
	DATAROW=2;
RUN;

PROC IMPORT DATAFILE="/home/student/shop_csv/products.csv"
	 OUT=shop.products
	DBMS=csv
	REPLACE;
	GETNAMES=YES;
	GUESSINGROWS=1000;
	DATAROW=2;
RUN;

/* orders.csv to users.sasdat 로 변환 */
PROC IMPORT DATAFILE="/home/student/shop_csv/orders.csv"
	 OUT=shop.orders
	DBMS=csv
	REPLACE;
	GETNAMES=YES;
	GUESSINGROWS=1000;
	DATAROW=2;
RUN;

/* 사용자의 이름, 아이디, 나이 지역 출력 */
proc sql outobs=10;
	select user_id, name, age, city
	from shop.users;
quit;

/* DATA steop seoul인 고객만 추출 */
DATA work.seoul_users;
	SET shop.users;
	KEEP user_id name city;
	WHERE city = '서울';
run;

proc sql outobs=10;
	select * from work.seoul_users;
quit;

PROC SQL;
	select *
	from shop.users
	where city='서울'
	and age between 30 and 39;
quit;


proc sql outobs=20;
	select user_id, name, age, city, vip_grade
	from shop.users
	where city='서울';
	select *
	from shop.users
	where city='서울'
	and age between 30 and 39;
quit;

proc sql outobs=10;
	select name as 고객명,
		   age as 나이,
		   age*12 as 개월수,
		   cat(city, ' ', vip_grade) as 지역등급,
		   vip_grade as 등급
	from shop.users;
quit;

proc sql outobs=10;
	select product_id as 상품ID, product_name as 상품, price as 가, rating_avg as 별점
	from shop.products;
quit;

proc sql outobs=10;
	select upcase(payment_method) as 결제수단,
			round(total_amount, 100) as 금액반올림 format=comma12.,
			substr(channel, 1, 3) as 채널약어,
			total_amount format=comma12. as 금액
	from shop.orders;
quit;

proc sql;
	select count(*) as 주문수 format=comma12.,
			sum(total_amount) as gmv format=comma15.,
			avg(total_amount) as aov format comma12.,
			calculated gmv / calculated 주문수 as 재계산aov format=comma12.
	from shop.orders;
quit;

proc sql outobs=10;
	select name, age, city
	from shop.users
	where name like '김%'
	and city in ('서울', '부산', '대구');
quit;

proc sql outobs=20;
	select name, age, city
	from shop.users
	where city in ('서울', '부산', '대구');
quit;

proc sql outobs=10;
	select name, age, city
	from shop.users
	where name like '김%'
	and city in ('서울', '부산', '대구');
quit;

proc sql outobs=10;
	select order_id, user_id, total_amount format comma12.0, status, channel, order_date format=YYMMDDS10.
	from shop.orders
	where status='paid'
	and total_amount >= 1000000
	and channel in ('organic', 'direct')
order by order_date desc;
quit;

proc sql;
	select name, channel
	from shop.users
	where channel is null;
quit;

proc sql; select count(channel) from shop.users; quit;

/* count(*), count(user_id), count(distinct user_id) orders */
proc sql;
	select count(*) as 총주문수,
			count(user_id) as 회원주문수,
			count(distinct user_id) as 활성고객수
	from shop.orders;
quit;

/* 도시종류를 구하는데 count(*), count(city), count(distinct city) */
proc sql;
	select count(*) as 도시수, count(city) as 도시수2, count(distinct city) as 고유도시수
	from shop.users;
quit;

proc sql;
	select distinct channel as 채널종류
	from shop.users;
	select distinct channel as 채널종류
	from shop.orders;
quit;

/* 전체주문수, 고객수, 인당 주문수(전체 주문수 . 고객수) */
proc sql;
	select
		count(order_id) as 전체주문수,
		count(distinct user_id) as 고객수,
		calculated 전체주문수 / calculated 고객수 as 인당주문수,
		count(order_id) / count(distinct user_id) as 테스트
	from shop.orders;
quit;

proc sql;
	select
		sum(order_count) as 총주문수,
		count(distinct user_id) as 고객수,
		calculated 총주문수 / calculated 고객수 as 인당주문수
	from shop.users;
quit;

/* orders에서 총주문금액, 주문고객수, 인당주문금액, 정상거래만 */
proc sql;
	select
		sum(total_amount) format comma15. as 총주문금액,
		count(distinct user_id) format comma10. as 주문고객수,
		calculated 총주문금액 / calculated 주문고객수 format comma10. as 인당주문금액
	from shop.orders
	where status='paid';
quit;

/* 연령이 60이상이면 '시니어', 아니면 '청년' 출력, 이름, 나이, 연령대 */
proc sql outobs=20;
	select
		name as 이름,
		age as 나이,
		case
			when age >= 60 then '시니어'
			else '청년'
		end as 연령대
	from shop.users;
quit;

proc sql outobs=30;
	select
		name as 이름,
		age as 나이,
		case
			when age >= 60 then '시니어'
			when age >= 50 then '50대'
			when age >= 40 then '40대'
			when age >= 30 then '30대'
			when age >= 20 then '20대'
			when age >= 10 then '10대'		
		end as 연령대
	from shop.users;
quit;

proc sql outobs=30;
	select
		name as 이름,
		age as 나이,
		total_spent format comma10. as 총주문금액,
		case
			when age >= 60 then '시니어'
			when age >= 40 then '중장년'
			when age >= 20 then '청년'
			else '미청년'
		end as 연령대,
		case
			when total_spent >= 1000000 then 'VIP'
			when total_spent >= 100000 then '우수'
			else '일반'
		end as 고객등급
	from shop.users;
quit;

libname shop "/home/student/shop_db";

proc sql outobs=10;
	select name, channel,
		case channel
			when 'paid_search' then '검색 광고'
			when 'social' then '소셜'
			when 'organic' then '오가닉'
			when 'referral' then '추천'
			else '기타'
		end as 채널_한글
	from shop.users;
quit;

proc sql outobs=10;
	select name, vip_grade,
		case			
			when vip_grade is null then '미입력'
			when vip_grade = 'vip' then 'vip'
			else '일반'
		end as 분류
	from shop.users;
quit;

proc sql outobs=20;
	select
		case
			when age < 30 then '20대'
			when age < 40 then '30대'
			when age < 50 then '40대'
			else '50대+'
		end as 연령대,
		count(user_id) as 회원수
	from shop.users
	group by 연령대;
quit;

proc sql outobs=10;
	select user_id, name, age, city, vip_grade, total_spent
	from shop.users
	where city='서울'
	and age between 30 and 50
	and vip_grade='gold'
	order by total_spent desc;
quit;

proc sql outobs=10;
	select
		user_id, name, age,
		case
			when age < 20 then '10대'
			when age < 30 then '20대'
			when age < 40 then '30대'
			when age < 50 then '40대'
			else '50대+'
		end as 연령대
	from shop.users;
quit;

proc sql;
	select channel, count(*) as 회원수,
		count(distinct vip_grade) as 등급수,
		avg(total_spent) as 평균매출 format COMMA15.
	from shop.users
	where channel is not null
	group by channel
	order by 회원수 desc;
quit;

proc sql;
	select count(*) as 주문건수,
			sum(total_amount) format=comma15. as 총매출,
			avg(total_amount) format=comma15. as 객단가,
			min(total_amount) as 최소,
			max(total_amount) as 최대
	from shop.orders;
quit;

/* 채널별 총주문서, 매출총액, 객단가 */
proc sql;
	select channel as 채널,
			count(order_id) as 총주문수,
			sum(total_amount) as 매출총액,
			mean(total_amount) as 객단가
	from shop.orders
	where status='paid'
	group by channel;
quit;

/* 채널별 device별 총주문서, 매출총액, 객단가 */
proc sql;
	select channel as 채널,
			device as 디바이스,
			count(order_id) as 총주문수,
			sum(total_amount) format comma15. as 매출총액,
			mean(total_amount) format comma12. as 객단가
	from shop.orders
	where status='paid'
	group by channel, device
	order by channel, device, 매출총액 desc;
quit;

proc sql;
	select u.vip_grade as 등급, o.channel as 채널,
			count(*)as 주문수, sum(o.total_amount) as 매출,
			avg(o.total_amount) as 객단가
	from shop.orders o
	join shop.users u
	on u.user_id = o.user_id
	group by 등급, 채널;
quit;

/* 고객의 가입 채널명 매출총액 단, 매출총액이 500만원 이상인 채널만, 매출총액이 많은 채널 순으로 출력 */
proc sql;
	select
		u.channel as 채널명,
		sum(o.total_amount) format comma15. as 매출총액
	from shop.users u
	join shop.orders o
	on u.user_id=o.user_id
	group by 채널명
	having 매출총액 >= 10000000000
	order by 매출총액 desc;
quit;

/* 고객별 누적매출, 주문수를 출력. 단, 누적매출이 500만원 이상인 고객만 전체 이터 중 20건만 출력 */
proc sql outobs=20;
	select
		user_id as 유저ID,
		sum(total_amount) format comma10. as 누적매출,
		count(order_id) as 주문수
	from shop.orders
	where status='paid'
	group by user_id
	having 누적매출 >= 5000000
	order by 누적매출 desc;
quit;

/* 연도별 주문수, 주문총액, 정상주문 */
proc sql;
	select
		YEAR(order_date) as 연도,
		count(*) as 주문수,
		sum(total_amount) format comma15.0 as 주문총액
	from shop.orders
	where status = 'paid'
	group by 연도
	order by 주문총액 desc;
quit;

proc sql;
	select
		YEAR(order_date) as 연도,
		MONTH(order_date) as 월,
		count(*) as 주문수,
		sum(total_amount) format comma15.0 as 주문총액
	from shop.orders
	where status = 'paid'
	group by 연도, 월
	order by 연도, 월;
quit;

/* 날짜함수 year(), day(), qtr() 분기,
	intnx('MONTH', order_date, 0, 'B')
	-> 0:금월, 1:다음월, 'B':달의 첫날, 'E': 마지막 */
/* 고객명, 마지막 접속한 열/월/일/분기/접속한 달의 1일 출력 */
proc sql outobs=20;
	select
		name as 이름,
		year(last_login_date) as 연도,
		month(last_login_date) as 월,
		day(last_login_date) as 일,
		qtr(last_login_date) as 분기,
		intnx('MONTH', last_login_date, 0, 'b') format yymmdd10. as 마지막접속월,
		intnx('MONTH', last_login_date, 1, 'e') format yymmdd10. as 마지막접속다음월
	from shop.users
	where last_login_date is not null
	order by 연도, 월, 일;
quit;


/* 월별 KPI 영구 저장 */
proc sql;
	create table shop.monthly_kpi as
	select intnx('month', order_date, 0, 'b') format yymmdd7. as 월,
			count(*) as 주문수, sum(total_amount) as 총매출액
	from shop.orders
	where 월 < 260701
	group by 월
	order by 월;
quit;

proc sql outobs=10;
	select * from shop.monthly_kpi;
quit;

/* view로 보 */
proc sql;
	create view shop.vw_monthly_kpi as
	select intnx('month', order_date, 0, 'b') format yymmdd7. as 월,
			count(*) as 주문수, sum(total_amount) as 총매출액
	from shop.orders
	group by 월
	order by 월;
quit;

proc sql outobs=10;
	select * from shop.vw_monthly_kpi;
quit;

proc sql outobs=1;
	select year(order_date), month(order_date)
	from shop.orders;
quit;

proc sql;
	create table shop.monthly_kpi_1 as
	select year(order_date)* 100 + month(order_date) as 년월,
	count(*) as 주문수 format comma10.,
	sum(total_amount) as GMV format comma15.,
	avg(total_amount) as AOV format comma12.,
	count(distinct user_id) as MAU format comma10.
	from shop.orders
	group by 년월
	order by 년월;
quit;

proc sql outobs=10;
	select * from shop.monthly_kpi_1;
quit;

proc sql;
	create view shop.vw_channel_monthly_1 as
	select channel as 채널,
	year(order_date) * 100 + month(order_date) as 년월,
	count(*) format comma10. as 주문수,
	sum(total_amount) format comma15. as 매출
	from shop.orders
	where order_date >= '01JAN2025'd
	group by channel, 년월;
quit;

proc sql outobs=20;
	select * from shop.vw_channel_monthly_1;
quit;

proc sql;
	select u.vip_grade as 고객등급, o.channel as 주문채널,
	count(o.order_id) as 총주문수, sum(o.total_amount) as 총매출액
	from shop.users as u, shop.orders as o
	where u.user_id = o.user_id
	and o.status = 'paid'
	group by u.vip_grade, o.channel;
quit;

proc sql;
	select u.vip_grade as 고객등급, o.channel as 주문채널,
	count(o.order_id) as 총주문수, sum(o.total_amount) as 총매출액
	from shop.users as u inner join  shop.orders as o
	on u.user_id = o.user_id
	and o.status = 'paid'
	group by u.vip_grade, o.channel;
quit;

/* 고객명, 주문일자, 상품id, 주문금액을 출력 : 정상 거래만,
	users, orders, order_items join
1. order_items.csv -> sas database로 shop_db에 저장
2. 컬럼 정보 확인
3. 쿼리 문장 작성 */

PROC IMPORT DATAFILE="/home/student/shop_csv/order_items.csv"
	 OUT=shop.order_items
	DBMS=csv
	REPLACE;
	GETNAMES=YES;
	GUESSINGROWS=1000;
	DATAROW=2;
RUN;

proc sql outobs=20;
	select * from shop.order_items;
quit;

proc sql;
	select count(*) from shop.order_items;
quit;


proc sql outobs=20;
	select
		u.name as 고객명,
		o.order_date format yymmdd10. as 주문일자,
		i.product_id as 상품id,
		i.line_total as 주문금액
	from shop.orders o
	inner join shop.users u
	on o.user_id = u.user_id
	inner join shop.order_items i
	on o.order_id = i.order_id
	where o.status = 'paid';
quit;

PROC IMPORT DATAFILE="/home/student/shop_csv/products.csv"
	 OUT=shop.products
	DBMS=csv
	REPLACE;
	GETNAMES=YES;
	GUESSINGROWS=1000;
	DATAROW=2;
RUN;

proc sql outobs=20;
	select
		u.name as 고객명,
		o.order_date format yymmdd10. as 주문일자,
		p.product_name as 상품명,
		i.line_total as 주문금액
	from shop.orders o
	inner join shop.users u
	on o.user_id = u.user_id
	inner join shop.order_items i
	on o.order_id = i.order_id
	inner join shop.products p
	on i.product_id = p.product_id
	where o.status = 'paid';
quit;

proc sql outobs=20;
	select
		p.product_name as 상품명,
		count(o.order_id) as 누적주문건수,
		sum(oi.line_total) format comma15. as 누적주문금액
	from shop.orders o
	inner join shop.order_items oi
	on o.order_id = oi.order_id
	inner join shop.products p
	on oi.product_id = p.product_id
	where o.status = 'paid'
	group by 상품명;
quit;

/* 채널별 상품명별 누적 주문금액 */
proc sql outobs=20;
	select
		p.product_name as 상품명,
		o.channel as 채널,
		sum(oi.line_total) format comma15. as 누적주문금액
	from shop.orders o
	inner join shop.order_items oi
	on o.order_id = oi.order_id
	inner join shop.products p
	on oi.product_id = p.product_id
	where o.status = 'paid'
	group by 상품명, 채널;
quit;

/* 비활성 고객 명단 추출, 이름, 가입일자 출력 */
proc sql outobs=20;
	select u.name as 이름, u.signup_date format yymmdd10. as 가입일자
	from shop.users u
	left join shop.orders o
	on u.user_id = o.user_id
	where o.user_id is null
	order by 2;
quit;

/* 1. 사웊ㅁ명, 누적주문금액, 주문이 없는 상품도 출력 20건만
	2. 주문이 전혀 없는 상품명 출력 */
proc sql outobs=20;
	select p.product_name as 상품명, sum(oi.line_total) as 누적주문금액
	from shop.products p
	left join shop.order_items oi
	on p.product_id = oi.product_id
	left join shop.orders o
	on o.order_id = oi.order_id
	group by 상품명;
quit;

proc sql outobs=20;
	select p.product_name as 상품명
	from shop.products p
	left join shop.order_items oi
	on p.product_id = oi.product_id
	where oi.order_id is null;
quit;

/* 실습1 */
proc sql;
	select
		u.vip_grade as 등급,
		year(o.order_date) * 100 + month(o.order_date) as 년월,
		count(o.order_id) as 주문수
	from shop.users u
	inner join shop.orders o
	on u.user_id = o.user_id
	where year(o.order_date) * 100 + month(o.order_date) >= 202501
	and u.vip_grade is not null
	group by 등급, 년월
	order by 등급, 년월;
quit;

/* 실습2 */
proc sql outobs=20;
	select
		u.user_id as 회원ID,
		u.name as 이름,
		u.city as 도시,
		u.signup_date format yymmdd10. as 가입일
	from shop.users u
	left join shop.orders o
	on u.user_id = o.user_id
	where qtr(u.signup_date) = 1
	and year(u.signup_date) = 2025
	and o.order_id is null
	group by 회원ID
	order by u.signup_date;
quit;

/* 실습3 */
proc sql outobs=10;
	create table shop.top_products as
		select
			p.product_name as 상품,
			p.brand as 브랜드,
			sum(oi.quantity) format comma10. as 수량,
			sum(o.total_amount) format comma15. as 매출
		from shop.products p
		left join shop.order_items oi
		on p.product_id = oi.product_id
		left join shop.orders o
		on oi.order_id = o.order_id
		where o.status = 'paid'
		group by 상품, 브랜드
		order by 수량 desc;
quit;

/* 실습4 */
proc sql;
	select
		o.channel as 채널,
		year(o.order_date) * 100 + month(o.order_date) as 년월,
		count(o.order_id) as 주문수,
		avg(o.total_amount) format comma10. as AOV,
		sum(o.total_amount) format comma15. as 매출
	from shop.orders o
	where year(o.order_date) * 100 + month(o.order_date) >= 202501
	group by 채널, 년월;
quit;

/* 실습5 */
proc sql;
	create view shop.vw_city_vip as
		select
			u.city as 도시,
			count(u.user_id) as 총회원,
			sum(case when u.vip_grade = 'vip' then 1 else 0 end) as VIP수,
			calculated VIP수 / calculated 총회원 format percent8.2 as VIP비율
		from shop.users u
		group by 도시;
quit;

proc sql;
select
			u.city as 도시,
			count(u.user_id) as 총회원,
			sum(case when u.vip_grade = 'vip' then 1 else 0 end) as VIP수,
			calculated VIP수 / calculated 총회원 format percent8.2 as VIP비율
		from shop.users u
		group by 도시;
quit;

