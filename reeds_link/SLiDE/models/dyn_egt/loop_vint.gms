$stitle capital updates for loop year


*------------------------------------------------------------------------
* Vintage capital endowment updates
*------------------------------------------------------------------------

* if only a single extant vintage
if (card(v) eq 1,

*------------------------------------------------------------------------
* track extant
*------------------------------------------------------------------------

v_trk(r,"*",s,v,t,"oldvk") = x_k(r,s,v)*srvt(t);

vegt_trk(r,"*",s,egt,v,t,"oldvk") = xegt_k(r,s,egt,v)*srvt(t);
* srv_trk is governed by a switch in load_pin.gms to be either variable or fixed decay rate
vegt_trk(r,"*",s,egt,v,t,"oldvk")$[coal(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t);
vegt_trk(r,"*",s,egt,v,t,"oldvk")$[ngas(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t);
vegt_trk(r,"*",s,egt,v,t,"oldvk")$[nuc(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t);
vegt_trk(r,"*",s,egt,v,t,"oldvk")$[hyd(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t);

vbet_trk(r,"*",s,egt,v,t,"oldvk") = xbet_k(r,s,egt,v)*srvt(t);

v_trk(r,"*",s,v,t,"newvk") = DKM.l(r,s)*srvt(t)*xvt_shr(s,t);
vegt_trk(r,"*",s,egt,v,t,"newvk") = DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t);
vbet_trk(r,"*",s,egt,v,t,"newvk") = DKMBET.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t);

*------------------------------------------------------------------------
* update mutable capital endowment
*------------------------------------------------------------------------

* !!!! as you increase time step you get less growth as a construct of the model
* 1) the first year can start later than 2017/2018 where there is no growth between that first year
* 2) each year the growth rate increases, so the wider the interval, the less growth you're capturing recursively

* * !!!! ensure proper updates to mutable
* newcap(r,t) = inv.l(r)*(
* * depreciated extant
* 	sum((s,v)$[(not y_egt(s))$v_act(r,s)],x_k(r,s,v)-v_trk(r,"*",s,v,t,"oldvk"))
* 	+sum((s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)],xegt_k(r,s,egt,v)-vegt_trk(r,"*",s,egt,v,t,"oldvk"))
* 	+sum((s,egt,v)$[y_egt(s)$vbet_act(r,s,egt)],xbet_k(r,s,egt,v)-vbet_trk(r,"*",s,egt,v,t,"oldvk"))
* * depreciated mutable
* *	+ ((1-srvt(t))*ks_m(r))
* 	+ ((1-srvt(t))*ks_m0(r))
* );

newcap(r,t) = (ktot0(r) - ktot0(r)*srvt(t))*inv.l(r);

display newcap;

display newcap;
*+++++++++++++++++++

* Total mutable capital: new capital, plus existing putty net of depreciation,
totalcap(r,t) = newcap(r,t)
	+ ks_m(r)*srvt(t)
	- sum(s$[v_act(r,s)],DKM.l(r,s)*srvt(t)*xvt_shr(s,t))
	- sum((s,egt)$[vegt_act(r,s,egt)],DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t))
	- sum((s,egt)$[vbet_act(r,s,egt)],DKMBET.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t))
;

*ks_m(r)*srvt(t) + (1-srvt(t))*ks_m(r)*inv.l(r)

* Update mutable capital
ks_m(r) = totalcap(r,t);
display ks_m;

*------------------------------------------------------------------------
* update vintage capital parameters
*------------------------------------------------------------------------

x_k(r,s,v)$[v_act(r,s)$vf(v)] = x_k(r,s,v)*srvt(t)
	+ DKM.l(r,s)*srvt(t)*xvt_shr(s,t)
;

xegt_k(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$coal(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t)
	+ DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t)
;

xegt_k(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$ngas(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t)
	+ DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t)
;

xegt_k(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$nuc(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t)
	+ DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t)
;

xegt_k(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$hyd(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t)
	+ DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t)
;

xegt_k(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$othc(egt)] = xegt_k(r,s,egt,v)*srvt(t)
	+ DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t)
;

xbet_k(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)] = xbet_k(r,s,egt,v)*srvt(t)
	+ DKMBET.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t)
	+ DRMBET.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t)
;

* !!!! consider tracking the fixed resource component of xbet_k separately


*------------------------------------------------------------------------
* assumptions: policy induced exogenous extant coal depreciation
*------------------------------------------------------------------------

* how to distribute exogenously depreciated extant coal... 
* option 1) 
dkegt_shr(r,egt,t,"DKEGT_R","%scn%")$[vgen(egt)$(sum((r.local,egt.local)$[vgen(egt)],rep(r,egt,t-1,"DKEGT","%scn%")))] =
	rep(r,egt,t-1,"DKEGT","%scn%")/sum((r.local,egt.local)$[vgen(egt)],rep(r,egt,t-1,"DKEGT","%scn%"));

* option 2)
dkegt_shr(r,egt,t,"DKEGT","%scn%")$[vgen(egt)$(sum((egt.local)$(vgen(egt)),rep(r,egt,t-1,"DKEGT","%scn%")))] =
	rep(r,egt,t-1,"DKEGT","%scn%")/sum((egt.local)$[vgen(egt)],rep(r,egt,t-1,"DKEGT","%scn%"));

* !!!! add better parameter definition and allow for variable exogenous adjustment here
dkegt_shr(r,egt,t,"KADD_R","%scn%")$[vgen(egt)] =
	+(0.05*sum(r.local,xegt_k(r,"ele","conv-coal","v1")))*dkegt_shr(r,egt,t,"DKEGT_R","%scn%")
;

dkegt_shr(r,egt,t,"KADD","%scn%")$[vgen(egt)] =
	+(0.05*xegt_k(r,"ele","conv-coal","v1"))*dkegt_shr(r,egt,t,"DKEGT","%scn%")
;

dkegt_shr(r,egt,"%bmkyr%","oldscale","%scn%") = 1;
dkegt_shr(r,egt,t,"oldscale","%scn%")$[xbet_k(r,"ele",egt,"v1")$vgen(egt)] =
	dkegt_shr(r,egt,t-1,"oldscale","%scn%")*(1+dkegt_shr(r,egt,t,"KADD_R","%scn%")/xbet_k(r,"ele",egt,"v1"))
;

* !!!! Currently, depreciated coal goes to mutable capital
* ---- other option is to distribute to renewables (currently that option creates solver issues)
$if %subexodep%==0 $goto skipexodep
if(swsubegt=1,
if(t.val ge subyrstart,
if(t.val le subyrend,

* exogenous extra coal extant depreciation
	xegt_k(r,s,egt,v)$coal(egt) = xegt_k(r,s,egt,v)-0.05*xegt_k(r,s,egt,v);

* * exogenous extra renewable extant capacity
* 	xbet_k(r,s,egt,v)$[vbet_act(r,s,egt)] =
* 		xbet_k(r,s,egt,v)
* *		+ dkegt_shr(r,egt,t,"KADD_R","%scn%")
* 		+ dkegt_shr(r,egt,t,"KADD","%scn%")
* ;

* update mutable stock
	ks_m(r) = ks_m(r)+sum((egt),dkegt_shr(r,egt,t,"KADD_R","%scn%"));	

* end if t le subyrend
);
* end if t ge subyrstart
);
* end if swsubegt=1
);

$label skipexodep


* lower bound on capital endowment
x_k(r,s,v)$[v_act(r,s)$vf(v)] =max(1e-5, x_k(r,s,v));
xegt_k(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)] =max(1e-5, xegt_k(r,s,egt,v));
xbet_k(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)] =max(1e-5, xbet_k(r,s,egt,v));

* store capital for tracking purposes
v_trk(r,"*",s,v,t,"k") = x_k(r,s,v);
vegt_trk(r,"*",s,egt,v,t,"k") = xegt_k(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,t,"k") = xbet_k(r,s,egt,v);


*------------------------------------------------------------------------
* determining the capital weighted subsidy rate for single extant vintage
*------------------------------------------------------------------------


*------------------------------------------------------------------------
* !!!! capital weighting needs verification of correctness with scalable time steps
* !!!! only works if tint = 1 pretty sure
*------------------------------------------------------------------------

capweight(r,s,v,egt,tt,t)$[(tt.val le t.val)$(sum(tt.local,(vbet_trk(r,"*",s,egt,v,tt,"newvk")))+(vbet_trk(r,"*",s,egt,v,"%bmkyr%","k")))] =
	((vbet_trk(r,"*",s,egt,v,tt,"newvk")*(srv**(t.val-tt.val))))
	/ (sum(tt.local,(vbet_trk(r,"*",s,egt,v,tt,"newvk"))*(srv**(t.val-tt.val)))+(vbet_trk(r,"*",s,egt,v,"%bmkyr%","k")*srv**(t.val-%bmkyr%)))
;
	
capweight(r,s,v,egt,tt,t)$[(tt.val eq %bmkyr%)$(sum(tt.local,(vbet_trk(r,"*",s,egt,v,tt,"k")))+(vbet_trk(r,"*",s,egt,v,"%bmkyr%","k")))] =
	(vbet_trk(r,"*",s,egt,v,"%bmkyr%","k")*srv**(t.val-%bmkyr%))
	/(sum(tt.local,(vbet_trk(r,"*",s,egt,v,tt,"newvk"))*(srv**(t.val-tt.val)))+(vbet_trk(r,"*",s,egt,v,"%bmkyr%","k")*srv**(t.val-%bmkyr%)))
;

capweight(r,s,v,egt,tt,t)$[(tt.val le t.val)$(sum(tt.local,(vegt_trk(r,"*",s,egt,v,tt,"newvk")))+(vegt_trk(r,"*",s,egt,v,"%bmkyr%","k")))] =
	((vegt_trk(r,"*",s,egt,v,tt,"newvk")*(srv**(t.val-tt.val))))
	/ (sum(tt.local,(vegt_trk(r,"*",s,egt,v,tt,"newvk"))*(srv**(t.val-tt.val)))+(vegt_trk(r,"*",s,egt,v,"%bmkyr%","k")*srv**(t.val-%bmkyr%)))
;
	
capweight(r,s,v,egt,tt,t)$[(tt.val eq %bmkyr%)$(sum(tt.local,(vegt_trk(r,"*",s,egt,v,tt,"k")))+(vegt_trk(r,"*",s,egt,v,"%bmkyr%","k")))] =
	(vegt_trk(r,"*",s,egt,v,"%bmkyr%","k")*srv**(t.val-%bmkyr%))
	/(sum(tt.local,(vegt_trk(r,"*",s,egt,v,tt,"newvk"))*(srv**(t.val-tt.val)))+(vegt_trk(r,"*",s,egt,v,"%bmkyr%","k")*srv**(t.val-%bmkyr%)))
;

capweight(r,s,v,egt,"%bmkyr%","%bmkyr%")$[y_egt(s)] = 1;

subxbetyr(r,s,egt,v,t) = sum(tt$[act_subxbet2(r,s,egt,v,tt,t)],-subrate*capweight(r,s,v,egt,tt,t));


*------------------------------------------------------------------------
* else --- card(v) > 1
* if more than a single extant vintage
* !!!! currently only works if 20 vintages
*------------------------------------------------------------------------

else

*------------------------------------------------------------------------
* track extant
*------------------------------------------------------------------------

v_trk(r,"*",s,v,t,"oldvk") = x_k(r,s,v)*srvt(t);

vegt_trk(r,"*",s,egt,v,t,"oldvk") = xegt_k(r,s,egt,v)*srvt(t);
vegt_trk(r,"*",s,egt,v,t,"oldvk")$[coal(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t);
vegt_trk(r,"*",s,egt,v,t,"oldvk")$[ngas(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t);
vegt_trk(r,"*",s,egt,v,t,"oldvk")$[nuc(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t);
vegt_trk(r,"*",s,egt,v,t,"oldvk")$[hyd(egt)] = xegt_k(r,s,egt,v)*srv_trk(r,egt,t);

vbet_trk(r,"*",s,egt,v,t,"oldvk") = xbet_k(r,s,egt,v)*srvt(t);

v_trk(r,"*",s,v,t,"newvk") = DKM.l(r,s)*srvt(t)*xvt_shr(s,t);
vegt_trk(r,"*",s,egt,v,t,"newvk") = DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t);
vbet_trk(r,"*",s,egt,v,t,"newvk") = DKMBET.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t);

*------------------------------------------------------------------------
* update mutable capital endowment
*------------------------------------------------------------------------

* * !!!! ensure proper updates to mutable
* newcap(r,t) = inv.l(r)*(
* * depreciated extant
* 	sum((s,v)$[(not y_egt(s))$v_act(r,s)],x_k(r,s,v)-v_trk(r,"*",s,v,t,"oldvk"))
* 	+sum((s,egt,v)$[y_egt(s)$vegt_act(r,s,egt)],xegt_k(r,s,egt,v)-vegt_trk(r,"*",s,egt,v,t,"oldvk"))
* 	+sum((s,egt,v)$[y_egt(s)$vbet_act(r,s,egt)],xbet_k(r,s,egt,v)-vbet_trk(r,"*",s,egt,v,t,"oldvk"))
* * depreciated mutable
* *	+ ((1-srvt(t))*ks_m(r))
* 	+ ((1-srvt(t))*ks_m0(r))
* );

newcap(r,t) = (ktot0(r) - ktot0(r)*srvt(t))*inv.l(r);

display newcap;
*+++++++++++++++++++

* Total mutable capital: new capital, plus existing putty net of depreciation,
totalcap(r,t) = newcap(r,t)
	+ ks_m(r)*srvt(t)
	- sum(s$[v_act(r,s)],DKM.l(r,s)*srvt(t)*xvt_shr(s,t))
	- sum((s,egt)$[vegt_act(r,s,egt)],DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t))
	- sum((s,egt)$[vbet_act(r,s,egt)],DKMBET.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t))
;

* Update mutable capital
ks_m(r) = totalcap(r,t);
display ks_m;

x_k(r,s,v+1)$[v_act(r,s)$(not vl(v+1))] = max(1e-5,x_k(r,s,v)*srvt(t));

* !!!! ensure correctness, especially of last vintage --- think something could be wrong with the 'v's here
* !!!! an issue with the outcome is that initially, all of the capital are distributed across all vintages
* ---- which causes a shock for some reason once that first piece of putty hits the final vintage
* ---- maybe just distributing that into the first and leaving all others empty would fix
x_k(r,s,v+1)$[v_act(r,s)$vl(v+1)] = max(1e-5,x_k(r,s,v)*srvt(t) + x_k(r,s,v+1)*srvt(t));

x_k(r,s,v)$[v_act(r,s)$vf(v)] = max(1e-5,DKM.l(r,s)*srvt(t)*xvt_shr(s,t));

xegt_k(r,s,egt,v+1)$[vegt_act(r,s,egt)$(not vl(v+1))] = max(1e-5,xegt_k(r,s,egt,v)*srvt(t));
xegt_k(r,s,egt,v+1)$[vegt_act(r,s,egt)$vl(v+1)] = max(1e-5,xegt_k(r,s,egt,v)*srvt(t) + xegt_k(r,s,egt,v+1)*srvt(t));
xegt_k(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)] = max(1e-5,DKMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t));
* !!!! can add depreciation rate specifics here... srvt(t)trk instead of srvt(t) for col

xbet_k(r,s,egt,v+1)$[vbet_act(r,s,egt)$(not vl(v+1))] = max(1e-5,xbet_k(r,s,egt,v)*srvt(t));
xbet_k(r,s,egt,v+1)$[vbet_act(r,s,egt)$vl(v+1)] = max(1e-5,xbet_k(r,s,egt,v)*srvt(t) + xbet_k(r,s,egt,v+1)*srvt(t));

xbet_k(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)] = max(1e-5,
	DKMBET.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t)
	+ DRMBET.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t)
);

* !!!! updates needed for subsidy rate on vintages... final vintage will still need mixing

);

*------------------------------------------------------------------------
* vintage resource endowment updates (not used)
*------------------------------------------------------------------------

* x_fr(r,s,v+1)$[v_act(r,s)$(not vl(v+1))] = x_fr(r,s,v)*srvt(t);
* x_fr(r,s,v+1)$[v_act(r,s)$vl(v+1)] = x_fr(r,s,v)*srvt(t);
* x_fr(r,s,v)$[v_act(r,s)$vf(v)] = DRM.l(r,s)*srvt(t)*xvt_shr(s,t);

* xegt_fr(r,s,egt,v+1)$[vegt_act(r,s,egt)$(not vl(v+1))] = xegt_fr(r,s,egt,v)*srvt(t);
* xegt_fr(r,s,egt,v+1)$[vegt_act(r,s,egt)$vl(v+1)] = xegt_fr(r,s,egt,v)*srvt(t);
* xegt_fr(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)] = DRMEGT.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t);

* xbet_fr(r,s,egt,v+1)$[vbet_act(r,s,egt)$(not vl(v+1))] = xbet_fr(r,s,egt,v)*srvt(t);
* xbet_fr(r,s,egt,v+1)$[vbet_act(r,s,egt)$vl(v+1)] = xbet_fr(r,s,egt,v)*srvt(t);
* xbet_fr(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)] = DRMBET.l(r,s,egt)*srvt(t)*xvtegt_shr(s,egt,t);


*------------------------------------------------------------------------
* input coefficient updates
*------------------------------------------------------------------------

if (card(v) eq 1,

* update tracking with old coefficients
v_trk(r,g,s,v,t,"oldid") = x_id_in(r,g,s,v);
vegt_trk(r,g,s,egt,v,t,"oldid") = xegt_id_in(r,g,s,egt,v);
vbet_trk(r,g,s,egt,v,t,"oldid") = xbet_id_in(r,g,s,egt,v);

v_trk(r,"*",s,v,t,"oldld") = x_ld_in(r,s,v);
vegt_trk(r,"*",s,egt,v,t,"oldld") = xegt_ld_in(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,t,"oldld") = xbet_ld_in(r,s,egt,v);

v_trk(r,"*",s,v,t,"oldkd") = x_kd_in(r,s,v);
vegt_trk(r,"*",s,egt,v,t,"oldkd") = xegt_kd_in(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,t,"oldkd") = xbet_kd_in(r,s,egt,v);

v_trk(r,"*",s,v,t,"oldfrd") = x_frd_in(r,s,v);
vegt_trk(r,"*",s,egt,v,t,"oldfrd") = xegt_frd_in(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,t,"oldfrd") = xbet_frd_in(r,s,egt,v);

* update tracking with new coefficient
v_trk(r,g,s,v,t,"newid")$[v_act(r,s)$en(g)$(YM.l(r,s))] = DIDME.l(r,g,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
v_trk(r,g,s,v,t,"newid")$[v_act(r,s)$nne(g)$(YM.l(r,s))] = DIDMM.l(r,g,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
vegt_trk(r,g,s,egt,v,t,"newid")$[vegt_act(r,s,egt)$(YMEGT.l(r,s,egt))] = DIDMEGT.l(r,g,s,egt)/(YMEGT.l(r,s,egt)*obar_gen0(r,egt)*(1-ty0(r,s)));
vbet_trk(r,g,s,egt,v,t,"newid")$[vbet_act(r,s,egt)$(YBET.l(r,s,egt))] = DIDBET.l(r,g,s,egt)/(YBET.l(r,s,egt));

v_trk(r,"*",s,v,t,"newld")$[v_act(r,s)$(YM.l(r,s))] = DLDM.l(r,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
vegt_trk(r,"*",s,egt,v,t,"newld")$[vegt_act(r,s,egt)$(YMEGT.l(r,s,egt))] = DLDMEGT.l(r,s,egt)/(YMEGT.l(r,s,egt)*obar_gen0(r,egt)*(1-ty0(r,s)));
vbet_trk(r,"*",s,egt,v,t,"newld")$[vbet_act(r,s,egt)$(YBET.l(r,s,egt))] = DLDMBET.l(r,s,egt)/(YBET.l(r,s,egt));

v_trk(r,"*",s,v,t,"newkd")$[v_act(r,s)$(YM.l(r,s))] = DKM.l(r,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
vegt_trk(r,"*",s,egt,v,t,"newkd")$[vegt_act(r,s,egt)$(YMEGT.l(r,s,egt))] = DKMEGT.l(r,s,egt)/(YMEGT.l(r,s,egt)*obar_gen0(r,egt)*(1-ty0(r,s)));
vbet_trk(r,"*",s,egt,v,t,"newkd")$[vbet_act(r,s,egt)$(YBET.l(r,s,egt))] = DKMBET.l(r,s,egt)/(YBET.l(r,s,egt));

v_trk(r,"*",s,v,t,"newfrd")$[v_act(r,s)$(YM.l(r,s))] = DRM.l(r,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));;
vegt_trk(r,"*",s,egt,v,t,"newfrd")$[vegt_act(r,s,egt)$(YMEGT.l(r,s,egt))] = DRMEGT.l(r,s,egt)/(YMEGT.l(r,s,egt)*obar_gen0(r,egt)*(1-ty0(r,s)));
vbet_trk(r,"*",s,egt,v,t,"newfrd")$[vbet_act(r,s,egt)$(YBET.l(r,s,egt))] = DRMBET.l(r,s,egt)/(YBET.l(r,s,egt));

vbet_trk(r,g,s,egt,v,t,"newid")$[vbet_act(r,s,egt)$(not YBET.l(r,s,egt))] = cs_bet(r,g,egt)*bsfact(r,egt);
vbet_trk(r,"*",s,egt,v,t,"newld")$[vbet_act(r,s,egt)$(not YBET.l(r,s,egt))] = cs_bet(r,"l",egt)*bsfact(r,egt);
vbet_trk(r,"*",s,egt,v,t,"newkd")$[vbet_act(r,s,egt)$(not YBET.l(r,s,egt))] = (cs_bet(r,"k",egt)/(1+tk0(r)))*bsfact(r,egt);
vbet_trk(r,"*",s,egt,v,t,"newfrd")$[vbet_act(r,s,egt)$(not YBET.l(r,s,egt))] = (cs_bet(r,"fr",egt)/(1+tk0(r)))*bsfact(r,egt);

*------------------------------------------------------------------------
* Update non-electricity extant inputs
*------------------------------------------------------------------------

*------------------------------------------------------------------------
* update intermediate inputs
*------------------------------------------------------------------------
x_id_in(r,g,s,v)$[en(g)$v_act(r,s)] =
	(DIDX.l(r,g,s,v)+DIDME.l(r,g,s)*xvt_shr(s,t))
	/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v))+YM.l(r,s)*xvt_shr(s,t)*sum(g.local,ys0(r,s,g)))*(1-ty0(r,s)))
;

x_id_in(r,g,s,v)$[nne(g)$v_act(r,s)] =
	(DIDX.l(r,g,s,v)+DIDMM.l(r,g,s)*xvt_shr(s,t))
	/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v))+YM.l(r,s)*xvt_shr(s,t)*sum(g.local,ys0(r,s,g)))*(1-ty0(r,s)))
;

*------------------------------------------------------------------------
* update factor demand
*------------------------------------------------------------------------

x_ld_in(r,s,v)$[v_act(r,s)] =
	(DLDX.l(r,s,v)+DLDM.l(r,s)*xvt_shr(s,t))
	/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v))+YM.l(r,s)*xvt_shr(s,t)*sum(g.local,ys0(r,s,g)))*(1-ty0(r,s)))
;
	

x_kd_in(r,s,v)$[v_act(r,s)] =
	((DKX.l(r,s,v)+DKM.l(r,s)*xvt_shr(s,t)))
	/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v))+YM.l(r,s)*xvt_shr(s,t)*sum(g.local,ys0(r,s,g)))*(1-ty0(r,s)))
;
	

x_frd_in(r,s,v)$[v_act(r,s)] =
	((DRX.l(r,s,v)+DRM.l(r,s)*xvt_shr(s,t)))
	/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v))+YM.l(r,s)*xvt_shr(s,t)*sum(g.local,ys0(r,s,g)))*(1-ty0(r,s)))
;
	
*------------------------------------------------------------------------
* update co2 demand
*------------------------------------------------------------------------

x_co2d_in(r,g,s,v)$[v_act(r,s)] = cco2(r,g,s)*x_id_in(r,g,s,v);

*------------------------------------------------------------------------
* Update Electricity extant inputs
*------------------------------------------------------------------------

*------------------------------------------------------------------------
* update intermediate inputs
*------------------------------------------------------------------------

xegt_id_in(r,g,s,egt,v)$[vegt_act(r,s,egt)$(YXEGT.l(r,s,egt,v) + YMEGT.l(r,s,egt))] =
	(DIDXEGT.l(r,g,s,egt,v)+DIDMEGT.l(r,g,s,egt)*xvtegt_shr(s,egt,t))
	/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v))+YMEGT.l(r,s,egt)*xvtegt_shr(s,egt,t)*obar_gen0(r,egt))*(1-ty0(r,s)))
;


*------------------------------------------------------------------------
* update factor demand
*------------------------------------------------------------------------

xegt_ld_in(r,s,egt,v)$[vegt_act(r,s,egt)$(YXEGT.l(r,s,egt,v) + YMEGT.l(r,s,egt))] =
	(DLDXEGT.l(r,s,egt,v)+DLDMEGT.l(r,s,egt)*xvtegt_shr(s,egt,t))
	/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v))+YMEGT.l(r,s,egt)*xvtegt_shr(s,egt,t)*obar_gen0(r,egt))*(1-ty0(r,s)))
;

xegt_kd_in(r,s,egt,v)$[vegt_act(r,s,egt)$(YXEGT.l(r,s,egt,v) + YMEGT.l(r,s,egt))] =
	(DKXEGT.l(r,s,egt,v)+DKMEGT.l(r,s,egt)*xvtegt_shr(s,egt,t))
	/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v))+YMEGT.l(r,s,egt)*xvtegt_shr(s,egt,t)*obar_gen0(r,egt))*(1-ty0(r,s)))
;

xegt_frd_in(r,s,egt,v)$[vegt_act(r,s,egt)$(YXEGT.l(r,s,egt,v) + YMEGT.l(r,s,egt))] =
	(DRXEGT.l(r,s,egt,v)+DRMEGT.l(r,s,egt)*xvtegt_shr(s,egt,t))
	/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v))+YMEGT.l(r,s,egt)*xvtegt_shr(s,egt,t)*obar_gen0(r,egt))*(1-ty0(r,s)))
;


* if empty
xegt_id_in(r,g,s,egt,v)$[vegt_act(r,s,egt)$(not (YXEGT.l(r,s,egt,v) + YMEGT.l(r,s,egt)))] =
	vegt_trk(r,g,s,egt,v,t-1,"id")
;
xegt_ld_in(r,s,egt,v)$[vegt_act(r,s,egt)$(not (YXEGT.l(r,s,egt,v) + YMEGT.l(r,s,egt)))] =
	vegt_trk(r,"*",s,egt,v,t-1,"ld")
;

xegt_kd_in(r,s,egt,v)$[vegt_act(r,s,egt)$(not (YXEGT.l(r,s,egt,v) + YMEGT.l(r,s,egt)))] =
	vegt_trk(r,"*",s,egt,v,t-1,"kd")
;

xegt_frd_in(r,s,egt,v)$[vegt_act(r,s,egt)$(not (YXEGT.l(r,s,egt,v) + YMEGT.l(r,s,egt)))] =
	vegt_trk(r,"*",s,egt,v,t-1,"frd")
;

xegt_kd_in(r,s,egt,v)$[vegt_act(r,s,egt)$(not (DKXEGT.l(r,s,egt,v) + DKMEGT.l(r,s,egt)))] =
	vegt_trk(r,"*",s,egt,v,t-1,"kd")
;


*------------------------------------------------------------------------
* update co2 demand
*------------------------------------------------------------------------

xegt_co2d_in(r,g,s,egt,v)$[vegt_act(r,s,egt)] = (cco2egt(r,g,s,egt))*xegt_id_in(r,g,s,egt,v);
* xegt_co2d_in(r,g,s,egt,v)$[vegt_act(r,s,egt)] = cco2(r,g,s)*xegt_id_in(r,g,s,egt,v);

*------------------------------------------------------------------------
* Update Electricity backstop extant inputs
*------------------------------------------------------------------------

*------------------------------------------------------------------------
* update intermediate inputs
*------------------------------------------------------------------------

xbet_id_in(r,g,s,egt,v)$[vegt_act(r,s,egt)$(YXBET.l(r,s,egt,v) + YBET.l(r,s,egt))] =
	(DIDXBET.l(r,g,s,egt,v)+DIDBET.l(r,g,s,egt)*xvtegt_shr(s,egt,t))
	/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v))+YBET.l(r,s,egt)*xvtegt_shr(s,egt,t)/(1-ty0(r,s)))*(1-ty0(r,s)))
;

*------------------------------------------------------------------------
* update factor demand
*------------------------------------------------------------------------

xbet_ld_in(r,s,egt,v)$[vegt_act(r,s,egt)$(YXBET.l(r,s,egt,v) + YBET.l(r,s,egt))] =
	(DLDXBET.l(r,s,egt,v)+DLDMBET.l(r,s,egt)*xvtegt_shr(s,egt,t))
	/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v))+YBET.l(r,s,egt)*xvtegt_shr(s,egt,t)/(1-ty0(r,s)))*(1-ty0(r,s)))
;

xbet_kd_in(r,s,egt,v)$[vegt_act(r,s,egt)$(YXBET.l(r,s,egt,v) + YBET.l(r,s,egt))] =
	(DKXBET.l(r,s,egt,v)+DKMBET.l(r,s,egt)*xvtegt_shr(s,egt,t)+(DRMBET.l(r,s,egt)*xvtegt_shr(s,egt,t)))
	/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v))+YBET.l(r,s,egt)*xvtegt_shr(s,egt,t)/(1-ty0(r,s)))*(1-ty0(r,s)))
;

xbet_frd_in(r,s,egt,v)$[vegt_act(r,s,egt)$(YXBET.l(r,s,egt,v) + YBET.l(r,s,egt))] =
*	(DRXBET.l(r,s,egt,v)+DRMBET.l(r,s,egt)*xvtegt_shr(s,egt,t))
	(DRMBET.l(r,s,egt)*xvtegt_shr(s,egt,t))
	/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v))+YBET.l(r,s,egt)*xvtegt_shr(s,egt,t)/(1-ty0(r,s)))*(1-ty0(r,s)))
;
* zero this out
xbet_frd_in(r,s,egt,v) = 0;

xbet_id_in(r,g,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)$(not (YBET.l(r,s,egt)+YXBET.l(r,s,egt,v)))] = vbet_trk(r,g,s,egt,v,t-1,"id");
xbet_ld_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)$(not (YBET.l(r,s,egt)+YXBET.l(r,s,egt,v)))] = vbet_trk(r,"*",s,egt,v,t-1,"ld");
xbet_kd_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)$(not (YBET.l(r,s,egt)+YXBET.l(r,s,egt,v)))] = vbet_trk(r,"*",s,egt,v,t-1,"kd");
xbet_frd_in(r,s,egt,v)$[vbet_act(r,s,egt)$os_bet(r,egt)$(not (YBET.l(r,s,egt)+YXBET.l(r,s,egt,v)))] = vbet_trk(r,"*",s,egt,v,t-1,"frd");

* update tracking parameter with new mixed vintage
v_trk(r,g,s,v,t,"id") = x_id_in(r,g,s,v);
vegt_trk(r,g,s,egt,v,t,"id") = xegt_id_in(r,g,s,egt,v);
vbet_trk(r,g,s,egt,v,t,"id") = xbet_id_in(r,g,s,egt,v);

v_trk(r,"*",s,v,t,"ld") = x_ld_in(r,s,v);
vegt_trk(r,"*",s,egt,v,t,"ld") = xegt_ld_in(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,t,"ld") = xbet_ld_in(r,s,egt,v);

v_trk(r,"*",s,v,t,"kd") = x_kd_in(r,s,v);
vegt_trk(r,"*",s,egt,v,t,"kd") = xegt_kd_in(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,t,"kd") = xbet_kd_in(r,s,egt,v);

v_trk(r,"*",s,v,t,"frd") = x_frd_in(r,s,v);
vegt_trk(r,"*",s,egt,v,t,"frd") = xegt_frd_in(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,t,"frd") = xbet_frd_in(r,s,egt,v);

*------------------------------------------------------------------------
* extant fixed resource rescaling 
*------------------------------------------------------------------------
xbet_fr(r,s,egt,v)$[xbet_kd_in(r,s,egt,v)] = xbet_k(r,s,egt,v)*xbet_frd_in(r,s,egt,v)/xbet_kd_in(r,s,egt,v);
* xbet_fr(r,s,egt,v) = max(1e-6,xbet_fr(r,s,egt,v));
display xbet_fr;

vbet_trk(r,"*",s,egt,v,t,"fr") = xbet_fr(r,s,egt,v);
vbet_trk(r,"*",s,egt,v,t,"fr/k")$[xbet_k(r,s,egt,v)] = xbet_fr(r,s,egt,v)/xbet_k(r,s,egt,v);

*------------------------------------------------------------------------
* else -- card(v) > 1
*------------------------------------------------------------------------

else

* !!!! update tracking of vintage coefficients v_trk, vegt_trk, vbet_trk

* extant sectoral (non electric)
x_id_in(r,g,s,v+1)$[v_act(r,s)$(not vl(v+1))] = x_id_in(r,g,s,v);
x_id_in(r,g,s,v+1)$[v_act(r,s)$(vl(v+1))$(YX.l(r,s,v) + YX.l(r,s,v+1))] =
	x_id_in(r,g,s,v)*(YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)))/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)) + YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1))))
	+ x_id_in(r,g,s,v+1)*(YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1)))/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)) + YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1))))
;

x_ld_in(r,s,v+1)$[v_act(r,s)$(not vl(v+1))] = x_ld_in(r,s,v);
x_ld_in(r,s,v+1)$[v_act(r,s)$(vl(v+1))$(YX.l(r,s,v) + YX.l(r,s,v+1))] =
	x_ld_in(r,s,v)*(YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)))/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)) + YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1))))
	+ x_ld_in(r,s,v+1)*(YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1)))/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)) + YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1))))
;

x_kd_in(r,s,v+1)$[v_act(r,s)$(not vl(v+1))] = x_kd_in(r,s,v);
x_kd_in(r,s,v+1)$[v_act(r,s)$(vl(v+1))$(YX.l(r,s,v) + YX.l(r,s,v+1))] =
	x_kd_in(r,s,v)*(YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)))/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)) + YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1))))
	+ x_kd_in(r,s,v+1)*(YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1)))/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)) + YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1))))
;

x_frd_in(r,s,v+1)$[v_act(r,s)$(not vl(v+1))] = x_frd_in(r,s,v);
x_frd_in(r,s,v+1)$[v_act(r,s)$(vl(v+1))$(YX.l(r,s,v) + YX.l(r,s,v+1))] =
	x_frd_in(r,s,v)*(YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)))/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)) + YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1))))
	+ x_frd_in(r,s,v+1)*(YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1)))/((YX.l(r,s,v)*sum(g.local,x_ys_out(r,s,g,v)) + YX.l(r,s,v+1)*sum(g.local,x_ys_out(r,s,g,v+1))))
;


* conventional electricity
xegt_id_in(r,g,s,egt,v+1)$[vegt_act(r,s,egt)$(not vl(v+1))] = xegt_id_in(r,g,s,egt,v);
xegt_id_in(r,g,s,egt,v+1)$[vegt_act(r,s,egt)$(vl(v+1))$(YXEGT.l(r,s,egt,v)+YXEGT.l(r,s,egt,v+1))] =
	xegt_id_in(r,g,s,egt,v)*(YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)))/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)) + YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1))))
	+ xegt_id_in(r,g,s,egt,v+1)*(YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1)))/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)) + YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1))))
;


xegt_ld_in(r,s,egt,v+1)$[vegt_act(r,s,egt)$(not vl(v+1))] = xegt_ld_in(r,s,egt,v);
xegt_ld_in(r,s,egt,v+1)$[vegt_act(r,s,egt)$(vl(v+1))$(YXEGT.l(r,s,egt,v)+YXEGT.l(r,s,egt,v+1))] =
	xegt_ld_in(r,s,egt,v)*(YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)))/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)) + YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1))))
	+ xegt_ld_in(r,s,egt,v+1)*(YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1)))/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)) + YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1))))
;


xegt_kd_in(r,s,egt,v+1)$[vegt_act(r,s,egt)$(not vl(v+1))] = xegt_kd_in(r,s,egt,v);
xegt_kd_in(r,s,egt,v+1)$[vegt_act(r,s,egt)$(vl(v+1))$(YXEGT.l(r,s,egt,v)+YXEGT.l(r,s,egt,v+1))] =
	xegt_kd_in(r,s,egt,v)*(YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)))/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)) + YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1))))
	+ xegt_kd_in(r,s,egt,v+1)*(YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1)))/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)) + YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1))))
;


xegt_frd_in(r,s,egt,v+1)$[vegt_act(r,s,egt)$(not vl(v+1))] = xegt_frd_in(r,s,egt,v);
xegt_frd_in(r,s,egt,v+1)$[vegt_act(r,s,egt)$(vl(v+1))$(YXEGT.l(r,s,egt,v)+YXEGT.l(r,s,egt,v+1))] =
	xegt_frd_in(r,s,egt,v)*(YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)))/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)) + YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1))))
	+ xegt_frd_in(r,s,egt,v+1)*(YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1)))/((YXEGT.l(r,s,egt,v)*sum(g.local,xegt_ys_out(r,s,egt,g,v)) + YXEGT.l(r,s,egt,v+1)*sum(g.local,xegt_ys_out(r,s,egt,g,v+1))))
;


* backstop electricity
xbet_id_in(r,g,s,egt,v+1)$[vbet_act(r,s,egt)$(not vl(v+1))] = xbet_id_in(r,g,s,egt,v);
xbet_id_in(r,g,s,egt,v+1)$[vbet_act(r,s,egt)$(vl(v+1))$(YXBET.l(r,s,egt,v) + YXBET.l(r,s,egt,v+1))] =
	xbet_id_in(r,g,s,egt,v)*(YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)))/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)) + YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1))))
	+ xbet_id_in(r,g,s,egt,v+1)*(YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1)))/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)) + YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1))))
;


xbet_ld_in(r,s,egt,v+1)$[vbet_act(r,s,egt)$(not vl(v+1))] = xbet_ld_in(r,s,egt,v);
xbet_ld_in(r,s,egt,v+1)$[vbet_act(r,s,egt)$(vl(v+1))$(YXBET.l(r,s,egt,v) + YXBET.l(r,s,egt,v+1))] =
	xbet_ld_in(r,s,egt,v)*(YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)))/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)) + YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1))))
	+ xbet_ld_in(r,s,egt,v+1)*(YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1)))/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)) + YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1))))
;


xbet_kd_in(r,s,egt,v+1)$[vbet_act(r,s,egt)$(not vl(v+1))] = xbet_kd_in(r,s,egt,v);
xbet_kd_in(r,s,egt,v+1)$[vbet_act(r,s,egt)$(vl(v+1))$(YXBET.l(r,s,egt,v) + YXBET.l(r,s,egt,v+1))] =
	xbet_kd_in(r,s,egt,v)*(YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)))/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)) + YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1))))
	+ xbet_kd_in(r,s,egt,v+1)*(YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1)))/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)) + YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1))))
;


* !!!! zero out and add mutable portion to xbet_kd_in instead
xbet_frd_in(r,s,egt,v+1)$[vbet_act(r,s,egt)$(not vl(v+1))] = xbet_frd_in(r,s,egt,v);
xbet_frd_in(r,s,egt,v+1)$[vbet_act(r,s,egt)$(vl(v+1))$(YXBET.l(r,s,egt,v) + YXBET.l(r,s,egt,v+1))] =
	xbet_frd_in(r,s,egt,v)*(YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)))/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)) + YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1))))
	+ xbet_frd_in(r,s,egt,v+1)*(YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1)))/((YXBET.l(r,s,egt,v)*sum(g.local,xbet_ys_out(r,s,egt,g,v)) + YXBET.l(r,s,egt,v+1)*sum(g.local,xbet_ys_out(r,s,egt,g,v+1))))
;


x_id_in(r,g,s,vf) = 0;
x_ld_in(r,s,vf) = 0;
x_kd_in(r,s,vf) = 0;
x_frd_in(r,s,vf) = 0;

xegt_id_in(r,g,s,egt,vf) = 0;
xegt_ld_in(r,s,egt,vf) = 0;
xegt_kd_in(r,s,egt,vf) = 0;
xegt_frd_in(r,s,egt,vf) = 0;

xbet_id_in(r,g,s,egt,vf) = 0;
xbet_ld_in(r,s,egt,vf) = 0;
xbet_kd_in(r,s,egt,vf) = 0;
xbet_frd_in(r,s,egt,vf) = 0;

x_id_in(r,g,s,v)$[en(g)$v_act(r,s)$vf(v)] = DIDME.l(r,g,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
x_id_in(r,g,s,v)$[nne(g)$v_act(r,s)$vf(v)] = DIDMM.l(r,g,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
x_ld_in(r,s,v)$[v_act(r,s)$vf(v)] = DLDM.l(r,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
x_kd_in(r,s,v)$[v_act(r,s)$vf(v)] = DKM.l(r,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));
x_frd_in(r,s,v)$[v_act(r,s)$vf(v)] = DRM.l(r,s)/(YM.l(r,s)*sum(g.local,ys0(r,s,g))*(1-ty0(r,s)));

xegt_id_in(r,g,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$(YMEGT.l(r,s,egt))] = DIDMEGT.l(r,g,s,egt)/(YMEGT.l(r,s,egt)*obar_gen0(r,egt)*(1-ty0(r,s)));
xegt_ld_in(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$(YMEGT.l(r,s,egt))] = DLDMEGT.l(r,s,egt)/(YMEGT.l(r,s,egt)*obar_gen0(r,egt)*(1-ty0(r,s)));
xegt_kd_in(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$(YMEGT.l(r,s,egt))] = DKMEGT.l(r,s,egt)/(YMEGT.l(r,s,egt)*obar_gen0(r,egt)*(1-ty0(r,s)));
xegt_frd_in(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$(YMEGT.l(r,s,egt))] = DRMEGT.l(r,s,egt)/(YMEGT.l(r,s,egt)*obar_gen0(r,egt)*(1-ty0(r,s)));

xbet_id_in(r,g,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(YBET.l(r,s,egt))] = bsfact(r,egt)*DIDBET.l(r,g,s,egt)/(YBET.l(r,s,egt));
xbet_ld_in(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(YBET.l(r,s,egt))] = bsfact(r,egt)*DLDMBET.l(r,s,egt)/(YBET.l(r,s,egt));
xbet_kd_in(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(YBET.l(r,s,egt))] = bsfact(r,egt)*DKMBET.l(r,s,egt)/(YBET.l(r,s,egt));
* !!!! zero out and send to x_kd_in
xbet_frd_in(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(YBET.l(r,s,egt))] = bsfact(r,egt)*DRMBET.l(r,s,egt)/(YBET.l(r,s,egt));

* aggregate frd into kd
xbet_kd_in(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(YBET.l(r,s,egt))] = xbet_kd_in(r,s,egt,v)+xbet_frd_in(r,s,egt,v);

*zero out;
xbet_frd_in(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(YBET.l(r,s,egt))] = 0;

* !!!! must be a better solution than a lower bound on YM
x_id_in(r,g,s,v)$[v_act(r,s)$vf(v)$(not YM.l(r,s))] = x_id_in(r,g,s,v+1)*2;
x_ld_in(r,s,v)$[v_act(r,s)$vf(v)$(not YM.l(r,s))] = x_ld_in(r,s,v+1)*2;
x_kd_in(r,s,v)$[v_act(r,s)$vf(v)$(not YM.l(r,s))] = x_kd_in(r,s,v+1)*2;
x_frd_in(r,s,v)$[v_act(r,s)$vf(v)$(not YM.l(r,s))] = x_frd_in(r,s,v+1)*2;

xegt_id_in(r,g,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$(not YMEGT.l(r,s,egt))] = xegt_id_in(r,g,s,egt,v+1)*2;
xegt_ld_in(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$(not YMEGT.l(r,s,egt))] = xegt_ld_in(r,s,egt,v+1)*2;
xegt_kd_in(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$(not YMEGT.l(r,s,egt))] = xegt_kd_in(r,s,egt,v+1)*2;
xegt_frd_in(r,s,egt,v)$[vegt_act(r,s,egt)$vf(v)$(not YMEGT.l(r,s,egt))] = xegt_frd_in(r,s,egt,v+1)*2;

xbet_id_in(r,g,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(not YBET.l(r,s,egt))] = xbet_id_in(r,g,s,egt,v+1)*2;
xbet_ld_in(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(not YBET.l(r,s,egt))] = xbet_ld_in(r,s,egt,v+1)*2;
xbet_kd_in(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(not YBET.l(r,s,egt))] = xbet_kd_in(r,s,egt,v+1)*2;
xbet_frd_in(r,s,egt,v)$[vbet_act(r,s,egt)$vf(v)$(not YBET.l(r,s,egt))] = xbet_frd_in(r,s,egt,v+1)*2;

x_co2d_in(r,g,s,v)$[v_act(r,s)] = cco2(r,g,s)*x_id_in(r,g,s,v);
xegt_co2d_in(r,g,s,egt,v)$[vegt_act(r,s,egt)] = (cco2egt(r,g,s,egt))*xegt_id_in(r,g,s,egt,v);

* end if statement
);

