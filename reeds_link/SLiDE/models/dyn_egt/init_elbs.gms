$stitle create electrification backstops

* ++++++++++
* load_elbs.gms
* ++++++++++
* declare backstop tech sets and parameters
* cost share calculations
* remove fossil and sub that share for electricity
* add markup factor
* initialize TSF

scalar swelbs	electrification backstop switch	/%swelbsval%/;

set elbs  backstop tech   /
    elbs_gas   "backstop for gas",
    elbs_oil    "backstop for refined oil",
	elbs_col	"backstop tech for coal",
	elbs_cru	"crude oil backstop",
	elbs_trn	"transportation backstop",
	elbs_eint	"energy intensive backstop"
	elbs_omnf	"other mfg backstop"
	elbs_con
	elbs_osrv
	elbs_roe
/;

sets
    elbs_gas(elbs)  gas backstop            /elbs_gas/
    elbs_oil(elbs)  refined oil backstop    /elbs_oil/
	elbs_col(elbs)	col backstop			/elbs_col/
	elbs_cru(elbs)	cru backstop			/elbs_cru/
	elbs_trn(elbs)	trn backstop			/elbs_trn/
	elbs_eint(elbs) eint backstop			/elbs_eint/
	elbs_omnf(elbs)	omnf backstop			/elbs_omnf/
	elbs_con(elbs)	con backstop			/elbs_con/
	elbs_osrv(elbs)	osrv backstop			/elbs_osrv/
	elbs_roe(elbs)	roe backstp				/elbs_roe/
;

set mapelbs(elbs,s)	mapping of elbs to sector	/
    elbs_gas.gas
    elbs_oil.oil
	elbs_col.col
	elbs_cru.cru
	elbs_trn.trn
	elbs_eint.eint
	elbs_omnf.omnf
	elbs_con.con
	elbs_osrv.osrv
	elbs_roe.roe
/;

parameter	elbs_act(r,s)	active or inactive;
elbs_act(r,s) = no;

* activate
elbs_act(r,s)$[(sum(mapelbs(elbs,s),elbs_trn(elbs)))$swelbs] = yes;
elbs_act(r,s)$[(sum(mapelbs(elbs,s),elbs_eint(elbs)))$swelbs] = yes;
elbs_act(r,s)$[(sum(mapelbs(elbs,s),elbs_con(elbs)))$swelbs] = yes;
elbs_act(r,s)$[(sum(mapelbs(elbs,s),elbs_omnf(elbs)))$swelbs] = yes;
elbs_act(r,s)$[(sum(mapelbs(elbs,s),elbs_roe(elbs)))$swelbs] = yes;
* elbs_act(r,s)$[(sum(mapelbs(elbs,s),elbs_eint(elbs)))$swelbs] = yes;
* elbs_act(r,s)$[(sum(mapelbs(elbs,s),elbs_eint(elbs)))$swelbs] = yes;



parameters
	cval_bs		benchmark cost
	cval_bs0		benchmark year cost
	cshr_bs		benchmark cost share
	cshr_bs0	benchmark year cost share
	oshr_bs		benchmark output share
	oshr_bs0	benchmark year output share
	chk_cbal	check balance
;

alias(xx,*);

* store benchmark cost shares
cval_bs0(r,"k",s) = (kd0(r,s)*(1+tk0(r)));
cval_bs0(r,"l",s) = ld0(r,s);
cval_bs0(r,"fr",s) = fr0(r,s)*(1+tk0(r));
cval_bs0(r,g,s) = id0(r,g,s);
cval_bs0(r,"total",s) = sum(xx,cval_bs0(r,xx,s));

cshr_bs0(r,"k",s)$[cval_bs0(r,"total",s)] = cval_bs0(r,"k",s)/cval_bs0(r,"total",s);
cshr_bs0(r,"l",s)$[cval_bs0(r,"total",s)] = cval_bs0(r,"l",s)/cval_bs0(r,"total",s);
cshr_bs0(r,"fr",s)$[cval_bs0(r,"total",s)] = cval_bs0(r,"fr",s)/cval_bs0(r,"total",s);
cshr_bs0(r,g,s)$[cval_bs0(r,"total",s)] = cval_bs0(r,g,s)/cval_bs0(r,"total",s);
cshr_bs0(r,"total",s) = sum(xx,cshr_bs0(r,xx,s));

oshr_bs0(r,s,g)$[(sum(g.local,ys0(r,s,g)))] = ys0(r,s,g)/sum(g.local,ys0(r,s,g));

* check balance
chk_cbal(r,s) = sum(g,ys0(r,s,g))*(1-ty0(r,s)) - cval_bs0(r,"total",s);

* remove fossil from backstop and add to electricity
cval_bs(r,"k",s) = cval_bs0(r,"k",s);
cval_bs(r,"l",s) = cval_bs0(r,"l",s);
cval_bs(r,"fr",s) = cval_bs0(r,"fr",s);
cval_bs(r,g,s) = cval_bs0(r,g,s);

* rebalance - no crude for now
cval_bs(r,g,s)$[fe(g)] = 0;
cval_bs(r,g,s)$[ele(g)] = cval_bs0(r,g,s)+sum(fe,cval_bs0(r,fe,s));

cval_bs(r,"total",s) = sum(xx,cval_bs(r,xx,s));

* store updated cost shares
cshr_bs(r,"k",s)$[cval_bs(r,"total",s)] = cval_bs(r,"k",s)/cval_bs(r,"total",s);
cshr_bs(r,"l",s)$[cval_bs(r,"total",s)] = cval_bs(r,"l",s)/cval_bs(r,"total",s);
cshr_bs(r,"fr",s)$[cval_bs(r,"total",s)] = cval_bs(r,"fr",s)/cval_bs(r,"total",s);
cshr_bs(r,g,s)$[cval_bs(r,"total",s)] = cval_bs(r,g,s)/cval_bs(r,"total",s);
cshr_bs(r,"total",s) = sum(xx,cshr_bs(r,xx,s));

oshr_bs(r,s,g) = oshr_bs0(r,s,g);

parameters
	elbs_in		backstop input
	elbs_out	backstop output
	chk_elbs_bal	check balance
;

elbs_out(r,s,g)$[elbs_act(r,s)] = oshr_bs(r,s,g)/(1-ty0(r,s));
* elbs_out(r,elbs,g)$[elbs_act(r,elbs)] = sum(mapelbs(elbs,s),oshr_bs(r,s,g));
* elbs_out(r,"elbs_eint",g) = oshr_bs(r,"eint",g);

elbs_in(r,"k",s)$[elbs_act(r,s)] = cshr_bs(r,"k",s)/(1+tk0(r));
elbs_in(r,"l",s)$[elbs_act(r,s)] = cshr_bs(r,"l",s);
elbs_in(r,"fr",s)$[elbs_act(r,s)] = cshr_bs(r,"fr",s)/(1+tk0(r));
elbs_in(r,g,s)$[elbs_act(r,s)] = cshr_bs(r,g,s);

chk_elbs_bal(r,s) = sum(g,elbs_out(r,s,g))*(1-ty0(r,s))
	- elbs_in(r,"k",s)*(1+tk0(r))
	- elbs_in(r,"l",s)
	- elbs_in(r,"fr",s)*(1+tk0(r))
	- sum(g,elbs_in(r,g,s))
;

* add technology specific factor and rebalance
* !!!! could readjust capital tax rate in future, not going to mess with it for now
elbs_in(r,"tsf",s)$[elbs_act(r,s)] = 0.01;
elbs_in(r,"k",s)$[elbs_act(r,s)] = elbs_in(r,"k",s)-elbs_in(r,"tsf",s);

* add back in "fr" for now as well - since no backstop on resource extraction sectors
elbs_in(r,"k",s)$[elbs_act(r,s)] = elbs_in(r,"k",s) + elbs_in(r,"fr",s);

display cval_bs0, cshr_bs0, chk_cbal, elbs_out, chk_elbs_bal;

parameters
	elbs_mkup	markup factor
	elbs_techrate	technology improvement rate
	elbs_techadj	technology improvment adjustment factor
;

elbs_mkup(r,s)$[elbs_act(r,s)] = 1.2;

elbs_techrate(r,s)$[elbs_act(r,s)] = 0.01;
elbs_techadj(r,s)$[elbs_act(r,s)]  = 1;

* set tsf substitution elasticity here
* !!!! Can be calibrated to supply elasticity - implies ~30
parameter	es_elbs	subsitution elasticity with fixed factor;
es_elbs(r,s) = 0.30;

* initialize technology specific factor resource endowment
parameters
	elbse0	base year backstop resource endowment
	elbse	backstop resource endowment
	elTSF0	base year backstop tech specific factor supply
	elTSF	backstop tech specific factor supply
	q_elbs	backstop quantity produced
;


loop(yr$(yr.val eq %bmkyr%),

elTSF0(r,s,yr)$[elbs_act(r,s)] = 1e-6;
elTSF(r,s,yr) = elTSF0(r,s,yr);

elbse0(r,s)$[elbs_act(r,s)] = elTSF(r,s,yr);
elbse(r,s) = elbse0(r,s);

);

