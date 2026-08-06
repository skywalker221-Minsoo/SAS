libname shop '/home/student/shop_db';

PROC IMPORT DATAFILE="/home/student/shop_csv/order_items.csv"
	 OUT=shop.order_items
	DBMS=csv
	REPLACE;
	GETNAMES=YES;
	GUESSINGROWS=1000;
	DATAROW=2;
RUN;


proc sort data=shop.users out=work.us; by user_id; run;
proc sort data=shop.orders out=work.od; by user_id; run;

data work.merge1n;
	merge work.us (keep=user_id name vip_grade)
		  work.od (keep=user_id order_id total_amount);
	by user_id;
run;

title "[S1] 1:N merge";
proc print data=work.merge1n (obs=10); run;
title;

data work.uo;
	merge work.us work.od;
	by user_id;
	if status='paid';
run;
proc print data=work.uo(obs=15); title "[Exercise 1]"; run;
title;

data work.season;
	merge us (keep=user_id vip_grade)
		  od (keep=user_id total_amount
			 order_date status
			 where=(status='paid'));
	by user_id;

	월 = month(order_date);
run;
proc means data=season;
	var total_amount;
	class 월 vip_grade;
run;

proc means data=season n mean sum;
	var total_amount;
	class 월 vip_grade;
	types 월 vip_grade; /* 월과 등급의 교차 집계 */
	title "월별 / VIP 등급별 매출 통계 요약";
run;

proc tabulate data=work.season;
	class 월 vip_grade;
	var total_amount;
	table 월 all='합계',
		vip_grade * total_amount=''* (N='주문건수');
	title "월별 등급별 매출 현황";
run;


proc sort data=shop.users
			out=us; by user_id; run;
proc sort data=shop.orders
			out=od; by user_id; run;

data work.dormant;
	merge us (in=ua)
		  od (in=ob);
	by user_id;
	if ua and not ob;
	휴면일수 = today() - signup_date;
	if 휴면일수 > 720 then coupon =  '쿠폰_30%';
	else if 휴면일수 > 365 then coupon = '쿠폰_20%';
	else coupon = '쿠폰_10%';
	format signup_date yymmdd10.;
run;

title "[S2] 휴면 고객(orders 없음)";
proc print data=work.dormant(obs=10);
	var user_id name signup_date 휴면일수 coupon;
run;
title;

proc contents data=shop.order_items; run;
proc contents data=shop.products; run;
proc contents data=shop.orders; run;
proc sort data=shop.orders out=od; by order_id; run;
proc sort data=shop.order_items out=oi; by order_id product_id; run;
proc sort data=shop.products out=pd; by product_id; run;

data work.order_detail;
	merge work.od (keep=order_id order_date in=a)
		  work.oi (keep=order_id product_id line_total in=b);
	by order_id;
	if a and b;
run;

proc sort data=work.order_detail; by product_id; run;

data work.report;
	merge order_detail ( in=a)
		  work.pd (in=b);
	by product_id;
	if a;
	월 = month(order_date);
run;

proc means data=work.report sum mean n maxdec=0;
	var line_total;
	class 월 product_name;
	types 월;
run;

proc sort data=shop.order_items out=oi; by product_id; run;
data no_order;
	merge oi (in=a) pd(in=b);
	by product_id;
	if b and not a;
run;
proc print data=no_order; run;

/* session 3 LTV */
proc sort data=shop.orders out=work.odsort; by user_id order_date; run;

data work.first_last;
	set work.odsort;
	by user_id;
	retain 첫주문;
	if first.user_id then do;
		누적매출=0; 주문수=0; 첫주문=order_date;
	end;
	주문수 + 1;
	누적매출 + total_amount;
	if last.user_id; /* 그룹 마지막 행만 출력 */
	마지막주문 = order_date;
	format 누적매출 comma15.;
	format 첫주문 yymmdd10.;
	format 마지막주문 yymmdd10.;
	keep user_id order_id 주문수 누적매출 order_date 첫주문 마지막주문;
run;

/* 월별로 처음 주문한 상품의 주문일자, 상품명, 브랜드명을 검색 */
proc sort data=shop.order_items out=sorted_order_items; by order_id product_id; run;
proc sort data=shop.orders out=sorted_orders; by order_id; run;
data work.order_detail;
	merge sorted_order_items (keep order_id product_id)
		  sorted_orders (keep order_id order_date);
	by product_id;
run;

data order_products;
	merge order_detail shop.products (keep=product_id product_name brand);
	by product_id;
	월 = month(order_date);
run;

proc sort data=order_products; by 월 order_date; run;

data order_out;
	set order_products;
	by 월;
	if first.월;
run;