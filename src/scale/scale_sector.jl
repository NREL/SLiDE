"""
    scale_sector!(d, set, x; kwargs...)
"""
function scale_sector!(dataset::Dataset, d::Dict, set::Dict; kwargs...)
    set!(dataset; step="scale")
    d, set = scale_sector!(d, set; kwargs...)
    d = Dict{Any,Any}(SLiDE.write_build!(dataset, d))
    return d, set
end


function scale_sector!(d::Dict, set::Dict; path::String=SCALE_EEM_IO)
    return scale_sector!(d, set, read_file(path)[:,1:2])
end


function scale_sector!(d::Dict, set::Dict, dfmap::DataFrame)
    # Store dfmap as `Mapping` and set scheme based on the current sectoral set.
    # After the build stream, this *should* be equivalent to the summary-level set.
    mapping = Mapping(dfmap)
    set_scheme!(mapping, DataFrame(g=set[:sector]))
    
    return scale_sector!(d, set, mapping)
end


function scale_sector!(d::Dict, set::Dict, mapping::Mapping; kwargs...)
    # If (2) scaling FROM ANY detail-level codes not yet listed in `sector` OR
    # (1) disaggregating, disaggregate summary- to detail-level (or a hybrid of the two).
    # After assessing whether disaggregation is necessary, update `from`.
    if !complete_with!(set, mapping) || mapping.direction==:disaggregate
        disaggregate_sector!(d, set; kwargs...)
    end
    
    mapping.direction==:aggregate && aggregate_sector!(d, set, mapping; kwargs...)

    return d, set
end


function scale_sector!(d::Dict, set::Dict, weighting::Weighting; kwargs...)
    return disaggregate_sector!(d, set, weighting; kwargs...)
    # d = if weighting.direction==:aggregate
    #     aggregate_sector!(d, set, weighting; kwargs...)
    # elseif weighting.direction==:disaggregate
    #     disaggregate_sector!(d, set, weighting; kwargs...)
    # end
    # return d
end


function scale_sector!(d::Dict, set::Dict, x, var::Symbol; kwargs...)
    x = compound_sector!(d, set, x, var; kwargs...)
    d[var] = scale_with(d[var], x)
    return d[var]
end


function scale_sector!(d::Dict, set::Dict, x, var::AbstractArray; kwargs...)
    [scale_sector!(d, set, x, v; kwargs...) for v in var]
    return d
end


function SLiDE.scale_sector!(set::Dict, x::T) where T<:Scale
    [scale_sector!(set, x, var) for var in [:gm,:sector] if var in keys(set)]
    SLiDE.set_sector!(set, set[:sector])
    return set
end

scale_sector!(set::Dict, x, var::Symbol) = set[var] = SLiDE.scale_with(set[var], x)


"""
    disaggregate_sector!(d::Dict, set::Dict; kwargs...)
    disaggregate_sector!(d::Dict, set::Dict, weighting::Weighting; kwargs...)
"""
function disaggregate_sector!(d::Dict, set::Dict)
    weighting = share_sector!(d, set)
    disaggregate_sector!(d, set, weighting)
    return d
end


function disaggregate_sector!(d::Dict, set::Dict, x::Weighting; label=:disaggregate)
    push!(d, label=>x)

    taxes = SLiDE.list("taxes")
    variables = setdiff(SLiDE.list!(set, Dataset(""; build="io", step=SLiDE.PARAM_DIR)), taxes)

    x_tax = convert_type(Mapping, x)
    SLiDE.scale_sector!(d, set, x, variables; label=label)
    SLiDE.scale_sector!(d, set, x_tax, taxes; label=label)

    # Update sector to match.
    SLiDE.scale_sector!(set, x)
    return d
end


"""
    disaggregate_sector!(d::Dict, set::Dict, mapping::Mapping; kwargs...)
"""
function aggregate_sector!(d::Dict, set::Dict, x::Mapping; label=:aggregate)
    push!(d, label=>x)

    # Aggregate taxes. Their associated scaling parameters will be aggregated in the process.
    taxes = [(:ta0,:a0), (:tm0,:m0), (:ty0,:ys0)]
    [aggregate_tax_with!(d, set, x, tax, key; label=label) for (tax,key) in taxes]
    
    # Aggregate remaining variables.
    parameters = list!(set, Dataset(""; build="io", step=PARAM_DIR))
    variables = setdiff(parameters, vcat(ensurearray.(taxes)...))
    scale_sector!(d, set, x, variables; label=label)

    # Update sector to match.
    SLiDE.scale_sector!(set, x)
    return d
end


"""
    aggregate_tax_with!(d::Dict, set::Dict, mapping::Mapping, tax::Symbol, key::Symbol)
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
- `set::Dict` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)
- `mapping::Mapping` defining ``map_{gg\\rightarrow g}``
- `tax::Symbol`: tax parameter key
- `key::Symbol`: scaling parameter key

# Returns
- `d[tax]::DataFrame`: mapped tax parameter
- `d[key]::DataFrame`: mapped scaling parameter
"""
function aggregate_tax_with!(d::Dict, set::Dict, x::Mapping, tax::Symbol, key::Symbol; kwargs...)
    sector = setdiff(propertynames(d[key]), propertynames(d[tax]))

    d[tax] = d[tax] * combine_over(d[key], sector)
    scale_sector!(d, set, x, [key,tax]; kwargs...)
    d[tax] = d[tax] / combine_over(d[key], sector)

    return dropzero!(dropnan!(d[tax])), d[key]
end


"""
    compound_sector!(d::Dict, set::Dict, scale::T, var::Symbol; kwargs...)

# Arguments
- `d::Dict` of model parameters
- `set::Dict` of Arrays describing parameter indices (years, regions, goods, sectors, etc.)
- `scale::T where T<:Scale`, defining ``map_{gg\\rightarrow g}``, or with its associated weights
- `var::Symbol` that will ultimately require scaling
"""
function compound_sector!(d::Dict, set::Dict, scale::T, var::Symbol; label=missing) where T <: Scale
    df = d[var]
    sector = SLiDE.find_sector(df)
    scale = copy(scale)

    if ismissing(sector)
        return missing
    else
        key = SLiDE._inp_key(label, scale, sector)
        # If the key does not already exist in the DataFrame, compound for the DataFrame
        # (with sector columns only) to run set_scheme! and update direction.
        # If the key exists, but is the wrong type (Weighting vs. Mapping), re-compound.
        if !haskey(d, key) || typeof(scale) !== typeof(d[key])
            set_on!(scale, sector)
            push!(d, key=>SLiDE.compound_for(scale, set[:sector], df))
        end
        return d[key]
    end
end


"""
    complete_with(lst::AbstractArray, mapping::Mapping)
This function assesses whether `Mapping` replaces any of the values in `lst`.
If it does, we must first disaggregate before aggregating.
"""
function complete_with(lst::AbstractArray, x::Mapping)
    return isempty(antijoin(x.data, DataFrame(x.on=>lst), on=Pair.(x.from, x.on)))
end


"""
    complete_with!(set::Dict, mapping::Mapping)
"""
function complete_with!(set::Dict, x::Mapping)
    was_complete = complete_with(set[:sector], x)
    set_sector!(set, x.data[:,x.from])
    return was_complete
end


"""
"""
function find_set(mapping::Mapping, set::Dict, levels::AbstractArray)
    df = vcat([DataFrame(mapping.on => set[k], :set => k) for k in levels]...)
    df = innerjoin(mapping.data, df, on=Pair.(mapping.from, mapping.on))
    return unique(df[:,:set])
end