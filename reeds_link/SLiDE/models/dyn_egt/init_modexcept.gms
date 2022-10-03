$stitle initialize additional exception handling for the model

* exogenous parameters for endowment
parameters
	exo_id0(r,g,s)
	exo_kd0(r,s)
	exo_ld0(r,s)
	exo_ys0(r,s,g)
	chk_exobal
;

exo_ys0(r,s,g)$[y_egt(s)] = ys0(r,s,g);

exo_id0(r,g,s)$[y_egt(s)] = sum(egt,ibar_gen0(r,g,egt));

exo_kd0(r,s)$[y_egt(s)] = sum(egt,fbar_gen0(r,"k",egt)+fbar_gen0(r,"fr",egt));

exo_ld0(r,s)$[y_egt(s)] = sum(egt,fbar_gen0(r,"l",egt));

chk_exobal("core",r,s)$[y_egt(s)] =
	sum(g,ys0(r,s,g)*(1-ty0(r,s)))
	- sum(g,id0(r,g,s))
	- kd0(r,s)*(1+tk0(r))
	- ld0(r,s)
;

chk_exobal("exo",r,s)$[y_egt(s)] =
	sum(g,exo_ys0(r,s,g)*(1-ty0(r,s)))
	- sum(g,exo_id0(r,g,s))
	- exo_kd0(r,s)*(1+tk0(r))
	- exo_ld0(r,s)
;

display chk_exobal;

if(swegt=0,

obar_gen0(r,egt) = 0;
va_tot(r,egt) = 0;
ibar_gen0(r,g,egt) = 0;
fbar_gen0(r,"k",egt) = 0;
fbar_gen0(r,"l",egt) = 0;
fbar_gen0(r,"fr",egt) = 0;
ybet_except(r,s,egt) = no;
* y_egt(s) = no;

);


