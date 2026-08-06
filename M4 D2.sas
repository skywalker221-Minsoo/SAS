%let userid = student;
%let csv_dir = /home/&userid/shop_csv;

libname shop "/home/&userid/shop_db";

proc import
	datafile="&csv_dir/orders_dirty.csv"
	out = shop.orders_dirty
	dbms = csv
	replace;
	getnames = yes;
	guessingrows = max;
run;

/* confirm columns data types */
proc contents data=shop.orders_dirty;
run;

proc print data=shop.orders_dirty(obs=10);
run;
proc sql;
	select count(*) from shop.orders_dirty;
quit;

/* SASHELP 에 있는 cars 정보 확인 */
proc print data=sashelp.cars(obs=10);
run;

proc contents data=sashelp.cars;
run;

proc sql;
	select count(*) from sashelp.cars;
quit;

/* shop.users tax 컬럼 추가해서 tax = total_spent * 0.1 로 저장후
   work.temp 라고 저장
   work.temp -> 채널별로 누적 매출을 출력한 뒤
   shop.user_tax 로 저장 */

data work.temp;
	set shop.users;
	tax = total_spent * 0.1;
run;

proc sql;
	create table shop.user_tax as
		select
			channel, sum(total_spent) format comma12. as 누적매출
		from work.temp
		group by channel;
quit;

proc sort data=work.temp;
	by channel;
run;

proc print data=work.temp(obs=10) noobs;
run;

data shop.user_tax;
	set work.temp;
	retain 누적합계 0;
	if first.channel then 누적합계 = 0;
	누적합계 + total_spent;
run;

proc contents data=shop.user_tax;
run;

proc print data=shop.user_tax(obs=10) noobs;
run;

proc sql;
	select count(*) from shop.user_tax;
run;

proc freq data=shop.user_tax;
	tables channel / nocum;
run;

proc import
	datafile="&csv_dir/users_dirty.csv"
	out = shop.users_dirty
	dbms = csv
	replace;
	getnames = yes;
	guessingrows = max;
run;

proc means data=shop.users_dirty noprint;
	var age;
	class channel;
	output out=ch_stats
		n=cnt mean=age_mean std=age_std;
run;

/* data print */
proc print data=ch_stats noobs;
	where _TYPE_ = 1;
	var channel cnt age_mean age_std;
	format age_mean age_std 8.1;
run;

proc sgplot data=ch_stats;
	where _type_ = 1;
	vbar channel / response=age_mean;
	xaxis label = "가입채널";
	yaxis label = "평균매출";
run;

proc means data=shop.users_dirty noprint;
	var age;
	output out=ch_stats
		n=cnt mean=age_mean std=age_std;
run;

proc means data=shop.users_dirty;
	var age;
	class channel;
	output out=ch_stats
		n=cnt mean=age_mean std=age_std;
run;

proc means data=shop.users_dirty;
	var age;
	class channel gender;
	output out=ch_stats
		n=cnt mean=age_mean std=age_std;
run;

proc print data=work.ch_stats noobs;
	where _type_ = 2;
	var channel cnt age_mean age_std;
	format age_mean age_std 8.1;
run;

/* Session 4 */
proc freq data=shop.users_dirty;
	tables channel;
run;

/* 누적 제외 */
proc freq data=shop.users_dirty;
	tables channel / nocum;
run;

/* 빈도순으로 정렬 */
proc freq data=shop.users_dirty order=freq; /* 빈도 내림차순 */
	table channel / nocum;
run;

proc freq data=shop.users_dirty order=internal; /* 빈도 오름차순 */
	table channel / nocum;
run;

proc freq data=shop.users_dirty order=data; /* 빈도 오름차순 */
	table channel / nocum;
run;

proc freq data=shop.users_dirty; /* 빈도 오름차순 */
	table channel / nocum missing;
run;

/* 막대그래프 작성 */
proc freq data=shop.users_dirty; /* 빈도 오름차순 */
	table channel / nocum plots=freqplot;
run;

/* 2차원 교차표 -> channel * gender */
proc freq data=shop.users_dirty;
	tables channel * gender;
run;

proc freq data=shop.users_dirty;
	tables channel * gender / nocum;
run;

proc freq data=shop.users_dirty;
	tables channel * gender / norow nocol nopercent;
run;

data shop.users_year;
	set shop.users;
	signup_year = year(signup_date);
run;

proc freq data=shop.users_year;
	tables signup_year * channel * gender / norow nocol nopercent;
run;

proc freq data=shop.users_year;
	tables signup_year * channel * gender / fisher;
run;

proc freq data=shop.users_year;
	tables signup_year * channel * gender / chisq expected;
run;

proc freq data=shop.orders;
	tables channel / nocum;
run;

proc freq data=shop.orders;
	tables channel * device / norow nocol;
run;

proc freq data=shop.orders;
	tables channel * device / chisq;
run;

proc freq data=shop.orders noprint;
	tables channel * device / norow nocol nopercent chisq
		out=ch_cross;
run;

/* session 5 : univariate 정규분포 확인 */
proc univariate data=shop.orders normal;
	var total_amount;
	histogram total_amount / normal;
	qqplot total_amount / normal(mu=est sigma=est);
run;

proc sort data=shop.users out=u1;
	by user_id;
run;

proc sort data=shop.users out=u2;
	by descending age;
run;

proc sort data=shop.users out=u3;
	by channel age;
run;

proc sort data=shop.users out=u4;
	by channel descending age;
run;

proc sort data=shop.users out=u5 nodupkey;
	by user_id signup_at;
run;

/* nodupkey 기본 */
proc sort data=shop.users out=u_uniq nodupkey;
	by user_id;
run;
/* 10005 -> 10000 중복 5행 제거 */

/* 2) dupout - 중복 따로 */
proc sort data=shop.users
		out=u_uniq dupout=u_dup nodupkey;
	by user_id;
run;

proc print data=u_dup; run; /* 중복 5행 */

/* 3) noduplicates - 모든 컬럼 동일 */
proc sort data=shop.users
		out=u_dup_all noduplicates;
	by user_id;
run;

/* 4) merge 전 양쪽 정렬 */
proc sort data=shop.users; by user_id; run;
proc sort data=shop.orders; by user_id; run;
data combined; merge shop.users shop.orders; by user_id; run;