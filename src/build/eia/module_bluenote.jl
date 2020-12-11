"""
"""
function _module_convfac(d::Dict)
    return filter_with(d[:seds], (src="cru", sec="supply", units=BTU_PER_BARREL); drop=true)
end


"""
"""
function _module_cprice(d::Dict, maps::Dict)
    df = convertjoin(d[:crude_oil], _module_convfac(d); id=[:cru,:convfac])
    return operate_with(df, maps[:operate])
end


"""
"""
function _module_prodbtu(d::Dict)
    return filter_with(d[:seds], (src=["cru","gas"], sec="supply", units=BTU); drop=true)
end