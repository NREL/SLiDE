$stitle loop for updating TSF (Technology specific factor)

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
seems like time step is important for managing vintages -- seems like 20-25 vintages would be a lot!!!

Another paper to read:
Representing the costs oflow-carbon power generation in mult-region multi-sector energy-economic models
Morris, Farrell, Khsehigi, Thomann, YH Chen, Paltsev, Herzog
https://globalchange.mit.edu/sites/default/files/MITJPSPGC_Reprint_19-6.pdf

This paper details markup calculations using LCOE

$offtext

* parameters
* 	egt_out		regional output by electricity generation technology (egt)
* 	ele_out		total regional electricity output
* 	inv_out		investment in capability to produce egt_out
* 	beta1		estimated factor from morris reilly chen 2019
* 	theta_tsf	fixed resource share parameter (arbitrarily low 0.01 in MRC 2019)
* 	ISh			Initial output (penetration) share in benchmark year
* 	inishTSF	initial fixed resource endowment in benchmark year
* 	TSF			technology specific factor for year region egt
* 	invTSF		investment in tsf for year region egt
* 	chk_inish
* 	test_tsf
* ;

* beta1 = 1.064;
* delta = 0.05;
* ---- beta1-delta = 0.014

* store benchmark technology output quantity
* !!!! lots of different assumption possibilities here that can make a big difference for renewable deployment
* !!!! doesn't get used when pinning
* 2 x extant for arbitrary knowledge diffusion
egt_out(r,egt,t-1)$[vgen(egt)] = eps + YBET.l(r,"ele",egt) + sum(v,YXBET.l(r,"ele",egt,v));
* egt_out(r,egt,t)$[vgen(egt)] = eps + YBET.l(r,"ele",egt);

* store total electricity output quantity
ele_out(r,t-1) = sum(egt,YBET.l(r,"ele",egt)+SYMEGT.l(r,"ele",egt)*(1-ty0(r,"ele")));
* add in extant
ele_out(r,t-1) = ele_out(r,t-1)
	+ sum((s,egt)$[y_egt(s)$(not vgen(egt))],sum(v,YXEGT.l(r,s,egt,v)$[xegt_k(r,s,egt,v)]))
	+ sum(egt$[vgen(egt)],sum(v,YXBET.l(r,"ele",egt,v)))
;

* egt_out(r,egt,t-1)$vgen(egt) = ele_out(r,t-1);

*!!!! This is a hack to get my model to produce meaningful amounts of the backstop
* nuc share of penetration 1967 1.4% - ISh = 1.4%
inishTSF(r,egt)$[(t.val eq %bmkyr%)$os_bet(r,egt)] = theta_tsf(r,egt)*0.014*ele_out(r,t);
* inishTSF(r,egt)$[(t.val eq %bmkyr%)$vgen(egt)$(ISh(r,egt) le 0.014)] = theta_tsf(r,egt)*0.014*ele_out(r,t);

* compute new TSF using method in MRC2019
* !!!! This could invalidate method if delta != 5% --- look into this
* egt_out(r,egt,t)$[vgen(egt)] = beta1*egt_out(r,egt,t-1) - delta*egt_out(r,egt,t-1);
* *egt_out(r,egt,t)$[vgen(egt)] = (beta1-delta)*egt_out(r,egt,t-1);
* inv_out(r,egt,t-1)$[vgen(egt)] = egt_out(r,egt,t)-egt_out(r,egt,t-1)*(1-delta);
* invTSF(r,egt,t-1)$[vgen(egt)] = theta_tsf(r,egt)*inv_out(r,egt,t-1);
* TSF(r,egt,t)$[vgen(egt)] = max((TSF(r,egt,t-1)*(1-delta)+invTSF(r,egt,t-1)),inishTSF(r,egt));

egt_out(r,egt,t)$[vgen(egt)] = ((beta1-delta)**(tstep(t)))*egt_out(r,egt,t-1);
inv_out(r,egt,t-1)$[vgen(egt)] = egt_out(r,egt,t)-egt_out(r,egt,t-1)*((1-delta)**tstep(t));
invTSF(r,egt,t-1)$[vgen(egt)] = theta_tsf(r,egt)*inv_out(r,egt,t-1);
TSF(r,egt,t)$[vgen(egt)] = max((TSF(r,egt,t-1)*((1-delta)**tstep(t))+invTSF(r,egt,t-1)),inishTSF(r,egt));

*------------------------------------------------------------------------
* when swsspin = 1
*------------------------------------------------------------------------

* Renewables
* !!!! overwrites MRC2019 Method
* !!!! for pinning, needs some thought and depends on assumptions...
* !!!! verify status of hiak(r) --- sometimes gets hardcoded
* !!!! can choose to reduce/or not reduce bse in next year by the extant fixed resource factor amount (not a perfect solution)
TSF(r,egt,t)$[vgen(egt)$swsspin$(not hiak(r))] =
	theta_tsf(r,egt)*max(mingenscale(r,egt),imp_pele0(r)*ss_gen(r,t,egt)
		-sum(v,YXBET.l(r,"ele",egt,v)*sum(g,xbet_ys_out(r,"ele",egt,g,v))*srvt(t))
	)*(1-ty0(r,"ele"))
;

TSF(r,egt,t)$[vgen(egt)$switerpin$(not hiak(r))] =
	theta_tsf(r,egt)*max(mingenscale(r,egt),imp_pele0(r)*ss_gen(r,t,egt)
		-sum(v,YXBET.l(r,"ele",egt,v)*sum(g,xbet_ys_out(r,"ele",egt,g,v))*srvt(t))
	)*(1-ty0(r,"ele"))
;

* !!!! no resource updates for conventional currently (commented)
* Conventional
* bse(r,"fr",egt)$[fbar_gen0(r,"fr",egt)$(not vgen(egt))$swsspin$(not hiak(r))] =
* 	cs_egt(r,"fr",egt)/(1+tk0(r))*max(mingenscale(r,egt),imp_pele0(r)*ss_gen(r,t,egt)
* 	)*(1-ty0(r,"ele"));

* bse(r,"fr",egt)$[fbar_gen0(r,"fr",egt)$(not vgen(egt))$switerpin$(not hiak(r))] =
* 	cs_egt(r,"fr",egt)/(1+tk0(r))*max(mingenscale(r,egt),imp_pele0(r)*ss_gen(r,t,egt)
* 	)*(1-ty0(r,"ele"));


*------------------------------------------------------------------------
* Store
*------------------------------------------------------------------------

test_tsf(r,egt,t-1)$[vgen(egt)] = TSF(r,egt,t-1);
test_tsf(r,egt,t)$[vgen(egt)] = TSF(r,egt,t-1)*(1-delta)**tstep(t)+invTSF(r,egt,t-1);

bse(r,"fr",egt)$[vgen(egt)] = max(1e-6,TSF(r,egt,t));
