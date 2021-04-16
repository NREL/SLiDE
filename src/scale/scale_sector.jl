"""
    aggregate_sector!(d, set, x; kwargs...)
"""
function aggregate_sector!(d::Dict, set::Dict;
    path::String=SCALE_EEM_IO,
)
    return aggregate_sector!(d, set, read_file(path)[:,1:2])
end


function aggregate_sector!(d::Dict, set::Dict, dfmap::DataFrame)
    # Store dfmap as `Mapping` and set scheme based on the current sectoral set.
    # After the build stream, this *should* be equivalent to the summary-level set.
    mapping = Mapping(dfmap)
    SLiDE.set_scheme!(mapping, DataFrame(g=set[:sector]))

    # If scaling FROM ANY detail-level codes, disaggregate summary- to detail-level
    # (or a hybrid of the two).
    if !iscomplete(mapping, set[:sector])
        # Need to set sector to whatever the goal is here before SCALING.
        SLiDE.set_sector!(set, mapping.data[:,mapping.from])

        # !!!! Verify that only summary- and detail-level codes are represented in mapping.from
        # find_set(mapping, set, [:detail,:summary])
        disaggregate_sector!(d, set)
    else
        SLiDE.set_sector!(set, mapping.data[:,mapping.from])
    end
    
    aggregate_sector!(d, set, mapping; scale_id=:eem)
    
    return d, set
end


function aggregate_sector!(d::Dict, set::Dict, x::Mapping;
    scale_id=:aggregate,
)
    !haskey(d, scale_id) && push!(d, scale_id=>x)
    parameters = list!(set, Dataset(""; build="io", step=PARAM_DIR))

    # Aggregate taxes.
    # Their associated scaling parameters will be aggregated in the process.
    taxes = [(:ta0,:a0), (:tm0,:m0), (:ty0,:ys0)]
    [SLiDE.aggregate_tax_with!(d, set, x, tax, key; scale_id=scale_id) for (tax,key) in taxes]
    
    # Aggregate remaining variables.
    variables = setdiff(parameters, vcat(ensurearray.(taxes)...))
    SLiDE.scale_sector!(d, set, x, variables; scale_id=scale_id)

    # Update sector to match. Using d[id,g,s] in case scheme was updated by compound_for
    # SLiDE.set_sector!(set, x)
    SLiDE.set_sector!(set, d[scale_id,:g,:s])
    return d
end


"""
    disaggregate_sector!(d, set, x; kwargs...)
"""
function disaggregate_sector!(d::Dict, set::Dict)
    weighting = share_sector!(d, set)
    disaggregate_sector!(d, set, weighting)
    return d
end

function disaggregate_sector!(d::Dict, set::Dict, x::Weighting; scale_id=:disaggregate)
    !haskey(d, scale_id) && push!(d, scale_id=>x)

    taxes = list("taxes")
    variables = setdiff(list!(set, Dataset(""; build="io", step=PARAM_DIR)), taxes)

    x_tax = convert_type(Mapping, x)
    SLiDE.scale_sector!(d, set, x, variables; scale_id=scale_id)
    SLiDE.scale_sector!(d, set, x_tax, taxes; scale_id=scale_id)

    # Update sector to match. Using d[id,g,s] in case scheme was updated by compound_for
    # set_sector!(set, x)
    set_sector!(set, d[scale_id,:g,:s])
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


"""
    compound_sector!(d, set, var; scale_id)
"""
function compound_sector!(d::Dict, set::Dict, var::Symbol; scale_id=missing)
    df = d[var]
    sector = find_sector(df)

    if ismissing(sector)
        return missing
    else
        key = SLiDE._inp_key(scale_id, sector)
        # If the key does not already exist in the DataFrame, compound for the DataFrame
        # (with sector columns only) to run set_scheme! and update direction.
        # If the key exists, but is the wrong type (Weighting vs. Mapping), re-compound.
        if !haskey(d, key) || typeof(d[scale_id]) !== typeof(d[key])
            d[key] = compound_for(d[scale_id], df[:, ensurearray(sector)], set[:sector])
        end
        return d[key]
    end
end


"""
"""
function iscomplete(mapping::Mapping, lst::AbstractArray)
    df = DataFrame(mapping.on => lst)
    return isempty(antijoin(mapping.data, df, on=Pair.(mapping.from, mapping.on)))
end


"""
"""
function find_set(mapping::Mapping, set::Dict, levels::AbstractArray)
    df = vcat([DataFrame(mapping.on => set[k], :set => k) for k in levels]...)
    df = innerjoin(mapping.data, df, on=Pair.(mapping.from, mapping.on))
    return unique(df[:,:set])
end