"""
```math
\\tilde{energy}_{yr,r,src,sec} = \\left\\{\\tilde{seds}\\left( yr,r,src,sec \\right)
\\;\\vert\\; yr, \\, r, \\, e \\in src, \\, ed \\in sec \\right\\}
```
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
```math
\\tilde{supply}_{yr,r,src=ele} = \\sum_{src} \\tilde{ele}_{yr,r,src}
```
"""
function _module_energy_supply(d::Dict)
    idx = DataFrame(src="ele", sec="supply")
    df = combine_over(d[:elegen], :src)
    df = indexjoin(idx, df)
    return select(df, propertynames(d[:seds]))
end


"""
```math
\\tilde{ref}_{yr,r,src=ele} \\text{ [billion kWh]}
=
\\tilde{ref}_{yr,r,src=ele} \\text{ [trillion btu]}
\\cdot
\\dfrac{\\tilde{ind}_{yr,r,src=ele} \\text{ [billion kWh]}}
      {\\tilde{ind}_{yr,r,src=ele} \\text{ [trillion btu]}}
```
"""
function _module_energy_ref(df::DataFrame)
    df_split = DataFrame(permute((
        src = "ele",
        sec = ["ind","ref"],
        base = ["btu","kwh"],
    )))

    df, df_out, df_split = _split_with(df, df_split, [:sec,:base])
    
    df[!,:ref_kwh] .= df[:,:ref_btu] .* (df[:,:ind_kwh] ./ df[:,:ind_btu])
    df[!,_add_id(:ref_kwh,:units)] .= df[:,_add_id(:ind_kwh,:units)]

    return _merge_with(df, df_out, df_split)
end


"""
```math
\\tilde{ind}_{yr,r,src=(ff,ele)}
= \\tilde{ind}_{yr,r,src=(ff,ele)}
- \\tilde{ref}_{yr,r,src=(ff,ele)}
```
"""
function _module_energy_ind(df::DataFrame)
    df_split = select(crossjoin(
        DataFrame(sec=["ind","ref"]), [
            DataFrame(src=set[:ff], base="btu");
            DataFrame(src="ele",    base="kwh");
        ],
    ), [:src,:sec,:base])

    df, df_out, df_split = _split_with(df, df_split, [:sec])
    df[!,:ind] .= df[:,:ind] .- df[:,:ref]
    return _merge_with(df, df_out, df_split)
end


"""
```math
\\begin{aligned}
\\tilde{ff}_{yr,r,sec=ele} \\text{ [USD/million btu]}
&= 10^3 \\cdot
\\dfrac{\\tilde{ff}_{yr,r,sec=ele} \\text{ [billion USD]}}
      {\\tilde{ff}_{yr,r,sec=ele} \\text{ [trillion btu]}}
\\\\
\\tilde{ele}_{yr,r,sec} \\text{ [USD/thousand kWh]}
&= 10^3 \\cdot
\\dfrac{\\tilde{ele}_{yr,r,sec} \\text{ [billion USD]}}
      {\\tilde{ele}_{yr,r,sec} \\text{ [thousand kWh]}}
\\end{aligned}
```
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
    # !!!! figure out the units situation when joining to make this one function.
    # This wouldn't be such an issue if we ignored the units columns,
    # but they're nice to keep track of for now.
    id = [:value,:units]
    key = [:usd,:x]

    df, df_out, df_split = _split_with(df, df_split, :key)
    df = operate_with(df, maps[:operate]; id=key, keepinput=true)

    alt = setdiff(convert_type.(Symbol, df_split[:,:key]), key)[1]
    if alt in _with_id(df,:value)
        ii = .|(isnan.(df[:,:value]), isinf.(df[:,:value]))
        df[ii,:value] .= df[ii, _add_id(alt,:value)]
    end

    df = edit_with(df, Replace.(:value, [Inf,NaN], 0.0))

    # Maybe move to _merge_with if this all is general enough? Doubt it tbh.
    alt = _add_id.(alt, id)
    df = edit_with(df, [Deselect(alt,"=="); Rename.(id, alt)])
    return _merge_with(df, df_out, df_split)
end