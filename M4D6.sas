cas mysession;
caslib _all_ assign;

data casuser.users;
	set shop.users;
run;

proc casutil;
	list tables incaslib="casuser";
quit;

proc casutil;
	save casdata="users_cas"
		 incaslib="casuser"
		 outcaslib="casuser";
quit;

cas mysession terminate;
cas mysession;
caslib _all_ assign;

libname mycas cas caslib="casuser";

proc casutil;
	promote casdata="users_cas"
			incaslib="casuser"
			outcaslib="casuser";
quit;

cas othersession;
caslib _all_ assign;

proc print data=casuser.users_cas (obs=5);
run;

proc casutil;
	load casdata="public.orders"
		 incaslib="casuser"
		 outcaslib="casuser"
		 casout="orders_cas";
quit;

proc means data=casuser.users;
	var age;
run;

proc caslib all list;
run;

%put [Viya] environment information];
%put sysuserid = &sysuserid;
%put sysdate = &sysdate;
%put sysdate = &sysdate;

cas othersession terminate;


/* cas 엔진 start */
cas mysession;

/* cas library allocation */
caslib _all_ assign;

/* cas library 목록 */
proc cas;
	table.caslibinfo;
run;

/* casutil -> table list estimation */
proc casutil;
	list tables incaslib="casuser";
run;

/* shop.orders load and change global */
data casuser.orders;
	set shop.orders;
run;

proc casutil;
	promote casdata="orders"
			incaslib="casuser"
			outcaslib="casuser";
run;

cas session2 terminate;

cas session2;
caslib _all_ assign;

/* global table down to session only(copy) and delete old table */
/* step 1: copy old table */
proc casutil;
	copy casdata="orders"
		 incaslib="casuser"
		 outcaslib="casuser"
		 casout="orders_copy";
quit;
/* step 2: delete old table */
proc casutil;
	droptable casdata="orders"
			incaslib="casuser";
run;

/* step 3: rename copy table to original table */
proc casutil;
	altertable casdata="orders_copy"
			   incaslib="casuser"
			   rename="orders";
quit;

cas mysession terminate;
cas mysession; caslib _all_ assign;

/* csv -> cas (fast) */
proc import
	datafile = "/home/student/shop_csv/order_items.csv"
	out = casuser.order_items
	dbms = csv replace;
	getnames = yes;
	guessingrows = max;
run;

proc print data=casuser.order_items(obs=10);
run;

/* order_items -> save로 order_items_bak */
proc casutil;
	save casdata="order_items"
		 incaslib="casuser"
		outcaslib="casuser"
		casout = "order_items_bak"
	replace;
run;

proc casutil;
	save casdata="order_items"
		 incaslib="casuser"
		outcaslib="casuser"
		casout = "order_items_restore";
run;

proc casutil;
	load casdata="order_items_bak.sashdat"
		incaslib="casuser"
		outcaslib="casuser"
		casout="order_items_restore";
run;

proc casutil;
	list files incaslib="casuser";
	list tables incaslib="casuser";
quit;

proc casutil;
	droptable casdata="order_items_bak"
			incaslib="casuser";
	deletesource casdata="order_items_bak.sashdat" incaslib="casuser";

	droptable casdata="order_items_restore"
			incaslib="casuser";
	deletesource casdata="order_items_restore.sashdat" incaslib="casuser";
quit;

/* 자신만의 caslib 생성 */
caslib myown
	datasource=(srctype = "path")
	path="/home/student/casdata"
	sessref = mysession;

cas mysession terminate;
cas mysession;
caslib _all_ assign;

data myown.order_items;
	set shop.order_items;
run;

proc casutil;
	list files incaslib="myown";
	list tables incaslib="myown";
quit;

proc casutil;
	save casdata="order_items"
		incaslib="myown"
		outcaslib="myown";
quit;

caslib myown drop;

/* session 5: proc cas -> sas viya engine generate */
cas mysession terminate;
cas mysession;
caslib _all_ assign;

/* simple.summary -> proc means */
libname shop "/home/student/shop_db";
proc means data=shop.users;
	var age;
run;

proc cas;
	simple.summary /
	table = "users", input="age";
quit;

/* simple.freq - proc freq */
proc cas;
	simple.freq / table = "users", inputs = "channel";
quit;

/* simple.crosstab : second demensions */
proc cas;
	simple.crosstab /
	table = "users",
	row = "channel",
	col = "gender";
quit;

proc freq data=shop.users;
	tables channel * gender / norow nocol nopercent;
run;

/* fedSQL - 채널별 KPI */

proc cas;
	fedsql.execdirect /
		query = "
			select channel, count(*) as n,
					avg(age) as avg_age
			from casuser.users
			group by channel
			order by n desc
		";
quit;

cas mysession terminate;
cas mysession sessopts=(timeout=3600);
caslib _all_ assign;

data casuser.orders;
	set shop.orders;
run;


/* join - cas table */
proc cas;
	fedsql.execdirect /
		query = "
			create table casuser.kpi_cas as
			select u.channel,
					sum(o.total_amount) as total
			from casuser.users u
			inner join casuser.orders o
					on u.user_id = o.user_id
			group by u.channel
		";
quit;

/* proc sql - 그대로 */
proc sql;
	select * from casuser.kpi_cas;
quit;

/* total_amount means by grade > vip_grade, total_spent */
proc sql;
	select vip_grade, avg(total_spent)
	from casuser.users
	group by vip_grade;
quit;

proc cas;
	fedsql.execdirect / 
		query = "
			select vip_grade, avg(total_spent)
			from casuser.users
			group by vip_grade;
		";
quit;

