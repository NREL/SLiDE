"""
This function prepares SEDS energy data for the EEM.

# Returns
- `d::Dict` of EIA data from the SLiDE input files,
    with the addition of the following data sets describing:
    1. Electricity - [`eem_elegen!`](@ref)
    1. Energy - [`eem_energy!`](@ref)
    3. CO2 Emissions - [`eem_co2emis!`](@ref)
"""
function eem(dataset::String)

    # !!!! will probably rename such preparing the energy input is a sub-feature of the
    # module as a whole -- this feels similar to partitioning the supply/use data?
    f_data = joinpath(SLIDE_DIR,"data")
    f_read = joinpath(SLIDE_DIR,"src","build","readfiles")

    set = merge(
        read_from(joinpath(f_read,"setlist.yml")),
        Dict(k=>df[:,1] for (k,df) in read_from(joinpath(f_data,"coresets","eem"))),
        # !!!! define energy sets in yaml so we can specify that this is a set input.
    )

    maps = read_from(joinpath(f_read,"maplist.yml"))

    d = read_from(joinpath(f_data,"input","eia"))
    [d[k] = extrapolate_year(df, (yr=set[:yr],)) for (k,df) in d]
    
    eem_elegen!(d, maps)
    eem_energy!(d, set, maps)
    eem_co2emis!(d, set, maps)

    return d, set, maps
end