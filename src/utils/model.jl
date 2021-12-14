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
    df[!,:value] .= zero_negative.(df[:,:value])
    return df
end

function zero_negative!(df::DataFrame, subset::Pair)
    if subset[1] in propertynames(df)
        ii = df[subset[1]] .== subset[2]
        df[ii,:value] .= zero_negative.(df[ii,:value])
    end
    return df
end

zero_negative!(d::Dict) = zero_negative!(d, keys(d))
zero_negative!(d::Dict, var::Symbol) = zero_negative!(d[var])

function zero_negative!(d::Dict, var::AbstractArray)
    [zero_negative!(d, v) for v in var]
    return d
end

function zero_negative!(d::Dict, var::InvertedIndex)
    var = setdiff(collect(keys(d)), ensurearray(var.skip))
    return zero_negative!(d, var)
end


zero_negative(x::Real) = max(0, x)


"""
This function returns the start value of the JuMP Model VariableRef `model[var][idx]`.
"""
_start_value(model::Model, var::Symbol, idx::Tuple) = start_value(model[var][idx...])
_start_value(model::Model, var::Symbol, idx::String) = start_value(model[var][idx])


"""
    upper_bound(x::Real; kwargs...)
This function returns an upper bound on `x`:
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

# Keyword Arguments
- `factor::Real=0` to use to calculate upper bound.
- `value::Real=NaN`: If a value is given, set upper bound to this value.
- `allow_negative::Bool=true`: Do we want to make negative values positive?

# Returns
- `x::Real`: calculted upper bound
"""
function upper_bound(x::Real; factor::Real=0, value::Real=NaN, allow_negative::Bool=true)
    return if iszero(x)
        Inf
    elseif !isnan(value)
        value
    else
        allow_negative ? factor*x : abs(factor*x)
    end
end


"""
    lower_bound(x::Real; kwargs...)
This function calculates a lower bound on `x`:
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

# Keyword Arguments
- `factor::Real=0` to use to calculate lower bound.
- `value::Real=NaN`: If a value is given, set lower bound to this value.
- `allow_negative::Bool=true`: Do we want to set negative values to zero?

# Returns
- `x::Real`: calculted lower bound
"""
function lower_bound(x::Real; factor::Real=0, value::Real=NaN, allow_negative::Bool=true)
    return if !isnan(value)
        value
    else
        allow_negative ? factor*x : max.(0, factor*x)
    end
end


"""
    set_upper_bound!(model::JuMP.Model, var, idx; kwargs...)
This function sets a JuMP Model variable's upper bound as calculated by
[`SLiDE.upper_bound`](@ref).

# Arguments
- `model::JuMP.Model` to update
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to update
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to set bounds.

# Keyword Arguments
Consistent with [`SLiDE.upper_bound`](@ref)
"""
function set_upper_bound!(model::Model, var::Symbol, idx::Tuple; kwargs...)
    val = _start_value(model, var, idx)
    !iszero(val) && set_upper_bound(model[var][idx...], upper_bound(val; kwargs...))
    return nothing
end

function set_upper_bound!(model::Model, var::Symbol, idx::String; kwargs...)
    val = SLiDE._start_value(model, var, idx)
    !iszero(val) && set_upper_bound(model[var][idx], upper_bound(val; kwargs...))
    return nothing
end

set_upper_bound!(args...; kwargs...) = _call_jump!(set_upper_bound!, args...; kwargs...)


"""
    set_lower_bound!(model::JuMP.Model, var, idx; kwargs...)
This function sets a JuMP Model variable's lower bound as calculated by
[`SLiDE.lower_bound`](@ref).

# Arguments
- `model::JuMP.Model` to update
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to update
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to set bounds.

# Keyword Arguments
Consistent with [`SLiDE.lower_bound`](@ref)
"""
function set_lower_bound!(model::Model, var::Symbol, idx::Tuple; kwargs...)
    val = _start_value(model, var, idx)
    set_lower_bound(model[var][idx...], lower_bound(val; kwargs...))
    return nothing
end

function set_lower_bound!(model::Model, var::Symbol, idx::String; kwargs...)
    val = _start_value(model, var, idx)
    set_lower_bound(model[var][idx], lower_bound(_start_value(model, var, idx); kwargs...))
    return nothing
end

set_lower_bound!(args...; kwargs...) = _call_jump!(set_lower_bound!, args...; kwargs...)


"""
    set_bounds!(model::JuMP.Model, var, idx; kwargs...)
This function sets upper and lower bound on the specified JuMP Model variable(s).

# Arguments
- `model::JuMP.Model` to update
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to update
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to set bounds.

# Keyword Arguments
- `lower_factor::Real=0`: passed to [`SLiDE.lower_bound`](@ref) as `factor`
- `upper_factor::Real=0`: passed to [`SLiDE.upper_bound`](@ref) as `factor`
- `allow_negative::Bool=true`: passed to [`SLiDE.lower_bound`](@ref) and [`SLiDE.upper_bound`](@ref)
"""
function set_bounds!(model::Model, var::Symbol, idx::Union{String,Tuple};
    lower_factor::Real=0,
    upper_factor::Real=0,
    allow_negative::Bool=true,
)
    set_lower_bound!(model, var, idx; factor=lower_factor, allow_negative=allow_negative)
    set_upper_bound!(model, var, idx; factor=upper_factor, allow_negative=allow_negative)
    return nothing
end

set_bounds!(args...; kwargs...) = _call_jump!(set_bounds!, args...; kwargs...)


"""
    fix!(model::JuMP.Model, var, idx; kwargs...)
This function fixes a model variable `model[var][idx]` if its start value meets a specified
condition.

# Arguments
- `model::JuMP.Model` to update
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to update
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to set bounds.

# Keyword Arguments
- `values::Real=NaN`, to which to fix the JuMP Variable if it meets the condition.
    If `value==NaN`, as is specified by default, fix the variable based on its start value.
- `condition::Function=isreal`, that determines whether to fix the value. By default, all
    Real-valued start values will be fixed. If, for instance, `condition=iszero`, is given,
    all variables with start values of zero will be fixed to zero.
    Non-zero values will not be fixed.
- `force::true`, passed to JuMP.fix
"""
function fix!(model::Model, var::Symbol, idx::Tuple;
    condition::Function=isreal,
    value::Real=NaN,
    force=true,
)
    if !isnan(value)
        fix(model[var][idx...], value, force=force)
    else
        value = SLiDE._start_value(model, var, idx)
        # condition(value) && SLiDE.fix!(model, var, idx; value=value)
        condition(value) && fix(model[var][idx...], value, force=force)
    end
    return nothing
end

function fix!(model::Model, var::Symbol, idx::String;
    condition::Function=isreal,
    value::Real=NaN,
    force=true,
)
    if !isnan(value)
        fix(model[var][idx], value, force=force)
    else
        value = SLiDE._start_value(model, var, idx)
        # condition(value) && SLiDE.fix!(model, var, idx; value=value)
        condition(value) && fix(model[var][idx], value, force=force)
    end
    return nothing
end

fix!(args...; kwargs...) = _call_jump!(fix!, args...; kwargs...)


"""
    fix_lower_bound!(model::JuMP.Model, var, idx; kwargs...)
This function fixes a model variable `model[var][idx]` if its start value meets a specified
condition using [`SLiDE.fix!`](@ref), OR sets its lower bound using [`SLiDE.set_lower_bound!`](@ref).

# Arguments
- `model::JuMP.Model` to update
- `var::Symbol` or `var::AbstractArray`: variable or list of variables to update
- `idx::Symbol`, `idx::Tuple`, or `idx::AbstractArray`: index or list of indices overwhich
    to set bounds.

# Keyword Arguments
See [`SLiDE.fix!`](@ref) and [`SLiDE.lower_bound`](@ref)
"""
function fix_lower_bound!(model::Model, var::Symbol, idx::Union{String,Tuple}; kwargs...)
    if iszero(_start_value(model, var, idx))
        fix!(model, var, idx)
    else
        set_lower_bound!(model, var, idx; kwargs...)
    end
end

fix_lower_bound!(args...; kwargs...) = _call_jump!(fix_lower_bound!, args...; kwargs...)


"""
"""
function _call_jump!(f::Function, model::Model, var::Symbol, idx::AbstractArray; kwargs...)
    if any(SLiDE.isarray.(idx))
        idx = permute(ensurearray.(idx)...)
    end
    [f(model, var, x; kwargs...) for x in idx]
    return nothing
end


function _call_jump!(f::Function, model::Model, var::AbstractArray, idx; kwargs...)
    [_call_jump!(f, model, v, idx; kwargs...) for v in var]
    return nothing
end


function _call_jump!(f::Function, model::Model, var::Symbol; kwargs...)
    idx = permute(model[var].axes)
    _call_jump!(f, model, var, idx; kwargs...)
    return nothing
end


function _call_jump!(f::Function, model::Model, var::AbstractArray; kwargs...)
    [_call_jump!(f, model, v; kwargs...) for v in var]
    return nothing
end


function _call_jump!(f::Function, model::Model; kwargs...)
    # var = [k for (k,v) in model.obj_dict if typeof(v) <: JuMP.Containers.DenseAxisArray]
    var = _oftype_in(JuMP.Containers.DenseAxisArray{VariableRef}, model)
    for v in var
        println("Applying $f to $v")
        _call_jump!(f, model, v; kwargs...)
    end
    return nothing
end


function _call_jump!(f::Function, model::Model, var::InvertedIndex; kwargs...)
    var = setdiff(
        _oftype_in(JuMP.Containers.DenseAxisArray{VariableRef}, model),
        ensurearray(var.skip),
    )
    for v in var
        println("Applying $f to $v")
        _call_jump!(f, model, v; kwargs...)
    end
    return nothing
end


function _oftype_in(::Type{T}, model::Model) where T<:Any
    return [k for (k,v) in model.obj_dict if typeof(v) <: T]
end