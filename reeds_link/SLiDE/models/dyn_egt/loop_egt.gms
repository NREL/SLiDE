$stitle Loop over years

* ++++++++++ begin loop over loopyr ++++++++++

* Begin loop over future years
loop(loopyr$(loopyr.val gt %bmkyr%),



$include loop_vint.gms
execute_unload "%gdxdir%mgeout_%rmap%_%scn%_loop.gdx";

* *++++++++++ Steady-state assumption ++++++++++
* * New capital: depreciated total capital * benchmark investment index (inv.l(r)=1 in bmkyr)
* newcap(r,loopyr) = (ktot0(r) - ktot0(r)*srv)*inv.l(r);
* *+++++++++++++++++++

* * Total mutable capital: new capital, plus existing putty net of depreciation,
* * .... (not implemented) minus share of existing moved to vintaged
* totalcap(r,loopyr) = newcap(r,loopyr) + ks_m(r)*srv;
* * totalcap(r,loopyr) = newcap(r,loopyr)
* * 	+ ks_m(r)*srv
* *	- sum(s$[v_act(r,s)],DKM.l(r,s)*xvt_shr(s,loopyr))
* *	- sum((s,egt)$[vegt_act(r,s,egt)],DKMEGT.l(r,s,egt)*xvtegt_shr(s,egt,loopyr))

* * Update mutable capital
* ks_m(r) = totalcap(r,loopyr);

* * Vintaged capital update: vintaged capital net of depreciation, plus putty moved to clay
* ks_x(r,s) = kd0(r,s)*thetax(r,s)*(srv**(loopyr.val-%bmkyr%));
* * ks_x(r,s) = ks_x(r,s)*(srv);
* * ks_x(r,s) = ks_x(r,s)*(srv)
* * 	+ DKM.l(r,s)*xvt_shr(s,loopyr)
* * ;

* ksxegt(r,s,egt) = ksxegt0(r,s,egt)*(srv**(loopyr.val-%bmkyr%));
* * ksxegt(r,s,egt) = ksxegt(r,s,egt)*(srv);
* * ksxegt(r,s,egt) = ksxegt(r,s,egt)*(srv)
* * 	+ DKMEGT.l(r,s,egt)*xvtegt_shr(s,egt,loopyr)
* * ;

* frxegt(r,s,egt) = frxegt0(r,s,egt)*(srv**(loopyr.val-%bmkyr%));
* * frxegt(r,s,egt) = frxegt(r,s,egt)*(srv)
* * 	+ DRMEGT.l(r,s,egt)*xvtegt_shr(s,egt,loopyr);

* assign productivity growth factor for current year
gprod = prodf(loopyr);

* update the pinning constraint EGTRATE 
ss_shr_yr(r,egt) = ss_shr(r,loopyr,egt);
ss_gen_yr(r,egt) = ss_gen(r,loopyr,egt);

* force minimum value for solvability
ss_pq_gen(r,egt) = max(mingenscale(r,egt),imp_pele0(r)*ss_gen_yr(r,egt));
* round
ss_pq_gen(r,egt) = round(ss_pq_gen(r,egt),6);

if(loopyr.val > %bmkyr%,
* assign esub_ele increase
esub_ele(s) = esub_ele(s)*es_ele_tf;
esub_ele("fd") = esub_ele("fd")*es_ele_tf;
esub_ele(s) = min(2,esub_ele(s));
esub_ele("fd") = min(2,esub_ele("fd"));

* set arbitrary bounds on total improvements

elk(r,g,sfd)$[ele(g)] = min(1.4,elk(r,g,sfd)*(1+elkrate));
aeei(r,g,sfd)$[fe(g)] = max(0.7,aeei(r,g,sfd)*1/(1+aeeirate));
en_bar(r,s) = sum(g$[en(g)], id0(r,g,s)*elk(r,g,s)*aeei(r,g,s));
);

YBET.lo(r,s,egt)$[os_egt(r,egt)] = 1e-4;

if(loopyr.val > %bmkyr%,
YBET.lo(r,s,egt) = 1e-4;
);

* ele technology improvements
* bstechrate(r,egt) = 0.02
* bstechfact(r,egt) = bstechfact(r,egt)/(1+bstechrate(r,egt));

* $exit

* egtrate_bau(r,s,egt)$[swload] = rep_pin_bau(r,s,egt,loopyr,"EGTRATE","%bauscn%");
* egtmod_bau(r,s,egt)$[swload] = rep_pin_bau(r,s,egt,loopyr,"EGTMOD","%bauscn%");
* bse_bau(r,"fr",egt)$[(swload OR swloadit)] = rep_pin_bau(r,"fr",egt,loopyr,"BSE","%bauscn%");

* * update bse
* bse(r,"fr",egt)$[(swload OR swloadit)] = bse_bau(r,"fr",egt);

* EGTRATE.fx(r,s,egt)$[(not swsspin)] = 0;
* EGTRATE.fx(r,s,egt)$[swload] = egtrate_bau(r,s,egt);

* YMEGT.fx(r,s,egt)$[hiak(r)$switerpin] = YMEGT.l(r,s,egt);
* VAEGT.fx(r,s,egt)$[hiak(r)$switerpin] = VAEGT.l(r,s,egt);
* ID.fx(r,g,s,egt)$[hiak(r)$switerpin] = ID.l(r,g,s,egt);

tfp_adj(r,egt) = 1;

*reset tfp adjustment
iter_adj(r,egt)$[(not vgen(egt))] = 1;

adj_egt(r,egt)$(not vgen(egt)) = 0.25;

$if %rmap%=="state" $goto skipitercensus

iter_adj(r,egt) = 1;

adj_egt(r,egt)$vgen(egt) = 0.01;

if(loopyr.val>2023,
	
adj_egt(r,egt)$vgen(egt) = 0.1;
* adjstep(r,egt) if vgen = 5*adjstep(r,egt)

);

if(loopyr.val>2035,
	
adj_egt(r,egt)$vgen(egt) = 0.5;
* adjstep(r,egt)$vgen(egt) = 2*adjstep(r,egt)

);

$label skipitercensus


if (switerpin=1,

* include model and solve
mgemodel.savepoint = 1;

* $if exist %basesdir%%rmap%_%scn%_p.gdx execute_loadpoint '%basesdir%%rmap%_%scn%_p.gdx';

MGEMODEL.iterlim = 10000000;
$INCLUDE MGEMODEL.GEN
SOLVE MGEMODEL using mcp;
ABORT$(MGEMODEL.objval > 1e-4) "Error in benchmark calibration of the MGE model.";

*	Save the solution:
execute 'mv -f MGEMODEL_p.gdx %basesdir%%rmap%_%scn%_p.gdx';

loop(iter,

iter_store(r,egt,"TARGET") = ss_pq_gen(r,egt);
iter_store(r,egt,"MODEL") = EGTMOD.l(r,"ele",egt);

iter_comp(r,egt,loopyr,iter)$[iter_store(r,egt,"TARGET")] =
	iter_store(r,egt,"MODEL")/iter_store(r,egt,"TARGET");

iterdiff(r,egt,loopyr,iter) = iter_store(r,egt,"MODEL")-iter_store(r,egt,"TARGET");
* sse_iterdiff(loopyr,iter) = sum((r,egt),iterdiff(r,egt,loopyr,iter)**2);
sse_iterdiff(loopyr,iter) = sum((r,egt),abs(iterdiff(r,egt,loopyr,iter)));
avg_iterrat(r,loopyr,iter)$[(sum((egt)$iter_store(r,egt,"MODEL"),1))] = (1/sum((egt)$iter_store(r,egt,"MODEL"),1))*sum((egt),abs(iter_comp(r,egt,loopyr,iter)-1));
max_iterrat(r,loopyr,iter) = smax((egt),abs(iter_comp(r,egt,loopyr,iter)-1));
max_iterdiff(r,loopyr,iter) = smax((egt),abs(iterdiff(r,egt,loopyr,iter)));
wt_iterdiff(r,loopyr,iter)$[(sum((egt),iter_store(r,egt,"TARGET")))] = sum((egt),iterdiff(r,egt,loopyr,iter))/sum((egt),iter_store(r,egt,"TARGET"));
wt_iterrat(r,loopyr,iter)$[(sum(egt,iter_store(r,egt,"TARGET")))] = abs((sum(egt,iter_store(r,egt,"MODEL"))/sum(egt,iter_store(r,egt,"TARGET")))-1);

* if((avg_iterrat(loopyr,iter) < 0.05),
* 	break;
* );

* break$(avg_iterrat(loopyr,iter) le 0.05);


* $if %rmap%=="census" $goto skipadjstate
* State
iter_adj_yr(r,egt,loopyr,iter)$[vgen(egt)$(iter_comp(r,egt,loopyr,iter) > 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,loopyr,iter)] = iter_adj(r,egt)*(1+adjstep(r,egt)*10);
iter_adj_yr(r,egt,loopyr,iter)$[vgen(egt)$(iter_comp(r,egt,loopyr,iter) < 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,loopyr,iter)] = iter_adj(r,egt)*1/(1+adjstep(r,egt)*10);

iter_adj_yr(r,egt,loopyr,iter)$[(not vgen(egt))$(iter_comp(r,egt,loopyr,iter) > 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,loopyr,iter)] = iter_adj(r,egt)*(1+(iter_comp(r,egt,loopyr,iter)-1)*adj_egt(r,egt));
iter_adj_yr(r,egt,loopyr,iter)$[(not vgen(egt))$(iter_comp(r,egt,loopyr,iter) < 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,loopyr,iter)] = iter_adj(r,egt)/(1+(1-iter_comp(r,egt,loopyr,iter))*adj_egt(r,egt));

iter_adj_yr(r,egt,loopyr,iter)$[hiak(r)$(iter_comp(r,egt,loopyr,iter) > 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,loopyr,iter)] = iter_adj(r,egt)*(1+adjstep(r,egt)*10);
iter_adj_yr(r,egt,loopyr,iter)$[hiak(r)$(iter_comp(r,egt,loopyr,iter) < 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,loopyr,iter)] = iter_adj(r,egt)*1/(1+adjstep(r,egt)*10);

iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) > 1)$(iter.val < 2*round(card(iter)/3,0))$(iter.val >= round(card(iter)/3,0))] = iter_adj(r,egt)*(1+adjstep(r,egt)*10);
iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) < 1)$(iter.val < 2*round(card(iter)/3,0))$(iter.val >= round(card(iter)/3,0))] = iter_adj(r,egt)*1/(1+adjstep(r,egt)*10);

iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) > 1)$(iter.val >= 2*round(card(iter)/3,0))] = iter_adj(r,egt)*(1+adjstep(r,egt));
iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) < 1)$(iter.val >= 2*round(card(iter)/3,0))] = iter_adj(r,egt)*1/(1+adjstep(r,egt));
* $label skipadjstate

* $if %rmap%=="state" $goto skipadjcensus
* Census
* iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) > 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,loopyr,iter)] = iter_adj(r,egt)*(1+(iter_comp(r,egt,loopyr,iter)-1)*adj_egt(r,egt));
* iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) < 1)$(iter.val < round(card(iter)/3,0))$iter_comp(r,egt,loopyr,iter)] = iter_adj(r,egt)/(1+(1-iter_comp(r,egt,loopyr,iter))*adj_egt(r,egt));

* iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) > 1)$(iter.val < 2*round(card(iter)/3,0))$(iter.val >= round(card(iter)/3,0))] = iter_adj(r,egt)*(1+adjstep(r,egt)*10);
* iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) < 1)$(iter.val < 2*round(card(iter)/3,0))$(iter.val >= round(card(iter)/3,0))] = iter_adj(r,egt)*1/(1+adjstep(r,egt)*10);

* iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) > 1)$(iter.val >= 2*round(card(iter)/3,0))] = iter_adj(r,egt)*(1+adjstep(r,egt));
* iter_adj_yr(r,egt,loopyr,iter)$[(iter_comp(r,egt,loopyr,iter) < 1)$(iter.val >= 2*round(card(iter)/3,0))] = iter_adj(r,egt)*1/(1+adjstep(r,egt));
* $label skipadjcensus

iter_adj(r,egt) = iter_adj_yr(r,egt,loopyr,iter);
iter_adj(r,egt)$iter_adj(r,egt) = min(10,iter_adj(r,egt));
iter_adj(r,egt)$iter_adj(r,egt) = max(0.1,iter_adj(r,egt));

* include model and solve
mgemodel.savepoint = 1;

* $if exist %basesdir%%rmap%_%scn%_p.gdx execute_loadpoint '%basesdir%%rmap%_%scn%_p.gdx';

MGEMODEL.iterlim = 10000000;
$INCLUDE MGEMODEL.GEN
SOLVE MGEMODEL using mcp;
* ABORT$(MGEMODEL.objval > 1e-4) "Error in benchmark calibration of the MGE model.";

* if(mgemodel.objval > 1e-4,
* 	iter_adj(r,egt) = iter_adj(r,egt)*1.001;
* 	MGEMODEL.iterlim = 10000000;
* 	$INCLUDE MGEMODEL.GEN
* 	SOLVE MGEMODEL using mcp;
* );

*	Save the solution:
execute 'mv -f MGEMODEL_p.gdx %basesdir%%rmap%_%scn%_p.gdx';

execute_unload "%gdxdir%chk_iter_post.gdx";

execute "sleep 1";



);

*store last iteration
iterpin_adj_yr(r,egt,loopyr) = sum(iter$iterl(iter),iter_adj_yr(r,egt,loopyr,iter));

* end if switerpin
);

* load iterative pin cost side tfp adjustment
iter_adj(r,egt)$[swloadit] = rep_pin_bau(r,"ele",egt,loopyr,"TFPADJ","%bauscn%");
* iter_adj("HI",egt)$[swloadit] = 1;
* iter_adj("AK",egt)$[swloadit] = 1;
display iter_adj;

* logic for decarbonization
* might be better to add an auxiliary rationing constraint (TAU) to handle cap
if (loopyr.val ge capyr,
swcarb = swdecarb;
carblim(loopyr)$[(loopyr.val le capendyr)] = 1 - (%decarbval%*yrint_shr * ((loopyr.val-(capyr-1))));
* carblim(loopyr)$[(loopyr.val eq capendyr)] = carblim(loopyr-1);
carblim(loopyr)$[(loopyr.val > capendyr)] = 1-%decarbval%;
carb0(r)$[swdecarb] = carblim(loopyr)*carb0capyr(r);
co2base(r,sfd)$[swdecarb] = co2basecapyr(r,sfd);
co2target$[swdecarb] = round(carblim(loopyr)*sum((r,sfd),co2basecapyr(r,sfd)),6);
swcarb$[(sum((r,sfd)$[co2base(r,sfd)],emit_bau(r,sfd,loopyr)) le co2target)$swloadit] = 0;

PCO2.fx$[swctax] = co2tax;

* Fix nuc and hydro if running decarb counterfactual
YMEGT.fx(r,s,egt)$[ele(s)$obar_gen0(r,egt)$(nuc(egt))$swloadit] = rep_pin_bau(r,s,egt,loopyr,"YMEGT","%bauscn%");
YMEGT.fx(r,s,egt)$[ele(s)$obar_gen0(r,egt)$(hyd(egt))$swloadit] = rep_pin_bau(r,s,egt,loopyr,"YMEGT","%bauscn%");
* YMEGT.fx(r,s,egt)$[ele(s)$obar_gen0(r,egt)$(othc(egt))] = rep_pin_bau(r,s,egt,loopyr,"YMEGT","%bauscn%");

else
swcarb=0;
* set to large value if not running decarb case
* proably not needed...
carb0(r)$[swdecarb] = 1e10;
co2target$[swdecarb] = 1e10;
);

if (swsubegt=1,
subegt(r,s,egt)=subegtyr(r,s,egt,loopyr);
subxegt(r,s,egt) = subegt(r,s,egt);
subxbet(r,s,egt,v) = subxbetyr(r,s,egt,v,loopyr);

if (loopyr.val ge subyrend,
subxegt(r,s,egt) = -subrate;
);
);

* include model and solve
mgemodel.savepoint = 1;

* $if exist %basesdir%%rmap%_%scn%_p.gdx execute_loadpoint '%basesdir%%rmap%_%scn%_p.gdx';

MGEMODEL.iterlim = 10000000;
$INCLUDE MGEMODEL.GEN
SOLVE MGEMODEL using mcp;
ABORT$(MGEMODEL.objval > 1e-4) "Error in benchmark calibration of the MGE model.";

*	Save the solution:
execute 'mv -f MGEMODEL_p.gdx %basesdir%%rmap%_%scn%_p.gdx';

* include reporting file for storage
* $include loop_store_hh.gms
$include loop_store_vint.gms

r_dco2_s(r,sfd,loopyr) = rep(r,sfd,loopyr,"DCO2_SECT","%scn%");

if (loopyr.val < %capyrval%,
swcarb=0;
carb0(r) = 1e10;
carb0capyr(r) = sum(g,r_dco2(r,g,loopyr));
co2basecapyr(r,sfd) = r_dco2_s(r,sfd,loopyr)*ss_ctax(r,sfd);
);

chk_rsco2(r) = carb0capyr(r) - sum(sfd,co2basecapyr(r,sfd));
display chk_rsco2;

$include loop_tsf.gms

$include loop_elbs.gms


* load bau pin values
egtrate_bau(r,s,egt)$[swload] = rep_pin_bau(r,s,egt,loopyr+1,"EGTRATE","%bauscn%");
egtmod_bau(r,s,egt)$[swload] = rep_pin_bau(r,s,egt,loopyr+1,"EGTMOD","%bauscn%");
bse_bau(r,"fr",egt)$[(swload OR swloadit)] = rep_pin_bau(r,"fr",egt,loopyr+1,"BSE","%bauscn%");

* update bse - maximum between MRC2019 method and loaded pin 
bse(r,"fr",egt)$[(swload OR swloadit)] = bse_bau(r,"fr",egt);
bse(r,"fr",egt)$[(swload OR swloadit)$vgen(egt)$swdecarb] = max(bse(r,"fr",egt),bse_bau(r,"fr",egt));
bse(r,"fr",egt)$[(swload OR swloadit)$(not vgen(egt))$swdecarb] = bse_bau(r,"fr",egt);

display bse;

EGTRATE.fx(r,s,egt)$[(not swsspin)] = 0;
EGTRATE.fx(r,s,egt)$[swload] = egtrate_bau(r,s,egt);


egtmod_chk(r,s,egt,loopyr)$vgen(egt) = EGTMOD.l(r,s,egt)*(1-ty0(r,s)) - (YBET.l(r,s,egt));
egtmod_chk(r,s,egt,loopyr)$(not vgen(egt)) = EGTMOD.l(r,s,egt)*(1-ty0(r,s)) - (SYMEGT.l(r,s,egt)*(1-ty0(r,s)));
chk_marg(r,s,egt,loopyr,"ReEDS")$[(egtrate.m(r,s,egt)>0)$ele(s)] = imp_pele0(r)*ss_gen_yr(r,egt);
chk_marg(r,s,egt,loopyr,"MINGEN")$[(egtrate.m(r,s,egt)>0)$ele(s)] = ss_pq_gen(r,egt);

chk_marg(r,g,"all",loopyr,"growth_rate")$[ele(g)$(sum(g.local,ys0(r,"ele",g)))] = sum(egt,ss_pq_gen(r,egt))/sum(g.local,ys0(r,"ele",g));

chk_marg(r,s,egt,loopyr,"shr_chk")$[ele(s)$y_(r,s)$ss_pq_gen(r,egt)] = ss_pq_gen(r,egt)/sum(egt.local,ss_pq_gen(r,egt)) - EGTMOD.l(r,s,egt)/sum(egt.local,EGTMOD.l(r,s,egt));

display egtmod_chk, chk_marg;

execute_unload "%gdxdir%mgeout_%rmap%_%scn%_loop.gdx";

$if %swloadval%==1     $goto skipchkmarg

loop((r,s,egt)$ele(s),
ABORT$(egtrate.m(r,s,egt) > 0) "Error in pin - egtrate has marginals.";
ABORT$(egtrate.m(r,s,egt) < 0) "Error in pin - egtrate has marginals.";
);

$label skipchkmarg

);
