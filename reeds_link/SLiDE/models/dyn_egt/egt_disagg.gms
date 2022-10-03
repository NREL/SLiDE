$title Disaggregation of ELE sector for technology representation

$ontext

*------------------------------------------------------------------------
* Disaggregation Notes 
*------------------------------------------------------------------------

* --- !!!! need to merge ReEDS lcoe scripts with this branch
* --- !!!! need to merge windc disagg with this branch

Order of disagg:

Generate LCOE data from ReEDS -- lcoe_raw.gdx

calc_gshr.gms
* loads in lcoe data 
* further disaggregates FOM and VOM using JEDI
* computes initial cost shares --- cshr_out.gdx

bluenote_egt2.gms
* Runs the normal bluenote disagg 
* Includes bn_egt_disagg2.gms and unloads obar_gen0 and gen_shr parameters
* This is just a normal bluenote disaggregation with a few new parameters calculated and unloaded
* in here, shares for fossil demanded in gas and coal generation are calculated so that fossil demand preserved

bluenote_egt.gms
* runs electricity disaggregation
* Includes bn_egt_disagg3.gms
**** This file determines the cost shares needed to force into rebalancing model as constraint
**** outputs new parameters for obar_gen0, ibar_gen0, fbar_gen0, and the big one cshr_r_ele_tech;
* The gdx files contain the new bluenote benchmarks with egt disaggregated

**** move the gdx files into the bmk_data directory for loading into model
readdata_hh_egt.gms
egt_disagg.gms
* Load in the shares from cshr_r_ele_tech and perform the disaggregation as preprocessing step


$offtext

* List sources for nesting structures in electricity sector
* --EPPA 4 Model Documentation: https://globalchange.mit.edu/sites/default/files/MITJPSPGC_Rpt125.pdf
* --USREP Tech Note 18: https://globalchange.mit.edu/sites/default/files/MITJPSPGC_TechNote18.pdf
* --Potential Alternative Approach: https://www.sciencedirect.com/science/article/pii/S0306261915006510
* --Phoenix model

*------------------------------------------------------------------------
* Disaggregate electricity from updated WiNDC benchmark
*------------------------------------------------------------------------

parameter	elegen(r,*,*)	seds electricity generation by source (bln kWh = TWh);

set src	seds source techs;
* WY	"wind"
* oil	"petroleum"
* so	"solar"
* nu	"nuclear"
* ge	"geothermal"
* gas	"natural gas"
* hy	"hydro"
* col	"coal"
* WD	"Wood and waste burning"

parameters
	cshr_ele_tech0_st
	cshr_ele_tech0_cen
	cshr_r_ele_tech0
;

$if %rmap%=="census"	$goto skipstate

* load the gdx data from seds from which disaggregation is based
$gdxin "%bmkdir%seds_state.gdx"
$load elegen
$load src
$gdxin

* load cost shares computed from ReEDS LCOE and JEDI
$gdxin cshr_out.gdx
$load cshr_r_ele_tech0=cshr_ele_tech0_st
$gdxin


$goto skipcensus
$label skipstate

* load the gdx data from seds from which disaggregation is based
$gdxin "%bmkdir%seds_census.gdx"
$load elegen
$load src
$gdxin

* load cost shares computed from ReEDS LCOE and JEDI
$gdxin cshr_out.gdx
$load cshr_r_ele_tech0=cshr_ele_tech0_cen
$gdxin

$label skipcensus

display elegen, src;

* * Declare new electricity generation source technologies
* set	egt		electricity generation technologies	/
* 	vre-wnd		"variable renewable wind",
* 	vre-sol		"variable renewable solar",
* 	conv-oth	"other conv"
* 	conv-gas	"conventional gas",
* 	conv-coal	"conventional coal",
* 	conv-nuc	"conventional nuclear",
* 	conv-hyd	"conventional hydro"
* 	/;

* alias(egt,eegt);

* map new technologies to seds sources
set mapsrc(egt,src)	/
	vre-wnd.WY,
	vre-sol.so,
	conv-nuc.nu,
	conv-hyd.hy,
	conv-gas.gas,
	conv-coal.col
	conv-oth.oil,
	conv-oth.ge,
	conv-oth.WD
/;

* declare additional sets for exception handling
sets
	cgen(egt)	conventional generation		/conv-gas, conv-coal, conv-nuc, conv-hyd, conv-oth/
	fgen(egt)	conventional fossil generation	/conv-gas, conv-coal/
	nfgen(egt)	conventional but not fossil generation
	nuc(egt)	nuclear generation	/conv-nuc/
	hyd(egt)	hydro generation	/conv-hyd/
;

nfgen(egt) = no;
nfgen(cgen)$[(not fgen(cgen))] = yes;

sets
	vgen(egt)	variable renewable generation	/vre-wnd, vre-sol/
	sol(egt)	solar generation	/vre-sol/
	wnd(egt)	wind generation		/vre-wnd/
	coal(egt)	coal gen	/conv-coal/
	ngas(egt)	gas gen		/conv-gas/
	othc(egt)	other gen	/conv-oth/
	nho(egt)	"nuc,hyd,oth"	/conv-oth,conv-hyd,conv-nuc/
;

* electricity production by fuel source used to share output
* Finally, windc SEDS data is available for generation by source by state

parameter	egen(r,*)	electricity generation by tech;
parameter	gen_shr(r,egt)	electricity generation share of total by region and tech;


* shares for composite production nests
parameters
	vgen_shr(r)	vre share of total
	cgen_shr(r)	cgen share of total
 	fgen_shr(r)	fgen share of cgen
;

* load in net generation data
egen(r,egt) = sum(mapsrc(egt,src),elegen(r,src,"2017"));
display egen;

* calculate output shares based on net generation
gen_shr(r,egt)$[sum(egt.local,egen(r,egt))] = egen(r,egt)/sum(egt.local,egen(r,egt));

* clear small values for fossil generation
gen_shr(r,egt)$[fgen(egt)$(gen_shr(r,egt)<0.01)] = 0.0;
egen(r,egt)$[fgen(egt)$(gen_shr(r,egt)<0.01)] = 0.0;

* recompute
gen_shr(r,egt)$[sum(egt.local,egen(r,egt))] = egen(r,egt)/sum(egt.local,egen(r,egt));

* calculate some aggregate shares
vgen_shr(r)$[sum(egt.local,egen(r,egt))] = sum(egt$[vgen(egt)], egen(r,egt))/sum(egt.local,egen(r,egt));
cgen_shr(r) = 1-vgen_shr(r);
fgen_shr(r)$[sum(cgen,egen(r,cgen))] = sum(fgen, egen(r,fgen))/sum(cgen,egen(r,cgen));

* shares for subnests
parameters
	theta_cgen(r,cgen)	cgen as a share of total cgen
	theta_vgen(r,vgen)	vgen as a share of total vgen
	theta_fgen(r,fgen)	fgen as a share of total fgen composite
;

theta_cgen(r,cgen)$[sum(cgen.local,egen(r,cgen))] = egen(r,cgen)/sum(cgen.local,egen(r,cgen));
theta_vgen(r,vgen)$[sum(vgen.local,egen(r,vgen))] = egen(r,vgen)/sum(vgen.local,egen(r,vgen));
theta_fgen(r,fgen)$[sum(fgen.local,egen(r,fgen))] = egen(r,fgen)/sum(fgen.local,egen(r,fgen));

* Cost shares need to be updated
* intermediate input cost shares
set vaf		value-added factors	/l,k,fr/;
set vafg(*)	goods and factors	/set.g, set.vaf/;
display vafg;

parameters
	cshr_r_ele_tech(r,*,egt)	cost share by tech and region
	cshr_ele_tech(*,egt)	cost share by tech
	cshr_ele_tech_yr
;

* load cost shares from windc disaggregation routine --- they are unloaded into the benchmark gdx file
$gdxin "%bmkdir%%ds%"
$load cshr_ele_tech_yr=cshr_r_ele_tech
$gdxin

cshr_r_ele_tech(r,vafg,egt) = cshr_ele_tech_yr("2017",r,vafg,egt);

cshr_r_ele_tech(r,"fr",egt)$[nuc(egt)] = cshr_r_ele_tech0(r,"fr",egt);

* set to 0.01 instead of rsccost for consistency with MRC2019 - eppa
cshr_r_ele_tech(r,"fr",egt)$[vgen(egt)] = 0.01;
cshr_r_ele_tech(r,"k",egt) = cshr_r_ele_tech(r,"k",egt)-cshr_r_ele_tech(r,"fr",egt);

* arbitrary share of capital moved to fixed resource
cshr_r_ele_tech(r,"k",egt)$[hyd(egt)] = cshr_r_ele_tech(r,"k",egt)*0.8;
cshr_r_ele_tech(r,"fr",egt)$[hyd(egt)] = cshr_ele_tech_yr("2017",r,"k",egt)*0.2;

cshr_r_ele_tech(r,"k",egt)$[othc(egt)] = cshr_r_ele_tech(r,"k",egt)*0.8;
cshr_r_ele_tech(r,"fr",egt)$[othc(egt)] = cshr_ele_tech_yr("2017",r,"k",egt)*0.2;



*------------------------------------------------------------------------
* establish tech specific inputs/outputs based on shares
*------------------------------------------------------------------------

parameters
	obar_gen0(r,egt)	output for each gen tech
	ibar_gen0(r,g,egt)	goods input for each gen tech
	fbar_gen0(r,vaf,egt)	factor input for each gen tech
;

* output
obar_gen0(r,egt) = sum((s,g)$[y_egt(s)], ys0(r,s,g))*gen_shr(r,egt);

* intermediate inputs
ibar_gen0(r,g,nfgen) = sum(s$[y_egt(s)],obar_gen0(r,nfgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,g,nfgen);
ibar_gen0(r,g,vgen)	= sum(s$[y_egt(s)],obar_gen0(r,vgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,g,vgen);

* factor inputs
fbar_gen0(r,"k",nfgen) = sum(s$[y_egt(s)],obar_gen0(r,nfgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,"k",nfgen)/(1+tk0(r));
fbar_gen0(r,"fr",nfgen) = sum(s$[y_egt(s)],obar_gen0(r,nfgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,"fr",nfgen)/(1+tk0(r));
fbar_gen0(r,"l",nfgen) = sum(s$[y_egt(s)],obar_gen0(r,nfgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,"l",nfgen);

fbar_gen0(r,"k",vgen) = sum(s$[y_egt(s)],obar_gen0(r,vgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,"k",vgen)/(1+tk0(r));
fbar_gen0(r,"fr",vgen) = sum(s$[y_egt(s)],obar_gen0(r,vgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,"fr",vgen)/(1+tk0(r));
fbar_gen0(r,"l",vgen) = sum(s$[y_egt(s)],obar_gen0(r,vgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,"l",vgen);

* output for aggregates
parameters
	obar_fgen0(r)
	obar_cgen0(r)
	obar_vgen0(r)
	obar_nfgen0(r)
	obar_ele0(r)
;

obar_fgen0(r) = sum((fgen,s)$[y_egt(s)],obar_gen0(r,fgen)*(1-ty0(r,s)));
obar_cgen0(r) = sum((cgen,s)$[y_egt(s)],obar_gen0(r,cgen)*(1-ty0(r,s)));
obar_vgen0(r) = sum((vgen,s)$[y_egt(s)],obar_gen0(r,vgen)*(1-ty0(r,s)));
obar_nfgen0(r)= sum((nfgen,s)$[y_egt(s)],obar_gen0(r,nfgen)*(1-ty0(r,s)));
obar_ele0(r) = obar_cgen0(r) + obar_vgen0(r);

parameter	chk_obar;
chk_obar(r,"ele0") = obar_ele0(r) - sum((s,g)$[y_egt(s)],ys0(r,s,g)*(1-ty0(r,s)));
display chk_obar;

* more aggregates
parameters
	ibar_fossil(r,g)
	fbar_fossil(r,vaf)
;	

ibar_fossil(r,g) = sum(s$y_egt(s),id0(r,g,s)) - sum(nfgen,ibar_gen0(r,g,nfgen)) - sum(vgen,ibar_gen0(r,g,vgen));
fbar_fossil(r,"k") = sum(s$y_egt(s),kd0(r,s)) - sum(nfgen,fbar_gen0(r,"k",nfgen)) - sum(vgen,fbar_gen0(r,"k",vgen));
fbar_fossil(r,"l") = sum(s$y_egt(s),ld0(r,s)) - sum(nfgen,fbar_gen0(r,"l",nfgen)) - sum(vgen,fbar_gen0(r,"l",vgen));

* adjust remaining fossil fuel portion
ibar_gen0(r,g,fgen)	= sum(s$[y_egt(s)],obar_gen0(r,fgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,g,fgen);
fbar_gen0(r,"k",fgen) = sum(s$[y_egt(s)],obar_gen0(r,fgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,"k",fgen)/(1+tk0(r));
fbar_gen0(r,"fr",fgen) = sum(s$[y_egt(s)],obar_gen0(r,fgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,"fr",fgen)/(1+tk0(r));
fbar_gen0(r,"l",fgen) = sum(s$[y_egt(s)],obar_gen0(r,fgen)*(1-ty0(r,s)))*cshr_r_ele_tech(r,"l",fgen);

* value-added calculation for production block
parameter	va_tot(r,egt);
va_tot(r,egt) = fbar_gen0(r,"l",egt) + fbar_gen0(r,"k",egt)*(1+tk0(r));

* check that profits are zero
parameter	chk_bal;
chk_bal(r,egt) = sum(s$y_egt(s),obar_gen0(r,egt)*(1-ty0(r,s))) - (sum(g,ibar_gen0(r,g,egt)) + fbar_gen0(r,"l",egt) + (fbar_gen0(r,"k",egt)+fbar_gen0(r,"fr",egt))*(1+tk0(r)));
display chk_bal;

* check that emissions are preserved
parameter chk_emit;
chk_emit(r,g,egt)$[(sum(eegt,ibar_gen0(r,g,eegt)))] = dcb0(r,g,"ele")*ibar_gen0(r,g,egt)/sum(eegt,ibar_gen0(r,g,eegt));
chk_emit(r,g,"tot") = sum(egt,chk_emit(r,g,egt));
chk_emit(r,g,"bal") = sum(egt,chk_emit(r,g,egt))-dcb0(r,g,"ele");

* output share for non-vgen techs
parameter os_novgen;
os_novgen(r,s)$[(sum(egt.local,obar_gen0(r,egt)))] = sum(egt$(not vgen(egt)),obar_gen0(r,egt))/sum(egt.local,obar_gen0(r,egt));
display os_novgen;

* implied electricity price by region given SEDS generation data
* used in pin
* !!!! could possibly infer transmission and distribution costs from electricity price (wholesale vs retail)
parameter 	imp_pele0(r)	implied electricity price by region billion USD per MWh;
imp_pele0(r)$[(sum(egt,egen(r,egt)))] = sum(egt,obar_gen0(r,egt))/sum(egt,egen(r,egt));

display imp_pele0, egen, obar_gen0;

*------------------------------------------------------------------------
* Putty-Clay capital updates for electricity (EGT)
*------------------------------------------------------------------------

* update capital stock for fixed resource and extant capital

parameter 	ksxegt(r,s,egt) extant egt capital stock;
parameter 	ksxegt0(r,s,egt) bmkyr extant egt capital stock;
parameter 	frxegt(r,s,egt)	extant egt resource stock;
parameter 	frxegt0(r,s,egt)	bmkyr extant egt resource stock;
parameter 	frmegt(r,s,egt)	mutable egt resource stock;
parameter	thetaxegt(s,egt)	extant share for egt;


* remove fixed resource
* ksrs_m0(r,s)$[y_egt(s)] = ksrs_m0(r,s) - sum(egt, fbar_gen0(r,"fr",egt));
ksrs_m0(r,s)$[y_egt(s)] = ksrs_m0(r,s) - sum(egt, fbar_gen0(r,"fr",egt));

* no extant capital for renewables (for now)
thetaxegt(s,egt)$[y_egt(s)$vgen(egt)] = %thetaxegtval%;

* extant conventional capital set to relatively high value
thetaxegt(s,egt)$[y_egt(s)$(not vgen(egt))] = %thetaxegtval%;

thetaxegt(s,egt)$[y_egt(s)$coal(egt)$swvext] = 0.99;
thetaxegt(s,egt)$[y_egt(s)$nuc(egt)$swvext] = 0.95;
thetaxegt(s,egt)$[y_egt(s)$hyd(egt)$swvext] = 0.95;

* disaggregate fixed resource
frxegt(r,s,egt) = 0;
frxegt0(r,s,egt)$[y_egt(s)] = frxegt(r,s,egt);
frmegt(r,s,egt)$[y_egt(s)] = fbar_gen0(r,"fr",egt);

* disaggregate and rebalance extant capital stock
ksxegt(r,s,egt)$[y_egt(s)] = fbar_gen0(r,"k",egt)*(thetaxegt(s,egt));
ksxegt0(r,s,egt)$[y_egt(s)] = ksxegt(r,s,egt);

* rebalance mutable capital stock
ksrs_m0(r,s)$[y_egt(s)] = ksrs_m0(r,s)-sum(egt,ksxegt(r,s,egt));
ksrs_m(r,s)$[y_egt(s)] = ksrs_m0(r,s);

ks_m0(r) = sum(s,ksrs_m0(r,s));
ks_m(r) = ks_m0(r);

* update total capital stock
ktot0(r) = ks_m0(r)+sum(s,ks_x(r,s))+sum((s,egt)$[y_egt(s)],ksxegt(r,s,egt));


*------------------------------------------------------------------------
* Policy initialization
*------------------------------------------------------------------------

* !!!! subsidy included here because we have egt set declared
parameter subegt(r,s,egt)	electricity sector vgen subsidy;
parameter subegtyr(r,s,egt,yr)	tracking yr subsidy;
parameter subxegt(r,s,egt);
parameter subrate;

* initially set to 0
subegt(r,s,egt)=0;
subxegt(r,s,egt) = 0;
subrate = 0.15;

* set time horizon for active subsidy
parameter subyrstart	start of subsidy;
parameter subyrend		end of subsidy;
parameter subterm		term of subsidy;

subyrstart=2023;
subyrend=2035;
subterm = 10;

subegtyr(r,s,egt,yr)$[(yr.val ge subyrstart)] = -subrate;
subegtyr(r,s,egt,yr)$[(yr.val > subyrend)] = 0.0;

* capital input subsidy for renewables
parameter	subkbetrate		capital subsidy rate;
parameter	subkbet		capital subsidy by tech;
parameter 	subkbet		capital subsidy tracking;
parameter	subkterm	subsidy term (approximate to asset lifetime);
subkbetrate = 0.15;
subkterm = 20;


*------------------------------------------------------------------------
* CO2 emissions coefficients for electricity techs
*------------------------------------------------------------------------
parameters
	dcb0egt(r,g,s,egt)	co2 emissions demand from electricity techs
	cco2egt	co2 emissions coefficient for electricity generation techs
;

dcb0egt(r,g,s,egt)$[y_egt(s)$(sum(egt.local,ibar_gen0(r,g,egt)))] =
	(dcb0(r,g,s)*ibar_gen0(r,g,egt)/sum(egt.local,ibar_gen0(r,g,egt)));

cco2egt(r,g,s,egt)$[y_egt(s)$ibar_gen0(r,g,egt)] = dcb0egt(r,g,s,egt) / ibar_gen0(r,g,egt);

