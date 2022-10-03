$stitle fixed resource, calibrating backstops, and TSF (Technology specific factor)


*------------------------------------------------------------------------
* Calibration of supply elasticities for electricity technologies
*------------------------------------------------------------------------

parameters
    bse     backstop endowment
	es_re		fixed resource substitution elasticity
	esup_egt	supply elasicity for electricity techs
	pene0		implied energy price in benchmark year
;

* fixed resource parameters
* bse(r,"fr",egt) = fbar_gen0(r,"fr",egt);
bse(r,"fr",egt) = frmegt(r,"ele",egt);

* calibrate supply elasticity/subsitution elasticity
es_re(r,egt) = 0.25;

* set to 1 as a placeholder
pene0(g) = 1;

* supply elasticities

* from MRC2019 - when 0.01 ff and 0.014 ish penetration, 
* they found 0.3 sub elast gets them to correct path (for nuclear in 1970s)
* --- es_re(r,vgen) = 0.3;
* at 0.01 ff, that corresponds to a supply elasticity w/ ff of ~30
esup_egt(vgen) = 30;
* esup_egt(vgen) = 10;

* relatively inelastic supply for others
esup_egt(nuc) = 0.25;
esup_egt(hyd) = 0.25;
esup_egt(othc) = 0.25;

* Rutherford 2002 --- !!!! think there is a balistreri/rutherford paper that first mentions this method
es_re(r,egt) = esup_egt(egt)*cshr_r_ele_tech(r,"fr",egt)/(1-cshr_r_ele_tech(r,"fr",egt));


*------------------------------------------------------------------------
* Backstop cost and output structure
*------------------------------------------------------------------------

parameters
    bsfact  backstop markup factor
    bstechfact  backstop technology cost improvement factor markup reduction factor
    bstechrate  backstop technology cost improvement rate markup reduction rate
    activebt  switch to activate backstop tech
;

parameter
	cs_bet	post-tax (tax inclusive added) cost share for active out-of-the-money backstop inputs,
	cs_egt	post-tax (tax inclusive) cost share for in-the-money gen techs,
	cshr_ele0	store cost shares;

cshr_ele0(r,vafg,egt) = cshr_r_ele_tech(r,vafg,egt);
cs_egt(r,vafg,egt)$[obar_gen0(r,egt)] = cshr_r_ele_tech(r,vafg,egt);
cs_bet(r,vafg,egt)$[(not obar_gen0(r,egt))$vgen(egt)] = cshr_r_ele_tech(r,vafg,egt);

activebt(r,egt) = no;
activebt(r,egt)$[(not obar_gen0(r,egt))$vgen(egt)$swbt] = yes;

parameter
	os_egt	post-tax (tax subtracted) output share in-the-money-egt (1),
	os_bet	post-tax (tax subtracted) output share out-of-the-money vgen (1);

os_egt(r,egt)$[obar_gen0(r,egt)] = 1;
os_bet(r,egt)$[activebt(r,egt)] = 1;

* markup factor arbitrary value for now
bsfact(r,egt) = 1;
bsfact(r,egt)$[activebt(r,egt)] = 1.1;

* !!!! not used
* rate of backstop technology improvement (markup reduction)
bstechrate(r,egt) = 0.02;
bstechfact(r,egt) = 1;
* each loop update bsfact(r,bt) = bsfact(r,bt)*bstechfact(r,bt);

* balance checks
parameter chk_bet;
chk_bet(r,s,egt)$(y_egt(s)$y_(r,s)) = sum(g,(os_bet(r,egt)*ys0(r,s,g)/sum(gg,ys0(r,s,gg))))
	- [(cs_bet(r,"fr",egt)) + (cs_bet(r,"k",egt)) + sum(g,(cs_bet(r,g,egt))) + (cs_bet(r,"l",egt))];

display chk_bet, bse, cs_bet;

parameter cs_posttax;
cs_posttax(r,g,egt)$[obar_gen0(r,egt)] = ibar_gen0(r,g,egt)/(obar_gen0(r,egt)*(1-ty0(r,"ele")));
cs_posttax(r,"k",egt)$[obar_gen0(r,egt)] = fbar_gen0(r,"k",egt)*(1+tk0(r))/(obar_gen0(r,egt)*(1-ty0(r,"ele")));
cs_posttax(r,"fr",egt)$[obar_gen0(r,egt)] = fbar_gen0(r,"fr",egt)*(1+tk0(r))/(obar_gen0(r,egt)*(1-ty0(r,"ele")));
cs_posttax(r,"l",egt)$[obar_gen0(r,egt)] = fbar_gen0(r,"l",egt)/(obar_gen0(r,egt)*(1-ty0(r,"ele")));
cs_posttax(r,"all",egt)$[obar_gen0(r,egt)] = sum(vafg,cs_posttax(r,vafg,egt));
cs_posttax(r,"comp",egt)$[obar_gen0(r,egt)] = (obar_gen0(r,egt)*(1-ty0(r,"ele")))/obar_gen0(r,egt);
display cs_posttax;

parameter chk_cs_post;
chk_cs_post(r,vafg,egt) = cs_posttax(r,vafg,egt) - cs_egt(r,vafg,egt);

display cs_egt, cs_posttax, chk_cs_post;


*------------------------------------------------------------------------
* Initialize Techology Specific Factor (TSF) --- fixed factor evolution
*------------------------------------------------------------------------

$ontext
Advanced Technologies in energy-economy models for climate change assessment
J.F. Morris, J. Reilly, Y. Chen
https://www.sciencedirect.com/science/article/pii/S0140988319300490

TSF accumuilates and depreciates, with a lower limit of the initial endowment:
TSF(t+1) = max((TSF(t)*(1-delta)+INVTSF(t)),inishTSF)

OUT(t+1) = beta*OUT(t)-OUT(t)*delta (estimated equation - EQ.6)
INVOUT(t) = OUT(t) - OUT(t-1)(1-delta)
INVTSF(t+1) = theta_tsf*INVOUT(t+1)

beta estimates range from 1.064-1.666 (say ~1.1 for wind/solar) (the nuclear test case used was beta=1.064)
delta was 0.05 -- this means that OUT(t+1) will always be greater than OUT(t).
Seems like yoiu would have problems if (beta-1)<delta.

the max() in TSF(t+1) seems super important as well. New TSF can't be less than initial TSF is what this is saying.

OUT is technology output
delta is the depreciation rate on capacity to produce OUT
INVOUT is investment in the capability to produce out, and is needed to meet the difference between
output in two periods, accounting for depreciated capacity to produce out

In EPPA - impose
theta_tsf = 0.01 and choose inishTSF in each region to be consistent with the data used to estimate EQ.6

such that:
inishTSF = theta_tsf*(TOUT(t=0)*ISh

where TOUT is total regional electricity output in the base year of the model
and ISh is the share of the example technology at the start of the regression period (1-1.5%)
Using nuclear as the share, this would mean that ISh is 1.4% (0.014) since in 1970,
this was nuclear penetration share of electricity mix.

The value of theta_tsf is set arbitrarily small, but, once set, consistency with the estimation
of our other equations demands that inishTSF be determined by inishTSF = theta_tsf*(tout(t=0))*ISh

Given other parameter values, the elasticity between TSF and other inputs in production, sigma_tff,
must be set so that, when forced with a carbon price high enough to create demand for the new tech,
the new tech expands at a rate simlar to the historical expansion of the technology analogue
used to estimate the TSF parameters. 

This paper also discusses Capital vintaging quickly - how many vintages should slide have if solving yearly?
seems like time step is important for managing vintages -- 20-25 vintages would be a lot!!!

Another paper to read:
Representing the costs oflow-carbon power generation in mult-region multi-sector energy-economic models
Morris, Farrell, Khsehigi, Thomann, YH Chen, Paltsev, Herzog
https://globalchange.mit.edu/sites/default/files/MITJPSPGC_Reprint_19-6.pdf

This paper details markup calculations using LCOE

$offtext


parameters
	egt_out		regional output by electricity generation technology (egt)
	ele_out		total regional electricity output
	inv_out		investment in capability to produce egt_out
	beta1		estimated factor from morris reilly chen 2019
	theta_tsf	fixed resource share parameter (arbitrarily low 0.01 in MRC 2019)
	ISh			Initial output (penetration) share in benchmark year
	inishTSF	initial fixed resource endowment in benchmark year
	TSF			technology specific factor for year region egt
	invTSF		investment in tsf for year region egt
	chk_inish
	test_tsf
;

* !!!! assumes 5% depreciation rate, but sometimes we use larger, verify consistency and note where not in loop_tsf.gms
* !!!! when pinning we just overwrite a lot
beta1 = 1+delta+0.014;
* beta1 = 1.064;
* delta = 0.05;
* ---- beta1-delta = 0.014

* begin benchmark year loop
loop(yr$(yr.val eq %bmkyr%),

* gets summed by ele_out across egt
egt_out(r,egt,yr) = obar_gen0(r,egt)*(1-ty0(r,"ele"));
egt_out(r,egt,yr)$[os_bet(r,egt)] = 0;

ele_out(r,yr) = sum(egt,egt_out(r,egt,yr));

ISh(r,egt)$[os_egt(r,egt)] = obar_gen0(r,egt)/sum(egt.local,obar_gen0(r,egt));

theta_tsf(r,egt)$[cs_egt(r,"fr",egt)$vgen(egt)] = bsfact(r,egt)*cs_egt(r,"fr",egt)/(1+tk0(r));
theta_tsf(r,egt)$[cs_bet(r,"fr",egt)$vgen(egt)] =  bsfact(r,egt)*cs_bet(r,"fr",egt)/(1+tk0(r));

inishTSF(r,egt) = theta_tsf(r,egt)*ele_out(r,"%bmkyr%")*ISh(r,egt);
inishTSF(r,egt)$[vgen(egt)] = max(1e-6,inishTSF(r,egt));

chk_inish(r,egt)$[inishTSF(r,egt)] = inishTSF(r,egt) - frmegt(r,"ele",egt);

display inishTSF, chk_inish;

TSF(r,egt,yr)$[vgen(egt)] = max(1e-6,inishTSF(r,egt));

bse(r,"fr",egt)$[vgen(egt)] = TSF(r,egt,yr);

* update initial extant/mutable
frxegt0(r,s,egt)$[os_egt(r,egt)$y_egt(s)$vgen(egt)] = bse(r,"fr",egt)*thetaxegt(s,egt);
frxegt0(r,s,egt)$[os_bet(r,egt)$y_egt(s)$vgen(egt)] = 0;
frxegt(r,s,egt)$[y_egt(s)$vgen(egt)] = frxegt0(r,s,egt);

bse(r,"fr",egt)$[os_egt(r,egt)$vgen(egt)] = bse(r,"fr",egt)*(1-thetaxegt("ele",egt));
inishTSF(r,egt)$[vgen(egt)] = max(1e-6,inishTSF(r,egt)*(1-thetaxegt("ele",egt)));
TSF(r,egt,yr)$[vgen(egt)] = max(1e-6,inishTSF(r,egt));

* close benchmark year loop
);

