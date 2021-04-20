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
"""
_start_value(model::Model, var::Symbol, idx::Tuple) = start_value(model[var][idx...])
_start_value(model::Model, var::Symbol, idx::String) = start_value(model[var][idx])


"""
"""
function _upper_bound(x::Real; factor::Real=0, value::Real=NaN, allow_negative::Bool=true)
    return if iszero(x)
        # Inf
        x
    elseif !isnan(value)
        value
    else
        allow_negative ? factor*x : abs(factor*x)
    end
end


"""
"""
function _lower_bound(x::Real; factor::Real=0, value::Real=NaN, allow_negative::Bool=true)
    return if !isnan(value)
        value
    else
        allow_negative ? factor*x : max.(0, factor*x)
    end
end


"""
"""
function set_upper_bound!(model::Model, var::Symbol, idx::Tuple; kwargs...)
    val = SLiDE._start_value(model, var, idx)
    !iszero(val) && set_upper_bound(model[var][idx...], _upper_bound(val; kwargs...))
    # set_upper_bound(model[var][idx...], SLiDE._upper_bound(val; kwargs...))
    return nothing
end


function set_upper_bound!(model::Model, var::Symbol, idx::String; kwargs...)
    val = SLiDE._start_value(model, var, idx)
    !iszero(val) && set_upper_bound(model[var][idx], _upper_bound(val; kwargs...))
    # set_upper_bound(model[var][idx], SLiDE._upper_bound(val; kwargs...))
    return nothing
end


set_upper_bound!(args...; kwargs...) = _call_jump!(set_upper_bound!, args...; kwargs...)


"""
"""
function set_lower_bound!(model::Model, var::Symbol, idx::Tuple; kwargs...)
    val = _start_value(model, var, idx)
    set_lower_bound(model[var][idx...], _lower_bound(val; kwargs...))
    return nothing
end


function set_lower_bound!(model::Model, var::Symbol, idx::String; kwargs...)
    val = _start_value(model, var, idx)
    set_lower_bound(model[var][idx], _lower_bound(_start_value(model, var, idx); kwargs...))
    return nothing
end


set_lower_bound!(args...; kwargs...) = _call_jump!(set_lower_bound!, args...; kwargs...)


"""
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
"""
function fix!(model::Model, var::Symbol, idx::Tuple;
    condition::Function=isreal,
    value::Real=NaN,
    force=true,
)
    if !isnan(value)
        fix(model[var][idx...], value, force=force)
    else
        val = _start_value(model, var, idx)
        condition(val) && fix(model[var][idx...], val, force=force)
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
        val = _start_value(model, var, idx)
        condition(val) && fix(model[var][idx], val, force=force)
    end
    return nothing
end

fix!(args...; kwargs...) = _call_jump!(fix!, args...; kwargs...)


"""
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
    var = _oftype_in(JuMP.Containers.DenseAxisArray, model)
    for v in var
        println("Applying $f to $v")
        _call_jump!(f, model, v; kwargs...)
    end
    return nothing
end


function _call_jump!(f::Function, model::Model, var::InvertedIndex; kwargs...)
    var = setdiff(
        _oftype_in(JuMP.Containers.DenseAxisArray, model),
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