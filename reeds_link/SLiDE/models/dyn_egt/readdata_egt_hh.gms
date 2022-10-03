$stitle Data read subroutine for static and dynamic models

* -----------------------------------------------------------------------------
* Set options
* -----------------------------------------------------------------------------

* Set the dataset
$if not set ds $set ds WiNDC_bluenote_cps_census_2017.gdx

* File separator
* $set sep %system.dirsep%

* -----------------------------------------------------------------------------
* Read in the base dataset
* -----------------------------------------------------------------------------

$gdxin '%bmkdir%%ds%'

set	sbea bea goods and sectors;
$load sbea=s

set sfd	bea and final demand	/set.sbea, fd/;

* sets in WiNDC
set
    r       States,
    s(sfd)       Goods and sectors from BEA,
    gm(s)   Margin related sectors,
    m       Margins (trade or transport),
    h       Household categories,
    tp     Transfer types;    


$loaddc r s m h tp=trn


* aliased sets
alias(s,g,gg,ss),(r,q,rr),(h,hh);

* time series of parameters
parameter
* core data
    ys0(r,g,s)  	Sectoral supply,
    id0(r,s,g)  	Intermediate demand,
    ld0(r,s)    	Labor demand,
    kd0(r,s)    	Capital demand,
    ty0(r,s)    	Output tax on production,
    m0(r,s)     	Imports,
    x0(r,s)     	Exports of goods and services,
    rx0(r,s)    	Re-exports of goods and services,
    md0(r,m,s)  	Total margin demand,
    nm0(r,g,m)  	Margin demand from national market,
    dm0(r,g,m)  	Margin supply from local market,
    s0(r,s)     	Aggregate supply,
    a0(r,s)     	Armington supply,
    ta0(r,s)    	Tax net subsidy rate on intermediate demand,
    tm0(r,s)    	Import tariff,
    cd0(r,s)    	Final demand,
    c0(r)       	Aggregate final demand,
    yh0(r,s)    	Household production,
    bopdef0(r)  	Balance of payments,
    hhadj(r)    	Household adjustment,
    g0(r,s)     	Government demand,
    i0(r,s)     	Investment demand,
    xn0(r,g)    	Regional supply to national market,
    xd0(r,g)    	Regional supply to local market,
    dd0(r,g)    	Regional demand from local  market,
    nd0(r,g)    	Regional demand from national market,

* household data
    pop(r,h)		Population (households or returns in millions),
    le0(r,q,h)		Household labor endowment,
    ke0(r,h)		Household interest payments,
    tk0(r)            	Capital tax rate,
    tl0(r,h)		Household labor tax rate,
    cd0_h(r,g,h)    	Household level expenditures,
    c0_h(r,h)		Aggregate household level expenditures,
    sav0(r,h)		Household saving,
    fsav0           	Foreign savings,
    totsav0	    	Aggregate savings,
    govdef0	   	Government deficit,
    taxrevL(r)     	Tax revenue,
    taxrevK	    	Capital tax revenue,
    tp0(r,h)		Household transfer payments,
    hhtp0(r,h,tp) 	Disaggregate transfer payments,

* bluenote additions
    resco2(r,g)		Residential co2 emissions,
    secco2(r,g,s)	Sector level co2 emissions;

* production data:
$loaddc ys0 ld0 kd0 id0 ty0

* aggregate consumption data:
$loaddc yh0 cd0 c0 i0 g0 bopdef0 hhadj

* trade data:
$loaddc s0 xd0 xn0 x0 rx0 a0 nd0 dd0 m0 ta0 tm0

* margins:
$loaddc md0 nm0 dm0

* household data:
$loaddc le0 ke0 tk0 tl0 cd0_h c0_h sav0 tp0=trn0 hhtp0=hhtrn0 pop

* bluenote data:
$loaddc resco2 secco2

$gdxin

* define margin goods
gm(g) = yes$(sum((r,m), nm0(r,g,m) + dm0(r,g,m)) or sum((r,m), md0(r,m,g)));




*subset for emitting goods
sets
	em(g)	sources with co2 intensity	/col, gas, oil, cru/
	fe(g)	fossil-final energy goods	/col, gas, oil/
	xe(s)	extractive resources		/col, gas, cru/
	ele(g)  electricity  				/ele/
	oil(g)	refined oil 				/oil/
	gas(g)	gas							/gas/
	cru(g)	cru 						/cru/
	col(g)	col 						/col/
    en(g)   goods in energy bundle	    /col, gas, oil, ele/
	nem(g)	non-emitting source goods
    nne(g)  non-energy goods
	nfe(g)	non-fossil-final energy goods
	nxe(g)	non-extractive resource goods
;

nem(g)$[(not em(g))] = yes;
nne(g)$[(not en(g))] = yes;
nfe(g)$[(not fe(g))] = yes;
nxe(g)$[(not xe(g))] = yes;


sets
    y_(r,s)     Sectors and regions with positive production,
    x_(r,g)     Disposition by region,
    a_(r,g)     Absorption by region;

y_(r,s) = yes$(sum(g, ys0(r,s,g))>0);
x_(r,g) = yes$s0(r,g);
a_(r,g) = yes$(a0(r,g) + rx0(r,g));

*------------------------------------------------------------------------
* switch on/off egt disagg
*------------------------------------------------------------------------
* 0 inactive, 1 activate egt disagg
$if not set swegtval $setglobal swegtval 0

scalar swegt	switch for exogenized electricity;
swegt = %swegtval%;

set y_egt(s)	exogenized sector;
y_egt(s) = no;
y_egt(s)$[ele(s)$swegt] = yes;

set n_egt(s)	no exog(s);
n_egt(s) = no;
n_egt(s)$[(not y_egt(s))] = yes;

$if %swegtval%==0 $goto skipswegt

$setglobal swbtval 0
$setglobal thetaxegtval 0

swbt = %swbtval%;

$label skipswegt

* Declare new electricity generation source technologies
set	egt		electricity generation technologies	/
	vre-wnd		"variable renewable wind",
	vre-sol		"variable renewable solar",
	conv-oth	"other conv"
	conv-gas	"conventional gas",
	conv-coal	"conventional coal",
	conv-nuc	"conventional nuclear",
	conv-hyd	"conventional hydro"
	/;

alias(egt,eegt);

*------------------------------------------------------------------------

* calculate additional aggregate parameters
totsav0 = sum((r,h), sav0(r,h));
fsav0 = sum((r,g), i0(r,g)) - totsav0;
taxrevL(rr) = sum((r,h),tl0(r,h)*le0(r,rr,h));
taxrevK = sum((r,s),tk0(r)*kd0(r,s));
govdef0 = sum((r,g), g0(r,g)) + sum((r,h), tp0(r,h))
	- sum(r, taxrevL(r)) 
	- taxrevK 
	- sum((r,s,g)$y_(r,s), ty0(r,s) * ys0(r,s,g)) 
	- sum((r,g)$a_(r,g),   ta0(r,g)*a0(r,g) + tm0(r,g)*m0(r,g));

parameter	ty(r,s)		"Counterfactual production tax"
		tm(r,g)		"Counterfactual import tariff"
		ta(r,g)		"Counteractual tax on intermediate demand";

ty(r,s) = ty0(r,s);
tm(r,g) = tm0(r,g);
ta(r,g) = ta0(r,g);

parameters
	te(r,g)	energy taxes ad-valorem (cf)
	tk(r,s)	capital taxes (cf)
	tl(r,h)	labor taxes (cf);

te(r,g) = 0;
tk(r,s) = tk0(r);
tl(r,h) = tl0(r,h);

* rescale taxes for now
*kd0(r,s) = kd0(r,s)*(1+tk0(r));

* minimum on small values in benchmark
kd0(r,s)$y_(r,s) = max(1e-5,kd0(r,s));

parameter inv0(r) investment supply;
inv0(r) = sum(g, i0(r,g));

* Investment HH parameters
parameters
	theta_sav(r,h)
	inv0_h(r,h)
	i0_h(r,g,h)
	fsav_h(r,h)
;

theta_sav(r,h) = sav0(r,h)/sum(h.local,sav0(r,h));
i0_h(r,g,h) = i0(r,g)*theta_sav(r,h);
inv0_h(r,h) = sum(g, i0_h(r,g,h));
fsav_h(r,h) = inv0_h(r,h) - sav0(r,h);

* Labor-Leisure parameters
parameters
    esub_z(r)  	subsitution elasticity between leisure and consumption,
    theta_l 	uncompensated labor supply elasticity,
    lab_e0(r)  	benchmark labor endowment,
	leis_e0(r) 	benchmark leisure endowment,
    lte0(r) 	benchmark time endowment,
    leis_shr(r) leisure share of full consumption,
    extra(r)    extra time to calibrate time endowment based on labor
	z0(r)		benchmark final consumption and investment
	w0(r)		welfare or full consumption
;

* uncompensated - as wage goes up or down, household income levels change (income effect)
* income effect in labor supply response

* initialize esub_z(r) - calibrated before model solve
esub_z(r) = 0;
theta_l = 0.05;
lab_e0(r) = sum(s, ld0(r,s));
extra(r) = 0.4;
lte0(r) = lab_e0(r) / (1-extra(r));
leis_e0(r) = lte0(r) - lab_e0(r);
z0(r) = c0(r) + leis_e0(r);
* z0(r) = c0(r) + inv0(r);
leis_shr(r) = leis_e0(r)/(c0(r)+leis_e0(r));
* leis_shr(r) = leis_e0(r)/(z0(r)+leis_e0(r));
w0(r) = z0(r) + inv0(r);
* w0(r) = z0(r) + leis_e0(r);

* Install value for esub_z
esub_z(r) = 1 + theta_l / leis_shr(r);

* Household labor-leisure parameters
parameters
	ls0(r,h)	labor supply net of taxes
	lsr0(r,h)	leisure demand
	lteh0(r,h)	time endowment
	z0_h(r,h)	final consumption and investment
	lsr_shr(r,h) leisure share of full consumption
	w0_h(r,h)	welfare or full consumption
	esub_zh(r,h)	substitution elasticity between leisure and consumption
;

ls0(r,h) = sum(q,le0(r,q,h))*(1-tl0(r,h));
lteh0(r,h) = ls0(r,h)/(1-extra(r));
lsr0(r,h) = lteh0(r,h) - ls0(r,h);
z0_h(r,h) = c0_h(r,h) + lsr0(r,h);
* z0_h(r,h) = c0_h(r,h) + inv0_h(r,h);
w0_h(r,h) = z0_h(r,h) + inv0_h(r,h);
* w0_h(r,h) = z0_h(r,h) + lsr0(r,h);
lsr_shr(r,h) = lsr0(r,h)/z0_h(r,h);
* lsr_shr(r,h) = lsr0(r,h)/w0_h(r,h);

* Install value for esub_z
esub_zh(r,h) = 1 + theta_l / lsr_shr(r,h);

parameters
	etranx(g)	transformation elasticity X
	esubd(r,g)	domestic-national import elasticity D
;
etranx(g) = 4;

parameter esubdm(g) Domestic-import substitution elasticities (eventually from GTAP 10) /
		  oil 5
		  gas 3
		  cru 5
		  col 2
		  ele 1
		  trn 2
		  con 2
		  eint 4
		  omnf 5
		  osrv 3
		  roe 5 /;

*	See literature on the rule of two which can be traced back to the
*	paper by Alan Fox and Drusilla Brown in the 1990s.
esubd(r,g) = 2*esubdm(g);

parameter esub_cd;
esub_cd = 1;

parameter esub_inv		substitution elasticity for investment;
esub_inv = 5;

parameter etaK	capital transformation elasticity;
etaK = 4;

* disaggregate fossil fuel fixed resource from capital (sage)
parameter fr_shr(r,s)	share of fixed resource in total capital;
fr_shr(r,col) = 0.4;
fr_shr(r,gas) = 0.25;
fr_shr(r,cru) = 0.25;

* 40% for agriculture and 40% for mining sectors also (sage - not included)

parameter fr0(r,s)		benchmark fixed resource factor;
fr0(r,s)$[fr_shr(r,s)] = fr_shr(r,s)*kd0(r,s);

*update capital
kd0(r,s) = kd0(r,s)-fr0(r,s);

* Recursive Dynamic Parameters
parameters
	thetax(r,s)	extant production share - share of new vintage frozen
;

thetax(r,s) = %thetaxval%;
thetax(r,s)$[y_egt(s)] = 0;
thetax(r,xe) = 0;

parameters
	ktot0(r)		base year total capital (mutable + extant)
	ktotrs0(r,s)	Sector specific base year total capital (mutable + extant)
	ks_m0(r)		base year mutable capital
	ks_m(r)			mutable capital
	ksrs_m0(r,s)	base year sector specific mutable capital
	ksrs_m(r,s)		sector specific mutable capital 
	ks_x(r,s)		extant capital endowment
	ks_x0(r,s)		bmk yr extant capital endowment
;
	
ktot0(r) = sum(s,kd0(r,s));
ktotrs0(r,s) = kd0(r,s);
ks_x(r,s) = thetax(r,s) * kd0(r,s);
ks_x0(r,s) = ks_x(r,s);
ks_m0(r) = ktot0(r) - sum(s,ks_x(r,s));
ks_m(r) = ks_m0(r);
ksrs_m0(r,s) = kd0(r,s)-ks_x(r,s);
ksrs_m(r,s)= ksrs_m0(r,s);	

parameters
	newcap(r,*)		new capital service coming from investment between period update
	totalcap(r,*)	total mutable capital between period update
	newcaprs(r,s,*)		sector specific new capital service coming from investment between period update
	totalcaprs(r,s,*)	sector specific total mutable capital between period update
;

* productivity growth
parameter prodf     productivity growth factor;
prodf(yr) = 1;

loop(yr,
	prodf(yr) = (1+eta)**(yr.val-%bmkyr%);
);

parameter gprod     productivity growth no-loopyear;
gprod=1;

parameter gdpfact   gdp growth factor;
gdpfact = 1;

* declare/assign co2 parameters
parameters
	carb0(r)	co2 endowment by region
	dcb0(r,g,*)	demand for effective co2
	cb0(r)		value of carbon good output
;

dcb0(r,g,s) = secco2(r,g,s);
dcb0(r,g,"fd") = resco2(r,g);
cb0(r) = (sum((g,s), dcb0(r,g,s)) + sum(g, dcb0(r,g,"fd")));
carb0(r) = cb0(r);

*verify correct units
*Data in Mt (million tons) of co2
*--Convert to Billion tons of co2,
*----so that model carbon prices can be interpreted in $/ton co2
*---- if not co2 price interpreted in 1000 USD/Ton co2
*---- super small values create issues in exception handling mpsge no source/sink errors
*---- may be better ways to construct the cap to circumvent
* dcb0(r,g,s) = dcb0(r,g,s) * 1e-3;
* dcb0(r,g,"fd") = dcb0(r,g,"fd") * 1e-3;
* cb0(r) = cb0(r) * 1e-3;
* carb0(r) = carb0(r) * 1e-3;

parameter cco2(r,g,*)   co2 emissions coefficient for region r fuel g sector s;
cco2(r,g,s) = 0;
cco2(r,g,s)$[id0(r,g,s)] = dcb0(r,g,s)/id0(r,g,s);
cco2(r,g,"fd")$[cd0(r,g)] = dcb0(r,g,"fd")/cd0(r,g);

parameter	cd0_h_shr(r,g,h)	used to disagg emissions in final demand;
cd0_h_shr(r,g,h)$[(sum(hh,cd0_h(r,g,hh)))] = cd0_h(r,g,h)/sum(hh,cd0_h(r,g,hh));

parameter cco2_h(r,g,h)   co2 emissions coefficient for region r fuel g sector s;
cco2_h(r,g,h)$[cd0_h(r,g,h)] = dcb0(r,g,"fd")*cd0_h_shr(r,g,h)/cd0_h(r,g,h);

* co2 cap/price policy setup
parameter ss_ctax	pricing regime switch;
ss_ctax(r,s) = 1;
ss_ctax(r,"fd") = 1;

$if %ssctaxele%==0	$goto skipctaxele

ss_ctax(r,s) = 0;
ss_ctax(r,"fd") = 0;
ss_ctax(r,"ele") = 1;

$label skipctaxele


parameter co2base	base co2 emissions subject to pricing regime;
co2base(r,s) = sum(g,dcb0(r,g,s))*ss_ctax(r,s);
co2base(r,"fd") = sum(g,dcb0(r,g,"fd"))*ss_ctax(r,"fd");

parameters
	lumpsum_us	flag for federal lump sum	/0/
	lumpsum_st	flag for state lump sum		/0/
;

lumpsum_st = 1;
lumpsum_us = 0;

$if %lsusval%==0	$goto skiplsus

lumpsum_st = 0;
lumpsum_us = 1;

$label skiplsus


parameter	co2target	emissions restriction target parameter;
co2target = sum((r,sfd),co2base(r,sfd));

parameter co2tax	co2taxrate;
co2tax = 20;
* co2tax = 1;

*convert to billion usd / million ton
co2tax = co2tax/1e3;

* energy nesting benchmark parameters
parameters
	va_bar(r,*)			benchmark value-added
	fe_bar(r,*)			benchmark FE
	en_bar(r,*)			benchmark EN
	vaen_bar(r,*)		benchmark VA+EN
	ne_bar(r,*)			benchmark NE
	klem_bar(r,*)		"benchmark KLEM (VA+EN+NE)"
;

va_bar(r,s) = ld0(r,s) + kd0(r,s)*(1+tk0(r));
fe_bar(r,s) = sum(g$[fe(g)], id0(r,g,s));
en_bar(r,s) = sum(g$[en(g)], id0(r,g,s));
vaen_bar(r,s) = va_bar(r,s) + en_bar(r,s);
ne_bar(r,s) = sum(g$[nne(g)], id0(r,g,s));
klem_bar(r,s) = vaen_bar(r,s) + ne_bar(r,s);

*declare substitution elasticities
parameters
	esub_va		"substitution elasticity in VA/KL nest"
	esub_fe		FE nest
	esub_ele	EN nest
	esub_ve		"VE/KLE nest"
	esub_ne		NE nest
	esub_klem	"Y/KLEM nest"
;

esub_va(s) = 1;
esub_fe(s) = 0.5;
esub_ele(s) = 0.5;
esub_ele(s)$ele(s) = 0;
esub_ve(s) = 0.5;
esub_ne(s) = 0;
esub_klem(s) = 0;

esub_ele('fd')= 0.5;
esub_fe('fd') = 0.5;

$if %swegtval%==1 $goto skipesub
esub_ve("ele") = 2;
esub_va("ele") = 1;
$label skipesub

parameter
	es_ele_tr	esub_ele growth rate
	es_ele_tf	esub_ele growth factor
;

es_ele_tr = %eletrval%;
es_ele_tf = 1+es_ele_tr;

* Calibrate resource supply curves
parameters
	esup_xe(s)		supply elasticity to calibrate to
	esub_fr(r,s)	substitution elasticity calibrated to supply elasticity
	theta_fr(r,s)	fixed resource as a share of total costs
;

esub_fr(r,s) = 0;

* from SAGE model documentation
esup_xe(cru) = 0.15;
esup_xe(gas) = 0.5;
esup_xe(col) = 2.4;

* calculate fixed resource share of total costs
theta_fr(r,s) = 0;
theta_fr(r,s)$[klem_bar(r,s)$xe(s)] = (fr0(r,s)*(1+tk0(r))) / (klem_bar(r,s)+(fr0(r,s)*(1+tk0(r))));

* calculate implied substitution elasticity from share and supply elasticity
esub_fr(r,s)$[xe(s)] = esup_xe(s) * theta_fr(r,s)/(1-theta_fr(r,s));

parameter   fr_x0(r,s)  vintage portion fixed resource bmk year;
parameter   fr_m0(r,s)  mutable portion fixed resource bmk year;
fr_x0(r,s) = fr0(r,s)*thetax(r,s);
fr_m0(r,s) = fr0(r,s)*(1-thetax(r,s));

parameter   fr_x(r,s)  vintage portion fixed resource;
parameter   fr_m(r,s)  mutable portion fixed resource;
fr_x(r,s) = fr_x0(r,s);
fr_m(r,s) = fr_m0(r,s);

parameter   frb0(r,s,*) base year resource;
frb0(r,s,"%bmkyr%") = fr_m0(r,s) + fr_x0(r,s);


set hiak(r)	hawaii and alaska;
hiak(r) = no;

$if %rmap%=="census"	$goto skipstate1
hiak("HI") = yes;
hiak("AK") = yes;
$label skipstate1

* other exogenous forcing initialization
parameter elk(r,g,sfd)	electrificiation demand shifter;
parameter elkrate	electrificiation demand shifter rate;

elk(r,g,sfd) = 1;
elk(r,g,sfd)$[ele(g)]=1;
elkrate=%elkrateval%;

parameter aeei(r,g,sfd)	fuel efficiency demand shifter;
parameter aeeirate	fuel efficiency demand shifter rate;

aeei(r,g,sfd) = 1;
aeei(r,g,sfd)$[fe(g)]=1;
aeeirate=%aeeirateval%;

