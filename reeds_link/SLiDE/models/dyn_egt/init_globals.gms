$stitle global sets and switches

* point to gdx output directory
$setglobal sep %system.dirsep%
$if not set gdxdir $setglobal gdxdir gdx%sep%
$if not set bmkdir $setglobal bmkdir ..%sep%..%sep%bmk_data%sep%

*	Create a bases directory:
$if not set basesdir $setglobal basesdir bases%sep%
* $if not dexist %basesdir% $call mkdir %basesdir%

* Declare globals
* model name
$if not set modname $setglobal modname MGEMODEL

* what regional mapping census or state
$if not set rmap $setglobal rmap census
* set the benchmark file
$if not set ds $setglobal ds WiNDC_bluenote_egt_real_cps_%rmap%_2017.gdx
* name scenario
$if not set scn $setglobal scn "BAU"
* reference bau scenario if loading
$if not set bauscn $setglobal bauscn not_specified
* switch for emissions accounting in the model
$if not set swcarbval $setglobal swcarbval 0
* switch for emissions accounting in the model
$if not set swdecarbval $setglobal swdecarbval 0
* specify value of decarbonization eventually reached
$if not set decarbval $setglobal decarbval 0.8
* switch for backstop techs
$if not set swbtval $setglobal swbtval 0
* benchmark year
$if not set bmkyr $setglobal bmkyr 2017
* end year in time horizon
$if not set endyr $setglobal endyr 2019
* year cap starts for decarbonization
$if not set capyrval $setglobal capyrval 2020
* cap end year in time horizon
$if not set capendyrval $setglobal capendyrval 2050
* share of extant vs. mutable capital
$if not set thetaxval $setglobal thetaxval 0.0
* share of extant vs. mutable capital in electricity egt
$if not set thetaxegtval $setglobal thetaxegtval 0.0
* growth rate
$if not set etaval $setglobal etaval 0.0
* esub_ele growth rate
$if not set eletrval $setglobal eletrval 0.0
* switch on sector specific electricity tax
$if not set ssctaxele $setglobal ssctaxele 0
* lump sum us refund of carbon tax revenues
$if not set lsusval $setglobal lsusval 0
* pin to standard scenarios electricity mix projection
$if not set swsspinval $setglobal swsspinval 0
* min generation value
$if not set mingenval $setglobal mingenval 0.01
* min generation value
$if not set slbndval $setglobal slbndval 0.01
* electricity as perfect substitutes or not
$if not set swperfval $setglobal swperfval 0
* iterative pin switch
$if not set switerpinval $setglobal switerpinval 0
* iterative iternum total
$if not set iternum $setglobal iternum 5
* iterative adjustment step
$if not set adjstepval $setglobal adjstepval 0.001
* load a scenario --- !!!! if swloaditval=1, then should be swloadval=1
$if not set swloadval $setglobal swloadval 0
* load a scenario with iterative pin
$if not set swloaditval $setglobal swloaditval 0
* run subsidy case
$if not set swsubegtval $setglobal swsubegtval 0
* run flat cap case
$if not set swflatcapval $setglobal swflatcapval 0
* run co2 tax case
$if not set swctaxval $setglobal swctaxval 0
* electrification demand shifter
$if not set elkrateval $setglobal elkrateval 0
* fuel efficiency demand shifter
$if not set aeeirateval $setglobal aeeirateval 0
* electrification backstop technology activiation
$if not set swelbsval $setglobal swelbsval 0
* run subsidy case
$if not set swsubkbetval $setglobal swsubkbetval 0
* run subsidy case with exogenous coal depreciation as part of the counterfactual
$if not set subexodep $setglobal subexodep 0
* jpow money printer go brr
$if not set jpowval $setglobal jpowval 0
* variable depreciation rates
$if not set swvdeprval $setglobal swvdeprval 0
* variable egt extant shares
$if not set swvextval $setglobal swvextval 0
* household extant capital option
$if not set swhhextval $setglobal swhhextval 0
* national capital mutable - if thetax > 0 set swrksval=1
$if not set swrksval $setglobal swrksval 0

scalar swctax	co2 tax switch;
swctax = %swctaxval%;

scalar swflatcap	flat straight up cap - flat;
swflatcap = %swflatcapval%;

scalar swsubegt	electricity renewables subsidy;
swsubegt = %swsubegtval%;

scalar swcarb switch to enable or disable emissions accounting;
swcarb = %swcarbval%;

scalar swdecarb		switch to enable or disable the decarbonization scenario;
swdecarb = %swdecarbval%;

scalar	swbt	backstop tech switch;
swbt = %swbtval%;

scalar swsspin	pin to standard scenarios switch;
swsspin = %swsspinval%;

scalar slack_bound	bound for slack variable;
slack_bound = %slbndval%;

scalar swperf	bound for slack variable;
swperf = %swperfval%;

scalar switerpin	iterative pin switch;
switerpin = %switerpinval%;

scalar swload   load values from previous run;
swload = %swloadval%;

scalar swloadit   load values from previous run;
swloadit = %swloaditval%;

scalar swsubegt	electricity renewables subsidy;
swsubegt = %swsubegtval%;

scalar swsubkbet	electricity renewables capital subsidy;
swsubkbet = %swsubkbetval%;

* JPOW money printer go BRRR switch
scalar mnyprntrgo money printing subsidy option;
mnyprntrgo = %jpowval%;

scalar swvdepr	variable electricity depreciation rates;
swvdepr = %swvdeprval%;

scalar swvext	variable electricity extant shares;
swvext = %swvextval%;

scalar swhhext	hh extant capital switch;
swhhext=%swhhextval%;

scalar swrks	national capital price switch;
swrks=%swrksval%;

