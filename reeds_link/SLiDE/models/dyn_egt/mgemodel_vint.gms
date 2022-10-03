$title  MPSGE Model with Pooled National Markets

$ONTEXT
$model:mgemodel

$sectors:

	YM(r,s)$[y_(r,s)$y_egt(s)$(not swperf)] ! Mutable production
	YM(r,s)$[y_(r,s)$(not y_egt(s))] ! Mutable production
	YX(r,s,v)$[y_(r,s)$x_k(r,s,v)] ! Extant production
	VA(r,s)$[va_bar(r,s)$(not y_egt(s))] ! Value added index
	E(r,s)$[en_bar(r,s)$(not y_egt(s))] ! Energy index

	X(r,g)$x_(r,g) ! Disposition
	A(r,g)$a_(r,g) ! Absorption
	MS(r,m) ! Margin supply

	INV(r) ! Investment
	C(r,h) ! Household consumption
	Z(r,h) ! Full consumption
	W(r,h) ! Welfare index
	LS(r,h) ! Labor supply

	KS$[(not swrks)] ! Aggregate capital supply
	CO2(r,sfd)$[swcarb$co2base(r,sfd)] ! CO2 emissions

	YMEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))] ! Electricity generation output index
	YXEGT(r,s,egt,v)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))$xegt_k(r,s,egt,v)] ! Extant electricity production
	VAEGT(r,s,egt)$[y_egt(s)$va_tot(r,egt)$(not vgen(egt))] ! Value added generation output index
	ID(r,g,s,egt)$[y_egt(s)$ibar_gen0(r,g,egt)$(not vgen(egt))] ! Intermediate demand generation output index

	YBET(r,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)] ! Backstop electricity production index
	YXBET(r,s,egt,v)$[y_(r,s)$vbet_act(r,s,egt)$ybet_except(r,s,egt)] ! Extant backstop electricity production
	
	Y_ELBS(r,s)$[elbs_act(r,s)]	! electrification backstop production

$commodities:

	PE(r,s)$[en_bar(r,s)$(not y_egt(s))] ! Energy price index
	PVA(r,s)$[va_bar(r,s)$(not y_egt(s))] ! Value added price index

	PA(r,g)$a0(r,g) ! Regional market (input)
	PY(r,g)$s0(r,g) ! Regional market (output)
	PD(r,g)$xd0(r,g) ! Local market price
	PN(g) ! National market
	PL(r) ! Wage rate
	RK(r,s)$[kd0(r,s)$(not swrks)] ! Sectoral rental rate (mutable)
	RKX(r,s,v)$[kd0(r,s)$x_k(r,s,v)] ! Sectoral rental rate (extant)
	RKS ! Aggregate capital market price
	PK ! Aggregate return to capital (mutable)
	RKEXT(r)$[ke0_x(r)$swhhext] ! Aggregate return to capital (extant)
	PRM(r,s)$[fr_m(r,s)$xe(s)] ! Extractable resource factor index (mutable)
	
	PM(r,m) ! Margin price
	PFX	! Foreign exchange

	PC(r,h) ! Final consumption price
	PZ(r,h) ! consumption and investment price
	PW(r,h) ! Welfare price
	PLS(r,h) ! Value of time endowment (leisure) opportunity cost of working

	PINV(r) ! Investment price

	PCO2$swcarb ! Carbon factor price
	PDCO2(r,sfd)$[swcarb$co2base(r,sfd)] ! Effective carbon price
 
	PREGT(r,s,egt)$[y_egt(s)$fbar_gen0(r,"fr",egt)$(not vgen(egt))] ! Conventional Generation Fixed Resource Factor
	PVAEGT(r,s,egt)$[y_egt(s)$va_tot(r,egt)$(not vgen(egt))] ! Conventional Gen value added generation
	PID(r,g,s,egt)$[y_egt(s)$ibar_gen0(r,g,egt)$(not vgen(egt))] ! Intermediate conventional gen
	PYEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not swperf)$(not vgen(egt))] ! Conventional gen

	PRBET(r,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)] ! backstop tech specific factor resource
*	PRXBET(r,s,egt,v)$[y_(r,s)$vbet_act(r,s,egt)] ! backstop tech specific factor resource
	RKXBET(r,s,egt,v)$[y_(r,s)$vbet_act(r,s,egt)] ! extant backstop rental rate

	PR_ELBS(r,s)$[elbs_act(r,s)] ! extant electrification backstop TSF resource price

	RKXEGT(r,s,egt,v)$[y_egt(s)$fbar_gen0(r,"k",egt)$(not vgen(egt))$xegt_k(r,s,egt,v)] ! Extant electricity rental rate


$consumer:
	RA(r,h) ! Representative agent
	NYSE ! Aggregate capital owner
	GOVT ! Aggregate government
	PINA ! pinning agent
	JPOW ! Subsidy agent
	KXX(r)$[ke0_x(r)$swhhext] ! aggregate extant capital owner

$auxiliary:
	TRANS ! Budget balance rationing constraint
	CPI ! Numeraire consumer price index
	ETAR$[swcarb] ! Emissions restriction rationing constraint
	CTAXREV$[swcarb] ! total permit revenues
	CTAXTRN(r,h)$[swcarb] ! permit revenue transfers
	EGTMOD(r,s,egt)$[y_egt(s)$y_(r,s)] ! Electricity generation (pbench*q)
	EGTRATE(r,s,egt)$[y_egt(s)$y_(r,s)] ! TFP endogenous rate adjustment for constraint pin
	EGTOUT(r,s,egt)$[y_egt(s)$y_(r,s)] ! Value of TFP rate for constraint pin
	EGTREV ! total revenue for tfp constraint pin
	BRRR ! subsidy cost to government
*	PYEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$swperf$(not vgen(egt))] ! here in case perfect substitutes
	DYMEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))] ! definitional ele tech demand
	SYMEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))] ! definitional ele production
	SYXEGT(r,s,egt,v)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))$xegt_k(r,s,egt,v)] ! definitional extant production

*------------------------------------------------------------------------
* Electricity production disaggregated 
*------------------------------------------------------------------------

* Definitionals for electricity generation
* $constraint:PYEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$swperf$(not vgen(egt))]
* 	PYEGT(r,s,egt) =e= sum(g,PY(r,g)*obar_gen0(r,egt)*ys0(r,s,g)/sum(g.local,ys0(r,s,g))/(sum((g.local),obar_gen0(r,egt)*ys0(r,s,g)/sum(g.local,ys0(r,s,g)))));
* * PYEGT(r,s,egt) = sum(g,PY(r,g)*obar_gen0(r,egt)*ys0(r,s,g)/sum(g.local,ys0(r,s,g))/(sum((g.local,egt.local),obar_gen0(r,egt)*ys0(r,s,g)/sum(g.local,ys0(r,s,g)))));

$constraint:DYMEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))]
	DYMEGT(r,s,egt) =e= YMEGT(r,s,egt)*sum(g,(obar_gen0(r,egt)*ys0(r,s,g)/sum(gg,ys0(r,s,gg))));

$constraint:SYMEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))]
	SYMEGT(r,s,egt) =e= YMEGT(r,s,egt)*sum(g,(obar_gen0(r,egt)*ys0(r,s,g)/sum(gg,ys0(r,s,gg))));

$constraint:SYXEGT(r,s,egt,v)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))$xegt_k(r,s,egt,v)]
	SYXEGT(r,s,egt,v) =e= YXEGT(r,s,egt,v)*sum(g,xegt_ys_out(r,s,egt,g,v));

$constraint:EGTMOD(r,s,egt)$[y_egt(s)$y_(r,s)]
	EGTMOD(r,s,egt)*(1-ty0(r,s)) =e=
	YBET(r,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)]
	+ ((YMEGT(r,s,egt))*obar_gen0(r,egt)*(1-ty0(r,s)))$[(not vgen(egt))]
	+ sum(v,YXBET(r,s,egt,v)$[y_(r,s)$vgen(egt)$vbet_act(r,s,egt)$ybet_except(r,s,egt)$xbet_k(r,s,egt,v)])
	+ sum(v,YXEGT(r,s,egt,v)$[(not vgen(egt))$xegt_k(r,s,egt,v)])
;

* endogenous TFP constraint that forces electricity generation to a target
$constraint:EGTRATE(r,s,egt)$[y_egt(s)$y_(r,s)$pin_except(r,s,egt)$swsspin]
	ss_pq_gen(r,egt) =e= EGTMOD(r,s,egt);

$constraint:EGTRATE(r,s,egt)$[y_egt(s)$y_(r,s)$(not pin_except(r,s,egt))$swsspin]
	EGTRATE(r,s,egt) =e= 0;

$constraint:EGTRATE(r,s,egt)$[y_egt(s)$y_(r,s)$(not swsspin)]
	EGTRATE(r,s,egt) =e= 0;

* Calculate adjustment needed for PINA to offset
$constraint:EGTOUT(r,s,egt)$[y_egt(s)$y_(r,s)$vgen(egt)]
	(EGTMOD(r,s,egt)-(sum(v,YXBET(r,s,egt,v))/(1-ty0(r,s)))$[y_(r,s)$vbet_act(r,s,egt)$ybet_except(r,s,egt)])*EGTRATE(r,s,egt)
	=e= EGTOUT(r,s,egt);

$constraint:EGTOUT(r,s,egt)$[y_egt(s)$y_(r,s)$(not vgen(egt))]
	(EGTMOD(r,s,egt)-(sum(v,YXEGT(r,s,egt,v))/(1-ty0(r,s)))$[(sum(v,xegt_k(r,s,egt,v)))])*EGTRATE(r,s,egt)
	=e= EGTOUT(r,s,egt);

$constraint:EGTREV
	sum((r,s,egt)$[y_egt(s)$y_(r,s)$vgen(egt)],
		sum(g,PY(r,g)*(ys0(r,s,g)/sum(gg,ys0(r,s,gg))))*EGTOUT(r,s,egt))
	+ sum((r,s,egt)$[y_egt(s)$y_(r,s)$(not vgen(egt))],
		PYEGT(r,s,egt)$[obar_gen0(r,egt)]*1*EGTOUT(r,s,egt))
	=e= EGTREV*PFX;
	

*------------------------------------------------------------------------
* Backstop ELBS - electrification backstop tech
*------------------------------------------------------------------------

* electrification backstop production
$prod:Y_ELBS(r,s)$[elbs_act(r,s)]	s:es_elbs(r,s)	mva:0 m(mva):0 va(mva):0
	o:PY(r,g)	q:elbs_out(r,s,g)
+		a:GOVT	t:ty(r,s)	p:(1-ty0(r,s))
	i:PA(r,g)	q:(elbs_in(r,g,s)*elbs_mkup(r,s))		m:
	i:PL(r)		q:(elbs_in(r,"l",s)*elbs_mkup(r,s))		va:
	i:RK(r,s)$[(not swrks)]	q:(elbs_in(r,"k",s)*elbs_mkup(r,s))		va:
+		a:GOVT	t:tk(r,s)	p:(1-tk0(r))
	i:RKS$[(swrks)]	q:(elbs_in(r,"k",s)*elbs_mkup(r,s))		va:
+		a:GOVT	t:tk(r,s)	p:(1-tk0(r))
	i:PR_ELBS(r,s)	q:(elbs_in(r,"tsf",s)*elbs_mkup(r,s))
+		a:GOVT	t:tk(r,s)	p:(1-tk0(r))


*------------------------------------------------------------------------
* Backstop EGT
*------------------------------------------------------------------------

* Backstop production
$prod:YBET(r,s,egt)$[y_(r,s)$y_egt(s)$os_bet(r,egt)$ybet_except(r,s,egt)] s:es_re(r,egt) mva:0 m(mva):0 va(mva):0.0
	o:PY(r,g)			q:(tfp_adj(r,egt)*(os_bet(r,egt)/(1-ty0(r,s)))*ys0(r,s,g)/sum(gg,ys0(r,s,gg)))
+		a:GOVT	t:ty(r,s) p:(1-ty0(r,s))
+		a:GOVT$[(not mnyprntrgo)]	t:subegt(r,s,egt)$[(not mnyprntrgo)]
+		a:JPOW$[mnyprntrgo]	t:subegt(r,s,egt)$[mnyprntrgo]	
+		a:PINA 	n:EGTRATE(r,s,egt)	m:(-1)
	i:PRBET(r,s,egt)	q:(iter_adj(r,egt)*cs_bet(r,"fr",egt)*bsfact(r,egt)*bstechfact(r,egt)/(1+tk0(r)))
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
	i:PA(r,g)			q:(iter_adj(r,egt)*cs_bet(r,g,egt)*bsfact(r,egt)*bstechfact(r,egt))					m:
	i:PL(r)				q:(iter_adj(r,egt)*cs_bet(r,"l",egt)*bsfact(r,egt)*bstechfact(r,egt))				va:
	i:RK(r,s)$[(not swrks)]	q:(iter_adj(r,egt)*cs_bet(r,"k",egt)*bsfact(r,egt)*bstechfact(r,egt)/(1+tk0(r)))	va:
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
	i:RKS$[(swrks)]			q:(iter_adj(r,egt)*cs_bet(r,"k",egt)*bsfact(r,egt)*bstechfact(r,egt)/(1+tk0(r)))	va:
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))

* benchmark binding backstop
$prod:YBET(r,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$os_egt(r,egt)$ybet_except(r,s,egt)] s:es_re(r,egt) mva:0 m(mva):0 va(mva):0.0
	o:PY(r,g)			q:(tfp_adj(r,egt)*(os_egt(r,egt)/(1-ty0(r,s)))*ys0(r,s,g)/sum(gg,ys0(r,s,gg)))
+		a:GOVT	t:ty(r,s) p:(1-ty0(r,s))
+		a:GOVT$[(not mnyprntrgo)]	t:subegt(r,s,egt)$[(not mnyprntrgo)]
+		a:JPOW$[mnyprntrgo]	t:subegt(r,s,egt)$[mnyprntrgo]	
+		a:PINA 	n:EGTRATE(r,s,egt)	m:(-1)
	i:PRBET(r,s,egt)	q:(iter_adj(r,egt)*cs_egt(r,"fr",egt)*bstechfact(r,egt)/(1+tk0(r)))
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
	i:PA(r,g)			q:(iter_adj(r,egt)*cs_egt(r,g,egt)*bstechfact(r,egt))					m:
	i:PL(r)				q:(iter_adj(r,egt)*cs_egt(r,"l",egt)*bstechfact(r,egt))				va:
	i:RK(r,s)$[(not swrks)]			q:(iter_adj(r,egt)*cs_egt(r,"k",egt)*bstechfact(r,egt)/(1+tk0(r)))	va:
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
	i:RKS$[(swrks)]			q:(iter_adj(r,egt)*cs_egt(r,"k",egt)*bstechfact(r,egt)/(1+tk0(r)))	va:
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))

*------------------------------------------------------------------------
* Conventional EGT
*------------------------------------------------------------------------

* !!!! Conventional techs only - no vgen
* value added 
$prod:VAEGT(r,s,egt)$[y_egt(s)$va_tot(r,egt)$(not vgen(egt))] s:0.0
	o:PVAEGT(r,s,egt)	q:(iter_adj(r,egt)*va_tot(r,egt))
	i:PL(r)				q:(iter_adj(r,egt)*fbar_gen0(r,"l",egt))
	i:RK(r,s)$[(not swrks)]			q:(iter_adj(r,egt)*fbar_gen0(r,"k",egt))
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
	i:RKS$[(swrks)]			q:(iter_adj(r,egt)*fbar_gen0(r,"k",egt))
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))

* intermediate including co2 price
$prod:ID(r,g,s,egt)$[y_egt(s)$ibar_gen0(r,g,egt)$(not vgen(egt))] s:0
	o:PID(r,g,s,egt)		q:(iter_adj(r,egt)*ibar_gen0(r,g,egt))
	i:PA(r,g)$(not em(g))	q:(iter_adj(r,egt)*ibar_gen0(r,g,egt))
	i:PA(r,g)$(em(g))		q:(iter_adj(r,egt)*ibar_gen0(r,g,egt)*aeei(r,g,s))
	i:PDCO2(r,s)$[swcarb$co2base(r,s)]		q:(iter_adj(r,egt)*aeei(r,g,s)*dcb0egt(r,g,s,egt)) p:(1e-6)

* output by generation technology
$prod:YMEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))$(not swperf)] s:es_re(r,egt) m:0
	o:PYEGT(r,s,egt)$(not swperf)							q:(tfp_adj(r,egt)*obar_gen0(r,egt))
+		a:PINA 	n:EGTRATE(r,s,egt)	m:(-1)
+		a:GOVT 	t:ty(r,s)
+		p:(1-ty0(r,s))
	i:PID(r,g,s,egt)$[ibar_gen0(r,g,egt)]		q:(iter_adj(r,egt)*ibar_gen0(r,g,egt))		m:
	i:PVAEGT(r,s,egt)$[va_tot(r,egt)]			q:(iter_adj(r,egt)*va_tot(r,egt))				m:
	i:PREGT(r,s,egt)$[fbar_gen0(r,"fr",egt)]	q:(iter_adj(r,egt)*fbar_gen0(r,"fr",egt))
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))

* !!!! Conventional techs only - no vgen
* !!!! perfect substitutes switch off as default, no logic built in to toggle this currently
$prod:YM(r,s)$[y_(r,s)$y_egt(s)$(not swperf)] s:4 m:8
	o:PY(r,g)	q:(os_novgen(r,s)*ys0(r,s,g))
* !!!! option for handling coal: if coal(egt) reduce scale_ymegt(s,egt) over time until there is almost no mutable left in the bmk by 2030
	i:PYEGT(r,s,egt)$[(not vgen(egt))$obar_gen0(r,egt)$(not swperf)$fgen(egt)]	q:(obar_gen0(r,egt)*scale_ymegt(s,egt))	m:
	i:PYEGT(r,s,egt)$[(not vgen(egt))$obar_gen0(r,egt)$(not swperf)$(not fgen(egt))]	q:(obar_gen0(r,egt)*scale_ymegt(s,egt))

* * output by generation technology
* $prod:YMEGT(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$swperf$(not vgen(egt))] s:es_re(r,egt) m:0.5
* 	o:PY(r,g)	q:(obar_gen0(r,egt)*ys0(r,s,g)/sum(gg,ys0(r,s,gg)))
* +		a:PINA 	n:EGTRATE(r,s,egt)	m:(-1)
* +		a:GOVT 	t:ty(r,s)
* +		p:(1-ty0(r,s))
* 	i:PID(r,g,s,egt)$[ibar_gen0(r,g,egt)]		q:(iter_adj(r,egt)*ibar_gen0(r,g,egt))		m:
* 	i:PVAEGT(r,s,egt)$[va_tot(r,egt)]			q:(iter_adj(r,egt)*va_tot(r,egt))				m:
* 	i:PREGT(r,s,egt)$[fbar_gen0(r,"fr",egt)]	q:(iter_adj(r,egt)*fbar_gen0(r,"fr",egt))
* +		a:GOVT	t:tk(r,s)	p:(1+tk0(r))


*------------------------------------------------------------------------
* EGT extant production
*------------------------------------------------------------------------

* extant backstop electricity production - coefficient form
$prod:YXBET(r,s,egt,v)$[y_(r,s)$vbet_act(r,s,egt)$ybet_except(r,s,egt)] s:0 mva:0 m(mva):0 va(mva):0
	o:PY(r,g)				q:(xbet_ys_out(r,s,egt,g,v))
+		a:GOVT	t:ty(r,s) p:(1-ty0(r,s))
+		a:GOVT$[(not mnyprntrgo)]	t:subxbet(r,s,egt,v)$[(not mnyprntrgo)]
+		a:JPOW$[mnyprntrgo]	t:subxbet(r,s,egt,v)$[mnyprntrgo]	
+		a:PINA 	n:EGTRATE(r,s,egt)	m:(-1)
	i:PA(r,g)				q:(xbet_id_in(r,g,s,egt,v)*bstechfact(r,egt))		m:
	i:PL(r)					q:(xbet_ld_in(r,s,egt,v)*bstechfact(r,egt))			va:
	i:RKXBET(r,s,egt,v)		q:((xbet_kd_in(r,s,egt,v)+xbet_frd_in(r,s,egt,v))*bstechfact(r,egt))			va:
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
* !!!! removed the TSF in extant block for renewables
* 	i:RKXBET(r,s,egt,v)		q:(xbet_kd_in(r,s,egt,v)*bstechfact(r,egt))			va:
* +		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
* 	i:RKXBET(r,s,egt,v)		q:(xbet_frd_in(r,s,egt,v)*bstechfact(r,egt))
* +		a:GOVT	t:tk(r,s)	p:(1+tk0(r))

* extant conventional electricity production - coefficient form
$prod:YXEGT(r,s,egt,v)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))$xegt_k(r,s,egt,v)] s:esr_egt(egt) m:0 va(m):0 g.tl(m):0
	o:PY(r,g)	q:(xegt_ys_out(r,s,egt,g,v))
+		a:GOVT 	t:ty(r,s)
+		p:(1-ty0(r,s))
	i:PA(r,g)	q:(xegt_id_in(r,g,s,egt,v))		g.tl:$(em(g))	m:$(not em(g))
	i:PL(r)											q:(xegt_ld_in(r,s,egt,v))	va:
	i:RKXEGT(r,s,egt,v)								q:(xegt_kd_in(r,s,egt,v))	
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
	i:PREGT(r,s,egt)$[xegt_frd_in(r,s,egt,v)]	q:(xegt_frd_in(r,s,egt,v))	m:
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
	i:PDCO2(r,s)#(em)$[swcarb$co2base(r,s)]		q:xegt_co2d_in(r,em,s,egt,v)	p:(1e-6)	em.tl:


*------------------------------------------------------------------------


*------------------------------------------------------------------------
* Mutable production non-ele
*------------------------------------------------------------------------

* value added
$prod:VA(r,s)$[va_bar(r,s)$(not y_egt(s))] s:esub_va(s)
	o:PVA(r,s) 	q:(va_bar(r,s))
	i:RK(r,s)$[(not swrks)] 	q:(kd0(r,s)) a:GOVT t:tk(r,s) p:(1+tk0(r))
	i:RKS$[(swrks)] 	q:(kd0(r,s)) a:GOVT t:tk(r,s) p:(1+tk0(r))
	i:PL(r) 	q:(ld0(r,s))

* energy
$prod:E(r,s)$[en_bar(r,s)$(not y_egt(s))] s:esub_ele(s) cgo:esub_fe(s) g.tl(cgo):0
    o:PE(r,s)   				q:(en_bar(r,s))
    i:PA(r,g)$[ele(g)]  		q:(id0(r,g,s)*aeei(r,g,s)*elk(r,g,s))
    i:PA(r,g)$[fe(g)]   		q:(id0(r,g,s)*aeei(r,g,s)*elk(r,g,s))  	g.tl:
    i:PDCO2(r,s)#(fe)$[swcarb$co2base(r,s)]   	q:(dcb0(r,fe,s)*aeei(r,fe,s)*elk(r,fe,s))	fe.tl:	p:(1e-6)

* mutable production
$prod:YM(r,s)$[y_(r,s)$(not y_egt(s))] s:esub_fr(r,s) vem:esub_klem(s) m(vem):esub_ne(s) ve(vem):esub_ve(s) g.tl(m):0
	o:PY(r,g)					q:ys0(r,s,g)
+		a:GOVT	t:ty(r,s)	p:(1-ty0(r,s))
	i:PA(r,g)$[(not en(g))]		q:id0(r,g,s)		m:$((not cru(g)))	g.tl:$(cru(g))
	i:PE(r,s)$[en_bar(r,s)]		q:en_bar(r,s)		ve:
	i:PVA(r,s)$[va_bar(r,s)]	q:va_bar(r,s)		ve:
    i:PDCO2(r,s)#(cru)$[swcarb$co2base(r,s)]  	q:(dcb0(r,cru,s))	cru.tl:	p:(1e-6)
	i:PRM(r,s)$[fr_m(r,s)]		q:fr0(r,s)
+		a:GOVT t:tk(r,s)	p:(1+tk0(r))

*------------------------------------------------------------------------
* extant production non-ele and non resource extraction
*------------------------------------------------------------------------

$prod:YX(r,s,v)$[y_(r,s)$x_k(r,s,v)$(not y_egt(s))] s:0 va:0 g.tl:0
	o:PY(r,g)						q:(x_ys_out(r,s,g,v))
+		a:GOVT t:ty(r,s)    p:(1-ty0(r,s))
	i:PA(r,g)						q:x_id_in(r,g,s,v)		g.tl:$(em(g))
	i:PL(r)							q:x_ld_in(r,s,v)			va:
	i:RKX(r,s,v)						q:x_kd_in(r,s,v)			va:
+		a:GOVT	t:tk(r,s)	p:(1+tk0(r))
	i:PDCO2(r,s)#(em)$[swcarb$co2base(r,s)]		q:(x_co2d_in(r,em,s,v))	em.tl:	p:(1e-6)
	i:PRM(r,s)$[x_fr(r,s,v)$xe(s)]	q:x_frd_in(r,s,v)
+		a:GOVT t:tk(r,s)	p:(1+tk0(r))


*------------------------------------------------------------------------
* Trade 
*------------------------------------------------------------------------

* disposition
$prod:X(r,g)$x_(r,g) t:etranx(g)
	o:PFX		q:(x0(r,g)-rx0(r,g))
	o:PN(g)		q:xn0(r,g)
	o:PD(r,g)	q:xd0(r,g)
	i:PY(r,g)	q:s0(r,g)

* absorption
$prod:A(r,g)$a_(r,g) s:0 dm:esubdm(g) d(dm):esubd(r,g)
	o:PA(r,g)	q:a0(r,g)
+		a:GOVT	t:ta(r,g)	p:(1-ta0(r,g))
	o:PFX		q:rx0(r,g)
	i:PN(g)		q:nd0(r,g)	d:
	i:PD(r,g)	q:dd0(r,g)	d:
	i:PFX		q:m0(r,g)	dm:
+		a:GOVT	t:tm(r,g) 	p:(1+tm0(r,g))
	i:PM(r,m)	q:md0(r,m,g)

* margin supply
$prod:MS(r,m)
	o:PM(r,m)	q:(sum(gm, md0(r,m,gm)))
	i:PN(gm)	q:nm0(r,gm,m)
	i:PD(r,gm)	q:dm0(r,gm,m)

*------------------------------------------------------------------------
*------------------------------------------------------------------------

* final consumption
$prod:C(r,h) s:esub_cd e:esub_ele("fd") cgo(e):esub_fe("fd") g.tl(cgo):0
	o:PC(r,h)	q:c0_h(r,h)
	i:PA(r,g)	q:(cd0_h(r,g,h)*elk(r,g,"fd")*aeei(r,g,"fd"))	g.tl:$(em(g)) e:$(ele(g))
	i:PDCO2(r,"fd")#(em)$[swcarb$co2base(r,"fd")]	q:(dcb0(r,em,"fd")*cd0_h_shr(r,em,h)*elk(r,em,"fd")*aeei(r,em,"fd"))	em.tl:	p:(1e-6)

* co2 emissions
$prod:CO2(r,sfd)$[swcarb$co2base(r,sfd)]
	o:PDCO2(r,sfd)	q:1
	i:PCO2		q:1		p:1
	i:PFX$[(not co2base(r,sfd))]		q:(1e-6)

* investment supply
$prod:INV(r) s:esub_inv
	o:PINV(r)	q:inv0(r)
	i:PA(r,g)	q:i0(r,g)

* labor supply
$prod:LS(r,h)
	o:PL(q)	q:(le0(r,q,h)*gprod)
+		a:GOVT	t:tl(r,h)	p:(1-tl0(r,h))
	i:PLS(r,h)	q:(ls0(r,h)*gprod)

* capital transformation function
* !!!! with vintaging, flexibility here matters for mutable capital costs
* ---- etak can be rescaled to allow more/less flexibility with vintaging
* ---- or just switch swrks = 1 to make mutable capital perfectly malleable
* $prod:KS$[(not swrks)] t:(5*etaK)
$prod:KS$[(not swrks)] t:(etaK)
	o:RK(r,s)	q:ksrs_m0(r,s)
	i:RKS		q:(sum((r,s),ksrs_m0(r,s)))

* full consumption
$prod:Z(r,h) s:esub_zh(r,h)
	o:PZ(r,h)		q:z0_h(r,h)
	i:PC(r,h)		q:c0_h(r,h)
	i:PLS(r,h)		q:lsr0(r,h)

* welfare
$prod:W(r,h) s:0
	o:PW(r,h)		q:w0_h(r,h)
	i:PZ(r,h)		q:z0_h(r,h)
	i:PINV(r)		q:inv0_h(r,h)

* Representative Agent
$demand:RA(r,h)
	d:PW(r,h)		q:w0_h(r,h)
	e:PFX			q:(sum(tp,hhtp0(r,h,tp)))	r:TRANS	
	e:PLS(r,h)		q:lsr0(r,h)
	e:PLS(r,h)		q:(ls0(r,h)*gprod)
* !!!! fsav_h(r,h) has both positive and negative values
* --- (not sure if it is technically foreign savings or some other type of adjustment)
	e:PFX			q:(fsav_h(r,h))
	e:PFX$[swcarb]	q:1		r:CTAXTRN(r,h)
* swhhext allows for the rental to be broken into extant and mutable components to avoid problems with more vintages
	e:PK$[(not swhhext)]	q:ke0(r,h)
	e:PK$[swhhext]			q:(ke0_m(r)*ke0_shr(r,h))
	e:RKEXT(r)$[swhhext]	q:(ke0_x(r)*ke0_shr(r,h))

* Government agent
$demand:GOVT
	d:PA(r,g)	q:g0(r,g)
	e:PFX		q:govdef0
	e:PFX		q:(-sum((r,h),tp0(r,h)))	r:TRANS
	e:PCO2$[swcarb]		q:(sum(r,sum(s,co2base(r,s))+co2base(r,"fd")))	r:ETAR
	e:PFX$[swcarb]		q:(-1)	r:CTAXREV

* Pinning agent - used for endogenous tfp electricity pin
$demand:PINA
	d:PFX		q:1
	e:PFX		q:1	r:EGTREV
	e:PFX		q:1

* Subsidy Agent
$demand:JPOW
	d:PFX	q:1
	e:PFX$[mnyprntrgo] 	q:(-1)	r:BRRR$[mnyprntrgo]
	e:PFX	q:1

$constraint:BRRR
		(sum((r,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)],
* mutable subsidy
			(sum(g,PY(r,g)*((os_bet(r,egt))/(1-ty0(r,s)))*(ys0(r,s,g)/sum(g.local,ys0(r,s,g))))*YBET(r,s,egt)*subegt(r,s,egt))$[os_bet(r,egt)]
			+ (sum(g,PY(r,g)*((os_egt(r,egt))/(1-ty0(r,s)))*(ys0(r,s,g)/sum(g.local,ys0(r,s,g))))*YBET(r,s,egt)*subegt(r,s,egt))$[os_egt(r,egt)]
* extant subsidy
			+ (sum(v,(sum(g,PY(r,g)*xbet_ys_out(r,s,egt,g,v))*YXBET(r,s,egt,v))*subxbet(r,s,egt,v)))$[vbet_act(r,s,egt)]
		)) + 0
		=e= BRRR*PFX
;

* Capital agent
* !!!! this block is getting too large, especially with vintaged capital in there
* .... use swhhext = 1 to reduce dimensions in the block
$demand:NYSE
	d:PK
	e:PY(r,g)						q:yh0(r,g)
	e:RKS							q:(sum(r,ks_m(r)))
	e:RKX(r,s,v)$[x_k(r,s,v)$(not swhhext)]			q:x_k(r,s,v)
	e:RKXEGT(r,s,egt,v)$[(not vgen(egt))$xegt_k(r,s,egt,v)$(not swhhext)]			q:xegt_k(r,s,egt,v)
	e:RKXBET(r,s,egt,v)$[vbet_act(r,s,egt)$xbet_k(r,s,egt,v)$ybet_except(r,s,egt)$(not swhhext)]		q:(xbet_k(r,s,egt,v)+xbet_fr(r,s,egt,v))
	e:PRM(r,s)$[fr_m(r,s)$xe(s)]	q:fr_m(r,s)
	e:PRM(r,s)$[fr_x(r,s)$xe(s)]	q:fr_x(r,s)
	e:PREGT(r,s,egt)$[y_egt(s)$fbar_gen0(r,"fr",egt)$(not vgen(egt))]	q:bse(r,"fr",egt)
	e:PRBET(r,s,egt)$[y_egt(s)$vgen(egt)$y_(r,s)$ybet_except(r,s,egt)] q:bse(r,"fr",egt)
	e:PR_ELBS(r,s)$[elbs_act(r,s)]	q:elbse(r,s)

* extant capital agent for aggregation
$demand:KXX(r)$[ke0_x(r)$swhhext]
	d:RKEXT(r)
	e:RKX(r,s,v)$[x_k(r,s,v)]	q:(x_k(r,s,v))
	e:RKXEGT(r,s,egt,v)$[(not vgen(egt))$xegt_k(r,s,egt,v)]		q:(xegt_k(r,s,egt,v))
	e:RKXBET(r,s,egt,v)$[vbet_act(r,s,egt)$xbet_k(r,s,egt,v)$ybet_except(r,s,egt)]	q:((xbet_k(r,s,egt,v)+xbet_fr(r,s,egt,v)))

* Transfer payments
$constraint:TRANS
	sum((r,g), PA(r,g)*g0(r,g)) =e= GOVT;

* CPI - cost of living index
$constraint:CPI
	CPI*sum((r,h),c0_h(r,h)) =e= sum((r,h),PC(r,h)*c0_h(r,h));

* Target emissions restriction
$constraint:ETAR$[swcarb]
	co2target =g= sum(r,sum(s,co2base(r,s))+co2base(r,"fd"))*ETAR;

* $constraint:ETAR$[swctax]
* 	co2tax =e= PCO2;

* CO2 tax revenue
$constraint:CTAXREV$[swcarb$(not swctax)]
	CTAXREV*PFX =e= PCO2*(sum(r,sum(s,co2base(r,s))+co2base(r,"fd")))*ETAR;

* carbon tax case
* !!!! verify that this should be CO2.l(r,sfd) and not instead CO2(r,sfd)
* ---- think it should probably be CO2(r,sfd)
* ---- CO2.l would mean revenues calculated off co2 from previous year's solve
$constraint:CTAXREV$[swcarb$swctax]
	CTAXREV*PFX =e= PCO2*(sum(r,sum(sfd,CO2.l(r,sfd)$[co2base(r,sfd)])));

* CO2 tax transfers - two lump sum methods currently
$constraint:CTAXTRN(r,h)$[swcarb]
	(CTAXTRN(r,h)*PFX - CTAXREV*(pop(r,h)/sum((hh,rr),pop(rr,hh))))$lumpsum_us
	+ (CTAXTRN(r,h)*PFX - PCO2*sum(sfd,co2base(r,sfd))*ETAR*(pop(r,h)/sum((hh),pop(r,hh))))$lumpsum_st
	=e= 0;

$report:
 	v:DCD(r,g,h)$[cd0_h(r,g,h)]	i:PA(r,g)	prod:C(r,h)	
	v:DIDI(r,g)$[i0(r,g)]	i:PA(r,g)	prod:INV(r)
	v:DIDG(r,g)	d:PA(r,g)	demand:GOVT
	v:DND(r,g)$[nd0(r,g)]	i:PN(g)		prod:A(r,g)
	v:DDD(r,g)$[dd0(r,g)]	i:PD(r,g)	prod:A(r,g)
	v:DMM(r,m,g)$[md0(r,m,g)]	i:PM(r,m)	prod:A(r,g)
	v:DMF(r,g)$[m0(r,g)]	i:PFX		prod:A(r,g)
 	v:REX(r,g)$[rx0(r,g)]	o:PFX		prod:A(r,g)
	v:DLS(r,h)	i:PLS(r,h)	prod:Z(r,h)
	v:DCO2C(r,g,h)$[(dcb0(r,g,"fd")*cd0_h_shr(r,g,h))$fe(g)]	i:PDCO2(r,"fd")#(g)	prod:C(r,h)
	v:DCO2(r)$[cb0(r)]	o:PDCO2(r,"fd")		prod:CO2(r,"fd")
	v:SCO2(r,sfd)$[cb0(r)]	i:PCO2		prod:CO2(r,sfd)
	v:SX(r,g)$[s0(r,g)]	i:PY(r,g)	prod:X(r,g)
	v:SXN(r,g)$[xn0(r,g)]	o:PN(g)	prod:X(r,g)
	v:SXF(r,g)$[(x0(r,g)-rx0(r,g))]	o:PFX	prod:X(r,g)
	v:SXD(r,g)$[xd0(r,g)]	o:PD(r,g)	prod:X(r,g)
	v:SLS(r,q,h)	o:PL(q)	prod:LS(r,h)
	v:DSLS(r,h)		i:PLS(r,h)	prod:LS(r,h)
	v:SINV(r)	o:PINV(r)	prod:INV(r)
	v:SARM(r,g)	o:PA(r,g)	prod:A(r,g)
	
*mutable production
	v:DKM(r,s)$[kd0(r,s)$(not swrks)]	i:RK(r,s)	prod:VA(r,s)
	v:DKM(r,s)$[kd0(r,s)$(swrks)]	i:RKS	prod:VA(r,s)
	v:DRM(r,s)$[fr_m(r,s)]	i:PRM(r,s)	prod:YM(r,s)
	v:DIDME(r,g,s)$[en(g)$id0(r,g,s)]	i:PA(r,g)	prod:E(r,s)
	v:DIDMM(r,g,s)$[nne(g)$id0(r,g,s)]	i:PA(r,g)	prod:YM(r,s)
	v:DLDM(r,s)$[ld0(r,s)]		i:PL(r)	prod:VA(r,s)
	v:DCO2M(r,g,s)$[dcb0(r,g,s)$cru(g)]	i:PDCO2(r,s)#(g)	prod:YM(r,s)
	v:DCO2E(r,g,s)$[dcb0(r,g,s)$fe(g)]	i:PDCO2(r,s)#(g)	prod:E(r,s)

*extant production
	v:DKX(r,s,v)$[x_k(r,s,v)]	i:RKX(r,s,v)	prod:YX(r,s,v)
	v:DRX(r,s,v)$[x_fr(r,s,v)]	i:PRM(r,s)	prod:YX(r,s,v)
	v:DIDX(r,g,s,v)$[id0(r,g,s)$x_k(r,s,v)]	i:PA(r,g)	prod:YX(r,s,v)
	v:DLDX(r,s,v)$[x_k(r,s,v)]		i:PL(r)	prod:YX(r,s,v)
	v:DCO2X(r,g,s,v)$[dcb0(r,g,s)$x_k(r,s,v)$(em(g))]	i:PDCO2(r,s)#(g)	prod:YX(r,s,v)

* mutable conventional electricity
	v:DIDMEGT(r,g,s,egt)$[y_egt(s)$ibar_gen0(r,g,egt)]	i:PA(r,g)	prod:ID(r,g,s,egt)
	v:DKMEGT(r,s,egt)$[y_egt(s)$fbar_gen0(r,"k",egt)$(not swrks)]		i:RK(r,s)	prod:VAEGT(r,s,egt)
	v:DKMEGT(r,s,egt)$[y_egt(s)$fbar_gen0(r,"k",egt)$(swrks)]		i:RKS	prod:VAEGT(r,s,egt)
	v:DRMEGT(r,s,egt)$[y_egt(s)$fbar_gen0(r,"fr",egt)]	i:PREGT(r,s,egt)	prod:YMEGT(r,s,egt)
	v:DLDMEGT(r,s,egt)$[y_egt(s)$fbar_gen0(r,"l",egt)]	i:PL(r)		prod:VAEGT(r,s,egt)
	v:DVAEGT(r,s,egt)$[y_egt(s)$va_tot(r,egt)]			o:PVAEGT(r,s,egt)	prod:VAEGT(r,s,egt)
	v:DCO2EGT(r,g,s,egt)$[y_egt(s)$em(g)$(dcb0(r,g,s)*ibar_gen0(r,g,egt))]	i:PDCO2(r,s)	prod:ID(r,g,s,egt)

* extant conventional electricity
	v:DIDXEGT(r,g,s,egt,v)$[y_egt(s)$ibar_gen0(r,g,egt)$xegt_k(r,s,egt,v)]	i:PA(r,g)	prod:YXEGT(r,s,egt,v)
	v:DKXEGT(r,s,egt,v)$[y_egt(s)$fbar_gen0(r,"k",egt)$xegt_k(r,s,egt,v)]		i:RKXEGT(r,s,egt,v)	prod:YXEGT(r,s,egt,v)
	v:DRXEGT(r,s,egt,v)$[y_egt(s)$fbar_gen0(r,"fr",egt)$xegt_k(r,s,egt,v)]	i:PREGT(r,s,egt)	prod:YXEGT(r,s,egt,v)
	v:DLDXEGT(r,s,egt,v)$[y_egt(s)$fbar_gen0(r,"l",egt)$xegt_k(r,s,egt,v)]	i:PL(r)		prod:YXEGT(r,s,egt,v)
	v:DCO2XEGT(r,g,s,egt,v)$[y_egt(s)$em(g)$(dcb0(r,g,s)*ibar_gen0(r,g,egt))$xegt_k(r,s,egt,v)]	i:PDCO2(r,s)	prod:YXEGT(r,s,egt,v)

* backstop and vgen electricity
	v:DIDBET(r,g,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)]	i:PA(r,g)	prod:YBET(r,s,egt)
	v:DKMBET(r,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)$(not swrks)]	i:RK(r,s)	prod:YBET(r,s,egt)
	v:DKMBET(r,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)$(swrks)]	i:RKS	prod:YBET(r,s,egt)
	v:DRMBET(r,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)]	i:PRBET(r,s,egt)	prod:YBET(r,s,egt)
	v:DLDMBET(r,s,egt)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)]	i:PL(r)		prod:YBET(r,s,egt)

* extant backstop
	v:DIDXBET(r,g,s,egt,v)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)$xbet_k(r,s,egt,v)]	i:PA(r,g)	prod:YXBET(r,s,egt,v)
	v:DKXBET(r,s,egt,v)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)$xbet_k(r,s,egt,v)]	i:RKXBET(r,s,egt,v)	prod:YXBET(r,s,egt,v)
	v:DLDXBET(r,s,egt,v)$[y_(r,s)$y_egt(s)$vgen(egt)$ybet_except(r,s,egt)$xbet_k(r,s,egt,v)]	i:PL(r)		prod:YXBET(r,s,egt,v)

* electrification backstop
	v:DID_ELBS(r,g,s)$[elbs_act(r,s)]	i:PA(r,g)		prod:Y_ELBS(r,s)
	v:DKM_ELBS(r,s)$[elbs_act(r,s)$(not swrks)]		i:RK(r,s)		prod:Y_ELBS(r,s)
	v:DKM_ELBS(r,s)$[elbs_act(r,s)$(swrks)]		i:RKS		prod:Y_ELBS(r,s)
	v:DRM_ELBS(r,s)$[elbs_act(r,s)]		i:PR_ELBS(r,s)	prod:Y_ELBS(r,s)
	v:DLDM_ELBS(r,s)$[elbs_act(r,s)]	i:PL(r)			prod:Y_ELBS(r,s)


$OFFTEXT

* $SYSINCLUDE mpsgeset mgemodel -mt=1
$SYSINCLUDE mpsgeset mgemodel

* numeraire price
PFX.fx = 1;

* initialize variables

YX.l(r,s,v) = 0;
YX.l(r,s,v)$[(not y_egt(s))] = sum(g,ys0(r,s,g))*(1-ty0(r,s))*thetax(r,s)*x_oshr(r,s,v);

YM.l(r,s)$[(not y_egt(s))] = 1-thetax(r,s);
E.l(r,s)$[(not y_egt(s))] = YM.l(r,s);
VA.l(r,s)$[(not y_egt(s))] = YM.l(r,s);

TRANS.l = 1;

CPI.l = 1;

YBET.l(r,s,egt) = 0;
YBET.l(r,s,egt)$[y_egt(s)$vgen(egt)] = 0;
YBET.l(r,s,egt)$[y_egt(s)$vgen(egt)$os_egt(r,egt)] = obar_gen0(r,egt)*(1-ty0(r,s))*(1-thetaxegt(s,egt));

YXBET.l(r,s,egt,v) = 0;
YXBET.l(r,s,egt,v)$[y_egt(s)$vgen(egt)$os_egt(r,egt)] = obar_gen0(r,egt)*(1-ty0(r,s))*thetaxegt(s,egt)*xegt_oshr(r,s,egt,v);

PRBET.l(r,s,egt)$[y_egt(s)$os_bet(r,egt)] = 1e-6;

* initialize extant and mutable production
YXEGT.l(r,s,egt,v) = 0;
YXEGT.l(r,s,egt,v)$[y_egt(s)$(not vgen(egt))] = obar_gen0(r,egt)*(1-ty0(r,s))*%thetaxegtval%*xegt_oshr(r,s,egt,v);
YXEGT.l(r,s,egt,v)$[y_egt(s)$(not vgen(egt))] = YXEGT.l(r,s,egt,v)*scale_yxegt(s,egt);

YMEGT.l(r,s,egt) = 1-%thetaxegtval%;
VAEGT.l(r,s,egt) = 1-%thetaxegtval%;
ID.l(r,g,s,egt) = 1-%thetaxegtval%;

YMEGT.l(r,s,egt) = YMEGT.l(r,s,egt)*scale_ymegt(s,egt);
VAEGT.l(r,s,egt) =VAEGT.l(r,s,egt)*scale_ymegt(s,egt);
ID.l(r,g,s,egt) = ID.l(r,g,s,egt)*scale_ymegt(s,egt);

YMEGT.l(r,s,egt)$vgen(egt) = 0;

* !!!! to avoid unmatched variable errors on YXEGT when ymegt.l = 0 in previous year
ymegt.lo(r,s,egt) = 1e-5;
ym.lo(r,s) = 1e-5;
* yxegt.lo(r,s,egt,v) = 0.01;

YM.l(r,s)$[y_egt(s)] = 1-%thetaxegtval%;

* to prevent endogenous retirement of extant nuc/hyd/othc
RKXEGT.lo(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)$nuc(egt)] = 1e-6;
RKXEGT.lo(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)$hyd(egt)] = 1e-6;
RKXEGT.lo(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)$othc(egt)] = 1e-6;
* and of gas in pin
* RKXEGT.lo(r,s,egt,v)$[y_egt(s)$xegt_k(r,s,egt,v)$ngas(egt)$switerpin] = 1e-4;


CO2.l(r,sfd) = co2base(r,sfd);
PCO2.l = 1e-6;
PDCO2.l(r,sfd) = 1e-6;

ETAR.l = 1;

CTAXREV.l = PCO2.l*(sum(r,sum(s,co2base(r,s))+co2base(r,"fd")))*ETAR.l;
CTAXTRN.l(r,h) = CTAXREV.l*(pop(r,h)/sum((hh,rr),pop(rr,hh)))$lumpsum_us
	+ PCO2.l*sum(sfd,co2base(r,sfd))*ETAR.l*(pop(r,h)/sum((hh),pop(r,hh)))$lumpsum_st
;

co2target = sum((r,sfd),co2base(r,sfd));

EGTRATE.l(r,s,egt) = 0;
EGTRATE.lo(r,s,egt) = -100;
EGTOUT.l(r,s,egt) = 0;
EGTOUT.lo(r,s,egt) = -inf;
EGTREV.l = 0;
EGTREV.lo = -inf;

EGTMOD.l(r,s,egt)$[y_egt(s)$y_(r,s)] =
	[YBET.l(r,s,egt)$[vgen(egt)$ybet_except(r,s,egt)]
	+ ((YMEGT.l(r,s,egt))*obar_gen0(r,egt)*(1-ty0(r,s)))$[(not vgen(egt))]
	+ sum(v,YXBET.l(r,s,egt,v)$[y_(r,s)$vbet_act(r,s,egt)$ybet_except(r,s,egt)$xbet_k(r,s,egt,v)])
	+ sum(v,YXEGT.l(r,s,egt,v)$[(not vgen(egt))$xegt_k(r,s,egt,v)])]/(1-ty0(r,s));

DYMEGT.l(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))] =
	YMEGT.l(r,s,egt)*sum(g,(obar_gen0(r,egt)*ys0(r,s,g)/sum(gg,ys0(r,s,gg))));
SYMEGT.l(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))] =
	YMEGT.l(r,s,egt)*sum(g,(obar_gen0(r,egt)*ys0(r,s,g)/sum(gg,ys0(r,s,gg))));

PYEGT.l(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))] = 1;

SYXEGT.l(r,s,egt,v)$[y_egt(s)$obar_gen0(r,egt)$(not vgen(egt))$xegt_k(r,s,egt,v)] =
	YXEGT.l(r,s,egt,v)*sum(g,xegt_ys_out(r,s,egt,g,"v1"));

* electrification backstop initalization
Y_ELBS.l(r,s)$[elbs_act(r,s)] = 0;
PR_ELBS.l(r,s)$[elbs_act(r,s)] = 1e-6;
PR_ELBS.lo(r,s)$[elbs_act(r,s)] = 1e-6;

* subsidy initialization
BRRR.l = 0;
BRRR.lo = -inf;

* balance checking
parameter chk_pk;

parameter chk_ctaxrev;

chk_ctaxrev("rhs") = PCO2.l*(sum(r,sum(s,co2base(r,s))+co2base(r,"fd")))*ETAR.l;
chk_ctaxrev("lhs") = PFX.l * CTAXREV.l;

