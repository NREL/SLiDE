$stitle load in data for BAU pin

* !!!! lot of overwriting and hardcoding in this script
*------------------------------------------------------------------------
* Load ReEDS standard scenarios mid case
*------------------------------------------------------------------------

sets
	std_egt		std scen generation tech set
*	std_state	std scen region set (states)
	std_year(yr)	std scen year set
;

set std_state	states /
AK	"Alaska"
AL	"Alabama"
AR	"Arkansas"
AZ	"Arizona"
CA	"California"
CO	"Colorado"
CT	"Connecticut"
DC	"District of Columbia"
DE	"Delaware"
FL	"Florida"
GA	"Georgia"
HI	"Hawaii"
IA	"Iowa"
ID	"Idaho"
IL	"Illinois"
IN	"Indiana"
KS	"Kansas"
KY	"Kentucky"
LA	"Louisiana"
MA	"Massachusetts"
MD	"Maryland"
ME	"Maine"
MI	"Michigan"
MN	"Minnesota"
MO	"Missouri"
MS	"Mississippi"
MT	"Montana"
NC	"North Carolina"
ND	"North Dakota"
NE	"Nebraska"
NH	"New Hampshire"
NJ	"New Jersey"
NM	"New Mexico"
NV	"Nevada"
NY	"New York"
OH	"Ohio"
OK	"Oklahoma"
OR	"Oregon"
PA	"Pennsylvania"
RI	"Rhode Island"
SC	"South Carolina"
SD	"South Dakota"
TN	"Tennessee"
TX	"Texas"
UT	"Utah"
VA	"Virginia"
VT	"Vermont"
WA	"Washington"
WI	"Wisconsin"
WV	"West Virginia"
WY	"Wyoming"
/;

parameter std_scen_gen	standard scenarios generation projections for pin (TWh);

* $call msappavail -Excel
* $ifE errorLevel<>0 $abort.noError 'Microsoft Excel is not available!';

* $onecho > gdxxrw.in
* i=Generation_StdScen19_Mid_Case_annual_state.xlsx
* o=std_scen_gen.gdx
* dset std_egt   		rng=std_scen_gen!c1 cdim=1
* dset std_state   	rng=std_scen_gen!a2 rdim=1
* dset std_year   	rng=std_scen_gen!b2 rdim=1

* par  std_scen_gen    rng=std_scen_gen!a1 rdim=2 cdim=1
* $offecho
* $call gdxxrw @gdxxrw.in trace=0
* $ifE errorLevel<>0 $abort 'problems with reading from Excel'

* $gdxin std_scen_gen.gdx
* $load std_scen_gen
* $gdxin

* display std_scen_gen;

* standard scenarios generation data calculated externally
$gdxin "pin_bau_data%sep%std_scen_gen.gdx"
$load std_scen_gen
$load std_egt
$load std_year
$gdxin

parameter	std_gen_r	generation by slide regions;

* !!!! ultimately want to use a mapping file to make this easily scalable for regions without the switch
$if %rmap%=="census"	$goto	mapstdcensus
set std_map_state(std_state,r)	map model state set to state /
	AL.AL
	AK.AK
	AZ.AZ
	AR.AR
	CA.CA
	CO.CO
	CT.CT
	DE.DE
	DC.DC
	FL.FL
	GA.GA
	HI.HI
	ID.ID
	IL.IL
	IN.IN
	IA.IA
	KS.KS
	KY.KY
	LA.LA
	ME.ME
	MD.MD
	MA.MA
	MI.MI
	MN.MN
	MS.MS
	MO.MO
	MT.MT
	NE.NE
	NV.NV
	NH.NH
	NJ.NJ
	NM.NM
	NY.NY
	NC.NC
	ND.ND
	OH.OH
	OK.OK
	OR.OR
	PA.PA
	RI.RI
	SC.SC
	SD.SD
	TN.TN
	TX.TX
	UT.UT
	VT.VT
	VA.VA
	WA.WA
	WV.WV
	WI.WI
	WY.WY
/;

std_gen_r(r,std_year,std_egt) = sum(std_map_state(std_state,r),std_scen_gen(std_state,std_year,std_egt));

$goto skipmapstdcensus
$label mapstdcensus

set std_map_census(std_state,r) map model census set to state	/
	AL.ESC
	AK.PAC
	AZ.MTN
	AR.WSC
	CA.PAC
	CO.MTN
	CT.NEG
	DE.SAC
	DC.SAC
	FL.SAC
	GA.SAC
	HI.PAC
	ID.MTN
	IL.ENC
	IN.ENC
	IA.WNC
	KS.WNC
	KY.ESC
	LA.WSC
	ME.NEG
	MD.SAC
	MA.NEG
	MI.ENC
	MN.WNC
	MS.ESC
	MO.WNC
	MT.MTN
	NE.WNC
	NV.MTN
	NH.NEG
	NJ.MID
	NM.MTN
	NY.MID
	NC.SAC
	ND.WNC
	OH.ENC
	OK.WSC
	OR.PAC
	PA.MID
	RI.NEG
	SC.SAC
	SD.WNC
	TN.ESC
	TX.WSC
	UT.MTN
	VT.NEG
	VA.SAC
	WA.PAC
	WV.SAC
	WI.ENC
	WY.MTN
/;

std_gen_r(r,std_year,std_egt) = sum(std_map_census(std_state,r),std_scen_gen(std_state,std_year,std_egt));

$label skipmapstdcensus

* 2021 Standard scenarios
* map ReEDS techs to SLiDE egt set
set std_egt_map(std_egt,egt)	mapping of std scen to egt	/
biopower_ccs_MWh.conv-oth
biopower_MWh.conv-oth
coal_MWh.conv-coal
csp_MWh.vre-sol
dac_MWh.conv-oth
geothermal_MWh.conv-oth
h2-ct_MWh.conv-oth
hydro_MWh.conv-hyd
*imports_MWh.
land-based_wind_MWh.vre-wnd
ng-cc-ccs_MWh.conv-gas
ng-cc_MWh.conv-gas
ng-ct_MWh.conv-gas
nuclear_MWh.conv-nuc
offshore_wind_MWh.vre-wnd
oil-gas-steam_MWh.conv-oth
pv_battery_MWh.vre-sol
rooftop_pv_MWh.vre-sol
utility_pv_MWh.vre-sol
/;

* 2019 standard scen -  PV and battery may not be in SEDS utility sector
* set std_egt_map(std_egt,egt)	mapping of std scen to egt	/
* biomass_MWh.conv-oth
* csp_MWh.vre-sol
* coal_MWh.conv-coal
* geothermal_MWh.conv-oth
* hydro_MWh.conv-hyd
* * canada_MWh.
* wind-ons_MWh.vre-wnd
* gas-cc_MWh.conv-gas
* gas-ct_MWh.conv-gas
* nuclear_MWh.conv-nuc
* wind-ofs_MWh.vre-wnd
* o-g-s_MWh.conv-oth
* distpv_MWh.vre-sol
* battery_MWh.vre-sol
* upv_MWh.vre-sol
* /;

* Map and Store
parameter	std_scen_egt	generation by slide region and tech;
std_scen_egt(r,std_year,egt) = sum(std_egt_map(std_egt,egt),std_gen_r(r,std_year,std_egt));

* convert from mwh to twh
std_scen_egt(r,std_year,egt) = std_scen_egt(r,std_year,egt) * 1e-6;

* Only works for single year time step, because ReEDS produces 2 year steps
* Splits the two years on a linear trend
* !!!! hack for single year solves
loop(yr$[yr.val > %bmkyr%],
std_scen_egt(r,yr,egt)$[(yr.val < %endyr%)$(not std_year(yr))] = (std_scen_egt(r,yr-1,egt)+std_scen_egt(r,yr+1,egt))/2;
std_scen_egt(r,yr,egt)$[(yr.val eq %endyr%)$(not std_year(yr))] = (std_scen_egt(r,yr-1,egt));
);

* first overwrite historical years --- will smooth linear from bmkyr to 2022
std_scen_egt(r,yr,egt)$[(yr.val<2022)] = std_scen_egt(r,"2022",egt);

parameter std_scen_genshr(r,yr,egt)	share of generation by technology in a given region;
std_scen_genshr(r,yr,egt)$[(sum(egt.local,std_scen_egt(r,yr,egt)))] =
	std_scen_egt(r,yr,egt)/sum(egt.local,std_scen_egt(r,yr,egt));

parameters
	ss_shr	standard scenarios share
	ss_gen	standard scenarios generation
;

ss_gen(r,yr,egt) = std_scen_egt(r,yr,egt);
ss_shr(r,yr,egt) = std_scen_genshr(r,yr,egt);

ss_gen(r,yr,egt) = std_scen_egt(r,yr,egt);
ss_gen(r,yr,egt)$[(yr.val > 2048)$ngas(egt)] = ss_gen(r,"2048",egt);

* force historical reeds years to 2021
* ss_gen(r,yr,egt)$[(yr.val < 2021)] = ss_gen(r,"2021",egt);

parameter sstotgen;
sstotgen(yr) = sum((r,egt),ss_gen(r,yr,egt));

parameters
	ss_shr_yr(r,egt)	benchmark year parameters
	ss_gen_yr(r,egt)	benchmark year parameters
;

parameter comp_gen 	compare generation for first two years;

* establish base year slide generation for use in smoothing
loop(yr$(yr.val eq %bmkyr%),

ss_shr(r,yr,egt)$[(sum(egt.local,obar_gen0(r,egt)))] = obar_gen0(r,egt)/sum(egt.local,obar_gen0(r,egt));
ss_gen(r,yr,egt)$imp_pele0(r) = obar_gen0(r,egt)/imp_pele0(r);
ss_shr_yr(r,egt) = ss_shr(r,yr,egt);
ss_gen_yr(r,egt) = ss_gen(r,yr,egt);
comp_gen(r,egt) = ss_gen(r,yr+1,egt) - ss_gen(r,yr,egt);

);

parameter ss_pq_gen;

* Smoothing of historical years
parameter delta_ss_gen;
delta_ss_gen(r,egt) = (ss_gen(r,"2022",egt)-ss_gen(r,"2017",egt))/(2022-2017);
ss_gen(r,yr,egt)$[(yr.val < 2022)] = ss_gen(r,"%bmkyr%",egt)+delta_ss_gen(r,egt)*(yr.val-%bmkyr%);

* Smoothing of late horizon years beyond 2034
delta_ss_gen(r,egt) = 0;
delta_ss_gen(r,egt) = (ss_gen(r,"%endyr%",egt)-ss_gen(r,"2034",egt))/(%endyr%-2034);
ss_gen(r,yr,egt)$[(yr.val > 2034)] = ss_gen(r,"2034",egt)+delta_ss_gen(r,egt)*(yr.val-2034);

ss_pq_gen(r,egt) = imp_pele0(r)*ss_gen_yr(r,egt);
ss_pq_gen(r,egt) = round(ss_pq_gen(r,egt),6);

* initialize tfp_adj
parameter tfp_adj	tfp adjustment for pin;
tfp_adj(r,egt) = 1;

* exception handling for checking, not used in model
parameter nonexist_gen	nonexistent generation region techs;
nonexist_gen(r,egt,yr) = 1;
nonexist_gen(r,egt,yr)$[(ss_gen(r,yr,egt)>0)] = 0;

nonexist_gen(r,egt,"ALLReEDS") = 1;
nonexist_gen(r,egt,"ALLReEDS")$[(sum(yr$(yr.val>2021),nonexist_gen(r,egt,yr))/(%endyr%-2021)<1)] = 0;

nonexist_gen(r,egt,"ALL") = 1;
nonexist_gen(r,egt,"ALL")$[(sum(yr,nonexist_gen(r,egt,yr))/(%endyr%-%bmkyr%+1)<1)] = 0;

display nonexist_gen;

parameter mingenscale;
mingenscale(r,egt) = %mingenval%;
mingenscale(r,egt)$vgen(egt) = %mingenval%/10;

*------------------------------------------------------------------------
* depreciation tracking based on ReEDS generation changeshk
*------------------------------------------------------------------------

* track declines in coal for pinning purposes
parameters
	rate_trk	tracks rate of change
	rate_trk2	tracks rate of change alternate method
	rate_chk	check the same
	dep_trk		depreciation of fossil
	srv_trk		survival rate
;


$offorder
rate_trk2(r,egt,solveyr)$[ss_gen(r,solveyr,egt)] = (ss_gen(r,solveyr+1,egt)-ss_gen(r,solveyr,egt))/ss_gen(r,solveyr,egt);
rate_trk2(r,egt,solveyr) = rate_trk2(r,egt,solveyr-1);
$onorder

rate_trk(r,egt,t)$[ss_gen(r,t,egt)] = (ss_gen(r,t+1,egt)-ss_gen(r,t,egt))/ss_gen(r,t,egt);
rate_trk(r,egt,t) = rate_trk(r,egt,t-1);

rate_chk(r,egt,yr)$solveyr(yr) = rate_trk(r,egt,yr) - rate_trk2(r,egt,yr);

display rate_trk, rate_trk2,rate_chk;

* $exit

dep_trk(r,egt,t) = min(-0.05, max(-0.99, rate_trk(r,egt,t)));
dep_trk(r,egt,t)$(nuc(egt)) = min(0,max(-0.99, rate_trk(r,egt,t)));
dep_trk(r,egt,t)$(hyd(egt)) = min(0,max(-0.99, rate_trk(r,egt,t)));
dep_trk(r,egt,t)$(coal(egt)) = min(-0.05,max(-0.99, rate_trk(r,egt,t)));

loop(t,
dep_trk(r,egt,t)$[(dep_trk(r,egt,t-1) eq -0.99)] = -0.99;
);

srv_trk(r,egt,t)$[swvdepr] = (1+dep_trk(r,egt,t));

srv_trk(r,egt,t)$[(not swvdepr)] = srvt(t);

display rate_trk, dep_trk, srv_trk;

* $exit

*------------------------------------------------------------------------
* additional filtering for the model
*------------------------------------------------------------------------

set pin_except(r,s,egt)		exception handling for constraint pin;
set ybet_except(r,s,egt)	exception handling for backstops;
parameter chk_subsidy;

* hiak(r) = no;

pin_except(r,s,egt)$[y_egt(s)$obar_gen0(r,egt)] = yes;
pin_except(r,s,egt)$[y_egt(s)$vgen(egt)$os_bet(r,egt)] = yes;
pin_except(r,s,egt)$[hiak(r)] = no;

ybet_except(r,s,egt) = pin_except(r,s,egt);
ybet_except(r,s,egt)$[hiak(r)$obar_gen0(r,egt)] = yes;
ybet_except(r,s,egt)$[hiak(r)$os_bet(r,egt)] = yes;

parameter shr_thetaxegt;
parameter avg_thetaxegt;
parameter scale_yxegt	rescale yxegt based on thetaxegt;
parameter scale_ymegt	rescale ymegt based on thetaxegt;

scale_ymegt(s,egt)$[y_egt(s)$(not vgen(egt))] = (1-thetaxegt(s,egt))/(1-%thetaxegtval%);
scale_yxegt(s,egt)$[y_egt(s)$(not vgen(egt))$thetaxegt(s,egt)] = (thetaxegt(s,egt))/(%thetaxegtval%);

display scale_ymegt,scale_yxegt;

os_novgen(r,s)$[y_egt(s)$(sum(egt.local,obar_gen0(r,egt)))] =
	sum(egt$(not vgen(egt)),obar_gen0(r,egt)*scale_ymegt(s,egt))
	/sum(egt.local,obar_gen0(r,egt));

parameter esr_egt(egt);
esr_egt(egt) = 0;
esr_egt(egt)$coal(egt) = 0.0;


