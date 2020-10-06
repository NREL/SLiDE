chk = copy(io)
[chk[k] = edit_with(copy(chk[k]), Rename(:value, k)) for k in [:supply, :use]]

#   interm(yr,j(jc_use),"use") = use(yr,"interm",jc_use);
#   basicva(yr,j(jc_use),"use") = use(yr,"basicvalueadded",jc_use);
#   valueadded(yr,j(jc_use),"use") = use(yr,"valueadded",jc_use);
#   output(yr,j(jc_use),"use") = use(yr,"industryoutput",jc_use);
#   totint(yr,i(ir_use),"use") = use(yr,ir_use,"totint");
#   totaluse(yr,i(ir_use),"use") = use(yr,ir_use,"totaluse");
chk[:interm]     = chk[:use] |> @filter(.&(_.i == "interm",          _.j in set[:j]))    |> DataFrame
chk[:basicva]    = chk[:use] |> @filter(.&(_.i == "basicvalueadded", _.j in set[:j]))    |> DataFrame
chk[:valueadded] = chk[:use] |> @filter(.&(_.i == "valueadded",      _.j in set[:j]))    |> DataFrame
chk[:output]     = chk[:use] |> @filter(.&(_.i == "industryoutput",  _.j in set[:j]))    |> DataFrame
chk[:totint]     = chk[:use] |> @filter(.&(_.i in set[:i],           _.j == "totint"))   |> DataFrame
chk[:totaluse]   = chk[:use] |> @filter(.&(_.i in set[:i],           _.j == "totaluse")) |> DataFrame

#   basicsupply(yr,i(ir_supply),'supply') = supply(yr,ir_supply,"BasicSupply");
#   tsupply(yr,i(ir_supply),'supply') = supply(yr,ir_supply,"Supply");
chk[:basicsupply] = chk[:supply] |> @filter(.&(_.i in set[:i], _.j == "basicsupply")) |> DataFrame
chk[:tsupply]     = chk[:supply] |> @filter(.&(_.i in set[:i], _.j == "supply"))      |> DataFrame

# Total intermediate inputs (purchasers' prices)
#   interm(yr,j,'id0') = sum(i,id0(yr,i,j));
#   interm(yr,j,"chk") = interm(yr,j,'id0') - interm(yr,j,"use");
chk[:interm][!, :id0] .= sum_over(chk[:id0], :i)
chk[:interm][!, :chk] .= chk[:interm][!, :id0] - chk[:interm][!, :use]

# Basic value added (purchasers' prices)
#   basicva(yr,j,"va0") = sum(va,va0(yr,va,j));
#   basicva(yr,j,"chk") = basicva(yr,j,"use") - basicva(yr,j,"va0");
chk[:basicva][!, :va0] .= sum_over(chk[:va0], :va)
chk[:basicva][!, :chk] .= chk[:basicva][!, :use] - chk[:basicva][!, :va0]

# Value added (purchaser's prices)
#   valueadded(yr,j,"va0+ts0") = sum(va,va0(yr,va,j)) + ts0(yr,"taxes",j) - ts0(yr,"subsidies",j);
#   valueadded(yr,j,"chk") = valueadded(yr,j,"use") - valueadded(yr,j,"va0+ts0");
chk[:valueadded][!, :va0_ts0] .= 
    sum_over(chk[:va0], :va) +
    chk[:ts0][chk[:ts0][:,:i] .== "taxes", :value] -
    chk[:ts0][chk[:ts0][:,:i] .== "subsidies", :value]
chk[:valueadded][!, :chk] .= chk[:valueadded][!, :use] - chk[:valueadded][!, :va0_ts0]

# Check on total taxes
#   taxtotal(yr,"ts_subsidies") = sum(j, ts0(yr,"subsidies",j));
#   taxtotal(yr,"ts_taxes") = sum(j, ts0(yr,"taxes",j));
#   taxtotal(yr,"s0") = sum(i,sbd0(yr,i));
#   taxtotal(yr,"t0+duty") = sum(i,tax0(yr,i)+duty0(yr,i));
chk[:taxtotal] = DataFrame(yr = set[:yr])
chk[:taxtotal][!, :ts_subsidies] .= sum_over(chk[:ts0][chk[:ts0][:,:i] .== "subsidies", :], :j)
chk[:taxtotal][!, :ts_taxes] .= sum_over(chk[:ts0][chk[:ts0][:,:i] .== "taxes", :], :j)
chk[:taxtotal][!, :s0] .= sum_over(chk[:sbd0], :i)
chk[:taxtotal][!, :t0_duty] .= sum_over(chk[:tax0], :i) + sum_over(chk[:duty0], :i)

# Total industry output (basic prices)
#   output(yr,j,"id0+va0") = sum(va,va0(yr,va,j)) + sum(i,id0(yr,i,j));
#   output(yr,j,'ys0') = sum(i,ys0(yr,j,i));
#   output(yr,j,"chk") = output(yr,j,"id0+va0") - output(yr,j,"use");
#   output(yr,j,"chk-ys0") = output(yr,j,"id0+va0") - output(yr,j,'ys0');
chk[:output][!, :id0_va0] .= sum_over(chk[:va0], :va) + sum_over(chk[:id0], :i)
chk[:output][!, :ys0]     .= sum_over(chk[:ys0], :i)
chk[:output][!, :chk]     .= chk[:output][:, :id0_va0] - chk[:output][:, :use]
chk[:output][!, :chk_ys0] .= chk[:output][:, :id0_va0] - chk[:output][:, :ys0]

# Total intermediate use (purchasers' prices)
#   totint(yr,i,'id0') = sum(j,id0(yr,i,j));
#   totint(yr,i,"chk") = totint(yr,i,"use") - totint(yr,i,'id0');
chk[:totint][!, :id0] .= sum_over(chk[:id0], :j)
chk[:totint][!, :chk] .= chk[:totint][:, :use] - chk[:totint][:, :id0]

# Total use of commodities (purchasers' prices)
#   totaluse(yr,i,"id0+fd0") = sum(j,id0(yr,i,j)) + sum(fd,fd0(yr,i,fd)) + x0(yr,i);
#   totaluse(yr,i,"chk") = totaluse(yr,i,"use") - totaluse(yr,i,"id0+fd0");
chk[:totaluse][!, :id0_fd0] .= sum_over(chk[:id0], :j) + sum_over(chk[:fd0], :fd) + chk[:x0][:,:value]
chk[:totaluse][!, :chk]     .= chk[:totaluse][:, :use] - chk[:totaluse][:, :id0_fd0]

# Basic supply
#   basicsupply(yr,i,'ys0') = sum(j,ys0(yr,j,i));
#   basicsupply(yr,i,"chk") = basicsupply(yr,i,'supply') - basicsupply(yr,i,'ys0');
chk[:basicsupply][!, :ys0] .= sum_over(chk[:ys0], :j)
chk[:basicsupply][!, :chk] .= chk[:basicsupply][:, :supply] - chk[:basicsupply][:, :ys0]

# Total supply
#   tsupply(yr,i,"ys0+...") = sum(j,ys0(yr,j,i)) + m0(yr,i) + mrg0(yr,i) +
#       trn0(yr,i) + duty0(yr,i) + tax0(yr,i) - sbd0(yr,i);
#   tsupply(yr,i,"totaluse") = sum(j,id0(yr,i,j)) + sum(fd,fd0(yr,i,fd)) + x0(yr,i);
#   tsupply(yr,i,"chk") = tsupply(yr,i,'supply') - tsupply(yr,i,"totaluse");
#   tsupply(yr,i,"supply-use") = tsupply(yr,i,"ys0+...") - tsupply(yr,i,"totaluse");
chk[:tsupply][!, :ys0_etc] .= sum_over(chk[:ys0], :j) + chk[:m0][:,:value] + chk[:mrg0][:,:value] +
    chk[:trn0][:,:value] + chk[:duty0][:,:value] + chk[:tax0][:,:value] - chk[:sbd0][:,:value]
chk[:tsupply][!, :totaluse] .= sum_over(chk[:id0], :j) + sum_over(chk[:fd0], :fd) + chk[:x0][:,:value]
chk[:tsupply][!, :chk]        .= chk[:tsupply][:, :supply] - chk[:tsupply][:, :totaluse]
chk[:tsupply][!, :supply_use] .= chk[:tsupply][:, :ys0_etc] - chk[:tsupply][:, :totaluse]

# Check on accounting identities.
#   details(yr,i,"y0") = y0(yr,i);
#   details(yr,i,"m0") = m0(yr,i) + duty0(yr,i);
#   details(yr,i,"mrg+trn") = mrg0(yr,i) + trn0(yr,i);
#   details(yr,i,"tax-sbd") = tax0(yr,i)-sbd0(yr,i);
#   details(yr,i,'id0') = sum(j, id0(yr,i,j));
#   details(yr,i,"fd0") = sum(fd,fd0(yr,i,fd));
#   details(yr,i,"x0") = x0(yr,i);
#   details(yr,i,"balance") = y0(yr,i)+m0(yr,i)+duty0(yr,i) + tax0(yr,i)-sbd0(yr,i)
#       - sum(j, id0(yr,i,j)) - sum(fd,fd0(yr,i,fd)) - x0(yr,i)
# 		+ (mrg0(yr,i) + trn0(yr,i));
chk[:details] = DataFrame(permute((yr = set[:yr], i = set[:i])))
chk[:details][!,:y0] .= chk[:y0][:,:value]
chk[:details][!,:m0] .= chk[:m0][:,:value] + chk[:duty0][:,:value]
chk[:details][!,:mrg_trn] .= chk[:mrg0][:,:value] + chk[:trn0][:,:value]
chk[:details][!,:tax_sbd] .= chk[:tax0][:,:value] - chk[:sbd0][:,:value]
chk[:details][!,:id0] .= sum_over(chk[:id0], :j)
chk[:details][!,:fd0] .= sum_over(chk[:fd0], :fd)
chk[:details][!,:x0]  .= chk[:x0][:,:value]
chk[:details][!,:balance] .= 
    chk[:y0][:,:value] + chk[:m0][:,:value] + chk[:duty0][:,:value] + chk[:tax0][:,:value] - chk[:sbd0][:,:value] -
    sum_over(chk[:id0], :j) - sum_over(chk[:fd0], :fd) - chk[:x0][:,:value] +
    chk[:mrg0][:,:value] + chk[:trn0][:,:value];

# Report of margin producing sectors.
    # imrginfo(yr,"a0",imrg) = a0(yr,imrg);
    # imrginfo(yr,"tax0",imrg) = tax0(yr,imrg);
    # imrginfo(yr,"sbd0",imrg) = sbd0(yr,imrg);
    # imrginfo(yr,"y0",imrg) = y0(yr,imrg);
    # imrginfo(yr,"x0",imrg) = x0(yr,imrg);
    # imrginfo(yr,"m0",imrg) = m0(yr,imrg);
    # imrginfo(yr,"duty0",imrg) = duty0(yr,imrg);
    # imrginfo(yr,m,imrg) = md0(yr,m,imrg);
chk[:imrg] = fill_zero((yr = set[:yr],))

# Only keep keys unique to the "chk" Dictionary.
chk = Dict(k => chk[k] for k in setdiff(keys(chk), keys(io)))