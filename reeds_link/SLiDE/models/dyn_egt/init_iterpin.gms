$stitle iterative pinning algorithm initial declarations

set	iter	number of iterations in algorithm	/1*%iternum%/;
set iterf(iter)	first iteration;
set iterl(iter)	last iteration;

alias(iter,iiter);

iterf(iter) = yes$(ord(iter) eq 1);
iterl(iter) = yes$(ord(iter) eq card(iter));

parameter	adjstep(r,egt)	adjustment step;
adjstep(r,egt) = %adjstepval%;

parameters
	iter_adj		tfp cost adjustment factor for pin
	iter_adj_yr		annual storage of tfp cost adjustment by iteration
	iterpin_adj_yr	annual storage of tfp cost adjustment final iteration
	iter_comp		iterative comparison of target vs model that converges to 1
	iter_store		store target and model values for comparison
;

iter_adj(r,egt) = 1;
iter_adj_yr(r,egt,yr,iter) = iter_adj(r,egt);
iterpin_adj_yr(r,egt,yr) = iter_adj(r,egt);


iter_store(r,egt,"TARGET") = 1;
iter_store(r,egt,"MODEL") = 1;

iter_store(r,egt,"TARGET") = ss_pq_gen(r,egt);
iter_store(r,egt,"MODEL") = ss_pq_gen(r,egt);

iter_comp(r,egt,yr,iter)$iter_store(r,egt,"TARGET") =
	iter_store(r,egt,"MODEL")/iter_store(r,egt,"TARGET");

* if model exceeds target, increase costs to reduce output
*iter_adj_yr(r,egt,yr,iter) = iter_adj(r,egt)*iter_comp(r,egt,yr,iter);
*iter_adj(r,egt) = iter_adj(r,egt)*iter_comp(r,egt,yr,iter);



