function iscomplete(mapping::Mapping, lst::AbstractArray)
    df = DataFrame(mapping.on => lst)
    return isempty(antijoin(mapping.data, df, on=Pair.(mapping.from, mapping.on)))
end

function find_set(mapping::Mapping, set::Dict, levels::AbstractArray)
    df = vcat([DataFrame(mapping.on => set[k], :set => k) for k in levels]...)
    df = innerjoin(mapping.data, df, on=Pair.(mapping.from, mapping.on))
    return unique(df[:,:set])
end


"""
    share_sector()
"""
function share_sector( ;
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
    df = select(det[:y0], Not(:units))
    
    # Initialize scaling information.
    weighting = Weighting(df)
    mapping = Mapping(dfmap)
    
    set_scheme!(weighting, mapping)
    share_with!(weighting, mapping)

    return weighting, mapping
end


function share_sector(lst::AbstractArray;
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"),
)
    weighting, mapping = share_sector(; path=path)
    filter_with!(weighting, mapping, lst)
    return weighting, mapping, lst
end


"""
"""
function share_sector!(d, set;
    path::String=joinpath(SLIDE_DIR,"data","coremaps","scale","sector","bluenote.csv"),
)
    # Need to make sure set[:sector] !== set[:summary]
    weighting, mapping, lst = share_sector(set[:sector]; path=path)
    d[:sector] = weighting

    SLiDE._set_sector!(set, lst)
    return d[:sector]
end


"""
"""
function disaggregate_sector!(d::Dict, set::Dict)
    weighting = share_sector!(d, set)
    disaggregate_sector!(d, set, weighting)
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
    # Store dfmap as `Mapping` and set scheme based on the current sectoral set.
    # After the build stream, this *should* be equivalent to the summary-level set.
    mapping = Mapping(dfmap)
    set_scheme!(mapping, DataFrame(g=set[:sector]))

    # If scaling FROM ANY detail-level codes, disaggregate summary- to detail-level
    # (or a hybrid of the two).
    if !iscomplete(mapping, set[:sector])
        println("INCOMPLETE")
        SLiDE._set_sector!(set, mapping.data[:,mapping.from])
        # !!!! Verify that only summary- and detail-level codes are represented in mapping.from
        # find_set(mapping, set, [:detail,:summary])
        disaggregate_sector!(d, set)
    else
        SLiDE._set_sector!(set, mapping.data[:,mapping.from])
    end
    
    dis = copy(d)
    aggregate_sector!(d, set, mapping; scale_id=:eem)
    agg = copy(d)

    return dis, agg
end