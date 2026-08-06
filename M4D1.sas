%let root = /home/student;

libname shop "&root/shop_db";

/* shop.users 가져와서 user_copy로) */
data user_copy;
	set shop.users;
run;

proc sql outobs=5;
	select user_id, name, age, gender, city, channel
	from user_copy;
quit;

/* change to proc print */
title "information of user_copy";
proc print data=user_copy(obs=5);
	var user_id name age gender city channel;
run;
title;

/* intermediate result saves in work folder
	tax = total_amount * 0.1 */
data users;
	set shop.users;
	tax = total_spent * 0.1;
run;

data shop.users_tax;
	set users;
run;

proc print data=shop.users_tax;
run;
quit;

/* user_id name age channel column
are extracted from shop.users */
data user_kept;
	set shop.users;
	keep user_id name age channel;
run;

/* except for total_spent order_count churn marketing_consent */
data user_dropped;
	set shop.users;
	drop total_spent order_count churn marketing_consent;
run;

title "[S1.3] keep result - 4 columns";
proc print data=work.user_kept(obs=5) noobs; run;

title "[S1.3] drop result - eliminate 4 columns";
proc print data=work.user_dropped(obs=5) noobs;
	var user_id name age city channel vip_grade;
run;
title;

title "users_kept union users_dropped -> union all";
data orders_2025;
	set shop.orders;
	where order_date between '01JAN2026'd and '31DEC2026'd;
run;

data users_2025;
	set shop.users;
	where signup_date between '01JAN2025'd and '31DEC2025'd;
run;

data users_2026;
	set shop.users;
	where signup_date between '01JAN2026'd and '31DEC2026'd;
run;

data users_all;
	set users_2025
		users_2026;
run;

data users_tagged;
	set users_2025 (in=y25)
		users_2026 (in=y26);
	if y25 then src="2025";
	else if y26 then src="2026";
run;

proc sort data=users_tagged;
	by user_id;
run;

proc print data=shop.orders(obs=5) noobs;
	var user_id order_id order_date;
run;

libname shop "/home/student/shop_csv";

/* users.csv to users.sasdat 로 변환 */
PROC IMPORT DATAFILE="/home/student/team_project/users.csv"
	 OUT=shop.users
	DBMS=csv
	REPLACE;
	GETNAMES=YES;
	GUESSINGROWS=1000;
	DATAROW=2;
RUN;

%let csvdir = /home/student/shop_csv;
%macro imp(name=);
	proc import datafile="&csvdir/&name..csv"
				out=shop.&name
				dbms=csv
				replace;
		getnames=yes;
		guessingrows=max;
	run;
	%put note: ==== &name..csv -> shop.&name changed ====;
%mend;

%imp(name=orders);
%imp(name=categories);

data orders_2026;
	set shop.orders;
	where order_date between '01JAN2026'd and '31DEC2026'd;
run;

libname pds "/home/student/team_project";


data shop.adae;
	set pds.pds.adae_pds2019;
run;

proc export data=shop.adae
			OUTFILE="/home/student/team_project/adae_output.csv"
			DBMS=CSV
			replace;
run;

/* session 2*/
data work.users_safe;
	length email $50;
	set shop.users;

	/* missing func */
	if missing(age) then age=0;
	if missing(email) then email="no-email";

	/* coalesce */
	age_safe = coalesce(age, 0);
	email_safe = coalesce(email, "unknown");

	/* row missing count */
	missing_cnt = nmiss(age, email, email_safe);

	/* delete missing rows */
	if missing(age) then delete;
run;

data work.users_calc;
	set shop.users;
	age_dec = floor(age / 10) * 10;
	spent_won_k = round(total_spent / 1000, 1);
	age_next = age + 1;
	keep user_id name age age_dec age_next total_spent spent_won_k;
run;
title "[S2.1] 새 변수 - 연령대 / 천원 매출";
proc print data=work.users_calc(obs=8) noobs; run;
title;

/* eliminate null value */
data work.users_filled;
	set shop.users;
	if missing(last_login_date) then do;
		last_login_flag = 1;
	end;
	else last_login_flag = 0;

	if missing(city) then city = '미상';
	if missing(age) then age = 0;
	keep user_id name age city last_login_date last_login_flag;
run;

title "[S2.2] 결측 보정 - last_login 미접속 플래그";
proc freq data=work.users_filled;
	tables last_login_flag / nocum;
run;
title;

/* session 3 */
data user_grp;
	length age_agrde $20;
	set shop.users;
	if missing(age) then age = 0;
	if age < 20 then age_grade = '10s';
	else if age < 30 then age_grade = '20s';
	else if age < 40 then age_grade = '30s';
	else age_grade = '40s+';

	keep user_id name age age_grade;
run;

/* statistics shows much better than SQL */
title "[S3.1] if/then/else - 4 depth age classification";
proc print data=user_grp(obs=5);
run;

/* statistics data */
proc freq data=user_grp;
	tables age_grade / nocum;
run;
title;

/* conditional processing */
data work.users_cohort;
	length cohort $20;
	set shop.users;
	select;
		when (age <= 25) cohort = 'z generation';
		when (age <= 35) cohort = 'millenial';
		when (age <= 50) cohort = 'x generation';
		otherwise cohort = 'babyboom';
	end;
	keep user_id name age cohort;
run;

/* population per generation, ratio */
proc freq data=users_cohort;
	tables cohort;
run;

/* practice 3 */
data work.users_bad;
	set shop.users;
	if age < 20 then age_grp = '10대';
	else if age < 30 then age_grp = '20대';
	else if age < 40 then age_grp = '30대';
	else age_grp = '40대 이상';
	
	if city not in ('서울', '경기', '인천') then metro = '기타지역';
	else metro = '수도권';
	keep user_id age age_grp city metro;
run;

proc freq data=users_bad;
	tables age_grp metro;
run;

data work.users_good;
	length age_grp $14 metro $20;
	set shop.users;
	if age < 20 then age_grp = '10대';
	else if age < 30 then age_grp = '20대';
	else if age < 40 then age_grp = '30대';
	else age_grp = '40대 이상';
	
	if city not in ('서울', '경기', '인천') then metro = '기타지역';
	else metro = '수도권';
	keep user_id age age_grp city metro;
run;

proc freq data=users_good;
	tables age_grp metro;
run;

/* session 4 */
title "[S4.1] OBS=5 - users first five rows";
proc print data=shop.users (obs=5);
	var user_id name age channel;
run;
title;

title "[S4.2] VAR - 4 columns";
proc print data=shop.users (obs=10) noobs;
	var user_id name age channel;
run;
title;

title "[S4.3] WHERE - 30+ female + Seoul";
proc print data=shop.users (obs=10) noobs;
	where gender = 'F' and age >= 30 and city = '서울';
	var user_id name age channel vip_grade total_spent;
run;
title;

title "[S4.4] SUM - VIP user sum of total spent";
proc print data=shop.users (obs=20) noobs;
	where vip_grade in ('gold', 'vip');
	var user_id name vip_grade total_spent order_count;
sum total_spent order_count;
run;
title;

/* aggregate by group */
proc sort data=work.orders;

	by status;
run;
proc print data=work.orders;
	by status;
	var order_id total_amount;;
	sum total_amount;
	sumby status;
run;

/* session 4 */
title "[S5.1] BETWEEN + IN collaboration";
proc print data=shop.users(obs=10) noobs label;
	where age between 30 and 39
	and channel in ('organic', 'paid_search', 'email');
	id user_id;
	var name age channel vip_grade total_spent;
run;
title;

/* To Korean header */
title "[S5.3] To Korean label";
proc print data=shop.users(obs=10) noobs label width<>full;
	where age between 30 and 39
	and channel in ('organic', 'paid_search', 'email');
	id user_id;
	var name age channel vip_grade total_spent;
	label user_id = '고객ID', name='고객명' age='나이'
		channel = '유입채널' vip_grade='고객등급' total_spent='매출';
run;
title;

/* title, title2, ... , footnote, footnote2, ... */
title "organic channel 30s+ users";
title2 "data : shop_data";
footnote "analysis : 2026-05-26 / datateam";

proc print data=shop.users (obs=10)
			noobs label double;
	var name channel age city;
	where channel='organic' and age >= 30;
run;

/* 보고서 pdf 저장 filename: m4d1_report&TODAY..pdf style=journal */
%let today = %sysfunc(today(), yymmddn8.);
ods pdf file="/home/student/m4d1_report&today..pdf" style=journal;
title "[S5.5] PDF 자동출력 보고서";
proc print data=shop.users noprint;
	where age between 30 and 39
	and channel in ('organic', 'paid_search', 'email');
	id user_id;
	var name age channel vip_grade total_spent;
	label user_id = '고객ID', name='고객명' age='나이'
		channel = '유입채널' vip_grade='고객등급' total_spent='매출';
run;
ods pdf close;
title;

/* practice 5: 고객id, 이름, 지역, email, total_spent, gender	컬럼 출력
email is naver, 30~50 ages, female, city except for seoul, kyunggi customer information */


title;
footnote;

ods excel close;
ods html;
ods listing;	