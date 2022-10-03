$stitle initialize vintaging production parameters


*------------------------------------------------------------------------
* Vintaging sets
*------------------------------------------------------------------------


* !!!! vintaging has multiple options to choose from, though not fully scalable yet
* !!!! build in control flow to choose with a switch
* set v	vintages	/v1*v20/;
* set v	vintages	/v1*v3/;
set v	vintages	/v1/;


set vf(v)	first vintage;
set vl(v)	last vintage;
vf(v) = yes$[(ord(v) eq 1)];
vl(v) = yes$[(ord(v) eq card(v))];

display vf,vl;

alias(v,vv);

set v_act 		active vintages;
set vbs_act 	active backstop vintages;
set vegt_act 	active vintages - ele;
set vbet_act 	active backstop vintages - ele;
set	vsect(s)		sectors with vintage structure;

* no vintaging for fossil sectors
* !!!! make sure to update this elsewhere, such as ks_x(r,s)
vsect(s)$(not xe(s)) = yes;

parameters
	x_shr(r,s)			benchmark share of extant vintage
	xvt_shr(s,yr)	share of new (malleable) vintage frozen each period

	xegt_shr(r,s,egt)	benchmark share of extant vintage
	xvtegt_shr(s,egt,yr)	electricity share of new frozen

	x_oshr(r,s,v)			extant output production share by vintage
	xegt_oshr(r,s,egt,v)	extant output production share by vintage electricity
;

parameter	chk_costbal;

parameters
	v_trk		tracking for non electricity vintages
	vegt_trk	tracking for conventional electricity vintages
	vbet_trk	tracking for backstop renewable electricity vintages
;


*------------------------------------------------------------------------
* tracking for intermediate vintaging where mixing required
*------------------------------------------------------------------------

* !!!! add global option for age %ageval%
$eval genyr %bmkyr%-30

set ayrs	age year combo 	/%genyr%*%endyr%/;

* track the age of the vintage - assumed uniform for now
set av	age of capital	/1*30/;
alias(av,avv);

set avf(av)	first vintage;
set avl(av)	last vintage;
avf(av) = yes$[(ord(av) eq 1)];
avl(av) = yes$[(ord(av) eq card(av))];

scalar	lifetime	life of capital asset in years;
lifetime = card(av);

parameter vinterval(v)	vintage interval;
vinterval(v) = lifetime/card(v);

parameter diffinterval(v);
diffinterval(v) = vinterval(v) - floor(vinterval(v));
* lower integer for interval if not last vintage
vinterval(v)$[(not vl(v))] = floor(vinterval(v));
* last vintage adds excess from round-down in other vintages
vinterval(v)$[vl(v)] = vinterval(v) + sum(vv$(not vl(vv)),diffinterval(vv));

display lifetime, vinterval;

parameter
	av_trk		tracking of vintages with age
	avegt_trk	tracking of vintages with age
;

set mapav(av,v)	mapping of ages to vintages;
set mapnewavyr(lyr,yr,av,v)	mapping of ages to vintages for new capital built after 2017;
set mapavyr(ayrs,yr,av,v)	mapping of ages to vintages;
set mapoldavyr(ayrs,yr,av,v)	mapping of ages to vintages old capital;

mapav(av,v)$[(not vl(v))$(av.val gt ((ord(v)-1)*vinterval(v)))$(av.val le ((ord(v)-1)*vinterval(v)+vinterval(v)))] = yes;
mapav(av,v)$[(vl(v))$(av.val gt ((ord(v)-1)*vinterval(v-1)))$(av.val le ((ord(v)-1)*vinterval(v-1)+vinterval(v)))] = yes;
mapnewavyr(lyr,yr,av,v)$[(av.val eq (yr.val-lyr.val))$mapav(av,v)] = yes;
mapavyr(ayrs,yr,av,v)$[(av.val eq (yr.val-ayrs.val))$mapav(av,v)] = yes;
mapoldavyr(ayrs,yr,av,v)$[(av.val eq (yr.val-ayrs.val))$(ayrs.val < %bmkyr%)$mapav(av,v)] = yes;

* $exit

parameters
	x_oshr_av(r,s,av)			extant output production share by age
	xegt_oshr_av(r,s,egt,av)	extant output production share by age electricity
;


*------------------------------------------------------------------------
* subsidy parameter population
*------------------------------------------------------------------------

* !!!! clean this up - lots of unused 
* !!!! will need to be updated for consistency flexible vintaging
parameters
	act_subxbet(r,s,egt,v,yr)
	act_subxbet2(r,s,egt,v,yr,yr)	tracking active subsidy
	subxbet(r,s,egt,v)	subsidy for extant
	subxbetyr(r,s,egt,v,yr)	subsidy for extant tracked by year
	subxbetyrmix(r,s,egt,v,yr)	mixed subsidy tracked by year
	subxbetmix(r,s,egt,v)	mixed subsidy tracked by year
	capweight	capital weight for a year
	iterx_adjyr	mixed vintage iteration adjustment by year
	iterx_adj	mixed vintage iteration adjustment
;

* make set for active subsidy by vintage and year
act_subxbet(r,s,egt,v,yr) = no;
act_subxbet2(r,s,egt,v,lyr,yr) = no;

if(swsubegt=1,
loop(yr,
if(yr.val > subyrstart,
act_subxbet(r,s,egt,v,yr)$(ord(v) le (yr.val-subyrstart)) = yes;
act_subxbet2(r,s,egt,v,lyr,yr)$[((yr.val-lyr.val) le (yr.val-subyrstart))$(lyr.val > subyrstart)] = yes;
act_subxbet2(r,s,egt,v,lyr,yr)$[((yr.val-lyr.val) ge (subterm+1))$(lyr.val > subyrstart)] = no;
act_subxbet2(r,s,egt,v,lyr,yr)$[(lyr.val>subyrend)] = no;
);
if(yr.val > subyrend,
act_subxbet(r,s,egt,v,yr)$(ord(v) le (yr.val-subyrend)) = no;
act_subxbet2(r,s,egt,v,lyr,yr)$[(lyr.val>subyrend)] = no;
);
);
act_subxbet2(r,s,egt,v,lyr,yr)$[(lyr.val>yr.val)] = no;
act_subxbet2(r,s,egt,v,lyr,yr)$[(not vgen(egt))] = no;
);

subxbet(r,s,egt,v) = 0;
* subxbetyr(r,s,egt,v,yr)$act_subxbet(r,s,egt,v,yr) = -subrate;

display act_subxbet, act_subxbet2;
* $exit

*------------------------------------------------------------------------
* Conventional Extant Vintage structure
*------------------------------------------------------------------------

* extant vintage structure
parameters
* value
	x_id(r,g,s,v)	extant vintage intermediate input demand
	x_ld(r,s,v)		extant vintage labor demand
	x_kd(r,s,v)		extant vintage capital demand
	x_frd(r,s,v)	extant vintage fixed factor resource demand
	x_co2d(r,g,s,v)	extant vintage demand for co2
	x_k(r,s,v)		extant vintage capital endowment
	x_fr(r,s,v)		extant vintage fixed factor endowment
	x_ys(r,s,g,v)
* share - input coefficient
	x_id_in(r,g,s,v)	extant vintage intermediate input demand
	x_ld_in(r,s,v)		extant vintage labor demand
	x_kd_in(r,s,v)		extant vintage capital demand
	x_frd_in(r,s,v)	extant vintage fixed factor resource demand
	x_co2d_in(r,g,s,v)	extant vintage demand for co2
	x_k_in(r,s,v)		extant vintage capital endowment
	x_fr_in(r,s,v)		extant vintage fixed factor endowment
	x_ys_out(r,s,g,v)
;

* extant conventional backstop structure - coefficients
parameters
* value
	xbs_id(r,g,s,v)		extant vintage intermediate input demand - backstop
	xbs_ld(r,s,v)		extant vintage labor demand - backstop
	xbs_kd(r,s,v)		extant vintage capital demand - backstop
	xbs_frd(r,s,v)		extant vintage fixed factor resource demand - backstop
	xbs_k(r,s,v)		extant vintage capital endowment - backstop
	xbs_fr(r,s,v)		extant vintage fixed factor endowment - backstop

* share - input coefficient
	xbs_id_in(r,g,s,v)		extant vintage intermediate input demand - backstop
	xbs_ld_in(r,s,v)		extant vintage labor demand - backstop
	xbs_kd_in(r,s,v)		extant vintage capital demand - backstop
	xbs_frd_in(r,s,v)		extant vintage fixed factor resource demand - backstop
	xbs_k_in(r,s,v)		extant vintage capital endowment - backstop
	xbs_fr_in(r,s,v)		extant vintage fixed factor endowment - backstop

;


*------------------------------------------------------------------------
* Electricity Extant Vintage structure
*------------------------------------------------------------------------

* extant electricity generation structure
parameters
*value
	xegt_id(r,g,s,egt,v)	extant vintage intermediate input demand - egt electricity generation
	xegt_ld(r,s,egt,v)		extant vintage labor demand - egt electricity generation
	xegt_kd(r,s,egt,v)		extant vintage capital demand - egt electricity generation
	xegt_frd(r,s,egt,v)		extant vintage fixed factor resource demand - egt electricity generation
	xegt_co2d(r,g,s,egt,v)	extant vintage demand for co2
	xegt_k(r,s,egt,v)		extant vintage capital endowment - egt electricity generation
	xegt_fr(r,s,egt,v)		extant vintage fixed factor endowment - egt electricity generation
	xegt_vatot(r,s,egt,v)	extant vintage value added
	xegt_ys(r,s,egt,g,v)
*share - input coefficient
	xegt_id_in(r,g,s,egt,v)	extant vintage intermediate input demand - egt electricity generation
	xegt_ld_in(r,s,egt,v)		extant vintage labor demand - egt electricity generation
	xegt_kd_in(r,s,egt,v)		extant vintage capital demand - egt electricity generation
	xegt_frd_in(r,s,egt,v)		extant vintage fixed factor resource demand - egt electricity generation
	xegt_co2d_in(r,g,s,egt,v)	extant vintage demand for co2
	xegt_k_in(r,s,egt,v)		extant vintage capital endowment - egt electricity generation
	xegt_fr_in(r,s,egt,v)		extant vintage fixed factor endowment - egt electricity generation
	xegt_vatot_in(r,s,egt,v)	extant vintage value added
	xegt_ys_out(r,s,egt,g,v)
;

* extant electricity generation structure - backstop coefficients
parameters
*value
	xbet_id(r,g,s,egt,v)	extant vintage intermediate input demand - egt electricity generation backstop
	xbet_ld(r,s,egt,v)		extant vintage labor demand - egt electricity generation backstop
	xbet_kd(r,s,egt,v)		extant vintage capital demand - egt electricity generation backstop
	xbet_frd(r,s,egt,v)		extant vintage fixed factor resource demand - egt electricity generation backstop
	xbet_k(r,s,egt,v)		extant vintage capital endowment - egt electricity generation backstop
	xbet_fr(r,s,egt,v)		extant vintage fixed factor endowment - egt electricity generation backstop
	xbet_ys(r,s,egt,g,v)

*share - input coefficient
	xbet_id_in(r,g,s,egt,v)		extant vintage intermediate input demand - egt electricity generation backstop
	xbet_ld_in(r,s,egt,v)		extant vintage labor demand - egt electricity generation backstop
	xbet_kd_in(r,s,egt,v)		extant vintage capital demand - egt electricity generation backstop
	xbet_frd_in(r,s,egt,v)		extant vintage fixed factor resource demand - egt electricity generation backstop
	xbet_k_in(r,s,egt,v)		extant vintage capital endowment - egt electricity generation backstop
	xbet_fr_in(r,s,egt,v)		extant vintage fixed factor endowment - egt electricity generation backstop
	xbet_ys_out(r,s,egt,g,v)
;


*------------------------------------------------------------------------
* Initialize vintage filtering / exception handling 
*------------------------------------------------------------------------

v_act(r,s) = no;
vbs_act(r,s) = no;
vegt_act(r,s,egt) = no;
vbet_act(r,s,egt) = no;

* activate conventional vintaging
v_act(r,s)$ks_x(r,s) = yes;
vegt_act(r,s,egt)$[ksxegt0(r,s,egt)$y_egt(s)$(not vgen(egt))] = yes;
vbet_act(r,s,egt)$[y_(r,s)$vgen(egt)$y_egt(s)$thetaxegt(s,egt)] = yes;

*------------------------------------------------------------------------
* Initialize vintage benchmark inputs to zero
*------------------------------------------------------------------------

* extant conventional backstop structure
x_id(r,g,s,v) = 0;
x_ld(r,s,v) = 0;
x_kd(r,s,v) = 0;
x_frd(r,s,v) = 0;
x_co2d(r,g,s,v) = 0;
x_k(r,s,v) = 0;
x_fr(r,s,v) = 0;

x_id_in(r,g,s,v) = 0;
x_ld_in(r,s,v) = 0;
x_kd_in(r,s,v) = 0;
x_frd_in(r,s,v) = 0;
x_co2d_in(r,g,s,v) = 0;
x_k_in(r,s,v) = 0;
x_fr_in(r,s,v) = 0;

* extant conventional structure - backstop coefficients
xbs_id(r,g,s,v) = 0;
xbs_ld(r,s,v) = 0;
xbs_kd(r,s,v) = 0;
xbs_frd(r,s,v) = 0;
xbs_k(r,s,v) = 0;
xbs_fr(r,s,v) = 0;

xbs_id_in(r,g,s,v) = 0;
xbs_ld_in(r,s,v) = 0;
xbs_kd_in(r,s,v) = 0;
xbs_frd_in(r,s,v) = 0;
xbs_k_in(r,s,v) = 0;
xbs_fr_in(r,s,v) = 0;

* extant electricity generation structure
xegt_id(r,g,s,egt,v) = 0;
xegt_ld(r,s,egt,v) = 0;
xegt_kd(r,s,egt,v) = 0;
xegt_frd(r,s,egt,v) = 0;
xegt_co2d(r,g,s,egt,v) = 0;
xegt_k(r,s,egt,v) = 0;
xegt_fr(r,s,egt,v) = 0;
xegt_vatot(r,s,egt,v) = 0;

xegt_id_in(r,g,s,egt,v) = 0;
xegt_ld_in(r,s,egt,v) = 0;
xegt_kd_in(r,s,egt,v) = 0;
xegt_frd_in(r,s,egt,v) = 0;
xegt_co2d_in(r,g,s,egt,v) = 0;
xegt_k_in(r,s,egt,v) = 0;
xegt_fr_in(r,s,egt,v) = 0;
xegt_vatot_in(r,s,egt,v) = 0;

* extant electricity generation structure - backstop coefficients
xbet_id(r,g,s,egt,v) = 0;
xbet_ld(r,s,egt,v) = 0;
xbet_kd(r,s,egt,v) = 0;
xbet_frd(r,s,egt,v) = 0;
xbet_k(r,s,egt,v) = 0;
xbet_fr(r,s,egt,v) = 0;

xbet_id_in(r,g,s,egt,v) = 0;
xbet_ld_in(r,s,egt,v) = 0;
xbet_kd_in(r,s,egt,v) = 0;
xbet_frd_in(r,s,egt,v) = 0;
xbet_k_in(r,s,egt,v) = 0;
xbet_fr_in(r,s,egt,v) = 0;

*------------------------------------------------------------------------
* Initialize active vintages in base year
*------------------------------------------------------------------------

* initial benchmark share
x_shr(r,s) = thetax(r,s);
xegt_shr(r,s,egt) = thetaxegt(s,egt);

* malleable frozen share
xvt_shr(s,yr) = %thetaxval%;
xvtegt_shr(s,egt,yr) = thetaxegt(s,egt);


* extant vintage output share distribution
* !!!! Flexible Vintaging update needed: could be first calculated based on "av", then redeclared across "v"
* ---- which can then be used to track pre-existing asset ages separately
x_oshr(r,s,v)$[v_act(r,s)] = srv**(ord(v)*vinterval(v))/sum(v.local,srv**(ord(v)*vinterval(v)));
xegt_oshr(r,s,egt,v)$[vegt_act(r,s,egt)] = srv**(ord(v)*vinterval(v))/sum(v.local,srv**(ord(v)*vinterval(v)));
xegt_oshr(r,s,egt,v)$[vbet_act(r,s,egt)] = srv**(ord(v)*vinterval(v))/sum(v.local,srv**(ord(v)*vinterval(v)));

x_oshr_av(r,s,av)$[v_act(r,s)] = srv**ord(av)/sum(av.local,srv**ord(av));
xegt_oshr_av(r,s,egt,av)$[vegt_act(r,s,egt)] = srv**ord(av)/sum(av.local,srv**ord(av));
xegt_oshr_av(r,s,egt,av)$[vbet_act(r,s,egt)] = srv**ord(av)/sum(av.local,srv**ord(av));

x_oshr(r,s,v)$[v_act(r,s)] = sum(av$mapav(av,v),x_oshr_av(r,s,av));
xegt_oshr(r,s,egt,v)$[vegt_act(r,s,egt)] = sum(av$mapav(av,v),xegt_oshr_av(r,s,egt,av));
xegt_oshr(r,s,egt,v)$[vbet_act(r,s,egt)] = sum(av$mapav(av,v),xegt_oshr_av(r,s,egt,av));

display mapav, mapnewavyr, mapoldavyr, mapavyr, ayrs;
execute_unload "maps.gdx", mapav, mapnewavyr, mapoldavyr, mapavyr, ayrs, x_oshr, xegt_oshr, x_oshr_av, xegt_oshr_av;
* $exit
* !!!! stopped here on flexible vintaging for now !!!!

* input initialization

* extant conventional backstop structure
x_id(r,g,s,v)$[v_act(r,s)] = id0(r,g,s);
x_ld(r,s,v)$[v_act(r,s)] = ld0(r,s);
x_kd(r,s,v)$[v_act(r,s)] = kd0(r,s);
x_frd(r,s,v)$[v_act(r,s)] = fr0(r,s);
x_co2d(r,g,s,v)$[v_act(r,s)] = dcb0(r,g,s);
x_k(r,s,v)$[v_act(r,s)] = ks_x(r,s)*x_oshr(r,s,v);
x_fr(r,s,v)$[v_act(r,s)] = fr_x(r,s)*x_oshr(r,s,v);

x_id_in(r,g,s,v)$[v_act(r,s)] = id0(r,g,s)/(sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
x_ld_in(r,s,v)$[v_act(r,s)] = ld0(r,s)/(sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
x_kd_in(r,s,v)$[v_act(r,s)] = (kd0(r,s)/(sum(g.local,ys0(r,s,g))*(1-ty0(r,s))));
x_frd_in(r,s,v)$[v_act(r,s)] = (fr0(r,s)/(sum(g.local,ys0(r,s,g))*(1-ty0(r,s))));

* ---- notes on co2 emissions for reference ----
* x_co2d_in(r,g,s,v)$[v_act(r,s)] = dcb0(r,g,s)/(sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
* * parameter cco2(r,g,*)   co2 emissions coefficient for region r fuel g sector s;
* * cco2(r,g,s) = 0;
* * cco2(r,g,s)$[id0(r,g,s)] = dcb0(r,g,s)/id0(r,g,s);
* * cco2(r,g,"fd")$[cd0(r,g)] = dcb0(r,g,"fd")/cd0(r,g);
x_co2d_in(r,g,s,v)$[v_act(r,s)] = cco2(r,g,s)*x_id_in(r,g,s,v);

x_k_in(r,s,v)$[v_act(r,s)] = ks_x(r,s)*x_oshr(r,s,v);
x_fr_in(r,s,v)$[v_act(r,s)] = fr_x(r,s)*x_oshr(r,s,v);

x_ys_out(r,s,g,v)$[v_act(r,s)] = (ys0(r,s,g)/sum(gg,ys0(r,s,gg)))/(1-ty0(r,s));

chk_costbal(r,s,v,"val")$[v_act(r,s)] = sum(g,ys0(r,s,g))*(1-ty0(r,s))
	- sum(g,x_id(r,g,s,v))
	- x_ld(r,s,v)
	- x_kd(r,s,v)*(1+tk0(r))
	- x_frd(r,s,v)*(1+tk0(r))
;

chk_costbal(r,s,v,"shr")$[v_act(r,s)] = sum(g,x_ys_out(r,s,g,v))*(1-ty0(r,s))
	- sum(g,x_id_in(r,g,s,v))
	- x_ld_in(r,s,v)
	- x_kd_in(r,s,v)*(1+tk0(r))
	- x_frd_in(r,s,v)*(1+tk0(r))
;

chk_costbal(r,s,v,"out")$[v_act(r,s)] = sum(g,x_ys_out(r,s,g,v))*(1-ty0(r,s))
;


display chk_costbal;


* extant conventional structure - backstop coefficients
xbs_id(r,g,s,v) = 0;
xbs_ld(r,s,v) = 0;
xbs_kd(r,s,v) = 0;
xbs_frd(r,s,v) = 0;
xbs_k(r,s,v) = 0;
xbs_fr(r,s,v) = 0;

* extant electricity generation structure
xegt_id(r,g,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = ibar_gen0(r,g,egt);
xegt_ld(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = fbar_gen0(r,"l",egt);
xegt_kd(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = fbar_gen0(r,"k",egt);
xegt_vatot(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = xegt_ld(r,s,egt,v)+xegt_kd(r,s,egt,v)*(1+tk0(r));
xegt_frd(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = fbar_gen0(r,"fr",egt);

xegt_co2d(r,g,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)$(sum(egt.local,ibar_gen0(r,g,egt)))] = (dcb0(r,g,s)*ibar_gen0(r,g,egt)/sum(egt.local,ibar_gen0(r,g,egt)));

xegt_k(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = ksxegt(r,s,egt)*xegt_oshr(r,s,egt,v);
xegt_fr(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = frxegt(r,s,egt)*xegt_oshr(r,s,egt,v);

xegt_id_in(r,g,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = ibar_gen0(r,g,egt)/(obar_gen0(r,egt)*(1-ty0(r,s)));
xegt_ld_in(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = fbar_gen0(r,"l",egt)/(obar_gen0(r,egt)*(1-ty0(r,s)));
xegt_kd_in(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = (fbar_gen0(r,"k",egt)/(obar_gen0(r,egt)*(1-ty0(r,s))));
xegt_vatot_in(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = (xegt_ld(r,s,egt,v)+xegt_kd(r,s,egt,v)*(1+tk0(r)))/(obar_gen0(r,egt)*(1-ty0(r,s)));
xegt_frd_in(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = (fbar_gen0(r,"fr",egt)/(obar_gen0(r,egt)*(1-ty0(r,s))));

xegt_co2d_in(r,g,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] =
	cco2egt(r,g,s,egt)*xegt_id_in(r,g,s,egt,v);

xegt_k_in(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = ksxegt(r,s,egt)*xegt_oshr(r,s,egt,v);
xegt_fr_in(r,s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)] = frxegt(r,s,egt)*xegt_oshr(r,s,egt,v);

xegt_ys_out(r,s,egt,g,v)$[y_egt(s)$vegt_act(r,s,egt)] = (ys0(r,s,g)/sum(gg,ys0(r,s,gg)))/(1-ty0(r,s));


* extant electricity generation structure - backstop coefficients

xbet_id_in(r,g,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = cs_bet(r,g,egt)*bsfact(r,egt);
xbet_ld_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = cs_bet(r,"l",egt)*bsfact(r,egt);
xbet_kd_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = (cs_bet(r,"k",egt)/(1+tk0(r)))*bsfact(r,egt);
xbet_frd_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = (cs_bet(r,"fr",egt)/(1+tk0(r)))*bsfact(r,egt);
xbet_k_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = max(1e-6,0);
xbet_fr_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = 0;

xbet_id_in(r,g,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = cs_egt(r,g,egt);
xbet_ld_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = cs_egt(r,"l",egt);
xbet_kd_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = (cs_egt(r,"k",egt)/(1+tk0(r)));
xbet_frd_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = (cs_egt(r,"fr",egt)/(1+tk0(r)));
xbet_k_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = max(0,ksxegt(r,s,egt)*xegt_oshr(r,s,egt,v));
xbet_fr_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = frxegt(r,s,egt)*xegt_oshr(r,s,egt,v);

xbet_ys_out(r,s,egt,g,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = (os_egt(r,egt)/(1-ty0(r,s)))*(ys0(r,s,g)/sum(g.local,ys0(r,s,g)));
xbet_ys_out(r,s,egt,g,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = (os_bet(r,egt)/(1-ty0(r,s)))*(ys0(r,s,g)/sum(g.local,ys0(r,s,g)));

xbet_id(r,g,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = cs_bet(r,g,egt)*0;
xbet_ld(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = cs_bet(r,"l",egt)*0;
xbet_kd(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = (cs_bet(r,"k",egt)/(1+tk0(r)))*0;
xbet_frd(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = (cs_bet(r,"fr",egt)/(1+tk0(r)))*0;
xbet_k(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = max(1e-6,0);
xbet_fr(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)] = 0;

xbet_id(r,g,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = cs_egt(r,g,egt)*obar_gen0(r,egt)*(1-ty0(r,s));
xbet_ld(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = cs_egt(r,"l",egt)*obar_gen0(r,egt)*(1-ty0(r,s));
xbet_kd(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = (cs_egt(r,"k",egt)/(1+tk0(r)))*obar_gen0(r,egt)*(1-ty0(r,s));
xbet_frd(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = (cs_egt(r,"fr",egt)/(1+tk0(r)))*obar_gen0(r,egt)*(1-ty0(r,s));
xbet_k(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = max(0,ksxegt(r,s,egt)*xegt_oshr(r,s,egt,v));
xbet_fr(r,s,egt,v)$[vbet_act(r,s,egt)$os_egt(r,egt)] = frxegt(r,s,egt)*xegt_oshr(r,s,egt,v);

xbet_fr(r,s,egt,v)$[xbet_kd_in(r,s,egt,v)] = xbet_k(r,s,egt,v)*xbet_frd_in(r,s,egt,v)/xbet_kd_in(r,s,egt,v);
* xbet_fr(r,s,egt,v) = max(1e-6,xbet_fr(r,s,egt,v));

* store tracking

loop(yr$[(yr.val eq %bmkyr%)],

v_trk(r,g,s,v,yr,"id") = x_id_in(r,g,s,v);
vegt_trk(r,g,s,egt,v,yr,"id") = xegt_id_in(r,g,s,egt,v);
vbet_trk(r,g,s,egt,v,yr,"id") = xbet_id_in(r,g,s,egt,v);

v_trk(r,"*",s,v,yr,"ld") = x_ld_in(r,s,v);
vegt_trk(r,"*",s,egt,v,yr,"ld") = xegt_ld_in(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,yr,"ld") = xbet_ld_in(r,s,egt,v);

v_trk(r,"*",s,v,yr,"kd") = x_kd_in(r,s,v);
vegt_trk(r,"*",s,egt,v,yr,"kd") = xegt_kd_in(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,yr,"kd") = xbet_kd_in(r,s,egt,v);

v_trk(r,"*",s,v,yr,"frd") = x_frd_in(r,s,v);
vegt_trk(r,"*",s,egt,v,yr,"frd") = xegt_frd_in(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,yr,"frd") = xbet_frd_in(r,s,egt,v);

v_trk(r,"*",s,v,yr,"k") = x_k(r,s,v);
vegt_trk(r,"*",s,egt,v,yr,"k") = xegt_k(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,yr,"k") = xbet_k(r,s,egt,v);

v_trk(r,"*",s,v,yr,"fr") = x_fr(r,s,v);
vegt_trk(r,"*",s,egt,v,yr,"fr") = xegt_fr(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,yr,"fr") = xbet_fr(r,s,egt,v);

* v_trk(r,"*",s,g,v,yr,"ys") = x_ys_out(r,s,g,v);
* vegt_trk(r,"*",s,egt,g,v,yr,"ys") = xegt_ys_out(r,s,egt,g,v);
* vbet_trk(r,"*",s,egt,g,v,yr,"ys") = xbet_ys_out(r,s,egt,g,v);

);


*------------------------------------------------------------------------
* update household capital endowment to bring into separate demand block for extant
*------------------------------------------------------------------------

* household share of capital -- used to bring extant capital into RA instead of NYSE
parameter ke0_shr(r,h)	household share of capital;
ke0_shr(r,h) = ke0(r,h)/sum(h.local,ke0(r,h));

parameter ke0_m(r)	household capital endowment summed over households (non-extant);
ke0_m(r) = sum(h,ke0(r,h))
	- sum((s,v)$[(not y_egt(s))],x_k(r,s,v))
	- sum((s,egt,v)$[y_egt(s)],xegt_k(r,s,egt,v))
	- sum((s,egt,v)$[y_egt(s)],xbet_k(r,s,egt,v)+xbet_fr(r,s,egt,v));

parameter ke0_xs(r,s)	household capital endowment summed over households (extant);
ke0_xs(r,s) = sum((v),x_k(r,s,v))$[(not y_egt(s))]
	+ sum((egt,v),xegt_k(r,s,egt,v))$[y_egt(s)]
	+ sum((egt,v),xbet_k(r,s,egt,v)+xbet_fr(r,s,egt,v))$[(y_egt(s))];

parameter ke0_x(r)	household capital endowment summed over households (extant);
ke0_x(r) = sum(s,ke0_xs(r,s));

parameter chk_ke0;

chk_ke0(r,h,"end") = (ke0_m(r) + sum(s,ke0_xs(r,s)))*ke0_shr(r,h) - ke0(r,h);

chk_ke0("*","*","m") = sum(r,ke0_m(r))
	- sum((r,g),yh0(r,g))
	- sum(r,ks_m(r))
	- sum((r,s)$[fr_m(r,s)$xe(s)],fr_m(r,s))
	- sum((r,s)$[fr_x(r,s)$xe(s)],fr_x(r,s))
	- sum((r,egt)$[fbar_gen0(r,"fr",egt)$(not vgen(egt))],bse(r,"fr",egt))
	- sum((r,egt)$[vgen(egt)],bse(r,"fr",egt))
	- sum((r,s)$[elbs_act(r,s)],elbse(r,s))
;

display chk_ke0;