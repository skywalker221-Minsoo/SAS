/*  ============================================
	my_이민수.SAS - M4 D1 종합
	============================================ */
libname mylib "/home/student/shop_db";

proc import
	datafile = "/home/student/shop_csv/users_dirty.csv"
	out = mylib.users DBMS=csv replace;
	getnames=yes; guessingrows=max;
run;

data mylib.users_v2;
	set mylib.users;
	length age_grp $6;
	if missing(age) then age = 0;
	if	    age < 30 then age_grp="20대-";
	else if age < 40 then age_grp="30대";
	else				  age_grp="40대+";
run;

title "organic 30+ 사용자 10명";
proc print data=mylib.users_v2 (obs=10) noobs;
	var user_id name channel age age_grp;
	where channel='organic' and age >= 30;
run; title;