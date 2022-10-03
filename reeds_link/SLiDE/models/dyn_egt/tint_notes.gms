* notes for scalable time intervals

* exec_bat.bat file needs to be updated so that each solve year is correct

* readdata_egt_hh.gms needs updated:
**** to correctly establish the time set
**** update survival rates

* load_pin.gms needs updates/consideration
**** to correctly establish pin path and survival rates

* Maybe we have a set for all years and a subset for solve years
* say yr and loopyr(yr)
* automate the writing of these parameters.. possibly with a put writing feature?
* maybe we also say... solve each year until the remaining time horizon is divisible by the interval w/out remainder

* any policies that start not in a solve year need to be handled

* need to update srv to have a time index srv(loopyr) and control for the year when establishing depreciation/vintages


* **** rep_init loads next year data... should load next solveyear data not loopyr

* loop(loopyr$(loopyr.val eq %bmkyr%),

* * Store benchmark year parameters
* $include loop_store_vint.gms

* * load bau pin values for next year
* * !!!! currently tfp pin doesn't get used, but in future will need separate swload switch for this
* * ---- or some way to store pinned values regardless of pin method so that a single switch can handle
* egtrate_bau(r,s,egt)$[swloadit] = rep_pin_bau(r,s,egt,loopyr+1,"EGTRATE","%bauscn%");
* egtmod_bau(r,s,egt)$[swloadit] = rep_pin_bau(r,s,egt,loopyr+1,"EGTMOD","%bauscn%");
* bse_bau(r,"fr",egt)$[(swloadit)] = rep_pin_bau(r,"fr",egt,loopyr+1,"BSE","%bauscn%");

* * update bse
* bse(r,"fr",egt)$[(swloadit)] = bse_bau(r,"fr",egt);
* display bse;

* EGTRATE.fx(r,s,egt)$[(not swsspin)] = 0;
* EGTRATE.fx(r,s,egt)$[swloadit] = egtrate_bau(r,s,egt);

* * close loopyr loop
* );


