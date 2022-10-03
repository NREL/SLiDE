$stitle initialize reports for loop

* !!!! clean up this file, specifically the loading of bau parameters and switches

*------------------------------------------------------------------------
* ++++++++++ include benchmark reporting parameters ++++++++++
*------------------------------------------------------------------------
parameter	pnum	Numeraire price index;
parameter r_dco2	emissions accounting parameter;
parameter r_dco2_s	emissions accounting parameter for sector;
parameter rkrs	capital rental rate;

parameter emissions	separate emissions tracking;
set cat emissions category /fuel, region, sector/;

parameter chk_co2	check co2 balance;

set taxes different types of taxes for revenue calculation	/
		subbet,subxbet,tl, tkm, tkx, tkelbs, tkmegt, tkxegt, tkmbet, tkxbet,
		tym, tyx, tymegt, tyxegt, tymbet, tyxbet, tyelbs,
		ta, tm, ctax
/
;

parameter dkegt_shr	updated capital input shares for vintaging;

parameter revenue	tax revenue;

parameter wdecomp	welfare decomposition;
parameter pexp		expenditure price index;
parameter pinc		income price index;
parameter r_gdp		gdp decomposition;
parameter r_elec	electricity reporting;
parameter chk_bres	check bres parameter;

alias(u,*);


* declare reporting parameters for storage
parameter reph	household reporting storage;
parameter rep   core value reporting storage;

* Gini coefficient parameters
parameters
	w_inc	welfare - income approach
	popall	population across regions
	p_shr	cumulative population share by household
	i_shr	cumulative income share by household
	pd_shr	bin-specific hh population share
	id_shr	bin-specific hh income share
	gini	gini coefficient
	lorenz	area under lorenz curve
;

parameter chk_rsco2	check co2;

* * load parameters from bau case for comparison
* * or load for establishing bau exogenous forcing
parameter reph_bau	household values from bau;
parameter rep_bau 	load values from bau;
parameter wdecomp_bau	bau welfare decomposition;
parameter r_gdp_bau 	bau gdp;
parameter emissions_bau	bau emissions;
parameter revenue_bau	bau tax revenue;
parameter r_elec_bau	bau electricity;

parameter rep_pin	store parameters for pin;
parameter rep_pin_bau	store (load) parameters for pin bau;
parameter iterpin_adj_yr_bau	bau cost side tfp ele adjustment for pin;

parameter egtmod_chk;
parameter chk_marg;
parameter adj_egt(r,egt)	adjustment factor for iterative pin;
parameter iterdiff	difference between target and model value;
parameter sse_iterdiff;
parameter avg_iterrat;
parameter max_iterrat;
parameter max_iterdiff;
parameter wt_iterdiff;
parameter wt_iterrat;

parameter chk_bau_rep;

parameter load_tint;

* !!!! clean up these switches - make it so that swloadval and swloaditval must be used separately
* ---- rather than both required
$if %swloadval%==0     $goto skiploadrepbau

* load benchmark BaU case
$gdxin "%gdxdir%mgeout_%rmap%_%bauscn%.gdx"

$load rep_bau=rep
$load reph_bau=reph
$load wdecomp_bau=wdecomp
$load r_gdp_bau=r_gdp
$load emissions_bau=emissions
$load revenue_bau=revenue
$load r_elec_bau=r_elec
* $load rep_pin_bau=rep_pin


$gdxin
$label skiploadrepbau


$if %swloaditval%==0     $goto skiploadrepbauit

$gdxin "%gdxdir%mgeout_%rmap%_%bauscn%.gdx"
$load iterpin_adj_yr_bau=iterpin_adj_yr
$load rep_pin_bau=rep_pin
$load rep_bau=rep
$load reph_bau=reph
$load wdecomp_bau=wdecomp
$load r_gdp_bau=r_gdp
$load emissions_bau=emissions
$load revenue_bau=revenue
$load r_elec_bau=r_elec

$gdxin

$label skiploadrepbauit

* initialize bau values used in counterfactuals
parameters
	egtrate_bau
	egtmod_bau
	bse_bau
	emit_bau
*	elerate_bau
;	

rep_pin_bau(r,s,egt,yr,"EGTRATE","%bauscn%")$[(not swloadit)]=0;
rep_pin_bau(r,s,egt,yr,"EGTMOD","%bauscn%")$[(not swloadit)]=0;
rep_pin_bau(r,"fr",egt,yr,"BSE","%bauscn%")$[(not swloadit)]=0;

*rep_pin_bau(r,g,"all",yr,"ELERATE","%bauscn%")$[(not swload)]=0;

iterpin_adj_yr_bau(r,egt,yr)$[(not swloadit)] = 1;
rep_pin_bau(r,"ele",egt,yr,"TFPADJ","%bauscn%")=iterpin_adj_yr_bau(r,egt,yr);
iterpin_adj_yr(r,egt,yr)$[swloadit] = iterpin_adj_yr_bau(r,egt,yr);
emit_bau(r,sfd,yr) = 0;
rep_bau(r,sfd,yr,"DCO2_SECT","%bauscn%")$[(not swload)$(not swloadit)]=0;
emit_bau(r,sfd,yr)$[swloadit] = rep_bau(r,sfd,yr,"DCO2_SECT","%bauscn%");


*------------------------------------------------------------------------
* Post-benchmark year solve loop to store and update for next year
*------------------------------------------------------------------------

loop(t$(t.val eq %bmkyr%),

* Store benchmark year parameters
$include loop_store_vint.gms

* load bau pin values for next year
* !!!! currently tfp pin doesn't get used, but in future will need separate swload switch for this
* ---- or some way to store pinned values regardless of pin method so that a single switch can handle
egtrate_bau(r,s,egt)$[swloadit] = rep_pin_bau(r,s,egt,t+1,"EGTRATE","%bauscn%");
egtmod_bau(r,s,egt)$[swloadit] = rep_pin_bau(r,s,egt,t+1,"EGTMOD","%bauscn%");
bse_bau(r,"fr",egt)$[(swloadit)] = rep_pin_bau(r,"fr",egt,t+1,"BSE","%bauscn%");

* update bse
bse(r,"fr",egt)$[(swloadit)] = bse_bau(r,"fr",egt);
display bse;

EGTRATE.fx(r,s,egt)$[(not swsspin)] = 0;
EGTRATE.fx(r,s,egt)$[swloadit] = egtrate_bau(r,s,egt);

* close yr loop
);

*------------------------------------------------------------------------
* declare initial parameters for decarbonization
*------------------------------------------------------------------------

parameter capyr year cap begins;
capyr=%capyrval%;

parameter capendyr end year cap;
capendyr=%capendyrval%;
capendyr$[(capendyr ge %endyr%)] = %endyr%;

parameter totyr total years in time horizon for cap;
totyr = capendyr-capyr+1;
totyr$[(totyr<0)]=0;

parameter yrint_shr share of total years for single interval;
yrint_shr$[(totyr>0)] = 1/totyr;
yrint_shr$[(totyr=0)] = 0;

parameter carblim(yr)   emissions limit for the loop year;
parameter carb0capyr(r)     endowment in first year of cap;
carb0capyr(r) = carb0(r);
carblim(yr)=1;

parameter co2basecapyr(r,sfd)	endowment in first year of cap sector specific;
co2basecapyr(r,sfd) = co2base(r,sfd);
