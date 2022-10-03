$stitle store values in loop

pnum("ALL",t) = CPI.l;
rkrs(r,s)$[swrks] = RKS.l;
rkrs(r,s)$[(not swrks)] = RK.l(r,s);

*------------------------------------------------------------------------
* Emissions check
*------------------------------------------------------------------------

r_dco2(r,g,t) =
	sum(s$[(not y_egt(s))],
		(DIDME.l(r,g,s)*cco2(r,g,s))$[fe(g)$id0(r,g,s)]
		+ (DIDMM.l(r,g,s)*cco2(r,g,s))$[cru(g)$id0(r,g,s)]
		+ sum(v,DIDX.l(r,g,s,v)$[x_k(r,s,v)]*cco2(r,g,s))$[em(g)$id0(r,g,s)]
	)
	+ sum(h,(DCD.l(r,g,h)*cco2(r,g,"fd"))$[fe(g)$cd0(r,g)])
	+ sum((s,egt)$[y_egt(s)],(DIDMEGT.l(r,g,s,egt)+DIDBET.l(r,g,s,egt))*cco2egt(r,g,s,egt))
	+ sum((s,egt)$[y_egt(s)],(sum(v,DIDXEGT.l(r,g,s,egt,v)))*cco2egt(r,g,s,egt))
;

r_dco2("ALL",g,t) = sum(r,r_dco2(r,g,t));
r_dco2(r,"ALL",t) = sum(g,r_dco2(r,g,t));

emissions("%scn%","fuel",g,t)	 = r_dco2("ALL",g,t);
emissions("%scn%","region",r,t) = r_dco2(r,"ALL",t);

emissions("%scn%","sector",s,t) = sum(r,sum(g,(DIDME.l(r,g,s)*cco2(r,g,s))$[fe(g)$id0(r,g,s)$(not y_egt(s))]
	+ (DIDMM.l(r,g,s)*cco2(r,g,s))$[cru(g)$id0(r,g,s)$(not y_egt(s))]
	+ (sum(v,DIDX.l(r,g,s,v)$[x_k(r,s,v)])*cco2(r,g,s))$[em(g)$id0(r,g,s)$(not y_egt(s))])
	+ sum((g,egt)$[ibar_gen0(r,g,egt)],(DIDMEGT.l(r,g,s,egt)+DIDBET.l(r,g,s,egt)+sum(v,DIDXEGT.l(r,g,s,egt,v)))*cco2egt(r,g,s,egt))$[y_egt(s)])
;
	
emissions("%scn%","sector","fd",t) = sum((r,h,g),(DCD.l(r,g,h)*cco2(r,g,"fd"))$[fe(g)$cd0(r,g)]);

emissions("%scn%","fuel","ALL",t)	 = sum(g,emissions("%scn%","fuel",g,t));
emissions("%scn%","region","ALL",t) = sum(r,emissions("%scn%","region",r,t));
emissions("%scn%","sector","ALL",t) = sum(s,emissions("%scn%","sector",s,t));

* check to see all emissions accounted for
chk_co2(r,"all",t) = sum(sfd,SCO2.l(r,sfd))-sum(g,r_dco2(r,g,t));
chk_co2("tot","all",t) =  sum((r,sfd),SCO2.l(r,sfd))-sum(s,emissions("%scn%","sector",s,t))-emissions("%scn%","sector","fd",t);
display chk_co2;


*------------------------------------------------------------------------
* Pinning constraint - check balance offset on budget
*------------------------------------------------------------------------

* chk_subsidy("%scn%",r,"sub_ymegt",t) =
* 	sum((s,egt)$[y_egt(s)$(not vgen(egt))$y_(r,s)],EGTRATE.l(r,s,egt)*YMEGT.l(r,s,egt)*PYEGT.l(r,s,egt)*obar_gen0(r,egt));

* chk_subsidy("%scn%",r,"sub_ymbet",t) =
* 	sum((s,egt)$[y_egt(s)$vgen(egt)$y_(r,s)],EGTRATE.l(r,s,egt)*YBET.l(r,s,egt)*sum(g,(((os_bet(r,egt)+os_egt(r,egt))/(1-ty0(r,s)))*ys0(r,s,g)/sum(gg,ys0(r,s,gg)))*PY.l(r,g)));

* chk_subsidy("%scn%","all","subREV",t) = sum(r,chk_subsidy("%scn%",r,"sub_ymegt",t)+chk_subsidy("%scn%",r,"sub_ymbet",t));

* chk_subsidy("%scn%","all","EGTREV",t) = EGTREV.l;

* chk_subsidy("%scn%","all","diffEGTREV",t) = chk_subsidy("%scn%","all","EGTREV",t)-chk_subsidy("%scn%","all","subREV",t);


*------------------------------------------------------------------------
* Renewable technology subsidy revenue
*------------------------------------------------------------------------

* subsidy revenue
r_elec(r,s,egt,t,"vgen","Msubrev","%scn%")$[y_(r,s)$y_egt(s)$vgen(egt)$os_bet(r,egt)] =
	sum(g,PY.l(r,g)*os_bet(r,egt)*(ys0(r,s,g)/sum(g.local,ys0(r,s,g)))/(1-ty0(r,s)))*YBET.l(r,s,egt)*subegt(r,s,egt)/CPI.l;

r_elec(r,s,egt,t,"vgen","Msubrev","%scn%")$[y_(r,s)$y_egt(s)$vgen(egt)$os_egt(r,egt)] =
	(sum(g,PY.l(r,g)*os_egt(r,egt)*(ys0(r,s,g)/sum(g.local,ys0(r,s,g)))/(1-ty0(r,s)))*YBET.l(r,s,egt))*subegt(r,s,egt)/CPI.l;

r_elec(r,s,egt,t,"vgen","Xsubrev","%scn%")$[y_(r,s)$vbet_act(r,s,egt)] =
	sum(v,(sum(g,PY.l(r,g)*xbet_ys_out(r,s,egt,g,v))*YXBET.l(r,s,egt,v))*subxbet(r,s,egt,v))/CPI.l;

r_elec(r,s,egt,t,"vgen","TOTsubrev","%scn%") = r_elec(r,s,egt,t,"vgen","Msubrev","%scn%")+r_elec(r,s,egt,t,"vgen","Xsubrev","%scn%");

r_elec("ALL","ALL","ALL",t,"vgen","TOTsubrevchk","%scn%") = sum((r,s,egt)$[y_(r,s)$y_egt(s)$ybet_except(r,s,egt)],r_elec(r,s,egt,t,"vgen","TOTsubrev","%scn%"))*CPI.l - BRRR.l;

*------------------------------------------------------------------------
* Tax Revenue decomposition
*------------------------------------------------------------------------
revenue("%scn%",r,"submbet",t)$[(not mnyprntrgo)] =
	sum((s,egt),r_elec(r,s,egt,t,"vgen","Msubrev","%scn%"));

revenue("%scn%",r,"subxbet",t)$[(not mnyprntrgo)] =
	sum((s,egt),r_elec(r,s,egt,t,"vgen","Xsubrev","%scn%"));

revenue("%scn%",r,"submbet",t)$[(mnyprntrgo)] = 0;

revenue("%scn%",r,"subxbet",t)$[(mnyprntrgo)] = 0;


revenue("%scn%",r,"tl",t) =
	sum((h,q),tl(r,h)*LS.L(r,h)*le0(r,q,h)*gprod*PL.L(q))/CPI.L;

revenue("%scn%",r,"tkm",t) =
	sum(s$(not y_egt(s)),tk(r,s)*(DKM.L(r,s)*rkrs(r,s)+DRM.l(r,s)*PRM.l(r,s)))/CPI.L;
revenue("%scn%",r,"tkx",t) =
	sum(s,tk(r,s)*(sum(v,DKX.L(r,s,v)*RKX.l(r,s,v)+DRX.l(r,s,v)*PRM.l(r,s))))/CPI.L;

revenue("%scn%",r,"tkelbs",t) =
	sum(s$elbs_act(r,s),tk(r,s)*(DKM_ELBS.l(r,s)*rkrs(r,s)+DRM_ELBS.l(r,s)*PR_ELBS.l(r,s)))/CPI.L;


revenue("%scn%",r,"tkmegt",t) =
	sum((s,egt)$(y_egt(s)),tk(r,s)*(DKMEGT.L(r,s,egt)*rkrs(r,s)+DRMEGT.l(r,s,egt)*PREGT.l(r,s,egt)))/CPI.L;
revenue("%scn%",r,"tkxegt",t) =
	sum((s,egt)$(y_egt(s)),tk(r,s)*(sum(v,DKXEGT.L(r,s,egt,v)*RKXEGT.l(r,s,egt,v)+DRXEGT.l(r,s,egt,v)*PREGT.l(r,s,egt))))/CPI.L;

revenue("%scn%",r,"tkmbet",t) =
	sum((s,egt)$(y_egt(s)$vgen(egt)),tk(r,s)*(DKMBET.L(r,s,egt)*rkrs(r,s)+DRMBET.l(r,s,egt)*PRBET.l(r,s,egt)))/CPI.L;
revenue("%scn%",r,"tkxbet",t) =
	sum((s,egt)$(y_egt(s)),tk(r,s)*(sum(v,DKXBET.L(r,s,egt,v)*RKXBET.l(r,s,egt,v))))/CPI.L;
*	sum((s,egt)$(y_egt(s)),tk(r,s)*(sum(v,DKXBET.L(r,s,egt,v)*RKXBET.l(r,s,egt,v)+DRXBET.l(r,s,egt,v)*PRXBET.l(r,s,egt,v))))/CPI.L;


revenue("%scn%",r,"tym",t) =
	sum(s$(not y_egt(s)),ty(r,s)*YM.l(r,s)*sum(g,ys0(r,s,g)*PY.L(r,g)))/CPI.L;
revenue("%scn%",r,"tyx",t)		  = sum(s,ty(r,s)*sum(v,YX.l(r,s,v)*sum(g,x_ys_out(r,s,g,v)*PY.L(r,g))))/CPI.L;

revenue("%scn%",r,"tymegt",t) =
	sum((s,egt)$[y_egt(s)$y_(r,s)$(not vgen(egt))],ty(r,s)*YMEGT.l(r,s,egt)*PYEGT.l(r,s,egt)*obar_gen0(r,egt))/CPI.L;	
*	sum(s$y_egt(s),ty(r,s)*YM.l(r,s)*sum(g,os_novgen(r,s)*ys0(r,s,g)*PY.L(r,g)))/CPI.L;
revenue("%scn%",r,"tyxegt",t) =
	sum((s,egt)$[y_egt(s)$y_(r,s)$(not vgen(egt))],ty(r,s)*sum(v$[xegt_k(r,s,egt,v)],YXEGT.l(r,s,egt,v)*sum(g,PY.l(r,g)*xegt_ys_out(r,s,egt,g,v))))/CPI.L;

revenue("%scn%",r,"tymbet",t) =
	sum((s,egt)$[y_egt(s)$vgen(egt)$y_(r,s)],ty(r,s)*YBET.l(r,s,egt)*sum(g,(((os_bet(r,egt)+os_egt(r,egt))/(1-ty0(r,s)))*ys0(r,s,g)/sum(gg,ys0(r,s,gg)))*PY.L(r,g)))/CPI.L;
revenue("%scn%",r,"tyxbet",t) =
	sum((s,egt)$[y_egt(s)$y_(r,s)$(vgen(egt))],ty(r,s)*sum(v$[xbet_k(r,s,egt,v)],YXBET.l(r,s,egt,v)*sum(g,PY.l(r,g)*xbet_ys_out(r,s,egt,g,v))))/CPI.L;



revenue("%scn%",r,"tyelbs",t) =
	sum(s$elbs_act(r,s),ty(r,s)*(Y_ELBS.l(r,s)*sum(g,PY.l(r,g)*elbs_out(r,s,g))))/CPI.L;


revenue("%scn%",r,"ta",t)		  = sum(g,A.L(r,g)*a0(r,g)*ta(r,g)*PA.L(r,g))/CPI.L;
revenue("%scn%",r,"tm",t)		  = sum(g$m0(r,g),tm(r,g)*DMF.L(r,g)*PFX.L)/CPI.L;
revenue("%scn%",r,"ctax",t)$[swcarb] = sum(h,CTAXTRN.l(r,h))/CPI.L;
* revenue("%scn%",r,"ctax",t)$[swcarb] = PCO2.l*(sum(s,co2base(r,s))+co2base(r,"fd"))*ETAR.l/CPI.L;

revenue("%scn%",r,"g.l",t)		  = GOVT.L/sum((r.local,g),PA.L(r,g)*g0(r,g));
revenue("%scn%",r,"govt.l",t)	  = sum(g,PA.L(r,g)*g0(r,g))/CPI.L * revenue("%scn%",r,"g.l",t);
revenue("%scn%",r,"transfers",t) = TRANS.l*sum((h),tp0(r,h));

revenue("%scn%","total",u,t)		= sum(r,revenue("%scn%",r,u,t));
revenue("%scn%",r,"total",t)		= sum(taxes,revenue("%scn%",r,taxes,t));
revenue("%scn%","total","total",t) = sum((r,taxes),revenue("%scn%",r,taxes,t));

revenue("%scn%","total","chk",t)	  = sum(r, revenue("%scn%",r,"govt.l",t))
	-(govdef0 - sum((r,h),tp0(r,h))*(TRANS.L))*PFX.L/CPI.L
	- sum((r,taxes),revenue("%scn%",r,taxes,t)) + (CTAXREV.L*PFX.L/CPI.L)$swcarb;

revenue("%scn%","total","chktrnrev",t) = sum((r,h),tp0(r,h))*(TRANS.L)*PFX.L/CPI.L - sum((r,taxes),revenue("%scn%",r,taxes,t)) +govdef0*PFX.l/CPI.l + (CTAXREV.L*PFX.L/CPI.L)$swcarb;

*------------------------------------------------------------------------
* Welfare decomposition
*------------------------------------------------------------------------

pexp(r,h,t) = PW.l(r,h);

* !!!! bad calculation - don't use
pinc(r,h,t)$[w0_h(r,h)] =
	[PFX.l*TRANS.l*tp0(r,h)
	+ PLS.l(r,h)*(lsr0(r,h)+ls0(r,h)*gprod)
	+ (PK.l*ke0(r,h))$[(not swhhext)]
	+ (PK.l*ke0_m(r)*ke0_shr(r,h))$[(swhhext)]
	+ (RKEXT.l(r)*ke0_x(r)*ke0_shr(r,h))$[(swhhext)]
	+ PFX.l*fsav_h(r,h)
	+ CTAXTRN.l(r,h)$[swcarb]
	] / w0_h(r,h);

* pinc(r,h,t) = PW.l(r,h);


wdecomp("%scn%","%","income",r,h,t,"PLS")$[w0_h(r,h)] =
	100*(PLS.l(r,h)/pexp(r,h,t))*(lsr0(r,h)+ls0(r,h)*gprod) / w0_h(r,h);
wdecomp("%scn%","%","income",r,h,t,"TRANS")$[w0_h(r,h)] =
	100*(PFX.l*TRANS.l/pexp(r,h,t))*(tp0(r,h)) / w0_h(r,h);
wdecomp("%scn%","%","income",r,h,t,"PK")$[w0_h(r,h)$(not swhhext)] =
	100*(PK.l/pexp(r,h,t))*(ke0(r,h)) / w0_h(r,h);
wdecomp("%scn%","%","income",r,h,t,"PK")$[w0_h(r,h)$(swhhext)] =
	100*(PK.l/pexp(r,h,t))*(ke0_m(r)*ke0_shr(r,h)) / w0_h(r,h);
wdecomp("%scn%","%","income",r,h,t,"RKEXT")$[w0_h(r,h)$(swhhext)] =
	100*(RKEXT.l(r)/pexp(r,h,t))*(ke0_x(r)*ke0_shr(r,h)) / w0_h(r,h);

wdecomp("%scn%","%","income",r,h,t,"FSAV")$[w0_h(r,h)] =
	100*(PFX.l/pexp(r,h,t))*(fsav_h(r,h)) / w0_h(r,h);
wdecomp("%scn%","%","income",r,h,t,"CTAXREV")$[w0_h(r,h)$swcarb] =
	100*(CTAXTRN.l(r,h)/pexp(r,h,t))/w0_h(r,h);

wdecomp("%scn%","%","income",r,h,t,"Wchk") = sum(u,wdecomp("%scn%","%","income",r,h,t,u));
wdecomp("%scn%","%","income",r,h,t,"W")	= 100*W.l(r,h);
wdecomp("%scn%","%","income",r,h,t,"dchk") =
	wdecomp("%scn%","%","income",r,h,t,"W") - wdecomp("%scn%","%","income",r,h,t,"Wchk");

wdecomp("%scn%","$","income",r,h,t,"PLS")$[w0_h(r,h)] =
	(PLS.l(r,h)/pexp(r,h,t))*(lsr0(r,h)+ls0(r,h)*gprod) ;
wdecomp("%scn%","$","income",r,h,t,"TRANS")$[w0_h(r,h)] =
	(PFX.l*TRANS.l/pexp(r,h,t))*(tp0(r,h)) ;
wdecomp("%scn%","$","income",r,h,t,"PK")$[w0_h(r,h)$(not swhhext)] =
	(PK.l/pexp(r,h,t))*(ke0(r,h));
wdecomp("%scn%","$","income",r,h,t,"PK")$[w0_h(r,h)$(swhhext)] =
	(PK.l/pexp(r,h,t))*(ke0_m(r)*ke0_shr(r,h));
wdecomp("%scn%","$","income",r,h,t,"RKEXT")$[w0_h(r,h)$(swhhext)] =
	(RKEXT.l(r)/pexp(r,h,t))*(ke0_x(r)*ke0_shr(r,h));

wdecomp("%scn%","$","income",r,h,t,"FSAV")$[w0_h(r,h)] =
	(PFX.l/pexp(r,h,t))*(fsav_h(r,h)) ;
wdecomp("%scn%","$","income",r,h,t,"CTAXREV")$[w0_h(r,h)$swcarb] =
	(CTAXTRN.l(r,h)/pexp(r,h,t));

wdecomp("%scn%","$","income","total",h,t,u) = sum(r,wdecomp("%scn%","$","income",r,h,t,u));
wdecomp("%scn%","%","income","total",h,t,u) = 100*sum(r,wdecomp("%scn%","$","income",r,h,t,u))/sum(r,w0_h(r,h));

wdecomp("%scn%","$","income",r,h,t,"Wchk") = sum(u,wdecomp("%scn%","$","income",r,h,t,u));
wdecomp("%scn%","$","income",r,h,t,"W")	= W.l(r,h)*w0_h(r,h);
wdecomp("%scn%","$","income",r,h,t,"dchk") =
	wdecomp("%scn%","$","income",r,h,t,"W") - wdecomp("%scn%","$","income",r,h,t,"Wchk");


*------------------------------------------------------------------------
* GDP decomposition
*------------------------------------------------------------------------

r_gdp("%scn%","$","income",r,t,"ctaxrev")$swcarb = sum(h,CTAXTRN.l(r,h)) / pnum("ALL",t);
r_gdp("%scn%","$","income",r,t,"taxrev") = revenue("%scn%",r,"total",t) - r_gdp("%scn%","$","income",r,t,"ctaxrev")$swcarb;
r_gdp("%scn%","$","income",r,t,"labinc") = sum(h,PLS.l(r,h)*LS.l(r,h)*ls0(r,h)*gprod) / pnum("ALL",t);
r_gdp("%scn%","$","income",r,t,"capinc")$[(not swhhext)] = sum(h,PK.l*ke0(r,h)) / pnum("ALL",t);
r_gdp("%scn%","$","income",r,t,"capinc")$[swhhext] = sum(h,(PK.l*ke0_m(r) + RKEXT.l(r)*ke0_x(r))*ke0_shr(r,h)) / pnum("ALL",t);
r_gdp("%scn%","$","income","total",t,u) = sum(r,r_gdp("%scn%","$","income",r,t,u));
r_gdp("%scn%","$","income",r,t,"total") = sum(u,r_gdp("%scn%","$","income",r,t,u));
r_gdp("%scn%","$","income","total",t,"total") = sum(r,r_gdp("%scn%","$","income",r,t,"total"));


*------------------------------------------------------------------------
* Electricity supply decomposition
*------------------------------------------------------------------------

* !!!! decompose extant vs. mutable at some point
r_elec(r,s,egt,t,"conv","supply (TWh)","%scn%")$[y_(r,s)$y_egt(s)$(not vgen(egt))] = ((SYMEGT.l(r,s,egt)+sum(v,SYXEGT.l(r,s,egt,v))))/imp_pele0(r);
r_elec(r,s,egt,t,"vgen","supply (TWh)","%scn%")$[y_(r,s)$y_egt(s)$vgen(egt)] = ((YBET.l(r,s,egt)+sum(v,YXBET.l(r,s,egt,v)))/(1-ty0(r,s)))/imp_pele0(r);

r_elec("ALL",s,egt,t,"conv","supply (TWh)","%scn%") = sum(r,r_elec(r,s,egt,t,"conv","supply (TWh)","%scn%"));
r_elec("ALL",s,egt,t,"vgen","supply (TWh)","%scn%") = sum(r,r_elec(r,s,egt,t,"vgen","supply (TWh)","%scn%"));


*------------------------------------------------------------------------
* Core storage
*------------------------------------------------------------------------

* ++++++++++ store model output ++++++++++

* ++++++++++ REPH - household params
* consumption
reph(r,"ALL",h,t,"C","%scn%") = C.l(r,h);
reph(r,"ALL",h,t,"PC","%scn%") = PC.l(r,h);
reph("ALL","ALL",h,t,"C","%scn%") = sum(r,C.l(r,h)*c0_h(r,h))/sum(r,c0_h(r,h));
reph(r,"ALL","ALL",t,"C","%scn%") = sum(h,C.l(r,h)*c0_h(r,h))/sum(h,c0_h(r,h));
reph("ALL","ALL","ALL",t,"C","%scn%") = sum((r,h),C.l(r,h)*c0_h(r,h))/sum((r,h),c0_h(r,h));

* full consumption
reph(r,"ALL",h,t,"Z","%scn%") = Z.l(r,h);
reph(r,"ALL",h,t,"PZ","%scn%") = PZ.l(r,h);
reph("ALL","ALL",h,t,"Z","%scn%") = sum(r,Z.l(r,h)*z0_h(r,h))/sum(r,z0_h(r,h));
reph(r,"ALL","ALL",t,"Z","%scn%") = sum(h,Z.l(r,h)*z0_h(r,h))/sum(h,z0_h(r,h));
reph("ALL","ALL","ALL",t,"Z","%scn%") = sum((r,h),Z.l(r,h)*z0_h(r,h))/sum((r,h),z0_h(r,h));

* welfare
reph(r,"ALL",h,t,"W","%scn%") = W.l(r,h);
reph(r,"ALL",h,t,"PW","%scn%") = PW.l(r,h);
reph("ALL","ALL",h,t,"W","%scn%") = sum(r,W.l(r,h)*(z0_h(r,h)+inv0_h(r,h)))/sum(r,z0_h(r,h)+inv0_h(r,h));
reph(r,"ALL","ALL",t,"W","%scn%") = sum(h,W.l(r,h)*(z0_h(r,h)+inv0_h(r,h)))/sum(h,z0_h(r,h)+inv0_h(r,h));
reph("ALL","ALL","ALL",t,"W","%scn%") = sum((r,h),W.l(r,h)*(z0_h(r,h)+inv0_h(r,h)))/sum((r,h),z0_h(r,h)+inv0_h(r,h));

* RA income
reph(r,"ALL",h,t,"RA","%scn%") = RA.l(r,h)/pnum("ALL",t);
reph("ALL","ALL",h,t,"RA","%scn%") = sum(r,RA.l(r,h))/pnum("ALL",t);
reph(r,"ALL","ALL",t,"RA","%scn%") = sum(h,RA.l(r,h))/pnum("ALL",t);
reph("ALL","ALL","ALL",t,"RA","%scn%") = sum((r,h),RA.l(r,h))/pnum("ALL",t);

* welfare
reph(r,"ALL",h,t,"WELFARE3","%scn%") = W.l(r,h);
reph("ALL","ALL",h,t,"WELFARE3","%scn%") = reph("ALL","ALL",h,t,"W","%scn%");
reph(r,"ALL","ALL",t,"WELFARE3","%scn%") = reph(r,"ALL","ALL",t,"W","%scn%");
reph("ALL","ALL","ALL",t,"WELFARE3","%scn%") = reph("ALL","ALL","ALL",t,"W","%scn%");

* transfers
reph("ALL","ALL","ALL",t,"TRANS","%scn%") = TRANS.l;
reph(r,"ALL",h,t,"HHTP","%scn%") = TRANS.l*(sum(tp,hhtp0(r,h,tp)));
reph("ALL","ALL",h,t,"HHTP","%scn%") = TRANS.l*(sum((tp,r),hhtp0(r,h,tp)));
reph(r,"ALL","ALL",t,"HHTP","%scn%") = TRANS.l*(sum((tp,h),hhtp0(r,h,tp)));
reph("ALL","ALL","ALL",t,"HHTP","%scn%") = TRANS.l*(sum((tp,r,h),hhtp0(r,h,tp)));


* carbon tax revenue household transfers/distributions
reph(r,"ALL",h,t,"CTAXREV","%scn%")$[(t.val ge 2020)$swcarb] =
	CTAXTRN.l(r,h)/pnum("ALL",t);
reph("ALL","ALL",h,t,"CTAXREV","%scn%")$[(t.val ge 2020)$swcarb] =
	sum(r,reph(r,"ALL",h,t,"CTAXREV","%scn%"));
reph(r,"ALL","ALL",t,"CTAXREV","%scn%")$[(t.val ge 2020)$swcarb] =
	sum(h,reph(r,"ALL",h,t,"CTAXREV","%scn%"));
reph("ALL","ALL","ALL",t,"CTAXREV","%scn%")$[(t.val ge 2020)$swcarb] =
	sum((r,h),reph(r,"ALL",h,t,"CTAXREV","%scn%"));

* RA income without carbon tax revenue transfers
reph(r,"ALL",h,t,"RAnocarb","%scn%")$[(z0_h(r,h)+inv0_h(r,h))] =
	(reph(r,"ALL",h,t,"RA","%scn%") - reph(r,"ALL",h,t,"CTAXREV","%scn%"))/(z0_h(r,h)+inv0_h(r,h));
reph("ALL","ALL",h,t,"RAnocarb","%scn%")$[(sum(r,(z0_h(r,h)+inv0_h(r,h))))] =
	sum(r,(reph(r,"ALL",h,t,"RA","%scn%") - reph(r,"ALL",h,t,"CTAXREV","%scn%")))/sum(r,(z0_h(r,h)+inv0_h(r,h)));
reph(r,"ALL","ALL",t,"RAnocarb","%scn%")$[(sum(h,(z0_h(r,h)+inv0_h(r,h))))] =
	sum(h,(reph(r,"ALL",h,t,"RA","%scn%") - reph(r,"ALL",h,t,"CTAXREV","%scn%")))/sum(h,(z0_h(r,h)+inv0_h(r,h)));
reph("ALL","ALL","ALL",t,"RAnocarb","%scn%")$[(sum((r,h),(z0_h(r,h)+inv0_h(r,h))))] =
	sum((r,h),(reph(r,"ALL",h,t,"RA","%scn%") - reph(r,"ALL",h,t,"CTAXREV","%scn%")))/sum((r,h),(z0_h(r,h)+inv0_h(r,h)));

* RA income with carbon tax revenue transfers
reph(r,"ALL",h,t,"RAcarb","%scn%")$[(z0_h(r,h)+inv0_h(r,h))] =
	(reph(r,"ALL",h,t,"RA","%scn%"))/(z0_h(r,h)+inv0_h(r,h));
reph("ALL","ALL",h,t,"RAcarb","%scn%")$[(sum(r,(z0_h(r,h)+inv0_h(r,h))))] =
	sum(r,(reph(r,"ALL",h,t,"RA","%scn%")))/sum(r,(z0_h(r,h)+inv0_h(r,h)));
reph(r,"ALL","ALL",t,"RAcarb","%scn%")$[(sum(h,(z0_h(r,h)+inv0_h(r,h))))] =
	sum(h,(reph(r,"ALL",h,t,"RA","%scn%")))/sum(h,(z0_h(r,h)+inv0_h(r,h)));
reph("ALL","ALL","ALL",t,"RAcarb","%scn%")$[(sum((r,h),(z0_h(r,h)+inv0_h(r,h))))] =
	sum((r,h),(reph(r,"ALL",h,t,"RA","%scn%")))/sum((r,h),(z0_h(r,h)+inv0_h(r,h)));

* Labor supply index (not scaled by grod)
reph(r,"ALL",h,t,"LS","%scn%") = LS.l(r,h);
* reph(r,"ALL",h,t,"LS","%scn%") = LS.l(r,h)*gprod;
reph(r,"ALL",h,t,"PLS","%scn%") = PLS.l(r,h);

* Labor supply
reph(r,q,h,t,"SLS","%scn%")$[le0(r,q,h)] = SLS.l(r,q,h)/le0(r,q,h);
reph(r,"ALL",h,t,"SLS","%scn%")$[(sum(q,le0(r,q,h)))] = sum(q,SLS.l(r,q,h))/sum(q,le0(r,q,h));
reph("ALL",q,h,t,"SLS","%scn%")$[(sum(r,le0(r,q,h)))] = sum(r,SLS.l(r,q,h))/sum(r,le0(r,q,h));
reph("ALL",q,"ALL",t,"SLS","%scn%")$[(sum((r,h),le0(r,q,h)))] = sum((r,h),SLS.l(r,q,h))/sum((r,h),le0(r,q,h));
reph(r,"ALL","ALL",t,"SLS","%scn%")$[(sum((q,h),le0(r,q,h)))] = sum((q,h),SLS.l(r,q,h))/sum((q,h),le0(r,q,h));
reph("ALL","ALL",h,t,"SLS","%scn%")$[(sum((r,q),le0(r,q,h)))] = sum((r,q),SLS.l(r,q,h))/sum((r,q),le0(r,q,h));
reph("ALL","ALL","ALL",t,"SLS","%scn%")$[(sum((r,q,h),le0(r,q,h)))] = sum((r,q,h),SLS.l(r,q,h))/sum((r,q,h),le0(r,q,h));


reph(r,"ALL",h,t,"DSLS","%scn%")$[ls0(r,h)] = DSLS.l(r,h)/ls0(r,h);
reph("ALL","ALL",h,t,"DSLS","%scn%")$[(sum(r,ls0(r,h)))] = sum(r,DSLS.l(r,h))/sum(r,ls0(r,h));
reph(r,"ALL","ALL",t,"DSLS","%scn%")$[(sum(h,ls0(r,h)))] = sum(h,DSLS.l(r,h))/sum(h,ls0(r,h));
reph("ALL","ALL","ALL",t,"DSLS","%scn%")$[(sum((r,h),ls0(r,h)))] = sum((r,h),DSLS.l(r,h))/sum((r,h),ls0(r,h));

* Leisure demand
reph(r,"ALL",h,t,"DLS","%scn%")$[lsr0(r,h)] = DLS.l(r,h)/lsr0(r,h);
reph("ALL","ALL",h,t,"DLS","%scn%")$[(sum(r,lsr0(r,h)))] = sum(r,DLS.l(r,h))/sum(r,lsr0(r,h));
reph(r,"ALL","ALL",t,"DLS","%scn%")$[(sum(h,lsr0(r,h)))] = sum(h,DLS.l(r,h))/sum(h,lsr0(r,h));
reph("ALL","ALL","ALL",t,"DLS","%scn%")$[(sum((r,h),lsr0(r,h)))] = sum((r,h),DLS.l(r,h))/sum((r,h),lsr0(r,h));

* Labor income
reph(r,"ALL",h,t,"LINC","%scn%")$[(sum((q),le0(r,q,h)))] =
	(sum(q, LS.l(r,h)*le0(r,q,h)*gprod*PL.l(q)) / pnum("ALL",t))/sum(q,le0(r,q,h));
reph("ALL","ALL",h,t,"LINC","%scn%")$[(sum((r,q),le0(r,q,h)))] =
	(sum((r,q), LS.l(r,h)*le0(r,q,h)*gprod*PL.l(q)) / pnum("ALL",t))/sum((r,q),le0(r,q,h));
reph(r,"ALL","ALL",t,"LINC","%scn%")$[(sum((h,q),le0(r,q,h)))] =
	(sum((h,q), LS.l(r,h)*le0(r,q,h)*gprod*PL.l(q)) / pnum("ALL",t))/sum((h,q),le0(r,q,h));
reph("ALL","ALL","ALL",t,"LINC","%scn%")$[(sum((r,q,h),le0(r,q,h)))] =
	(sum((r,q,h), LS.l(r,h)*le0(r,q,h)*gprod*PL.l(q)) / pnum("ALL",t))/sum((r,q,h),le0(r,q,h));

* Capital income
reph(r,"ALL",h,t,"KINC","%scn%")$[ke0(r,h)$(not swhhext)] =
	(PK.l*ke0(r,h) / pnum("ALL",t))/ke0(r,h);
reph("ALL","ALL",h,t,"KINC","%scn%")$[(sum(r,ke0(r,h)))$(not swhhext)] =
	(sum(r,PK.l*ke0(r,h)) / pnum("ALL",t))/sum(r,ke0(r,h));
reph(r,"ALL","ALL",t,"KINC","%scn%")$[(sum(h,ke0(r,h)))$(not swhhext)] =
	(sum(h,PK.l*ke0(r,h)) / pnum("ALL",t))/sum(h,ke0(r,h));
reph("ALL","ALL","ALL",t,"KINC","%scn%")$[(sum((r,h),ke0(r,h)))$(not swhhext)] =
	(sum((r,h),PK.l*ke0(r,h)) / pnum("ALL",t))/sum((r,h),ke0(r,h));

reph(r,"ALL",h,t,"KINC","%scn%")$[ke0(r,h)$(swhhext)] =
	((PK.l*ke0_m(r)+RKEXT.l(r)*ke0_x(r))*ke0_shr(r,h) / pnum("ALL",t))/((ke0_m(r)+ke0_x(r))*ke0_shr(r,h));
reph("ALL","ALL",h,t,"KINC","%scn%")$[(sum(r,ke0(r,h)))$(swhhext)] =
	(sum(r,(PK.l*ke0_m(r)+RKEXT.l(r)*ke0_x(r))*ke0_shr(r,h)) / pnum("ALL",t))/sum(r,((ke0_m(r)+ke0_x(r))*ke0_shr(r,h)));
reph(r,"ALL","ALL",t,"KINC","%scn%")$[(sum(h,ke0(r,h)))$(swhhext)] =
	(sum(h,(PK.l*ke0_m(r)+RKEXT.l(r)*ke0_x(r))*ke0_shr(r,h)) / pnum("ALL",t))/sum(h,((ke0_m(r)+ke0_x(r))*ke0_shr(r,h)));
reph("ALL","ALL","ALL",t,"KINC","%scn%")$[(sum((r,h),ke0(r,h)))$(swhhext)] =
	(sum((r,h),(PK.l*ke0_m(r)+RKEXT.l(r)*ke0_x(r))*ke0_shr(r,h)) / pnum("ALL",t))/sum((r,h),((ke0_m(r)+ke0_x(r))*ke0_shr(r,h)));


* ++++++++++ REP - core params
rep(r,g,t,"X","%scn%")		   = X.l(r,g);
rep(r,g,t,"PY","%scn%")	   = PY.l(r,g);
rep(r,g,t,"A","%scn%")		   = A.l(r,g);
rep(r,g,t,"PA","%scn%")	   = PA.l(r,g);
rep(r,s,t,"YM","%scn%")	   = YM.l(r,s);
rep(r,egt,t,"YMEGT","%scn%")  = YMEGT.l(r,"ele",egt);
rep(r,egt,t,"YXEGT","%scn%")  = sum(v,YXEGT.l(r,"ele",egt,v));
rep(r,egt,t,"YMBET","%scn%")  = YBET.l(r,"ele",egt);
rep(r,egt,t,"YXBET","%scn%")  = sum(v,YXBET.l(r,"ele",egt,v));
rep(r,s,t,"Y_ELBS","%scn%")  = Y_ELBS.l(r,s);
rep(r,s,t,"YX","%scn%")	   = sum(v,YX.l(r,s,v));
rep(r,s,t,"E","%scn%")		   = E.l(r,s);
rep(r,s,t,"VA","%scn%")	   = VA.l(r,s);
rep(r,"ALL",t,"C","%scn%")	   = sum(h,C.l(r,h)*c0_h(r,h))/sum(h,c0_h(r,h));
rep(r,"ALL",t,"PC","%scn%")   = sum(h,PC.l(r,h)*c0_h(r,h))/sum(h,c0_h(r,h));
rep(r,"ALL",t,"INV","%scn%")  = INV.l(r);
rep(r,"ALL",t,"PINV","%scn%") = PINV.l(r);
rep(r,"ALL",t,"Z","%scn%")	   = sum(h,Z.l(r,h)*z0_h(r,h))/sum(h,z0_h(r,h));
rep(r,"ALL",t,"PZ","%scn%")   = sum(h,PZ.l(r,h)*z0_h(r,h))/sum(h,z0_h(r,h));
rep(r,"ALL",t,"W","%scn%")	   = sum(h,W.l(r,h)*(z0_h(r,h)+inv0_h(r,h)))/sum(h,z0_h(r,h)+inv0_h(r,h));
rep(r,"ALL",t,"PW","%scn%")   = sum(h,PW.l(r,h)*(z0_h(r,h)+inv0_h(r,h)))/sum(h,z0_h(r,h)+inv0_h(r,h));

rep(r,"ALL",t,"PLS","%scn%") = sum(h,PLS.l(r,h)*(ls0(r,h)*gprod+lsr0(r,h)))/sum(h,(ls0(r,h)*gprod+lsr0(r,h)));
rep(r,"ALL",t,"LS","%scn%")  = sum(h,LS.l(r,h)*(ls0(r,h)*gprod))/sum(h,ls0(r,h)*gprod);
rep(r,"ALL",t,"PL","%scn%")  = PL.l(r);

rep(r,s,t,"RKX","%scn%")		 = sum(v,RKX.l(r,s,v));
rep(r,s,t,"RK","%scn%")		 = rkrs(r,s);
rep("ALL","ALL",t,"RKS","%scn%")= RKS.l;
rep("ALL","ALL",t,"KS","%scn%")$[(not swrks)] = KS.l;
rep("ALL","ALL",t,"PK","%scn%")= PK.l;
rep(r,"ALL",t,"RKEXT","%scn%")= RKEXT.l(r);
rep("ALL","ALL",t,"TRANS","%scn%")= TRANS.l;
rep("ALL","ALL",t,"CPI","%scn%")   = CPI.l;
reph("ALL","ALL","ALL",t,"CPI","%scn%")   = CPI.l;

rep(r,"ALL",t,"CO2","%scn%")	   = sum(sfd,CO2.l(r,sfd));
rep(r,sfd,t,"PDCO2","%scn%")	   = PDCO2.l(r,sfd)*1000;
rep("ALL","ALL",t,"PCO2","%scn%") = PCO2.l*1000;
rep("ALL","ALL",t,"PFX","%scn%")  = PFX.l;

rep(r,"ALL",t,"RA","%scn%") = sum(h,RA.l(r,h)) / pnum("ALL",t);

rep("ALL",g,t,"X","%scn%") = sum(r,X.l(r,g)*s0(r,g))/sum(r,s0(r,g));

rep("ALL",g,t,"PN","%scn%") = PN.l(g);
rep(r,s,t,"PVA","%scn%") = PVA.l(r,s);
rep(r,s,t,"PE","%scn%") = PE.l(r,s);
rep(r,s,t,"PRM","%scn%") = PRM.l(r,s);
rep("ALL","ALL",t,"GOVT","%scn%") = GOVT.l;
rep("ALL","ALL",t,"NYSE","%scn%") = NYSE.l;	
rep("ALL","ALL",t,"JPOW","%scn%") = JPOW.l;
rep("ALL","ALL",t,"JPOWm","%scn%") = JPOW.m;
rep("ALL","ALL",t,"BRRR","%scn%") = BRRR.l;

* welfare calculations
rep(r,"ALL",t,"WELFARE1","%scn%")$[z0(r)+inv0(r)] =
	sum(h,PW.l(r,h)*W.l(r,h)*(z0_h(r,h)+inv0_h(r,h)))/sum(h,(z0_h(r,h)+inv0_h(r,h)));
rep(r,"ALL",t,"WELFARE2","%scn%")$[z0(r)+inv0(r)] =
	sum(h,(RA.l(r,h)/PW.l(r,h)))/sum(h,(z0_h(r,h)+inv0_h(r,h)));
rep(r,"ALL",t,"WELFARE3","%scn%")$[z0(r)+inv0(r)] =
	rep(r,"ALL",t,"W","%scn%");
rep("ALL","ALL",t,"WELFARE1","%scn%") =
	sum((r,h),PW.l(r,h)*W.l(r,h)*(z0_h(r,h)+inv0_h(r,h)))/sum((r,h),z0_h(r,h)+inv0_h(r,h));
rep("ALL","ALL",t,"WELFARE2","%scn%") =
	sum((r,h),RA.l(r,h)/PW.l(r,h))/sum((r,h),z0_h(r,h)+inv0_h(r,h));
rep("ALL","ALL",t,"WELFARE3","%scn%") =
	sum((r,h),W.l(r,h)*(z0_h(r,h)+inv0_h(r,h)))/sum((r,h),z0_h(r,h)+inv0_h(r,h));

rep("ALL","ALL",t,"CARB0","%scn%") = sum(r,carb0(r));
rep("ALL","ALL",t,"CO2","%scn%")	= sum((r,sfd),CO2.l(r,sfd));

* productivity growth 
rep(r,g,t,"PRODF","%scn%")			= prodf(t);
rep("ALL","ALL",t,"PRODF","%scn%") = prodf(t);

* income GDP
rep("ALL","ALL",t,"RA","%scn%")   = sum((r,h),RA.l(r,h))/pnum("ALL",t);
rep("ALL","ALL",t,"GDP2","%scn%") = sum((r,h),(RA.l(r,h)-PLS.l(r,h)*DLS.l(r,h)));
rep(r,"ALL",t,"GDP2","%scn%")	   = sum(h,(RA.l(r,h)-PLS.l(r,h)*DLS.l(r,h)));

rep(r,"ALL",t,"GDPincome","%scn%") =
	(
		revenue("%scn%",r,"total",t)
*		+ [PDCO2.l(r)*CO2.l(r)]$[swcarb]
*		+ [PCO2.l*carb0(r)]$[swcarb]/ pnum("ALL",t)
		+ sum(h,PLS.l(r,h)*LS.l(r,h)*ls0(r,h)*gprod)/ pnum("ALL",t)
		+ sum(h,(PK.l*ke0(r,h)))$[(not swhhext)] / pnum("ALL",t)
		+ sum(h,(PK.l*ke0_m(r)*ke0_shr(r,h)))$[(swhhext)] / pnum("ALL",t)
		+ sum(h,(RKEXT.l(r)*ke0_x(r)*ke0_shr(r,h)))$[(swhhext)] / pnum("ALL",t)

	)
	;

rep("ALL","ALL",t,"GDPincome","%scn%") = sum(r,rep(r,"ALL",t,"GDPincome","%scn%"));

rep(r,"ALL",t,"GDPnocarb","%scn%") =
	(
		revenue("%scn%",r,"total",t)
		+ sum(h,PLS.l(r,h)*LS.l(r,h)*ls0(r,h)*gprod)/ pnum("ALL",t)
		+ sum(h,(PK.l*ke0(r,h)))$[(not swhhext)] / pnum("ALL",t)
		+ sum(h,(PK.l*ke0_m(r)*ke0_shr(r,h)))$[(swhhext)] / pnum("ALL",t)
		+ sum(h,(RKEXT.l(r)*ke0_x(r)*ke0_shr(r,h)))$[(swhhext)] / pnum("ALL",t)
		- revenue("%scn%",r,"ctax",t)$swcarb
	)
	;

rep("ALL","ALL",t,"GDPnocarb","%scn%") = sum(r,rep(r,"ALL",t,"GDPnocarb","%scn%"));


* commodity supply
rep(r,g,t,"SX","%scn%") = SX.l(r,g);
rep("ALL",g,t,"SX","%scn%") = sum(r,SX.l(r,g));


* labor supply
rep(r,"ALL",t,"SLS","%scn%") = sum((q,h),SLS.l(r,q,h));
rep("ALL","ALL",t,"SLS","%scn%") = sum((r,q,h),SLS.l(r,q,h));

* consumption
rep("ALL","ALL",t,"C","%scn%") = sum((r,h), C.l(r,h)*c0_h(r,h))/sum((r,h),c0_h(r,h));


*------------------------------------------------------------------------
* Demand for co2 emissions
*------------------------------------------------------------------------

* demand for co2 emissions
rep(r,g,t,"DCO2","%scn%") = r_dco2(r,g,t);
rep("ALL",g,t,"DCO2","%scn%") = sum(r,rep(r,g,t,"DCO2","%scn%"));
rep(r,"ALL",t,"DCO2","%scn%") = sum(g,rep(r,g,t,"DCO2","%scn%"));
rep("ALL","ALL",t,"DCO2","%scn%") = sum((r,g),rep(r,g,t,"DCO2","%scn%"));

* embodied direct sectoral emissions
rep(r,s,t,"DCO2_SECT","%scn%") =
	sum(g,(DIDME.l(r,g,s)*cco2(r,g,s))$[fe(g)$id0(r,g,s)$(not y_egt(s))]
	+ (DIDMM.l(r,g,s)*cco2(r,g,s))$[cru(g)$id0(r,g,s)$(not y_egt(s))]
	+ (sum(v,DIDX.l(r,g,s,v)$[x_k(r,s,v)])*cco2(r,g,s))$[(cru(g) or fe(g))$id0(r,g,s)$(not y_egt(s))])
	+ sum((g,egt)$[ibar_gen0(r,g,egt)],(DIDMEGT.l(r,g,s,egt)+DIDBET.l(r,g,s,egt)+sum(v,DIDXEGT.l(r,g,s,egt,v)$[xegt_k(r,s,egt,v)]))*cco2egt(r,g,s,egt))$[y_egt(s)]
;

rep(r,"fd",t,"DCO2_SECT","%scn%") = sum((h,g),(DCD.l(r,g,h)*cco2(r,g,"fd"))$[fe(g)$cd0(r,g)]);

rep("ALL",s,t,"DCO2_SECT","%scn%") = sum(r,rep(r,s,t,"DCO2_SECT","%scn%"));
rep("ALL","fd",t,"DCO2_SECT","%scn%") = sum(r,rep(r,"fd",t,"DCO2_SECT","%scn%"));

reph(r,g,s,t,"DCO2_SECT","%scn%") =
	(DIDME.l(r,g,s)*cco2(r,g,s))$[fe(g)$id0(r,g,s)$(not y_egt(s))]
	+ (DIDMM.l(r,g,s)*cco2(r,g,s))$[cru(g)$id0(r,g,s)$(not y_egt(s))]
	+ (sum(v,DIDX.l(r,g,s,v)$[x_k(r,s,v)])*cco2(r,g,s))$[(cru(g) or fe(g))$id0(r,g,s)$(not y_egt(s))]
	+ sum((egt)$[ibar_gen0(r,g,egt)],(DIDMEGT.l(r,g,s,egt)+DIDBET.l(r,g,s,egt)+sum(v,DIDXEGT.l(r,g,s,egt,v)$[xegt_k(r,s,egt,v)]))*cco2egt(r,g,s,egt))$[y_egt(s)]
;

reph(r,g,"fd",t,"DCO2_SECT","%scn%") = sum((h),(DCD.l(r,g,h)*cco2(r,g,"fd"))$[fe(g)$cd0(r,g)]);

reph("ALL",g,s,t,"DCO2_SECT","%scn%") = sum(r,reph(r,g,s,t,"DCO2_SECT","%scn%"));
reph("ALL",g,"fd",t,"DCO2_SECT","%scn%") = sum(r,reph(r,g,"fd",t,"DCO2_SECT","%scn%"));
* reph("ALL",g,sfd,t,"DCO2_SECT_chk","%scn%") = reph("ALL",g,sfd,t,"DCO2_SECT","%scn%") - ;

chk_co2(r,sfd,t) = SCO2.l(r,sfd)-rep(r,sfd,t,"DCO2_SECT","%scn%");
display chk_co2;

*------------------------------------------------------------------------
* Capital demand
*------------------------------------------------------------------------


* capital demand -- !!!! update to include fixed resource
rep(r,s,t,"DKM","%scn%")	   = DKM.l(r,s)+sum(egt,DKMEGT.l(r,s,egt)+DKMBET.l(r,s,egt))$y_egt(s)+DKM_ELBS.l(r,s)$[elbs_act(r,s)];
rep(r,s,t,"DKX","%scn%")	   = sum(v,DKX.l(r,s,v)+sum(egt,DKXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)]+DKXBET.l(r,s,egt,v)$[y_egt(s)$xbet_k(r,s,egt,v)]));
rep(r,egt,t,"DKMEGT","%scn%") = DKMEGT.l(r,"ele",egt);
rep(r,egt,t,"DKMBET","%scn%") = DKMBET.l(r,"ele",egt);
rep(r,s,t,"DKM_ELBS","%scn%")	   = DKM_ELBS.l(r,s)$[elbs_act(r,s)];
rep(r,egt,t,"DKXEGT","%scn%") = sum(v,DKXEGT.l(r,"ele",egt,v));
rep(r,egt,t,"DKXBET","%scn%") = sum(v,DKXBET.l(r,"ele",egt,v));
rep(r,s,t,"DKD","%scn%")	   = sum(v,DKX.l(r,s,v))+DKM.l(r,s)
	+sum(egt,DKMEGT.l(r,s,egt)+DKMBET.l(r,s,egt)
		+sum(v,DKXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)]+DKXBET.l(r,s,egt,v)$[y_egt(s)$xbet_k(r,s,egt,v)])
	)$[y_egt(s)]
	+DKM_ELBS.l(r,s)$[elbs_act(r,s)]
;

*capital by egt
rep(r,egt,t,"DKEGT","%scn%")$(not vgen(egt)) =
	rep(r,egt,t,"DKMEGT","%scn%")
	+ rep(r,egt,t,"DKXEGT","%scn%")
;

rep(r,egt,t,"DKEGT","%scn%")$vgen(egt) =
	rep(r,egt,t,"DKMBET","%scn%")
	+ rep(r,egt,t,"DKXBET","%scn%")
;

* ---- aggregate capital demand
rep("ALL",s,t,"DKM","%scn%")	   = sum(r,DKM.l(r,s)+sum(egt,DKMEGT.l(r,s,egt)+DKMBET.l(r,s,egt))$y_egt(s));
rep(r,"ALL",t,"DKM","%scn%")	   = sum(s,DKM.l(r,s)+sum(egt,DKMEGT.l(r,s,egt)+DKMBET.l(r,s,egt))$y_egt(s));

rep("ALL",s,t,"DKX","%scn%")	   = sum(v,sum(r,DKX.l(r,s,v)+sum(egt,DKXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)])));
rep(r,"ALL",t,"DKX","%scn%")	   = sum(v,sum(s,DKX.l(r,s,v)+sum(egt,DKXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)])));

rep("ALL",egt,t,"DKMEGT","%scn%") = sum(r,DKMEGT.l(r,"ele",egt));
rep(r,"ALL",t,"DKMEGT","%scn%")   = sum(egt,DKMEGT.l(r,"ele",egt));

rep("ALL",egt,t,"DKXEGT","%scn%") = sum(v,sum(r,DKXEGT.l(r,"ele",egt,v)));
rep(r,"ALL",t,"DKXEGT","%scn%")   = sum(v,sum(egt,DKXEGT.l(r,"ele",egt,v)));

rep("ALL",egt,t,"DKMBET","%scn%") = sum(r,DKMBET.l(r,"ele",egt));
rep(r,"ALL",t,"DKMBET","%scn%")   = sum(egt,DKMBET.l(r,"ele",egt));

rep("ALL",egt,t,"DKXBET","%scn%") = sum(v,sum(r,DKXBET.l(r,"ele",egt,v)));
rep(r,"ALL",t,"DKXBET","%scn%")   = sum(v,sum(egt,DKXBET.l(r,"ele",egt,v)));

rep("ALL",s,t,"DKM_ELBS","%scn%")	   = sum(r,DKM_ELBS.l(r,s)$[elbs_act(r,s)]);
rep(r,"ALL",t,"DKM_ELBS","%scn%")	   = sum(s,DKM_ELBS.l(r,s)$[elbs_act(r,s)]);


rep("ALL",s,t,"DKD","%scn%")	   = sum(r,sum(v,DKX.l(r,s,v))+DKM.l(r,s)+sum(egt,DKMEGT.l(r,s,egt)+sum(v,DKXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)]+DKXBET.l(r,s,egt,v)$[y_egt(s)$xbet_k(r,s,egt,v)])+DKMBET.l(r,s,egt))$y_egt(s)+DKM_ELBS.l(r,s)$[elbs_act(r,s)]);
rep(r,"ALL",t,"DKD","%scn%")	   = sum(s,sum(v,DKX.l(r,s,v))+DKM.l(r,s)+sum(egt,DKMEGT.l(r,s,egt)+sum(v,DKXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)]+DKXBET.l(r,s,egt,v)$[y_egt(s)$xbet_k(r,s,egt,v)])+DKMBET.l(r,s,egt))$y_egt(s)+DKM_ELBS.l(r,s)$[elbs_act(r,s)]);
rep("ALL","ALL",t,"DKD","%scn%")  = sum((r,s),sum(v,DKX.l(r,s,v))+DKM.l(r,s)+sum(egt,DKMEGT.l(r,s,egt)+sum(v,DKXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)]+DKXBET.l(r,s,egt,v)$[y_egt(s)$xbet_k(r,s,egt,v)])+DKMBET.l(r,s,egt))$y_egt(s)+DKM_ELBS.l(r,s)$[elbs_act(r,s)]);


*------------------------------------------------------------------------
* Labor demand and Jobs
*------------------------------------------------------------------------

* Labor Demand
rep(r,s,t,"DLDM","%scn%")		= DLDM.l(r,s)+sum(egt,DLDMBET.l(r,s,egt)+DLDMEGT.l(r,s,egt))$y_egt(s)+DLDM_ELBS.l(r,s)$[elbs_act(r,s)];
rep(r,s,t,"DLDX","%scn%")		= sum(v,DLDX.l(r,s,v)+sum(egt,DLDXEGT.l(r,s,egt,v)$[y_egt(s)$ksxegt(r,s,egt)]+DLDXBET.l(r,s,egt,v)$[y_egt(s)$xbet_k(r,s,egt,v)]));
rep(r,egt,t,"DLDMBET","%scn%") = DLDMBET.l(r,"ele",egt);
rep(r,egt,t,"DLDXBET","%scn%") = sum(v,DLDXBET.l(r,"ele",egt,v));
rep(r,egt,t,"DLDMEGT","%scn%") = DLDMEGT.l(r,"ele",egt);
rep(r,egt,t,"DLDXEGT","%scn%") = sum(v,DLDXEGT.l(r,"ele",egt,v));
rep(r,s,t,"DLDM_ELBS","%scn%")		= DLDM_ELBS.l(r,s)$[elbs_act(r,s)];
rep(r,s,t,"DLD","%scn%")		= sum(v,DLDX.l(r,s,v))+DLDM.l(r,s)+sum(egt,DLDMBET.l(r,s,egt)+sum(v,DLDXEGT.l(r,s,egt,v)+DLDXBET.l(r,s,egt,v))+DLDMEGT.l(r,s,egt))$y_egt(s)+DLDM_ELBS.l(r,s)$[elbs_act(r,s)];

* ---- aggregate labor demand
rep("ALL",s,t,"DLDM","%scn%")		= sum(r,DLDM.l(r,s)+sum(egt,DLDMBET.l(r,s,egt)+DLDMEGT.l(r,s,egt))$y_egt(s));
rep(r,"ALL",t,"DLDM","%scn%")		= sum(s,DLDM.l(r,s)+sum(egt,DLDMBET.l(r,s,egt)+DLDMEGT.l(r,s,egt))$y_egt(s));

rep("ALL",s,t,"DLDX","%scn%")		= sum(v,sum(r,DLDX.l(r,s,v)+sum(egt,DLDXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)])));
rep(r,"ALL",t,"DLDX","%scn%")		= sum(v,sum(s,DLDX.l(r,s,v)+sum(egt,DLDXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)])));

rep("ALL",egt,t,"DLDMEGT","%scn%") = sum(r,DLDMEGT.l(r,"ele",egt));
rep(r,"ALL",t,"DLDMEGT","%scn%")	= sum(egt,DLDMEGT.l(r,"ele",egt));

rep("ALL",egt,t,"DLDXEGT","%scn%") = sum(v,sum(r,DLDXEGT.l(r,"ele",egt,v)));
rep(r,"ALL",t,"DLDXEGT","%scn%")	= sum(v,sum(egt,DLDXEGT.l(r,"ele",egt,v)));

rep("ALL",egt,t,"DLDMBET","%scn%") = sum(r,DLDMBET.l(r,"ele",egt));
rep(r,"ALL",t,"DLDMBET","%scn%")	= sum(egt,DLDMBET.l(r,"ele",egt));

rep("ALL",egt,t,"DLDXBET","%scn%") = sum(v,sum(r,DLDXBET.l(r,"ele",egt,v)));
rep(r,"ALL",t,"DLDXBET","%scn%")	= sum(v,sum(egt,DLDXBET.l(r,"ele",egt,v)));

rep("ALL",s,t,"DLDM_ELBS","%scn%")		= sum(r,DLDM_ELBS.l(r,s)$[elbs_act(r,s)]);
rep(r,"ALL",t,"DLDM_ELBS","%scn%")		= sum(s,DLDM_ELBS.l(r,s)$[elbs_act(r,s)]);

rep("ALL",s,t,"DLD","%scn%")		= sum(r,sum(v,DLDX.l(r,s,v))+DLDM.l(r,s)+sum(egt,sum(v,DLDXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)]+DLDXBET.l(r,s,egt,v)$[y_egt(s)$xbet_k(r,s,egt,v)])+DLDMBET.l(r,s,egt)+DLDMEGT.l(r,s,egt))$y_egt(s)+DLDM_ELBS.l(r,s)$[elbs_act(r,s)]);
rep(r,"ALL",t,"DLD","%scn%")		= sum(s,sum(v,DLDX.l(r,s,v))+DLDM.l(r,s)+sum(egt,sum(v,DLDXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)]+DLDXBET.l(r,s,egt,v)$[y_egt(s)$xbet_k(r,s,egt,v)])+DLDMBET.l(r,s,egt)+DLDMEGT.l(r,s,egt))$y_egt(s)+DLDM_ELBS.l(r,s)$[elbs_act(r,s)]);
rep("ALL","ALL",t,"DLD","%scn%")	= sum((r,s),sum(v,DLDX.l(r,s,v))+DLDM.l(r,s)+sum(egt,sum(v,DLDXEGT.l(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)]+DLDXBET.l(r,s,egt,v)$[y_egt(s)$xbet_k(r,s,egt,v)])+DLDMBET.l(r,s,egt)+DLDMEGT.l(r,s,egt))$y_egt(s)+DLDM_ELBS.l(r,s)$[elbs_act(r,s)]);

* Jobs
* ---- use BEA wage data to translate model output to FTE workers
* ---- new data preprocessing script load_jobs.gms to populate avg_wages
rep(r,s,t,"JOBS","%scn%")							 =rep(r,s,t,"DLD","%scn%")/avg_wages(r,s);
rep("ALL",s,t,"JOBS","%scn%")						 =sum(r,rep(r,s,t,"JOBS","%scn%"));

rep(r,"ALL",t,"JOBS","%scn%")						 =sum(s,rep(r,s,t,"JOBS","%scn%"));
rep("ALL","ALL",t,"JOBS","%scn%")					 =sum((r,s),rep(r,s,t,"JOBS","%scn%"));

rep(r,egt,t,"JOBSEGT","%scn%")$[(not vgen(egt))]	 =(rep(r,egt,t,"DLDMEGT","%scn%")+rep(r,egt,t,"DLDXEGT","%scn%"))/avg_wages(r,"ele");
rep("ALL",egt,t,"JOBSEGT","%scn%")$[(not vgen(egt))]=sum(r,rep(r,egt,t,"JOBSEGT","%scn%"));

rep(r,egt,t,"JOBSEGT","%scn%")$[vgen(egt)]			 =(rep(r,egt,t,"DLDMBET","%scn%")+rep(r,egt,t,"DLDXBET","%scn%"))/avg_wages(r,"ele");
rep("ALL",egt,t,"JOBSEGT","%scn%")$[vgen(egt)]		 =sum(r,rep(r,egt,t,"JOBSEGT","%scn%"));

rep(r,"ALL",t,"JOBSEGT","%scn%")                    = sum(egt,rep(r,egt,t,"JOBSEGT","%scn%"));

*------------------------------------------------------------------------
* Industrial sectoral/commodity parameters
*------------------------------------------------------------------------

* Industrial/sector output
* -- quantity
rep(r,s,t,"YM","%scn%")$[(not y_egt(s))] = YM.l(r,s)*sum(g,ys0(r,s,g))+Y_ELBS.l(r,s)*sum(g,elbs_out(r,s,g));
rep(r,s,t,"YM","%scn%")$[y_egt(s)] =
	sum(egt$[(not vgen(egt))],YMEGT.l(r,s,egt)*obar_gen0(r,egt))
	+ sum(egt$[vgen(egt)],YBET.l(r,s,egt)/(1-ty0(r,s)))
	;

rep(r,s,t,"YX","%scn%")$[(not y_egt(s))] = sum(v,YX.l(r,s,v)*sum(g,x_ys_out(r,s,g,v)));
rep(r,s,t,"YX","%scn%")$[y_egt(s)] =
	sum(v,sum(egt$[(not vgen(egt))],YXEGT.l(r,s,egt,v)$[xegt_k(r,s,egt,v)]*sum(g,xegt_ys_out(r,s,egt,g,v))))
	+ sum(v,sum(egt$[(not vgen(egt))],YXBET.l(r,s,egt,v)$[xbet_k(r,s,egt,v)]*sum(g,xbet_ys_out(r,s,egt,g,v))))
;


rep(r,s,t,"Industrial Output","%scn%") = rep(r,s,t,"YX","%scn%") + rep(r,s,t,"YM","%scn%");
rep("ALL",s,t,"Industrial Output","%scn%") = sum(r,rep(r,s,t,"Industrial Output","%scn%"));

* -- price index
rep(r,s,t,"PYS","%scn%")$[(sum(g,ys0(r,s,g)))] = sum(g,PY.l(r,g)*ys0(r,s,g))/sum(g,ys0(r,s,g));
rep("ALL",s,t,"PYS","%scn%")$[(sum((r,g),ys0(r,s,g)))] = sum((r,g),PY.l(r,g)*ys0(r,s,g))/sum((r,g),ys0(r,s,g));

*PYEGT.l(r,s,egt) = sum(g,PY.l(r,g)*obar_gen0(r,egt)*ys0(r,s,g)/sum(g.local,ys0(r,s,g))/(sum(g.local,obar_gen0(r,egt)*ys0(r,s,g)/sum(g.local,ys0(r,s,g)));

* -- price * quantity = value

* Commodity output
* -- quantity = supply
* -- price index
* -- price * quantity = value
rep(r,g,t,"SX","%scn%") = SX.l(r,g);
rep("ALL",g,t,"SX","%scn%") = sum(r,SX.l(r,g));

rep("ALL",g,t,"PY","%scn%")$[(sum(r,s0(r,g)))] = sum(r,PY.l(r,g)*s0(r,g))/sum(r,s0(r,g));

* Commodity demand

* -- Industrial
rep(r,g,t,"DIDM","%scn%")					  = sum(s,DIDMM.l(r,g,s)$[nne(g)$id0(r,g,s)]+DIDME.l(r,g,s)$[en(g)$id0(r,g,s)]);
rep(r,g,t,"DIDX","%scn%")					  = sum(v,sum(s,DIDX.l(r,g,s,v)));
rep(r,g,t,"DIDMEGT","%scn%")				  = sum(egt,DIDMEGT.l(r,g,"ele",egt));
rep(r,g,t,"DIDXEGT","%scn%")				  = sum(v,sum(egt,DIDXEGT.l(r,g,"ele",egt,v)));
rep(r,g,t,"DIDBET","%scn%")				  = sum(egt,DIDBET.l(r,g,"ele",egt));
rep(r,g,t,"DIDXBET","%scn%")				  = sum(v,sum(egt,DIDXBET.l(r,g,"ele",egt,v)));
rep(r,g,t,"DID_ELBS","%scn%")				= sum(s,DID_ELBS.l(r,g,s));

reph(r,g,s,t,"DIDM","%scn%")	  = DIDMM.l(r,g,s)$[nne(g)$id0(r,g,s)]+DIDME.l(r,g,s)$[en(g)$id0(r,g,s)];
reph(r,g,s,t,"DIDX","%scn%")	  = sum(v,DIDX.l(r,g,s,v));
reph(r,g,"ele",t,"DIDMEGT","%scn%") = sum(egt,DIDMEGT.l(r,g,"ele",egt));
reph(r,g,"ele",t,"DIDXEGT","%scn%") = sum(v,sum(egt,DIDXEGT.l(r,g,"ele",egt,v)));
reph(r,g,"ele",t,"DIDBET","%scn%")  = sum(egt,DIDBET.l(r,g,"ele",egt));
reph(r,g,"ele",t,"DIDXBET","%scn%") = sum(v,sum(egt,DIDXBET.l(r,g,"ele",egt,v)));
reph(r,g,s,t,"DID_ELBS","%scn%")	  = DID_ELBS.l(r,g,s);

* rep("ALL",g,t,"DIDM","%scn%")				  = sum((r,s),DIDMM.l(r,g,s)$[nne(g)$id0(r,g,s)]+DIDME.l(r,g,s)$[en(g)$id0(r,g,s)]);
* rep("ALL",g,t,"DIDX","%scn%")				  = sum(v,sum((r,s),DIDX.l(r,g,s,v)));

rep(r,g,t,"Industrial Demand","%scn%")		  =
	rep(r,g,t,"DIDM","%scn%")
	+rep(r,g,t,"DIDX","%scn%")
	+rep(r,g,t,"DIDMEGT","%scn%")
	+rep(r,g,t,"DIDXEGT","%scn%")
	+rep(r,g,t,"DIDBET","%scn%")
	+rep(r,g,t,"DIDXBET","%scn%")	
	+rep(r,g,t,"DID_ELBS","%scn%")
	;

rep("ALL",g,t,"Industrial Demand","%scn%")	  = sum(r,rep(r,g,t,"Industrial Demand","%scn%"));

* sector specific demand
reph(r,g,s,t,"Industrial Demand","%scn%")		  =
	reph(r,g,s,t,"DIDM","%scn%")
	+reph(r,g,s,t,"DIDX","%scn%")
	+reph(r,g,s,t,"DIDMEGT","%scn%")
	+reph(r,g,s,t,"DIDXEGT","%scn%")
	+reph(r,g,s,t,"DIDBET","%scn%")
	+reph(r,g,s,t,"DIDXBET","%scn%")
	+reph(r,g,s,t,"DID_ELBS","%scn%")
	;

reph("ALL",g,s,t,"Industrial Demand","%scn%")	  = sum(r,reph(r,g,s,t,"Industrial Demand","%scn%"));


* -- Household
reph(r,g,h,t,"DCD","%scn%")				  = DCD.l(r,g,h);
rep(r,g,t,"DCD","%scn%")					  = sum(h,DCD.l(r,g,h));
rep("ALL",g,t,"DCD","%scn%")				  = sum((r,h),DCD.l(r,g,h));

rep(r,g,t,"Household Demand","%scn%")		  = rep(r,g,t,"DCD","%scn%");
rep("ALL",g,t,"Household Demand","%scn%")	  = sum(r,rep(r,g,t,"Household Demand","%scn%"));

reph(r,g,h,t,"Household Demand","%scn%")	  = reph(r,g,h,t,"DCD","%scn%");
reph("ALL",g,h,t,"Household Demand","%scn%") = sum(r,reph(r,g,h,t,"Household Demand","%scn%"));

* -- Investment
rep(r,g,t,"DIDI","%scn%")					  = DIDI.l(r,g);
rep("ALL",g,t,"DIDI","%scn%")				  = sum(r,DIDI.l(r,g));

rep(r,g,t,"Investment Demand","%scn%")		  = rep(r,g,t,"DIDI","%scn%");
rep("ALL",g,t,"Investment Demand","%scn%")	  = sum(r,rep(r,g,t,"DIDI","%scn%"));	

* -- Government
rep(r,g,t,"DIDG","%scn%")					  = DIDG.l(r,g);
rep("ALL",g,t,"DIDG","%scn%")				  = sum(r,DIDG.l(r,g));

rep(r,g,t,"Govt Demand","%scn%")             = rep(r,g,t,"DIDG","%scn%");
rep("ALL",g,t,"Govt Demand","%scn%")         = sum(r,rep(r,g,t,"DIDG","%scn%"));  

* -- Total
rep(r,g,t,"Total Demand","%scn%") =
	rep(r,g,t,"Industrial Demand","%scn%")
	+rep(r,g,t,"Household Demand","%scn%")
	+rep(r,g,t,"Investment Demand","%scn%")
	+rep(r,g,t,"Govt Demand","%scn%")
	;

rep("ALL",g,t,"Total Demand","%scn%")	  = sum(r,rep(r,g,t,"Total Demand","%scn%"));

* -- Absorption supply
rep(r,g,t,"Armington Supply","%scn%") = SARM.l(r,g);
rep("ALL",g,t,"Armington Supply","%scn%") = sum(r,SARM.l(r,g));

rep(r,g,t,"Foreign Import Demand","%scn%") = DMF.l(r,g);
rep("ALL",g,t,"Foreign Import Demand","%scn%") = sum(r,DMF.l(r,g));

rep(r,g,t,"National Import Demand","%scn%") = DND.l(r,g);
rep("ALL",g,t,"National Import Demand","%scn%") = sum(r,DND.l(r,g));

rep(r,g,t,"Local Demand","%scn%") = DDD.l(r,g);
rep("ALL",g,t,"Local Demand","%scn%") = sum(r,DDD.l(r,g));

rep(r,g,t,"Margin Demand","%scn%") = sum(m,DMM.l(r,m,g));
rep("ALL",g,t,"Margin Demand","%scn%") = sum((r,m),DMM.l(r,m,g));

* -- Check demand-supply balance
rep(r,g,t,"Demand-Supply","%scn%") =
	rep(r,g,t,"Total Demand","%scn%")
	- rep(r,g,t,"Armington Supply","%scn%")
	;

* rep(r,g,t,"Arm-Demand-Supply","%scn%") =
* 	rep(r,g,t,"Foreign Import Demand","%scn%")
* 	+rep(r,g,t,"National Import Demand","%scn%")
* 	+rep(r,g,t,"Local Demand","%scn%")
* 	+rep(r,g,t,"Margin Demand","%scn%")
* 	- rep(r,g,t,"Armington Supply","%scn%")
* 	- REX.l(r,g)
* 	;

* -- disposition
rep(r,g,t,"Disposition Supply","%scn%") = SX.l(r,g);
rep("ALL",g,t,"Disposition Supply","%scn%") = sum(r,SX.l(r,g));

rep(r,g,t,"Foreign Exports","%scn%") = SXF.l(r,g);
rep("ALL",g,t,"Foreign Exports","%scn%") = sum(r,SXF.l(r,g));

rep(r,g,t,"National Exports","%scn%") = SXN.l(r,g);
rep("ALL",g,t,"National Exports","%scn%") = sum(r,SXN.l(r,g));

rep(r,g,t,"Local Supply","%scn%") = SXD.l(r,g);
rep("ALL",g,t,"Local Supply","%scn%") = sum(r,SXD.l(r,g));

rep(r,m,t,"Margin Supply","%scn%") = MS.l(r,m)*(sum(gm, md0(r,m,gm)));
rep("ALL",m,t,"Margin Supply","%scn%") =  sum(r,MS.l(r,m)*(sum(gm, md0(r,m,gm))));

* -- net imports
* !!!! unsure if can be evaluated with quantities - may need values
rep(r,g,t,"Foreign Imports - Foreign Exports","%scn%") =
	rep(r,g,t,"Foreign Import Demand","%scn%")
	- rep(r,g,t,"Foreign Exports","%scn%")
	;

rep("ALL",g,t,"Foreign Imports - Foreign Exports","%scn%") =
	rep("ALL",g,t,"Foreign Import Demand","%scn%")
	- rep("ALL",g,t,"Foreign Exports","%scn%")
	;

rep(r,g,t,"Imports - Exports","%scn%") =
	rep(r,g,t,"Foreign Import Demand","%scn%")
	+rep(r,g,t,"National Import Demand","%scn%")
	- rep(r,g,t,"Foreign Exports","%scn%")
	- rep(r,g,t,"National Exports","%scn%")
	;

rep("ALL",g,t,"Imports - Exports","%scn%") =
	rep("ALL",g,t,"Foreign Import Demand","%scn%")
	+rep("ALL",g,t,"National Import Demand","%scn%")
	- rep("ALL",g,t,"Foreign Exports","%scn%")
	- rep("ALL",g,t,"National Exports","%scn%")
	;


rep(r,g,t,"Armington Supply - Disposition Supply","%scn%") =
	rep(r,g,t,"Armington Supply","%scn%")
	- rep(r,g,t,"Disposition Supply","%scn%")
	;

rep("ALL",g,t,"Armington Supply - Disposition Supply","%scn%") =
	rep("ALL",g,t,"Armington Supply","%scn%")
	- rep("ALL",g,t,"Disposition Supply","%scn%")
	;

* -- price index
rep("ALL",g,t,"PA","%scn%")$[(sum(r,a0(r,g)))] = sum(r,PA.l(r,g)*SARM.l(r,g))/sum(r,a0(r,g));

* -- price * quantity = value


* Wages - labor price
rep("ALL","ALL",t,"PLS","%scn%") =
	sum((r,h),PLS.l(r,h)*(ls0(r,h)*gprod+lsr0(r,h)))/sum((r,h),(ls0(r,h)*gprod+lsr0(r,h)));
rep("ALL","ALL",t,"PL","%scn%")  =
	sum(q,PL.l(q)*sum((r,h),(le0(r,q,h)*gprod)))/sum((r,q,h),(le0(r,q,h)*gprod));


* Rents - capital price


*------------------------------------------------------------------------
* Gini Coefficient
*------------------------------------------------------------------------

* Gini coefficient

*wdecomp("%scn%","$","income",r,h,t,"W")	= W.l(r,h)*w0_h(r,h);
*pop(r,h)

*Lorenz Curve
*First pop(r,"h1")/sum(h,pop(r,h)) has wdecomp(...,"h1"...)/sum(h,wdecomp(...,h,...))
*First & second (pop(r,"h1")+pop(r,"h2"))/sum(h,pop(r,h))
* --- has (wdecomp(...,"h1"...)+wdecomp(...,"h2"...))/sum(h,wdecomp(...,h,...))
*... and so on
*x axis is cumulative population share, y axis is cumulative income share

* Gini coefficient calculation
*http://www3.nccu.edu.tw/~jthuang/Gini.pdf

* parameters
* 	w_inc
* 	p_shr
* 	i_shr
* 	pd_shr
* 	id_shr
* 	gini
* ;

* Regional Lorenz Curve and Gini Coefficient
w_inc(r,h,t) = wdecomp("%scn%","$","income",r,h,t,"W");

p_shr(r,"hh1") = pop(r,"hh1")/sum(h,pop(r,h));
p_shr(r,"hh2") = p_shr(r,"hh1")+pop(r,"hh2")/sum(h,pop(r,h));
p_shr(r,"hh3") = p_shr(r,"hh2")+pop(r,"hh3")/sum(h,pop(r,h));
p_shr(r,"hh4") = p_shr(r,"hh3")+pop(r,"hh4")/sum(h,pop(r,h));
p_shr(r,"hh5") = p_shr(r,"hh4")+pop(r,"hh5")/sum(h,pop(r,h));

i_shr(r,"hh1",t) = w_inc(r,"hh1",t)/sum(h,w_inc(r,h,t));
i_shr(r,"hh2",t) = i_shr(r,"hh1",t)+w_inc(r,"hh2",t)/sum(h,w_inc(r,h,t));
i_shr(r,"hh3",t) = i_shr(r,"hh2",t)+w_inc(r,"hh3",t)/sum(h,w_inc(r,h,t));
i_shr(r,"hh4",t) = i_shr(r,"hh3",t)+w_inc(r,"hh4",t)/sum(h,w_inc(r,h,t));
i_shr(r,"hh5",t) = i_shr(r,"hh4",t)+w_inc(r,"hh5",t)/sum(h,w_inc(r,h,t));

pd_shr(r,"hh1") = p_shr(r,"hh1")-0;
id_shr(r,"hh1",t) = i_shr(r,"hh1",t)+0;	

pd_shr(r,"hh2") = p_shr(r,"hh2")-p_shr(r,"hh1");
id_shr(r,"hh2",t) = i_shr(r,"hh2",t)+i_shr(r,"hh1",t);

pd_shr(r,"hh3") = p_shr(r,"hh3")-p_shr(r,"hh2");
id_shr(r,"hh3",t) = i_shr(r,"hh3",t)+i_shr(r,"hh2",t);

pd_shr(r,"hh4") = p_shr(r,"hh4")-p_shr(r,"hh3");
id_shr(r,"hh4",t) = i_shr(r,"hh4",t)+i_shr(r,"hh3",t);

pd_shr(r,"hh5") = p_shr(r,"hh5")-p_shr(r,"hh4");
id_shr(r,"hh5",t) = i_shr(r,"hh5",t)+i_shr(r,"hh4",t);

* I believe you multiply by 1/2
lorenz(r,t) = (1/2)*sum(h,pd_shr(r,h)*id_shr(r,h,t));
gini(r,t) = 1-sum(h,pd_shr(r,h)*id_shr(r,h,t));

reph(r,"ALL","ALL",t,"GINI","%scn%") = gini(r,t);

* US National Lorenz Curve and Gini Coefficient
w_inc("ALL",h,t) = sum(r,wdecomp("%scn%","$","income",r,h,t,"W"));
popall("ALL",h) = sum(r,pop(r,h));

p_shr("ALL","hh1") = popall("ALL","hh1")/sum(h,popall("ALL",h));
p_shr("ALL","hh2") = p_shr("ALL","hh1")+popall("ALL","hh2")/sum(h,popall("ALL",h));
p_shr("ALL","hh3") = p_shr("ALL","hh2")+popall("ALL","hh3")/sum(h,popall("ALL",h));
p_shr("ALL","hh4") = p_shr("ALL","hh3")+popall("ALL","hh4")/sum(h,popall("ALL",h));
p_shr("ALL","hh5") = p_shr("ALL","hh4")+popall("ALL","hh5")/sum(h,popall("ALL",h));

i_shr("ALL","hh1",t) = w_inc("ALL","hh1",t)/sum(h,w_inc("ALL",h,t));
i_shr("ALL","hh2",t) = i_shr("ALL","hh1",t)+w_inc("ALL","hh2",t)/sum(h,w_inc("ALL",h,t));
i_shr("ALL","hh3",t) = i_shr("ALL","hh2",t)+w_inc("ALL","hh3",t)/sum(h,w_inc("ALL",h,t));
i_shr("ALL","hh4",t) = i_shr("ALL","hh3",t)+w_inc("ALL","hh4",t)/sum(h,w_inc("ALL",h,t));
i_shr("ALL","hh5",t) = i_shr("ALL","hh4",t)+w_inc("ALL","hh5",t)/sum(h,w_inc("ALL",h,t));

pd_shr("ALL","hh1") = p_shr("ALL","hh1")-0;
id_shr("ALL","hh1",t) = i_shr("ALL","hh1",t)+0;	

pd_shr("ALL","hh2") = p_shr("ALL","hh2")-p_shr("ALL","hh1");
id_shr("ALL","hh2",t) = i_shr("ALL","hh2",t)+i_shr("ALL","hh1",t);

pd_shr("ALL","hh3") = p_shr("ALL","hh3")-p_shr("ALL","hh2");
id_shr("ALL","hh3",t) = i_shr("ALL","hh3",t)+i_shr("ALL","hh2",t);

pd_shr("ALL","hh4") = p_shr("ALL","hh4")-p_shr("ALL","hh3");
id_shr("ALL","hh4",t) = i_shr("ALL","hh4",t)+i_shr("ALL","hh3",t);

pd_shr("ALL","hh5") = p_shr("ALL","hh5")-p_shr("ALL","hh4");
id_shr("ALL","hh5",t) = i_shr("ALL","hh5",t)+i_shr("ALL","hh4",t);

lorenz("ALL",t) = (1/2)*sum(h,pd_shr("ALL",h)*id_shr("ALL",h,t));
gini("ALL",t) = 1-sum(h,pd_shr("ALL",h)*id_shr("ALL",h,t));

reph("ALL","ALL","ALL",t,"GINI","%scn%") = gini("ALL",t);


* % difference in welfare by year
* % difference in income cumulative
* % difference in PV income cumulative


*------------------------------------------------------------------------
* Store values from Pin for loading in subsequent cases
*------------------------------------------------------------------------

* store values from pin
rep_pin(r,s,egt,t,"EGTRATE","%scn%") = EGTRATE.l(r,s,egt);
rep_pin(r,s,egt,t,"EGTMOD","%scn%") = EGTMOD.l(r,s,egt);
rep_pin(r,"fr",egt,t,"BSE","%scn%") = bse(r,"fr",egt);
rep_pin(r,"ele",egt,t,"TFPADJ","%scn%")=iter_adj(r,egt);
rep_pin(r,"ele",egt,t,"SRVTRK","%scn%")=srv_trk(r,egt,t);
rep_pin(r,"ele",egt,t,"YMEGT","%scn%")= YMEGT.l(r,"ele",egt);
rep_pin(r,"ele",egt,t,"YMEGT","%scn%")= YMEGT.l(r,"ele",egt);
rep_pin(r,"ele",egt,t,"SYMEGT","%scn%")= SYMEGT.l(r,"ele",egt);
rep_pin(r,"ele",egt,t,"SYXEGT","%scn%")= sum(v,SYXEGT.l(r,"ele",egt,v));
rep_pin(r,"ele",egt,t,"SYXEGT_shr","%scn%")$[(sum(v,SYXEGT.l(r,"ele",egt,v))+SYMEGT.l(r,"ele",egt))]=
	sum(v,SYXEGT.l(r,"ele",egt,v))/(sum(v,SYXEGT.l(r,"ele",egt,v))+SYMEGT.l(r,"ele",egt));
rep_pin(r,"ele",egt,t,"SYMEGT","%scn%")$vgen(egt)= YBET.l(r,"ele",egt)/(1-ty0(r,"ele"));
rep_pin(r,"ele",egt,t,"SYXEGT","%scn%")$vgen(egt)= sum(v,YXBET.l(r,"ele",egt,v))/(1-ty0(r,"ele"));
rep_pin(r,"ele",egt,t,"SYXEGT_shr","%scn%")$[vgen(egt)$(rep_pin(r,"ele",egt,t,"SYMEGT","%scn%")+rep_pin(r,"ele",egt,t,"SYXEGT","%scn%"))]=
	rep_pin(r,"ele",egt,t,"SYXEGT","%scn%")/(rep_pin(r,"ele",egt,t,"SYMEGT","%scn%")+rep_pin(r,"ele",egt,t,"SYXEGT","%scn%"));

rep_pin(r,"ele",egt,t,"PIN_TARGET","%scn%") = iter_store(r,egt,"TARGET");
rep_pin(r,"ele",egt,t,"PIN_MODEL","%scn%") = EGTMOD.l(r,"ele",egt);
rep_pin(r,"ele",egt,t,"PIN_diff","%scn%") = EGTMOD.l(r,"ele",egt) - iter_store(r,egt,"TARGET");
rep_pin(r,"ele",egt,t,"PIN_rat","%scn%")$[iter_store(r,egt,"TARGET")] =  EGTMOD.l(r,"ele",egt) / iter_store(r,egt,"TARGET");

rep_pin(r,"ele",egt,t,"DKX","%scn%")$[(not vgen(egt))] = sum(v,DKXEGT.l(r,"ele",egt,v));
rep_pin(r,"ele",egt,t,"KX","%scn%")$[(not vgen(egt))] = sum(v,xegt_k(r,"ele",egt,v));
rep_pin(r,"ele",egt,t,"DKX/KX","%scn%")$[(not vgen(egt))$rep_pin(r,"ele",egt,t,"KX","%scn%")] =
	rep_pin(r,"ele",egt,t,"DKX","%scn%")/rep_pin(r,"ele",egt,t,"KX","%scn%");

rep_pin(r,"ele",egt,t,"DKX","%scn%")$[(vgen(egt))] = sum(v,DKXBET.l(r,"ele",egt,v));
rep_pin(r,"ele",egt,t,"KX","%scn%")$[(vgen(egt))] = sum(v,xbet_k(r,"ele",egt,v));
rep_pin(r,"ele",egt,t,"DKX/KX","%scn%")$[(vgen(egt))$rep_pin(r,"ele",egt,t,"KX","%scn%")] =
	rep_pin(r,"ele",egt,t,"DKX","%scn%")/rep_pin(r,"ele",egt,t,"KX","%scn%");

rep_pin(r,"ele",egt,t,"PYEGT","%scn%") = PYEGT.l(r,"ele",egt);
rep_pin(r,"ele",egt,t,"PYS","%scn%") = rep(r,"ele",t,"PYS","%scn%");
rep_pin(r,"ele",egt,t,"RKXEGT","%scn%") = sum(v,RKXEGT.l(r,"ele",egt,v));

rep_pin(r,s,egt,t,"VAEGT","%scn%")$y_egt(s) = VAEGT.l(r,s,egt);
rep_pin(r,s,egt,t,"PREGT","%scn%")$y_egt(s) = PREGT.l(r,s,egt);
rep_pin(r,s,egt,t,"PVAEGT","%scn%")$y_egt(s) = PVAEGT.l(r,s,egt);
rep_pin(r,s,egt,t,"PRBET","%scn%")$y_egt(s) = PRBET.l(r,s,egt);
rep_pin(r,s,egt,t,"RKXBET","%scn%")$y_egt(s) = sum(v,RKXBET.l(r,s,egt,v));


*------------------------------------------------------------------------
* Energy consumption as a share of household budget
*------------------------------------------------------------------------

* electricity consumption as a share of household consumption/income
* energy consumption as a share of household consumption/income

* co2 price included in here
reph(r,g,h,t,"CD","%scn%") = DCD.l(r,g,h)*(PA.l(r,g)+PDCO2.l(r,"fd")*cco2(r,g,"fd"))/pexp(r,h,t);
reph(r,g,h,t,"CD2","%scn%") = reph(r,g,h,t,"CD","%scn%")*pexp(r,h,t);
reph(r,"energy",h,t,"CD2","%scn%") = sum(g$en(g),reph(r,g,h,t,"CD","%scn%"))*pexp(r,h,t);

* wrong way to calculate this --- PLS*DLS
reph(r,"ALL",h,t,"C+I","%scn%") = wdecomp("%scn%","$","income",r,h,t,"Wchk")-DLS.l(r,h)*PLS.l(r,h)/pexp(r,h,t);
reph(r,g,h,t,"CD/(C+I)","%scn%")$[reph(r,"ALL",h,t,"C+I","%scn%")] =
	100*reph(r,g,h,t,"CD","%scn%")/reph(r,"ALL",h,t,"C+I","%scn%");

reph(r,"energy",h,t,"CD/(C+I)","%scn%")$[reph(r,"ALL",h,t,"C+I","%scn%")] =
	100*sum(g$en(g),reph(r,g,h,t,"CD","%scn%"))/reph(r,"ALL",h,t,"C+I","%scn%");

reph(r,"ALL",h,t,"Wall","%scn%") = wdecomp("%scn%","$","income",r,h,t,"Wchk");
reph(r,g,h,t,"CD/Wall","%scn%")$[reph(r,"ALL",h,t,"Wall","%scn%")] =
	100*reph(r,g,h,t,"CD","%scn%")/reph(r,"ALL",h,t,"Wall","%scn%");

reph(r,"energy",h,t,"CD/Wall","%scn%")$[reph(r,"ALL",h,t,"Wall","%scn%")] =
	100*sum(g$en(g),reph(r,g,h,t,"CD","%scn%"))/reph(r,"ALL",h,t,"Wall","%scn%");

