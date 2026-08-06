libname shop "/home/student/shop_csv";

PROC IMPORT DATAFILE="/home/student/shop_csv/users.csv"
	 OUT=shop.users
	DBMS=csv
	REPLACE;
	GETNAMES=YES;
	GUESSINGROWS=1000;
	DATAROW=2;
RUN;

%macro vip_report(grade=);
	proc print data = shop.users(obs=10);
	where vip_grade = "&grade"; var user_id name total_spent vip_grade;
run;
%mend;
%vip_report(grade=gold);
%vip_report(grade=silver);

/* 1. channel별 kpi -> 주문건수, 주문총금액 -> 정상거래만, channel을 값을 받아서 실행 */
%macro ch_kpi(ch=);
	title "%ch 채널 KPI";
	proc sql;
		select "&ch" as channel length=15,
			count(*) as 주문건수,
			sum(total_amount) as 주문총금액 format comma15.
		from shop.orders
		where status = 'paid'
		and channel = "&ch";
	quit;
	title;
%mend;

/* 호출 -> channel : organic, email */
%ch_kpi(ch=organic);
%ch_kpi(ch=email);

/* 다중 매개변수 + 기본값 */
/* 채널, 나이 하한-상한 -> top N 출력 */
%macro ch_age_kpi(ch=organic, lo=20, hi=60, top=10);
	title "&CH (&lo ~ &hi) Top &top";
	proc sql outobs=&top;
		select u.user_id, u.name, u.age, o.total_amount
		from shop.users u inner join shop.orders o on u.user_id = o.user_id
		where u.age between &lo and &hi
		and o.channel = "&ch"
		and o.status = 'paid'
		order by o.total_amount desc;
	quit;
	title;
%mend;

options mprint mlogic symbolgen;
%ch_age_kpi();

/* 디버깅 종료 */
options nomprint nomlogic nosymbolgen;
%ch_age_kpi(ch=social, lo=20, hi=29, top=20);

/* VIp 등급별 매크로 - KPI 집계 -> vip_kpi(grade=)
	grade, 건수, 평균주문액(total_spent), 평균주문건수(order_count)
	format 8.1*/
%macro vip_kpi(grade=gold);
	title "&grade 등급 통계";	
	proc sql;
		select vip_grade as 등급,
			count(*) as 건수,
			avg(total_spent) format 8.1 as 평균주문액,
			avg(order_count) format 8.1 as 평균주문건수
		from shop.users
		where vip_grade = "&grade"
		group by vip_grade;
	quit;
	title;
%mend;

%vip_kpi();

/* session 3 : %do %if */
%macro yearly_pdf(year=);
	%do m = 1 %to 12;
		%let m2 = %sysfunc(
			putn(&m, z2.));
		%let ym = &year.&m2;
		ods pdf file = "&ym._매출.pdf";
		proc print data=shop.orders;
			where put(order_date, yymmn6.)
				= "&ym";
		run;
		ods pdf close;
	%end;
%mend;
%yearly_pdf(year=2024)

/* %do ~ %end practice */
%let channels = organic paid_search social referral email;

%macro ch_kpi(ch=);
	title "&ch 채널 KPI";
	proc sql;
		select "&ch" as channel length=15,
			count(*) as 주문건수,
			sum(total_amount) as 주문총금액 format comma15.
		from shop.orders
		where status = 'paid'
		and channel = "&ch";
	quit;
	title;
%mend;

proc sql;
	select distinct channel into :channels separated by ' '
	from shop.users;
quit;
%put channels : &channels;

%macro loop_channels;
	%do i = 1 %to 6;
		%let ch = %scan(&channels, &i);
		%put [&i] &ch;
		%ch_kpi(ch=&ch);
	%end;
%mend loop_channels;

%loop_channels;

%macro smart_kpi(ch=);
	%if &ch = paid_search OR &ch = email %then %do;
		title "[광고] &ch - ROI analyse";
		proc sql;
			select sum(total_amount) as sales format=comma15.
			from shop.orders
			where channel = '&ch' and status = 'paid';
		quit;
		title;
	%end;
	%else %do;
		title "[자연] &ch - 일반 KPI";
		proc freq data=shop.users;
			where channel="&ch";
			tables vip_grade / nocum;
		run;
		title;
	%end;
%mend smart_kpi;

%smart_kpi(ch=organic);
%smart_kpi(ch=paid_search);

options noquotelenmax;

/* S3.3 %Do %WHILE / %DO %UNTIL */
%macro countdown;
	%let n = 5;
	%do %while (&n > 0);
		%put 카운트 &n;
		%let n =%eval(&n-1);
	%end;
	%put 발사!;
%mend countdown;
%countdown;

proc sql noprint;
	select user_id into :vip_list separated by ","
	from shop.users
	where vip_grade = 'gold';
quit;
%put vip 수 : &sqlobs;



/* 4.2 */
proc sql;
	select distinct channel
	into :ch_list separated by ' '
	from shop.users;

	select count(distinct channel) into :n_ch
	from shop.users;
quit;

%put ch_list = &ch_list (&n_ch 개);

/* 4.3 */
proc sql noprint;
	select vip_grade, count(*) format comma10.
	into :vip1-:vip5, :cnt1-:cnt5
	from shop.users
	where vip_grade is not null
	group by vip_grade;
quit;

%put vip1=&vip1 cnt1=&cnt1;
%put vip2=&vip2 cnt2=&cnt2;

/* perfectly automatic */
proc sql noprint;
	select distinct channel into :ch_list separated by " "
	from shop.users;
quit;

%put ch_list -> &ch_list, ch_List 갯수 -> %sysfunc(countw(&ch_list)); /* channel list */
%macro auto_all_channels;
	%local n_ch i ch;
	%let n_ch = %sysfunc(countw(&ch_list));
	
	/* n_ch iteration */
	%do i = 1 %to &n_ch;
		%let ch = %scan(&ch_list, &i);
		%put [동적 [&i / &n_ch]] &ch;
		%ch_kpi(ch=&ch);
	%end;
%mend;

%auto_all_channels;

/* vip_list [산춣물] &vip_list + 동적 분석 결과 */
proc sql noprint;
	select user_id into :vip_list separated by ' '
	from shop.users
	where vip_grade = 'gold';
quit;

%put &vip_list;
%put vip 수 : &sqlobs;

title "[미니실습 4] vip 고객주문 내역 (동적 IN 절)";
proc sql outobs=10;
	select * from shop.orders
	where user_id in (&vip_list);
quit;
title;

ods pdf file="/path/report.pdf"
			style=journal;

proc print;
run;
ods pdf close;

%put id : &sysuserid;
%let userid = &sysuserid;
%let root = /home/&userid;
%let report_dir = &root/reports; 
%macro grade_excel;
	ods excel file=
		"&report_dir/등급별.xlsx";
	%do i = 1 %to 5;
		%let g = %scan(
			vip platinum gold silver bronze, &i);
		ods excel options (
			sheet_name="&g"
			autofilter="all");
		proc print data=shop.users;
			where vip_grade="&G";
		run;
	%end;
	ods excel close;
%mend;
%grade_excel;

PROC IMPORT DATAFILE="/home/student/shop_csv/users.csv"
	 OUT=shop.users
	DBMS=csv
	REPLACE;
	GETNAMES=YES;
	GUESSINGROWS=1000;
	DATAROW=2;
RUN;

/* Excercises */
%let root = /home/student/reports;
%let yyyymm = 202601;
%let cutoff = 100000;
ods pdf file = "&root/&yyyymm._매출.pdf";
proc print data=shop.orders;
	where put(order_date, yymmn6.) = "&yyyymm"
	and total_amount >= &cutoff;
run;
ods pdf close;


%macro import_csv(name=);
	%let csv_dir = /home/student/shop_csv;
	PROC IMPORT DATAFILE="&csv_dir/&name..csv"
		 OUT=shop.&name
		DBMS=csv
		REPLACE;
		GETNAMES=YES;
		GUESSINGROWS=1000;
		DATAROW=2;
	RUN;
%mend;

%import_csv(name=users);
%import_csv(name=orders);
%import_csv(name=products);
%import_csv(name=order_items);
%import_csv(name=categories);

%macro yearly_pdf(year=);
	%do m = 1 %to 12;
		%let m2 = %sysfunc(putn(&m, z2.));
		%let ym = &year.&m2;
		ods pdf file="/home/student/reports/&ym._매출.pdf";
			proc print data=shop.orders;
				where put(order_date, yymmn6.)="&ym";
			run;
		ods pdf close;
	%end;
%mend;

%yearly_pdf(year=2024);

proc sql noprint;
	select user_id into :vip_list separated by ","
	from shop.users
	where vip_grade = 'gold';
quit;
%put vip 수 : &sqlobs;

proc sql outobs=10;
	select * from shop.users;
	where user_id in &vip_list;
quit;

ods excel file="/home/student/grade.xlsx";
%macro grade_excel;
	%do i = 1 %to 5;
		%let g = %scan(vip platinum gold silver bronze, &i);
		ods excel options(sheet_name="&g" autofilter="all");
		proc print data=shop.users;
			where vip_grade="&g";
		run;
	%end;
%mend;
%grade_excel;
ods excel close;