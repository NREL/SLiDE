function _calibration_set!(set;
    region::Bool=false,
    energy::Bool=false,
    final_demand::Bool=false,
    value_added::Bool=false,
)
    if region
        add_permutation!(set, (:r,:m))
        add_permutation!(set, (:r,:g))
        add_permutation!(set, (:r,:s))
        add_permutation!(set, (:r,:g,:s))
        add_permutation!(set, (:r,:s,:g))
        add_permutation!(set, (:r,:g,:m))
        add_permutation!(set, (:r,:m,:g))

        if energy
            set[:eneg] = ["col","ele","oil"]
            add_permutation!(set, (:r,:e))
            add_permutation!(set, (:r,:e,:e))
            add_permutation!(set, (:r,:e,:g))
            add_permutation!(set, (:r,:e,:s))
            add_permutation!(set, (:r,:g,:e))
            add_permutation!(set, (:r,:m,:e))
        end
    else
        final_demand && add_permutation!(set, (:g,:fd))
        value_added && add_permutation!(set, (:va,:s))
        
        add_permutation!(set, (:g,:s))
        add_permutation!(set, (:s,:g))
        add_permutation!(set, (:g,:m))
        add_permutation!(set, (:m,:g))
    end

    return set
end


"""
"""
function _calibration_output(model::Model, set::Dict, year::Int; region::Bool=false)
    subset = :calibrate
    idxskip = region ? [:yr,:fdcat] : [:yr,:r,:fdcat]

    lst = intersect(list_parameters!(set, subset), keys(model.obj_dict))
    param = describe_parameters!(set, subset)

    d = Dict{Symbol,DataFrame}()
    
    for k in lst
        idxmodel = setdiff(param[k].index, idxskip)
        df = dropzero(convert_type(DataFrame, model[k]; cols=idxmodel))
        d[k] = select(edit_with(df, Add(:yr, year)), [:yr; idxmodel; :value])
    end

    return d
end


"""
    set_lower_bound!
"""
function set_lower_bound!(d::Dict, lst::AbstractArray;
    zero_negative::Bool=false,
    factor::Real=NaN,
    value::Real=NaN,
    id=:lb,
)
    [set_lower_bound!(d, k; factor=factor, value=value, zero_negative=zero_negative, id=id)
        for k in lst]
    return d
end


function set_lower_bound!(d::Dict, k::Symbol;
    zero_negative::Bool=false,
    factor::Real=NaN,
    value::Real=NaN,
    id=:lb,
)
    k_id = append(k,id)
    if !haskey(d, k_id)
        d[k_id] = _lower_bound(d[k]; factor=factor, value=value, zero_negative=zero_negative)
    end
    return d[k_id]
end


# ----- MODEL ------------------------------------------------------------------------------

function set_lower_bound!(model::Model, d::Dict, var::Symbol, idx::Tuple;
    zero_negative::Bool=false,
    factor::Real=NaN,
    value::Real=NaN,
)
    set_lower_bound(
        model[var][idx...],
        _lower_bound(d[var][idx]; factor=factor, value=value, zero_negative=zero_negative),
    )
    return model[var]
end


function set_lower_bound!(model::Model, d::Dict, var::Symbol, idx;
    zero_negative::Bool=false,
    factor::Real=NaN,
    value::Real=NaN,
)
    set_lower_bound(
        model[var][idx],
        _lower_bound(d[var][idx]; factor=factor, value=value, zero_negative=zero_negative),
    )
    return model[var]
end


"""
"""
function _lower_bound(x::Real;
    zero_negative::Bool=false,
    factor::Real=NaN,
    value::Real=NaN,
)
    !isnan(value) && return value
    isnan(factor) && throw(ArgumentError("Missing argument 'factor'."))
    return zero_negative ? max.(0, factor*x) : factor*x
end


function _lower_bound(df::DataFrame;
    zero_negative::Bool=false,
    factor::Real=NaN,
    value::Real=NaN,
)
    df = copy(df)
    df[!,:value] .= _lower_bound.(df[:,:value];
        zero_negative=zero_negative,
        factor=factor,
        value=value,
    )
    return df
end


"""
    set_upper_bound!
"""
function set_upper_bound!(d::Dict, lst::AbstractArray;
    zero_negative::Bool=false,
    factor::Real=NaN,
    id=:ub,
)
    [set_upper_bound!(d, k; factor=factor, zero_negative=zero_negative, id=id) for k in lst]
    return d
end


function set_upper_bound!(d::Dict, k::Symbol;
    zero_negative::Bool=false,
    factor::Real=NaN,
    id=:ub,
)
    k_id = append(k,id)
    if !haskey(d, k_id)
        d[k_id] = _upper_bound(d[k]; factor=factor, zero_negative=zero_negative)
    end
    return d[k_id]
end


# ----- MODEL ------------------------------------------------------------------------------

function set_upper_bound!(model::Model, d::Dict, var::Symbol, idx::Tuple;
    factor::Real=NaN,
    zero_negative=false,
)
    set_upper_bound(
        model[var][idx...],
        _upper_bound(d[var][idx]; factor=factor, zero_negative=zero_negative),
    )
    return nothing
end


function set_upper_bound!(model::Model, d::Dict, var::Symbol, idx;
    factor::Real=NaN,
    zero_negative=false,
)
    set_upper_bound(
        model[var][idx],
        _upper_bound(d[var][idx]; factor=factor, zero_negative=zero_negative),
    )
    return nothing
end


"""
"""
function _upper_bound(x::Real;
    factor::Real=NaN,
    zero_negative::Bool=false,
)
    isnan(factor) && throw(ArgumentError("Missing argument 'factor'."))
    return zero_negative ? abs(factor*x) : factor*x
end


function _upper_bound(df::DataFrame;
    zero_negative::Bool=false,
    factor::Real=NaN,
)
    df = copy(df)
    df[!,:value] .= _upper_bound.(df[:,:value];
        zero_negative=zero_negative,
        factor=factor,
    )
    return df
end


"""
    zero_negative!
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
zero_negative!(d::Dict, k::Symbol) = zero_negative!(d[k])

function zero_negative!(d::Dict, lst::AbstractArray)
    [zero_negative!(d,k) for k in lst]
    return d
end


"""
"""
function describe_parameters!(set::Dict, subset::Symbol)
    if !haskey(set, subset)
        set[subset] = SLiDE.build_parameters("$subset")
    end
    return set[subset]
end


"""
"""
function list_parameters!(set::Dict, subset::Symbol)
    subset_list = append(subset,:list)
    if !haskey(set, subset_list)
        set[subset_list] = if subset==:taxes
            [:ta0,:ty0,:tm0]
        else
            collect(keys(describe_parameters!(set, subset)))
        end
    end
    return set[subset_list]
end


"""
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


function set_bounds!(model::Model, d::Dict, var::Symbol, lst::AbstractArray;
    lower_bound::Real=NaN,
    upper_bound::Real=NaN,
)
    [set_bounds!(model, d, var, x; lower_bound=lower_bound, upper_bound=upper_bound)
        for x in lst]
    return model[var]
end


function set_bounds!(model::Model, d::Dict, set::Dict, var::Symbol, idx::Tuple;
    lower_bound::Real=NaN,
    upper_bound::Real=NaN,
)
    set_bounds!(model, d, var, set[idx]; lower_bound=lower_bound, upper_bound=upper_bound)
    return model
end


"""
"""
function fix!(model::Model, d::Dict, var::Symbol, idx::Tuple;
    value::Real=NaN,
    force::Bool=true,
)
    # !!!! splatting might depend on parameter type (should do only for dense axis array)
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


function fix!(model::Model, d::Dict, var::Symbol, lst::AbstractArray;
    value::Real=NaN,
    force::Bool=true,
)
    if any(SLiDE.isarray.(lst))
        lst = permute(ensurearray.(lst)...)
    end
    [fix!(model, d, var, idx; value=value, force=force) for idx in lst]
    return model[var]
end


function fix!(model::Model, d::Dict, var::AbstractArray, lst::AbstractArray;
    value::Real=NaN,
    force::Bool=true,
)
    [fix!(model, d, v, lst; value=value, force=force) for v in var]
    return model
end


function fix!(model::Model, d::Dict, set::Dict, var, idx;
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


function fix!(model::Model, var::Symbol, lst::AbstractArray; value=NaN, force=true)
    if any(SLiDE.isarray.(lst))
        lst = permute(ensurearray.(lst)...)
    end
    [fix!(model, var, idx; value=value, force=force) for idx in lst]
    return model[var]
end


function fix!(model::Model, var::AbstractArray, lst::AbstractArray; value=NaN, force=true)
    [fix!(model, v, lst; value=value, force=force) for v in var]
    return model
end


"""
"""
function fix_lower_bound!(model::Model, d::Dict, var::Symbol, idx;
    lower_bound::Real=NaN,
    force=true,
    value=0,
)
    isnan(lower_bound) && throw(ArgumentError("Missing argument 'lower_bound'."))

    if d[var][idx]==value
        fix!(model, d, var, idx; value=value, force=force)
    else
        set_lower_bound!(model, d, var, idx; factor=lower_bound)
    end
    return model[var]
end


function fix_lower_bound!(model::Model, d::Dict, var::Symbol, lst::AbstractArray;
    lower_bound::Real=NaN,
    force=true,
    value=0,
)
    if any(SLiDE.isarray.(lst))
        lst = permute(ensurearray.(lst)...)
    end

    [fix_lower_bound!(model, d, var, x;
            lower_bound=lower_bound,
            value=value,
            force=force,
        ) for x in lst]
    return model[var]
end


function fix_lower_bound!(model::Model, d::Dict, var::AbstractArray, lst::AbstractArray;
    lower_bound::Real=NaN,
    force=true,
    value=0,
)
    [fix_lower_bound!(model, d, v, lst;
            lower_bound=lower_bound,
            value=value,
            force=force,
        ) for v in var]
    return model
end