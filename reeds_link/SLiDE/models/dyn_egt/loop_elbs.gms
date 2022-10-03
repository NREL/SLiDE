* ++++++++++
* loop_elbs.gms
* ++++++++++
* technology specific factor updates

q_elbs(r,s,t-1)$[elbs_act(r,s)] = eps + Y_ELBS.l(r,s)*sum(g,elbs_out(r,s,g));

elTSF(r,s,t)$[elbs_act(r,s)$(t.val eq %bmkyr%)] =
	elTSF(r,s,t-1)*((1-delta)**tstep(t))
	+ elbs_in(r,"tsf",s)*elbs_mkup(r,s)*(q_elbs(r,s,t-1))
;

elTSF(r,s,t)$[elbs_act(r,s)$(t.val > %bmkyr%)] =
	elTSF(r,s,t-1)*((1-delta)**tstep(t))
	+ elbs_in(r,"tsf",s)*elbs_mkup(r,s)*(q_elbs(r,s,t-1) - q_elbs(r,s,t-2)*((1-delta)**tstep(t)))
;

elTSF(r,s,t)$[elbs_act(r,s)] = max(1e-6,elTSF(r,s,t));
elbse(r,s)$[elbs_act(r,s)] = elTSF(r,s,t);

