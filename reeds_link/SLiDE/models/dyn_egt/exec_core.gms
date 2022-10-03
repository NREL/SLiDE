$title load benchmark, preprocess, and replicate


*------------------------------------------------------------------------
* preprocessing and model setup
*------------------------------------------------------------------------

* include globals and associated switches
$include init_globals.gms

* initialize time horizon
$include init_tstep.gms

* Read the dataset:
$include readdata_egt_hh.gms

* !!!! if want to skip files, then all declarations need to be made separately
* Electricity disaggregation
$include egt_disagg.gms

* Initialize backstops and fixed resources
$include init_tsf.gms

* Load/Initialize electrification backstops
$include init_elbs.gms

* Initialize extant vintaging structure
$include init_vint.gms

* $exit

* Read in ReEDS Standard Scenarios Data from 2019 mid case
$include load_pin.gms

* $exit

* Read in jobs data
$include load_jobs.gms

* Declarations for iterative pinning
$include init_iterpin.gms

* * Initialize exogenize electricity
* $include init_exo.gms

* initialize model exceptions
$include init_modexcept.gms

* $exit

* display n_exo, y_exo;
* execute_unload "%gdxdir%mgeout_bmk_%rmap%_%scn%_%solveyr%.gdx";
*------------------------------------------------------------------------

* Read the MGE model:
$include mgemodel_vint.gms

*------------------------------------------------------------------------
* $exit
* Replicate the benchmark equilibrium:

* main opt file
$onecho > PATH.opt
convergence_tolerance 1e-5
time_limit 10000
$offecho

* opt file for iterative pin
$onecho > PATH.op2
convergence_tolerance 1e-5
time_limit 3600
$offecho

MGEMODEL.OptFile = 1;

MGEMODEL.workspace = 100;
MGEMODEL.iterlim = 0;

mgemodel.savepoint = 1;

* $if exist %basesdir%%rmap%_%scn%_p.gdx execute_loadpoint '%basesdir%%rmap%_%scn%_p.gdx';

$INCLUDE MGEMODEL.GEN
SOLVE MGEMODEL using mcp;
ABORT$(MGEMODEL.objval > 5e-4) "Error in benchmark calibration of the MGE model.";

* $exit
*	Save the solution:
execute 'mv -f MGEMODEL_p.gdx %basesdir%%rmap%_%scn%_p.gdx';

* resolve model with iterlim released
mgemodel.savepoint = 1;

$if exist %basesdir%%rmap%_%scn%_p.gdx execute_loadpoint '%basesdir%%rmap%_%scn%_p.gdx';

MGEMODEL.iterlim = 10000000;
$INCLUDE MGEMODEL.GEN
SOLVE MGEMODEL using mcp;
ABORT$(MGEMODEL.objval > 1e-4) "Error in benchmark calibration of the MGE model.";

*	Save the solution:
execute 'mv -f MGEMODEL_p.gdx %basesdir%%rmap%_%scn%_%solveyr%_p.gdx';

*------------------------------------------------------------------------
* prepare to loop over solve years
$include rep_init.gms
*------------------------------------------------------------------------

execute_unload "%gdxdir%mgeout_bmk_%rmap%_%scn%_%solveyr%.gdx";

* $exit

