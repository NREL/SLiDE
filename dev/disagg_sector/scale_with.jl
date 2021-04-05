"""
    scale_with(df, x)
"""
function scale_with(df::DataFrame, x::Weighting)
    # Save unaffected indices. Map the others and calculate share.
    df_ones = filter_with(df, Not(x))
    df = edit_with(df,
        Map(x.data, [x.constant;x.from], [x.to;:value], [x.constant;x.on], [x.on;:share], :inner)
    )
    df[!,:value] .*= df[:,:share]

    # Sum if aggregating.
    x.direction == :aggregate && (df = combine_over(df, :dummy))
    return vcat(select(df, Not(:share)), df_ones)
end


function scale_with(df::DataFrame, x::Mapping)    
    # Save unaffected indices. Map the others.
    df_ones = filter_with(df, Not(x))
    df = edit_with(df, Map(x.data, [x.from;], [x.to;], [x.on;], [x.on;], :inner))

    # Sum if aggregating.
    x.direction == :aggregate && (df = combine_over(df, :dummy; digits=false))
    return vcat(df, df_ones)
end


scale_with(df::DataFrame, x::Missing) = df


"""
    disaggregate_sector!(d, set, x; kwargs...)
"""
function disaggregate_sector!(d::Dict, set::Dict, x::Weighting;
    scale_id=:disaggregate,
)
    !haskey(d, scale_id) && push!(d, scale_id=>x)

    parameters = SLiDE.list_parameters!(set, :parameters)
    taxes = SLiDE.list_parameters!(set, :taxes)
    variables = setdiff(parameters, taxes)

    x_tax = convert_type(Mapping, x)
    scale_sector!(d, set, x, variables; scale_id=scale_id)
    scale_sector!(d, set, x_tax, taxes; scale_id=scale_id)
    return d
end


"""
    aggregate_sector!(d, set, x; kwargs...)
"""
function aggregate_sector!(d::Dict, set::Dict, x::Mapping;
    scale_id=:aggregate,
)
    !haskey(d, scale_id) && push!(d, scale_id=>x)
    parameters = SLiDE.list_parameters!(set, :parameters)

    # Aggregate taxes.
    # Their associated scaling parameters will be aggregated in the process.
    taxes = [(:ta0,:a0), (:tm0,:m0), (:ty0,:ys0)]
    [aggregate_tax_with!(d, set, x, tax, key; scale_id=scale_id) for (tax,key) in taxes]
    
    # Aggregate remaining variables.
    variables = setdiff(parameters, vcat(ensurearray.(taxes)...))
    scale_sector!(d, set, x, variables; scale_id=scale_id)
    return d
end


"""
    scale_sector!(d, set, x)
"""
function scale_sector!(d::Dict, set::Dict, x::T; scale_id=missing) where T <: Scale
    scale_id = SLiDE._inp_key(scale_id, x)

    d = if x.direction==:aggregate
        aggregate_sector!(d, set, x; scale_id=scale_id)
    elseif x.direction==:disaggregate
        disaggregate_sector!(d, set, x; scale_id=scale_id)
    end
    return d
end


function scale_sector!(d::Dict, set::Dict, x::Weighting, var::Symbol; scale_id=missing)
    scale_id = SLiDE._inp_key(scale_id, x)
    !haskey(d, scale_id) && push!(d, scale_id=>x)
    
    x = compound_sector!(d, set, var; scale_id=scale_id)

    d[var] = scale_with(d[var], x)
    return d[var]
end

function scale_sector!(d::Dict, set::Dict, x::Mapping, var::Symbol; scale_id=missing)
    scale_id = SLiDE._inp_key(scale_id, x)
    !haskey(d, scale_id) && push!(d, scale_id=>x)

    x = compound_sector!(d, set, var; scale_id=scale_id)

    if !ismissing(x)
        x = convert_type(Mapping, x)
        d[var] = scale_with(d[var], x)
    end
    return d[var]
end

function scale_sector!(d::Dict, set::Dict, x::T, var; scale_id=missing) where T <: Scale
    [scale_sector!(d, set, x, v; scale_id=scale_id) for v in var]
    return d
end


"""
    aggregate_tax_with!(d::Dict, set::)
This function is applied to the following tax rates, which are scaled by a the corresponding
parameters. It returns the aggregated tax rate as well as the aggregated scaling parameter.

- `ta(yr,r,g)`, absorption taxes, scaled by domestic absorption, `a(yr,r,g)`:
    ```math
    \\begin{aligned}
    \\bar{a}_{yr,r,g} &= \\bar{a}_{yr,r,gg} \\circ map_{gg\\rightarrow g}
    \\\\
    \\bar{ta}_{yr,r,g} &= \\dfrac
        {\\left(\\bar{ta}_{yr,r,gg} \\cdot \\bar{a}_{yr,r,gg} \\right) \\circ map_{gg\\rightarrow g}}
        {                                  \\bar{a}_{yr,r,g}}
    \\end{aligned}
    ```
- `tm(yr,r,g)`, import taxes, scaled by foreign imports, `m(yr,r,g)`:
    ```math
    \\begin{aligned}
    \\bar{m}_{yr,r,g} &= \\bar{m}_{yr,r,gg} \\circ map_{gg\\rightarrow g}
    \\\\
    \\bar{tm}_{yr,r,g} &= \\dfrac
        {\\left(\\bar{tm}_{yr,r,gg} \\cdot \\bar{m}_{yr,r,gg} \\right) \\circ map_{gg\\rightarrow g}}
        {                                  \\bar{m}_{yr,r,g}}
    \\end{aligned}
    ```
- `ty(yr,r,s)`, production taxes, scaled by total regional sectoral output, `ys(yr,r,s,g)`:
    ```math
    \\begin{aligned}
    \\bar{ys}_{yr,r,s,g} &= \\bar{ys}_{yr,r,ss,gg} \\circ map_{ss\\rightarrow s, gg\\rightarrow g}
    \\\\
    \\bar{ty}_{yr,r,s} &= \\dfrac
        {\\left(\\bar{ty}_{yr,r,ss} \\cdot \\sum_{gg} \\bar{ys}_{yr,r,ss,gg} \\right) \\circ map_{ss\\rightarrow s}}
        {                                  \\sum_{g}  \\bar{ys}_{yr,r,s ,g}}
    \\end{aligned}
    ```

where ``gg``, ``ss`` represent **dis**aggregate-level goods and sectors
and ``g``, ``s`` represent aggregate-level goods and sectors.

# Arguments
- `d::Dict` of model parameters
- `dfmap::DataFrame`: mapping ``map_{gg\\rightarrow g}``
- `tax::Symbol`: tax parameter key
- `key::Symbol`: scaling parameter key

# Returns
- `d[tax]::DataFrame`: mapped tax parameter
- `d[key]::DataFrame`: mapped scaling parameter
"""
function aggregate_tax_with!(d::Dict, set::Dict, x::Mapping, tax::Symbol, key::Symbol;
    scale_id=missing,
)
    scale_id = SLiDE._inp_key(scale_id, x)
    sector = setdiff(propertynames(d[key]), propertynames(d[tax]))

    d[tax] = d[tax] * combine_over(d[key], sector)
    scale_sector!(d, set, x, [key,tax]; scale_id=scale_id)
    d[tax] = d[tax] / combine_over(d[key], sector)

    return dropzero!(dropnan!(d[tax])), d[key]
end