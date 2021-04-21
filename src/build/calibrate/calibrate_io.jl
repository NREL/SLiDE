function calibrate(fun::Function, dataset::Dataset, io::Dict, set::Dict; kwargs...)
    step = "calibrate"
    cal = SLiDE.read_build(SLiDE.set!(dataset; step=step))

    if dataset.step=="input"
        # Initialize a DataFrame to contain results and do the calibration iteratively.
        SLiDE.set!(dataset; step=step)
        cal = Dict(k => DataFrame() for k in list!(set, dataset))
        
        for year in set[:yr]
            cal_yr = fun(io, set, year; kwargs...)
            [cal[k] = [cal[k]; cal_yr[k]] for k in keys(cal_yr)]
        end

        SLiDE.write_build!(dataset, cal)
    end
    
    return cal
end


"""
"""
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
            set[:nat] = setdiff(set[:s], set[:e])
            
            add_permutation!(set, (:r,:e))
            add_permutation!(set, (:r,:e,:e))
            add_permutation!(set, (:r,:e,:g))
            add_permutation!(set, (:r,:e,:s))
            add_permutation!(set, (:r,:g,:e))
            add_permutation!(set, (:r,:m,:e))
            
            add_permutation!(set, (:r,:nat))
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
function _calibration_input(fun::Function, d, set, ::Type{T}) where T <: Union{DataFrame,Dict}
    d, set = fun(d, set)
    T==Dict && (d = Dict(k => convert_type(Dict, fill_zero(df; with=set)) for (k,df) in d))
    return d, set
end

function _calibration_input(fun::Function, d, set, year, ::Type{T}
) where T <: Union{DataFrame,Dict}
    d = Dict(k => filter_with(df, (yr=year,); drop=true) for (k,df) in d)
    return _calibration_input(fun, d, set, T)
end


"""
"""
function _calibration_output(model::Model, set::Dict, year::Integer; region::Bool=false)
    build = region ? "eem" : "io"
    idxskip = region ? [:yr,:fdcat] : [:yr,:r,:fdcat]

    parameters = SLiDE.describe!(set, Dataset(""; build=build, step="calibrate"))

    d = Dict()
    for (k, parameter) in parameters
        if haskey(model.obj_dict, k)
            idxmodel = setdiff(parameter.index, idxskip)
            df = dropzero(convert_type(DataFrame, model[k]; cols=idxmodel))
            d[k] = select(edit_with(df, Add(:yr, year)), [:yr; idxmodel; :value])
        end
    end

    return d
end