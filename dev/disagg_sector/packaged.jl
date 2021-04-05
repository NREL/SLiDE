function iscomplete(index::Index, lst::AbstractArray)
    df = DataFrame(index.on => lst)
    return isempty(antijoin(index.data, df, on=Pair.(index.from, index.on)))
end

function find_set(index::Index, set::Dict, levels::AbstractArray)
    df = vcat([DataFrame(index.on => set[k], :set => k) for k in levels]...)
    df = innerjoin(index.data, df, on=Pair.(index.from, index.on))
    return unique(df[:,:set])
end


"""
    share_sector!(d, set)
"""
function share_sector!(d, set;
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"),
)
    dfmap = read_file(path)[:,1:2]

    # Get the detail-level info so we can disaggregate.
    set_det = SLiDE._set_sector!(copy(set), set[:detail])
    det = merge(
        read_from(joinpath("src","build","readfiles","input","detail.yml")),
        Dict(:sector=>:detail),
    )
    SLiDE._partition_y0!(det, set_det)

    df = select(det[:y0], Not(:units));

    # Initialize scaling information.
    factor = Factor(df)
    index = Index(dfmap)
    lst = copy(set[:sector])
    
    set_scheme!(factor, index)
    share_with!(factor, index)
    filter_with!(factor, index, lst)    # what if we only have summary OR detail-level lst?

    d[:sector] = factor
    return d[:sector]
end


"""
"""
function disaggregate_sector!(d::Dict, set::Dict)
    factor = share_sector!(d, set)
    scale_sector!(d, set, factor)
    return d
end


"""
"""
function aggregate_with!(d::Dict, set::Dict;
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","eem_pmt.csv"),
)
    return aggregate_with!(d, set, read_file(path)[:,1:2])
end


function aggregate_with!(d::Dict, set::Dict, dfmap::DataFrame)
    # Define an index and its scheme to map from the current sectoral set.
    # After the build stream, this *should* be equivalent to the summary-level set.
    index = Index(dfmap)
    set_scheme!(index, DataFrame(g=set[:sector]))

    # If scaling FROM ANY detail-level codes, disaggregate summary- to detail-level
    # (or a hybrid of the two).
    if !iscomplete(index, set[:sector])
        println("INCOMPLETE")
        SLiDE._set_sector!(set, index.data[:,index.from])
        # !!!! Verify that only summary- and detail-level codes are represented in index.from
        # find_set(index, set, [:detail,:summary])
        disaggregate_sector!(d, set)
    else
        SLiDE._set_sector!(set, index.data[:,index.from])
    end
    
    dis = copy(d)
    scale_sector!(d, set, index; scale_id=:eem)
    agg = copy(d)

    return dis, agg
end