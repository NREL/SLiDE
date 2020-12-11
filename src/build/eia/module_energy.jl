"""
"""
function module_energy!(d::Dict, set::Dict, maps::Dict)
    df = copy(d[:seds])
    df = filter_with(df, (src=set[:e], sec=set[:ed],))
    df = indexjoin(df, maps[:units_base]; kind=:inner)

    df_elegen = _module_energy_supply(d)
    df = _module_energy_ref(df)
    df = _module_energy_ind(df)
    df = _module_energy_price(df, maps)

    df = [df[:,propertynames(df_elegen)]; df_elegen]
    d[:energy] = indexjoin(df, maps[:pq]; kind=:inner)
    return d[:energy]
end


"""
"""
function _module_energy_supply(d::Dict)
    # !!!! Do something with sets to select.
    idx = DataFrame(src="ele", sec="supply")
    df = combine_over(d[:elegen], :src)
    df = indexjoin(idx, df)
    return select(df, propertynames(d[:seds]))
end


"""
"""
function _module_energy_ref(df::DataFrame)
    df_split = DataFrame(permute((
        src = "ele",
        sec = ["ind","ref"],
        base = ["btu","kwh"],
    )))

    df, df_out, df_split = _split_with(df, df_split, [:sec,:base])

    df[!,:ref_kwh_value] .= df[:,:ref_btu_value] .* (df[:,:ind_kwh_value] ./ df[:,:ind_btu_value])
    df[!,:ref_kwh_units] .= df[:,:ind_kwh_units]

    return _merge_with(df, df_out, df_split)
end


"""
"""
function _module_energy_ind(df::DataFrame)
    df_split = select(crossjoin(
        DataFrame(sec=["ind","ref"]), [
            DataFrame(src=set[:ff], base="btu");
            DataFrame(src="ele",    base="kwh");
        ],
    ), [:src,:sec,:base])

    df, df_out, df_split = _split_with(df, df_split, [:sec])
    df[!,:ind_value] .= df[:,:ind_value] .- df[:,:ref_value]
    return _merge_with(df, df_out, df_split)
end


"""
"""
function _module_energy_price(df::DataFrame, maps::Dict)
    splitter = Dict(
        :ff => crossjoin(
            DataFrame(src=set[:ff], sec="ele"),
            DataFrame(base=["usd","btu","usd_per_btu"], key=["usd","x","per"])
        ),
        :ele => crossjoin(
            DataFrame(src="ele", sec=set[:sec]),
            DataFrame(base=["usd","kwh","usd_per_kwh"], key=["usd","x","per"]),
        ),
    )

    [df = _module_energy_price(df, df_split,  maps) for df_split in values(splitter)]
    return df
end


function _module_energy_price(df::DataFrame, df_split::DataFrame, maps::Dict)
    id = [:usd,:x]
    df, df_out, df_split = _split_with(df, df_split, :key)
    df = operate_with(df, maps[:operate]; id=id, keepinput=true)

    # Function to ensure finite/set col to another col based on condition.
    alt = append(setdiff(Symbol.(df_split[:,:key]), id)[1], :value)
    if alt in propertynames(df)
        ii = .|(isnan.(df[:,:value]), isinf.(df[:,:value]))
        df[ii,:value] .= df[ii, alt]
    else
        df = edit_with(df, Replace.(:value, [Inf,NaN], 0.0))
    end
    
    # !!!! Functions to go between key/with units/values when stacking and unstacking.
    # !!!! Function to ensure finite/set col to another col based on condition.
    # When we restack at the end, we need the calculated value name to be consistent with
    # keys in slice so we know.
    # !!!! Move to _merge_with, before stacking. This will likely come up more than once.
    # Note: include output key in split df.
    res = [:value,:units]
    alt = append.(setdiff(Symbol.(df_split[:,:key]), id)[1], res)
    df = edit_with(df, [Deselect(alt,"==");Rename.(res, alt)])

    return _merge_with(df, df_out, df_split)
end