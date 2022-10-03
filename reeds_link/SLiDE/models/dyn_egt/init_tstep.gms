$stitle initialize time horizon and parameters for time step

*------------------------------------------------------------------------
* time intervals and year sets
*------------------------------------------------------------------------

* time interval default
$if not set tintval $setglobal tintval 1
* time interval of first step
$if not set tintfirst $setglobal tintfirst 1

* specify year/time sets
set yr  /%bmkyr%*%endyr%/;
set yrf(yr)	first year;
set yrl(yr)	last year;

alias(yr,loopyr,lyr,llyr);

yrf(yr) = yes$(ord(yr) eq 1);
yrl(yr) = yes$(ord(yr) eq card(yr));

* compute subsets
scalar horizon	time horizon;
horizon = %endyr%-%bmkyr%;
display horizon;

scalar	tint	time interval;
scalar	tintf	first time interval;
tint=%tintval%;
tintf=%tintfirst%;

scalar horizonchk;
horizonchk=horizon;
while(mod(horizonchk,tint)>0,
	horizonchk=horizonchk-1;
);

scalar firstyr	value of first year to solve after benchmark year;
firstyr = %endyr%-horizonchk;
* OR: firstyr=%bmkyr%+tintf;

set solveyr(yr) years to solve;

solveyr(yr)=no;
solveyr(yr)$[(yr.val eq %bmkyr%)] = yes;
solveyr(yr)$[(yr.val eq firstyr)] = yes;

scalar nextyr	next year;
nextyr = firstyr+tint;
while((nextyr le %endyr%),
	solveyr(yr)$[(yr.val eq nextyr)] = yes;
	nextyr = nextyr + tint;
);

* rewrite solveyr as ordered set so that leads/lags work without $offorder/$onorder
* alias(*,u);
* file set_t /set_t.inc/;
* put set_t 'set t(yr) solve year /'
* loop(SortedUels(u,solveyr)$(not yrl(solveyr)), put set_t solveyr.tl:0 ', ');
* loop(SortedUels(u,solveyr)$(yrl(solveyr)), put set_t solveyr.tl:0);
* put set_t '/;'
* putclose set_t;

* execute "sleep 1";
* $exit

$include set_t.inc
display t;

alias(t,tt);

parameter tstep(t)	time step for solveyear;

tstep(t)$[(t.val eq %bmkyr%)] = 0;
tstep(t)$[(t.val eq firstyr)] = tintf;
tstep(t)$[(t.val gt firstyr)] = tint;


parameters
	delta	depreciation rate
	srv		single year survival rate	
	eta		growth rate
;

delta = 0.05;
eta = %etaval%;
srv = (1-delta);

parameter srvt(t)	single period survival rate;

srvt(t) = srv**tstep(t);

display solveyr, tstep, srvt;
