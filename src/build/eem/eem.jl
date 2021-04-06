"""
This function prepares SEDS energy data for the EEM.

# Returns
- `d::Dict` of EIA data from the SLiDE input files,
    with the addition of the following data sets describing:
    1. Electricity - [`eem_elegen!`](@ref)
    1. Energy - [`eem_energy!`](@ref)
    3. CO2 Emissions - [`eem_co2emis!`](@ref)
"""
function partition_eem(dataset::Dataset, d::Dict, set::Dict)
    set!(dataset; build="eem", step="partition")
    maps = SLiDE.read_map()

    d_read = SLiDE.read_input!(dataset)

    if dataset.step=="input"
        [d_read[k] = extrapolate_year(df, (yr=set[:yr],)) for (k,df) in d_read]
        merge!(d, d_read)

        SLiDE.partition_elegen!(d, maps)
        SLiDE.partition_energy!(d, set, maps)
        SLiDE.partition_co2emis!(d, set, maps)

        d[:convfac] = _module_convfac(d)
        d[:cprice] = _module_cprice!(d, maps)
        d[:prodbtu] = _module_prodbtu!(d, set)
        d[:pedef] = _module_pedef!(d, set)
        d[:pe0] = _module_pe0!(d, set)
        d[:ps0] = _module_ps0!(d)
        d[:prodval] = _module_prodval!(d, set, maps)
        d[:shrgas] = _module_shrgas!(d)
        d[:netgen] = _module_netgen!(d)
        d[:trdele] = _module_trdele!(d)
        d[:pctgen] = _module_pctgen!(d, set)
        d[:eq0] = _module_eq0!(d, set)
        d[:ed0] = _module_ed0!(d, set, maps)
        d[:emarg0] = _module_emarg0!(d, set, maps)
        d[:ned0] = _module_ned0!(d)
    else
        merge!(d, d_read)
    end
        
    return d, set, maps
end


