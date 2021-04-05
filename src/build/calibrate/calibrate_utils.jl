"""
    set_lower_bound!(d::Dict{Symbol,DataFrame}, var)
    set_lower_bound!(model::JuMP.Model, d::Dict{Symbol,Dict}, var, idx; kwargs...)
This function adds a lower bound to the DataType given in the method's first argument,
as calculated by [`SLiDE._lower_bound`](@ref)

# Arguments
- `model::JuMP.Model` to update
- `d::Dict{Symbol,DataFrame}`, OR, if no model is given,
    `d::Dict{Symbol,Dict}`: reference values to calculate lower bound.
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to edit
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to set bounds.

# Keyword Arguments
- `id::Symbol=lb`: if updating a dictionary, push a new entry with the key `:var_id` and store
    the lower bound here. `d[var]` will not be modified.
- `factor::Real=NaN` to use to calculate lower bound.
- `value::Real=NaN`: If a value is given, set lower bound to this value.
- `allow_negative::Bool=true`: Do we want to set negative values to zero?

# Returns
Method's first argument with the addition of a lower bound:
- `model::JuMP.Model`, with specified variable(s)' lower bounds set over the
    given index/indices, **OR**
- `d::Dict`, with key(s) `:var_id => ` calculated lower bound
"""
function set_lower_bound!(d::Dict, var::AbstractArray;
    allow_negative::Bool=true,
    factor::Real=NaN,
    value::Real=NaN,
    id=:lb,
)
    [set_lower_bound!(d, v; factor=factor, value=value, allow_negative=allow_negative, id=id)
        for v in var]
    return d
end


function set_lower_bound!(d::Dict, var::Symbol;
    allow_negative::Bool=true,
    factor::Real=NaN,
    value::Real=NaN,
    id=:lb,
)
    var_id = append(var,id)
    if !haskey(d, var_id)
        d[var_id] = _lower_bound(d[var]; factor=factor, value=value, allow_negative=allow_negative)
    end
    return d[var_id]
end


# ----- MODEL ------------------------------------------------------------------------------

function set_lower_bound!(model::Model, d::Dict, var::Symbol, idx::Tuple;
    allow_negative::Bool=true,
    factor::Real=NaN,
    value::Real=NaN,
)
    set_lower_bound(
        model[var][idx...],
        _lower_bound(d[var][idx]; factor=factor, value=value, allow_negative=allow_negative),
    )
    return model[var]
end


function set_lower_bound!(model::Model, d::Dict, var::Symbol, idx;
    allow_negative::Bool=true,
    factor::Real=NaN,
    value::Real=NaN,
)
    set_lower_bound(
        model[var][idx],
        _lower_bound(d[var][idx]; factor=factor, value=value, allow_negative=allow_negative),
    )
    return model[var]
end


"""
Calculates a lower bound on `x`:
    ```math
    x_{lower} =
    \\begin{cases}
    \\max\\left\\{0,\\, factor \\cdot x \\right\\}  & \\texttt{allow_negative}
    \\
    factor \\cdot x                                 & \\texttt{!allow_negative}
    \\end{cases}
```

# Arguments
- `x::Real` reference value to calculate lower bound
- `df::DataFrame` for which to  calculate  lower bounds

# Keyword Arguments
- `factor::Real=NaN` to use to calculate lower bound.
- `value::Real=NaN`: If a value is given, set lower bound to this value.
- `allow_negative::Bool=true`: Do we want to set negative values to zero?

# Returns
- `x::Real`: calculted lower bound
- `df::DataFrame`: copy of input `df` with lower bounds calculated
"""
function _lower_bound(x::Real;
    allow_negative::Bool=true,
    factor::Real=NaN,
    value::Real=NaN,
)
    !isnan(value) && return value
    isnan(factor) && throw(ArgumentError("Missing argument 'factor'."))
    return allow_negative ? factor*x : max.(0, factor*x)
end


function _lower_bound(df::DataFrame;
    allow_negative::Bool=true,
    factor::Real=NaN,
    value::Real=NaN,
)
    df = copy(df)
    df[!,:value] .= _lower_bound.(df[:,:value];
        allow_negative=allow_negative,
        factor=factor,
        value=value,
    )
    return df
end


"""
    set_upper_bound!(d::Dict{Symbol,DataFrame}, var)
    set_upper_bound!(model::JuMP.Model, d::Dict, var, idx; kwargs...)
This function adds a upper bound to the DataType given in the method's first argument,
as calculated by [`SLiDE._upper_bound`](@ref)

# Arguments
- `model::JuMP.Model` to update
- `d::Dict{Symbol,DataFrame}`, OR, if no model is given,
    `d::Dict{Symbol,Dict}`: reference values to calculate upper bound.
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to edit
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to set bounds.

# Keyword Arguments
- `id::Symbol=lb`: if updating a dictionary, push a new entry with the key `:var_id` and store
    the upper bound here. `d[var]` will not be modified.
- `factor::Real=NaN` to use to calculate upper bound.
- `value::Real=NaN`: If a value is given, set upper bound to this value.
- `allow_negative::Bool=true`: Do we want to set negative values to zero?

# Returns
Method's first argument with the addition of a upper bound:
- `model::JuMP.Model`, with specified variable(s)' upper bounds set over the
    given index/indices, **OR**
- `d::Dict`, with key(s) `:var_id => ` calculated upper bound
"""
function set_upper_bound!(d::Dict, lst::AbstractArray;
    allow_negative::Bool=true,
    factor::Real=NaN,
    id=:ub,
)
    [set_upper_bound!(d, k; factor=factor, allow_negative=allow_negative, id=id) for k in lst]
    return d
end


function set_upper_bound!(d::Dict, k::Symbol;
    allow_negative::Bool=true,
    factor::Real=NaN,
    id=:ub,
)
    var_id = append(k,id)
    if !haskey(d, var_id)
        d[var_id] = _upper_bound(d[k]; factor=factor, allow_negative=allow_negative)
    end
    return d[var_id]
end


# ----- MODEL ------------------------------------------------------------------------------

function set_upper_bound!(model::Model, d::Dict, var::Symbol, idx::Tuple;
    factor::Real=NaN,
    allow_negative::Bool=true,
)
    set_upper_bound(
        model[var][idx...],
        _upper_bound(d[var][idx]; factor=factor, allow_negative=allow_negative),
    )
    return nothing
end


function set_upper_bound!(model::Model, d::Dict, var::Symbol, idx;
    factor::Real=NaN,
    allow_negative::Bool=true,
)
    set_upper_bound(
        model[var][idx],
        _upper_bound(d[var][idx]; factor=factor, allow_negative=allow_negative),
    )
    return nothing
end


"""
This function calculates an upper bound on `x`:
    ```math
    x_{upper} =
    \\begin{cases}
    \\abs\\left\\{factor \\cdot x \\right\\}  & \\texttt{allow_negative}
    \\
    factor \\cdot x                           & \\texttt{!allow_negative}
    \\end{cases}
```

# Arguments
- `x::Real` reference value to calculate upper bound
- `df::DataFrame` for which to  calculate  upper bounds

# Keyword Arguments
- `factor::Real=NaN` to use to calculate upper bound.
- `value::Real=NaN`: If a value is given, set upper bound to this value.
- `allow_negative::Bool=true`: Do we want to set negative values to zero?

# Returns
- `x::Real`: calculted upper bound
- `df::DataFrame`: copy of input `df` with upper bounds calculated
"""
function _upper_bound(x::Real;
    factor::Real=NaN,
    allow_negative::Bool=true,
)
    isnan(factor) && throw(ArgumentError("Missing argument 'factor'."))
    return allow_negative ? factor*x : abs(factor*x)
end


function _upper_bound(df::DataFrame;
    allow_negative::Bool=true,
    factor::Real=NaN,
)
    df = copy(df)
    df[!,:value] .= _upper_bound.(df[:,:value];
        allow_negative=allow_negative,
        factor=factor,
    )
    return df
end


"""
This function sets negative values to zero.

# Arguments
    zero_negative!(d)
    zero_negative!(d, var)
- `d::Dict{Symbol,DataFrame}` to edit
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to edit
    
    zero_negative!(df)
    zero_negative!(df, subset)
- `df::DataFrame` to edit
- `subset::Pair`: If given, only zero negative values for this `idx => value` pair.

# Returns
- `df::DataFrame` or `d::Dict{Symbol,DataFrame}` with negative values set to zero.
"""
function zero_negative!(df::DataFrame)
    df[!,:value] .= max.(0, df[:,:value])
    return df
end

function zero_negative!(df::DataFrame, subset::Pair)
    if subset[1] in propertynames(df)
        ii = df[subset[1]] .== subset[2]
        df[ii,:value] .= max.(0, df[ii,:value])
    end
    return df
end

zero_negative!(d::Dict) = zero_negative!(d, keys(d))
zero_negative!(d::Dict, var::Symbol) = zero_negative!(d[var])

function zero_negative!(d::Dict, var::AbstractArray)
    [zero_negative!(d, v) for v in var]
    return d
end


"""
    set_bounds!(model::JuMP.Model, d::Dict, var, idx; kwargs...)
This function sets upper and lower bound on the specified model variables.

# Arguments
- `model::JuMP.Model` to update
- `d::Dict{Symbol,Dict}`: reference values to calculate bounds
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to edit
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to set bounds.

# Keyword Arguments
- `lower_bound::Real=NaN`: factor passed to [`SLiDE.set_lower_bound!`](@ref)
- `upper_bound::Real=NaN`: factor passed to [`SLiDE.set_upper_bound!`](@ref)

# Returns
- `model::JuMP.Model`, with specified variable(s)' upper and lower bounds set over the
    given index/indices
"""
function set_bounds!(model::Model, d::Dict, var::Symbol, idx;
    lower_bound::Real=NaN,
    upper_bound::Real=NaN,
)
    isnan(lower_bound) && throw(ArgumentError("Missing argument 'lower_bound'."))
    isnan(upper_bound) && throw(ArgumentError("Missing argument 'upper_bound'."))
    set_lower_bound!(model, d, var, idx; factor=lower_bound)
    set_upper_bound!(model, d, var, idx; factor=upper_bound)
    return model[var]
end


function set_bounds!(model::Model, d::Dict, var::Symbol, idx::AbstractArray;
    lower_bound::Real=NaN,
    upper_bound::Real=NaN,
)
    [set_bounds!(model, d, var, x; lower_bound=lower_bound, upper_bound=upper_bound)
        for x in idx]
    return model[idx]
end


function set_bounds!(model::Model, d::Dict, var::Symbol, set::Dict, idx;
    lower_bound::Real=NaN,
    upper_bound::Real=NaN,
)
    set_bounds!(model, d, var, set[idx]; lower_bound=lower_bound, upper_bound=upper_bound)
    return model
end


"""
    fix!(model, d, var, idx; kwargs...)
    fix!(model, d, var, set, idx; kwargs...)
    fix!(model, var, set, idx; kwargs...)
This function fixes a `JuMP.Model` variable to either a value specified in a Dict `d` or a
scalar value using `JuMP.fix`.

# Arguments
- `model::JuMP.Model` to update
- `d::Dict{Symbol,Dict}` of reference values to fix to.
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to fix
- `set::Dict`: sets to reference when generating a list of indices to fix
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to fix the variable.

# Keyword Arguments
- `value::Real=NaN`: If a value is given,
    - If the value is given **with** an input `d::Dict`, set to this value *iff* it is equal
        to the dictionary value.
    - If a value is given **without** an input `d::Dict`, fix to this value regardless.
- `force::Bool` variable to pass to `JuMP.fix`

# Returns
- `model::JuMP.Model`, with specified variable(s) fixed over the given index/indices.
"""
function fix!(model::Model, d::Dict, var::Symbol, idx::Tuple;
    value::Real=NaN,
    force::Bool=true,
)
    # !!!! splatting might depend on variable type (should do only for dense axis array)
    if isnan(value)
        fix(model[var][idx...], d[var][idx], force=true)
    else
        d[var][idx] == value && fix(model[var][idx...], value, force=true)
    end
    return nothing
end


function fix!(model::Model, d::Dict, var::Symbol, idx;
    value::Real=NaN,
    force::Bool=true,
)
    if isnan(value)
        fix(model[var][idx], d[var][idx], force=true)
    else
        d[var][idx] == value && fix(model[var][idx], value, force=true)
    end
    return nothing
end


function fix!(model::Model, d::Dict, var::Symbol, idx::AbstractArray;
    value::Real=NaN,
    force::Bool=true,
)
    if any(SLiDE.isarray.(idx))
        idx = permute(ensurearray.(idx)...)
    end
    [fix!(model, d, var, x; value=value, force=force) for x in idx]
    return model[var]
end


function fix!(model::Model, d::Dict, var::AbstractArray, idx;
    value::Real=NaN,
    force::Bool=true,
)
    [fix!(model, d, v, idx; value=value, force=force) for v in var]
    return model
end


function fix!(model::Model, d::Dict, var, set::Dict, idx;
    value::Real=NaN,
    force::Bool=true,
)
    fix!(model, d, var, set[idx]; value=value, force=force)
    return model
end


# ----- WITHOUT DICTIONARY -----------------------------------------------------------------

function fix!(model::Model, var::Symbol, idx::Tuple; value=NaN, force=true)
    fix(model[var][idx...], value, force=force)
    return nothing
end


function fix!(model::Model, var::Symbol, idx; value=NaN, force=true)
    fix(model[var][idx], value, force=true)
    return nothing
end


function fix!(model::Model, var::Symbol, idx::AbstractArray; value=NaN, force=true)
    if any(SLiDE.isarray.(idx))
        idx = permute(ensurearray.(idx)...)
    end
    [fix!(model, var, x; value=value, force=force) for x in idx]
    return model[var]
end


function fix!(model::Model, var::AbstractArray, idx::AbstractArray; value=NaN, force=true)
    [fix!(model, v, idx; value=value, force=force) for v in var]
    return model
end


"""
    fix_lower_bound!(model, d, var, idx; kwargs...)
    fix_lower_bound!(model, d, var, set, idx; kwargs...)
    fix_lower_bound!(model, var, set, idx; kwargs...)
This function fixes a model variable `model[var][idx]` if it meets the specified condition
(`d[var][idx]==value`), or sets its lower bound using the input `factor`.
    ```
    if d[var][idx] == value
        fix!(model, d, var, idx)
    else
        set_lower_bound!(model, d, var, idx; factor=lower_bound)
    end
    ```

# Arguments
- `model::JuMP.Model` to update
- `d::Dict{Symbol,Dict}` of reference values to fix to.
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to fix
- `set::Dict`: sets to reference when generating a list of indices to fix
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to fix the variable OR set its lower bound

# Keyword Arguments
- `factor::Real=NaN` to use to calculate lower bound.
- `force::Bool=true` variable to pass to `JuMP.fix`.
- `value::Real=0`: Fix `model[var][idx]` to this `value` if it is equals `d[var][idx]`

# Returns
- `model::JuMP.Model`, with specified variable(s) fixed OR lower bounds set over the
    given index/indices.
"""
function fix_lower_bound!(model::Model, d::Dict, var::Symbol, idx;
    factor::Real=NaN,
    force::Bool=true,
    value=0,
)
    if d[var][idx]==value
        fix!(model, d, var, idx; value=value, force=force)
    else
        set_lower_bound!(model, d, var, idx; factor=factor)
    end
    return model[var]
end


function fix_lower_bound!(model::Model, d::Dict, var::Symbol, idx::AbstractArray;
    factor::Real=NaN,
    force::Bool=true,
    value=0,
)
    if any(SLiDE.isarray.(idx))
        idx = permute(ensurearray.(idx)...)
    end

    [fix_lower_bound!(model, d, var, x;
            factor=factor,
            force=force,
            value=value,
        ) for x in idx]
    return model[var]
end


function fix_lower_bound!(model::Model, d::Dict, var::AbstractArray, idx;
    factor::Real=NaN,
    force=true,
    value=0,
)
    [fix_lower_bound!(model, d, v, idx;
            factor=factor,
            force=force,
            value=value,
        ) for v in var]
    return model
end