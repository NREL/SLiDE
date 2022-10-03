$title single year loop

$show

* ++++++++++ begin loop over t ++++++++++

* Begin loop over future years
loop(t$[(t.val gt %bmkyr%)$(t.val eq %solveyr%)],

* update tsf for current solve year
$include loop_tsf.gms

* update tsf for electrification backstop
$include loop_elbs.gms

* load bau pin values
egtrate_bau(r,s,egt)$[swloadit] = rep_pin_bau(r,s,egt,t,"EGTRATE","%bauscn%");
egtmod_bau(r,s,egt)$[swloadit] = rep_pin_bau(r,s,egt,t,"EGTMOD","%bauscn%");
bse_bau(r,"fr",egt)$[swloadit] = rep_pin_bau(r,"fr",egt,t,"BSE","%bauscn%");

* update bse - maximum between MRC2019 method and loaded pin 
bse(r,"fr",egt)$[(swloadit)] = bse_bau(r,"fr",egt);
bse(r,"fr",egt)$[(swloadit)$vgen(egt)$swdecarb] = max(bse(r,"fr",egt),bse_bau(r,"fr",egt));
bse(r,"fr",egt)$[(swloadit)$(not vgen(egt))$swdecarb] = bse_bau(r,"fr",egt);

* update capital stock and vintaging
$include loop_vint.gms

* !!!! if loading a pin and different time interval, load endowments (capital main concern)
* !!!! don't think loading will work due to endogenous capital formation from previous period
* if(swloadit=1,
* if(tint > 1,

* ks_m(r) =

* );
* );


execute_unload "%gdxdir%mgeout_%rmap%_%scn%_loop.gdx";

* assign productivity growth factor for current year
gprod = prodf(t);

* update the pinning constraint EGTRATE 
ss_shr_yr(r,egt) = ss_shr(r,t,egt);
ss_gen_yr(r,egt) = ss_gen(r,t,egt);

* force minimum value for solvability
ss_pq_gen(r,egt) = max(mingenscale(r,egt),imp_pele0(r)*ss_gen_yr(r,egt));
* round
ss_pq_gen(r,egt) = round(ss_pq_gen(r,egt),6);

* !!!! redundant --- leave for now because could pass another year other than bmkyr
if(t.val > %bmkyr%,
* assign esub_ele increase
esub_ele(s) = esub_ele(s)*es_ele_tf;
esub_ele("fd") = esub_ele("fd")*es_ele_tf;
esub_ele(s) = min(2,esub_ele(s));
esub_ele("fd") = min(2,esub_ele("fd"));

* set arbitrary bounds on total improvements

elk(r,g,sfd)$[ele(g)] = min(1.4,elk(r,g,sfd)*(1+elkrate));
aeei(r,g,sfd)$[fe(g)$(not col(g))] = max(0.7,aeei(r,g,sfd)*1/(1+aeeirate));
en_bar(r,s) = sum(g$[en(g)], id0(r,g,s)*elk(r,g,s)*aeei(r,g,s));

* !!!! testing this to see if it works
* ---- possible way to get initial response from coal, and no response when policy lifted later
* scale_ymegt(s,egt)$[ele(s)$coal(egt)] = scale_ymegt(s,egt)/1.15;

);

YBET.lo(r,s,egt) = 1e-4;
 
* !!!! not used -- output side tfp shock
tfp_adj(r,egt) = 1;

*------------------------------------------------------------------------
* prepare for iterative pin
*------------------------------------------------------------------------

*reset iterative tfp pinning adjustment - cost side
iter_adj(r,egt)$[(not vgen(egt))] = 1;
iter_adj(r,egt)$[vgen(egt)$(t.val < 2022)] = 1;

adj_egt(r,egt)$[(not vgen(egt))] = 0.25;

$if %rmap%=="state" $goto skipitercensus

iter_adj(r,egt) = 1;

adj_egt(r,egt)$vgen(egt) = 0.01;

if(t.val>2023,
adj_egt(r,egt)$vgen(egt) = 0.1;
);

if(t.val>2035,
adj_egt(r,egt)$vgen(egt) = 0.5;
* adj_egt(r,egt)$vgen(egt) = 0.1;
* adj_egt(r,egt) = 0.1;
* adjstep(r,egt)$vgen(egt) = 2*adjstep(r,egt)
);

$label skipitercensus


* iterative pin control flow begins
if (switerpin=1,

* solve once before iteration loop
MGEMODEL.OptFile = 1;
MGEMODEL.iterlim = 10000000;
$INCLUDE MGEMODEL.GEN
SOLVE MGEMODEL using mcp;
ABORT$(MGEMODEL.objval > 1e-4) "Error in benchmark calibration of the MGE model.";

* begin iteration
loop(iter,

* record target and model values from previous solve
iter_store(r,egt,"TARGET") = ss_pq_gen(r,egt);
iter_store(r,egt,"MODEL") = EGTMOD.l(r,"ele",egt);

* ratio
iter_comp(r,egt,t,iter)$[iter_store(r,egt,"TARGET")] =
	iter_store(r,egt,"MODEL")/iter_store(r,egt,"TARGET");

* difference
iterdiff(r,egt,t,iter) = iter_store(r,egt,"MODEL")-iter_store(r,egt,"TARGET");

* store some diagnostics
sse_iterdiff(t,iter) = sum((r,egt),abs(iterdiff(r,egt,t,iter)));
avg_iterrat(r,t,iter)$[(sum((egt)$iter_store(r,egt,"MODEL"),1))] = (1/sum((egt)$iter_store(r,egt,"MODEL"),1))*sum((egt),abs(iter_comp(r,egt,t,iter)-1));
max_iterrat(r,t,iter) = smax((egt),abs(iter_comp(r,egt,t,iter)-1));
max_iterdiff(r,t,iter) = smax((egt),abs(iterdiff(r,egt,t,iter)));
wt_iterdiff(r,t,iter)$[(sum((egt),iter_store(r,egt,"TARGET")))] = sum((egt),iterdiff(r,egt,t,iter))/sum((egt),iter_store(r,egt,"TARGET"));
wt_iterrat(r,t,iter)$[(sum(egt,iter_store(r,egt,"TARGET")))] = abs((sum(egt,iter_store(r,egt,"MODEL"))/sum(egt,iter_store(r,egt,"TARGET")))-1);

* logic for pin based on regional aggregation
* !!!! this is hacky
$if %rmap%=="census" $goto skipadjstate
* State
iter_adj_yr(r,egt,t,iter)$[vgen(egt)$(iter_comp(r,egt,t,iter) > 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,t,iter)] = iter_adj(r,egt)*(1+adjstep(r,egt)*10);
iter_adj_yr(r,egt,t,iter)$[vgen(egt)$(iter_comp(r,egt,t,iter) < 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,t,iter)] = iter_adj(r,egt)*1/(1+adjstep(r,egt)*10);

iter_adj_yr(r,egt,t,iter)$[(not vgen(egt))$(iter_comp(r,egt,t,iter) > 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,t,iter)] = iter_adj(r,egt)*(1+(iter_comp(r,egt,t,iter)-1)*adj_egt(r,egt));
iter_adj_yr(r,egt,t,iter)$[(not vgen(egt))$(iter_comp(r,egt,t,iter) < 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,t,iter)] = iter_adj(r,egt)/(1+(1-iter_comp(r,egt,t,iter))*adj_egt(r,egt));

iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) > 1)$(iter.val < 2*round(card(iter)/3,0))$(iter.val >= round(card(iter)/3,0))] = iter_adj(r,egt)*(1+adjstep(r,egt)*10);
iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) < 1)$(iter.val < 2*round(card(iter)/3,0))$(iter.val >= round(card(iter)/3,0))] = iter_adj(r,egt)*1/(1+adjstep(r,egt)*10);

iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) > 1)$(iter.val >= 2*round(card(iter)/3,0))] = iter_adj(r,egt)*(1+adjstep(r,egt));
iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) < 1)$(iter.val >= 2*round(card(iter)/3,0))] = iter_adj(r,egt)*1/(1+adjstep(r,egt));

iter_adj_yr(r,egt,t,iter)$[hiak(r)] = 1;

$label skipadjstate

$if %rmap%=="state" $goto skipadjcensus
* Census
iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) > 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,t,iter)] = iter_adj(r,egt)*(1+(iter_comp(r,egt,t,iter)-1)*adj_egt(r,egt));
iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) < 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,t,iter)] = iter_adj(r,egt)/(1+(1-iter_comp(r,egt,t,iter))*adj_egt(r,egt));

iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) > 1)$(iter.val < 2*round(card(iter)/3,0))$(iter.val >= round(card(iter)/3,0))] = iter_adj(r,egt)*(1+adjstep(r,egt)*10);
iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) < 1)$(iter.val < 2*round(card(iter)/3,0))$(iter.val >= round(card(iter)/3,0))] = iter_adj(r,egt)*1/(1+adjstep(r,egt)*10);

iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) > 1)$(iter.val >= 2*round(card(iter)/3,0))] = iter_adj(r,egt)*(1+adjstep(r,egt));
iter_adj_yr(r,egt,t,iter)$[(iter_comp(r,egt,t,iter) < 1)$(iter.val >= 2*round(card(iter)/3,0))] = iter_adj(r,egt)*1/(1+adjstep(r,egt));

$label skipadjcensus

* store new iterative adjustment prior to resolving
iter_adj(r,egt) = iter_adj_yr(r,egt,t,iter);
iter_adj(r,egt)$iter_adj(r,egt) = min(10,iter_adj(r,egt));
iter_adj(r,egt)$iter_adj(r,egt) = max(1/10,iter_adj(r,egt));



* solve with new iterative adjustment
MGEMODEL.OptFile = 2;
MGEMODEL.iterlim = 10000000;
$INCLUDE MGEMODEL.GEN
SOLVE MGEMODEL using mcp;
* ABORT$(MGEMODEL.objval > 1e-4) "Error in iterative pin.";

*	Save the solution:
execute_unload "%gdxdir%chk_iter_post.gdx";

* sleep to prevent timing error
execute "sleep 1";

* end loop over iter
);

*store last iteration
iterpin_adj_yr(r,egt,t) = sum(iter$iterl(iter),iter_adj_yr(r,egt,t,iter));

* end if switerpin
);

* load iterative pin cost side tfp adjustment
iter_adj(r,egt)$[swloadit] = rep_pin_bau(r,"ele",egt,t,"TFPADJ","%bauscn%");

display iter_adj;

* loadpint logic for model base loading
if (swloadit eq 1,
if (swcarb=0,
$if exist %basesdir%%rmap%_%bauscn%_%solveyr%_p.gdx execute_loadpoint '%basesdir%%rmap%_%bauscn%_%solveyr%_p.gdx';
else
if (pco2.l le (0.01),
$if exist %basesdir%%rmap%_%bauscn%_%solveyr%_p.gdx execute_loadpoint '%basesdir%%rmap%_%bauscn%_%solveyr%_p.gdx';
);
);
);

*------------------------------------------------------------------------
* logic for decarbonization case (cap cases)
*------------------------------------------------------------------------

* iterative process to prevent convergence issues
$if %swdecarbval%==0 $goto skipitercap
loop(iter$[(iter.val le 2)],
$label skipitercap

$if %swdecarbval%==1 $goto skipnoitercap
loop(iter$[(iter.val eq 1)],
$label skipnoitercap

* control flow for active cap year
if (t.val ge capyr,
swcarb = swdecarb;
carblim(t)$[(t.val le capendyr)] = 1 - (%decarbval%*yrint_shr * ((t.val-(capyr-1))));

$if %swdecarbval%==0 $goto skipnoitercap2
if (iter.val eq 1,
* if first iteration of new year, use last year's cap before using updated cap in next iteration
carblim(t) = carblim(t-1);
);
$label skipnoitercap2

* update the co2 emissions limit
carblim(t)$[(t.val > capendyr)] = 1-%decarbval%;
carb0(r)$[swdecarb] = carblim(t)*carb0capyr(r);
co2base(r,sfd)$[swdecarb] = co2basecapyr(r,sfd);
co2target$[swdecarb] = round(carblim(t)*sum((r,sfd),co2basecapyr(r,sfd)),3);
swcarb$[(sum((r,sfd)$[co2base(r,sfd)],emit_bau(r,sfd,t)) le co2target)$swloadit] = 0;

* if flat carbon tax case
PCO2.fx$[swctax] = co2tax;

else
swcarb=0;
* set to large value if not running decarb case
* probably not needed... because swcarb=0, but a good data indicator regardless
carb0(r)$[swdecarb] = 1e10;
co2target$[swdecarb] = 1e10;
);

* if subsidy case is active
if (swsubegt=1,
subegt(r,s,egt)=subegtyr(r,s,egt,t);
subxegt(r,s,egt) = subegt(r,s,egt);
subxbet(r,s,egt,v) = subxbetyr(r,s,egt,v,t);

* activate subsidy years
if (t.val ge subyrend,
subxegt(r,s,egt) = -subrate;
);

* hacks to get subsidy to solve if failing
if(t.val > subyrstart,
* KS.l = rep("ALL","ALL",t-1,"KS","%scn%");
* PK.l = rep("ALL","ALL",t-1,"PK","%scn%");
* PN.l(g) = rep("ALL",g,t-1,"PN","%scn%");
);

* end if swsubegt
);


* include model and solve
mgemodel.savepoint = 1;
MGEMODEL.OptFile = 1;
MGEMODEL.iterlim = 10000000;
$INCLUDE MGEMODEL.GEN
SOLVE MGEMODEL using mcp;
ABORT$(MGEMODEL.objval > 1e-4) "Error in benchmark calibration of the MGE model.";

* end loop over iter (for cap iteration, not pin iteration)
);

*	Save the solution:
execute 'mv -f MGEMODEL_p.gdx %basesdir%%rmap%_%scn%_%solveyr%_p.gdx';

* include reporting file for storage
$include loop_store_vint.gms

* store co2 emissions
r_dco2_s(r,sfd,t) = rep(r,sfd,t,"DCO2_SECT","%scn%");

* prior to cap year beginning update base year co2 emissions
if (t.val < %capyrval%,
swcarb=0;
carb0(r) = 1e10;
carb0capyr(r) = sum(g,r_dco2(r,g,t));
co2basecapyr(r,sfd) = r_dco2_s(r,sfd,t)*ss_ctax(r,sfd);
);

chk_rsco2(r) = carb0capyr(r) - sum(sfd,co2basecapyr(r,sfd));
display chk_rsco2;

* if loading with constraint pin (not used currently due to problems solving at certain aggregations)
EGTRATE.fx(r,s,egt)$[(not swsspin)] = 0;
EGTRATE.fx(r,s,egt)$[swloadit] = egtrate_bau(r,s,egt);

* check that pin is replicated with bau loading
$if %swloadval%==0     $goto skipbauchk
chk_bau_rep(r,s,t,"DCO2_SECT") =
	rep(r,s,t,"DCO2_SECT","%scn%") - rep_bau(r,s,t,"DCO2_SECT","%bauscn%");

chk_bau_rep(r,"ALL",t,"RA") =
	rep(r,"ALL",t,"RA","%scn%") - rep_bau(r,"ALL",t,"RA","%bauscn%");

chk_bau_rep(r,egt,t,"YMEGT") =
	rep(r,egt,t,"YMEGT","%scn%") - rep_bau(r,egt,t,"YMEGT","%bauscn%");

chk_bau_rep(r,egt,t,"YMBET") =
	rep(r,egt,t,"YMBET","%scn%") - rep_bau(r,egt,t,"YMBET","%bauscn%");
$label  skipbauchk

execute_unload "%gdxdir%mgeout_%rmap%_%scn%_loop.gdx";

if(t.val = %endyr%,

execute_unload "%gdxdir%mgeout_%rmap%_%scn%.gdx";
execute_unload "%gdxdir%rep_%rmap%_%scn%.gdx", reph, rep, wdecomp, r_elec, r_gdp;

);

* end loop over solveyr
);

