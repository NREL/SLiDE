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