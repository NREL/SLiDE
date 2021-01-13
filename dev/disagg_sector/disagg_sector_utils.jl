function _map_step(x::Pair, y::Pair; fun::Function=Statistics.mean)
    (COL,VAL) = (1,2)

    cut = sort([
        x[VAL][1]; x[VAL][end];
        fun.(eachrow(DataFrame(low=y[VAL][1:end-1], high=y[VAL][2:end])));
    ])

    cut = DataFrame(
        y,
        :min => convert_type.(Int,Statistics.ceil.(cut[1:end-1])),
        :max => convert_type.(Int,Statistics.floor.(cut[2:end])),
    )

    df = crossjoin(DataFrame(x), cut)
    df[!,:keep] .= (df[:,x[COL]].>=df[:,:min]) .* (df[:,x[COL]].<=df[:,:max])
    df = df[df[:,:keep], [x[COL],y[COL]]]
    return df
end


function _map_year!(set::Dict, maps::Dict; fun::Function=Statistics.mean)
    if !haskey(maps,:yr)
        maps[:yr] = _map_step(:summary=>set[:yr], :detail=>set[:yr_det]; fun=fun)
    end
    return maps[:yr]
end


function _map_year(df::DataFrame, maps::Dict; fun::Function=Statistics.mean)
# function _map_year(df::DataFrame, set::Dict, maps::Dict; fun::Function=Statistics.mean)
    col = propertynames(df)
    dfmap = edit_with(maps[:yr], Rename.(propertynames(maps[:yr]), [:x,:y]))

    df = edit_with(outerjoin(dfmap, df, on=Pair(:y,:yr)), Rename(:x,:yr))
    return df[:,col]
end

# function _map_year!(set::Dict, maps::Dict; fun::Function=Statistics.mean)
#     !haskey(maps,:yr) && (maps[:yr] = _map_year(set; fun=fun))
#     return maps[:yr]
# end

# function _map_year!(df::DataFrame, set::Dict, maps::Dict; fun::Function=Statistics.mean)
#     col = propertynames(df)
#     dfmap = _map_year!(set, maps; fun=fun)
#     df = edit_with(outerjoin(dfmap, df, on=Pair(:detail,:yr)), Rename(:summary,:yr))
#     return df[:,col]
# end

function _share_bluenote!(d::Dict)
    df = copy(d[:y0])
    col = [:yr,:summary,:detail,:value]

    # !!!! should take levels as input; what if we want (summary => something else)?
    # ...will need to have a default option for aggregating summary level up.
    x = [
        Rename(:g,:detail);
        Map(joinpath("scale","sector","bluenote.csv"),
            [:detail_code],[:summary_code],[:detail],[:summary],:left);
    ]

    df = select(edit_with(df,x),col)
    d[:share_bluenote] = df / combine_over(df,:detail)
    return d[:share_bluenote]
end


function _share_bluenote_detail!(d::Dict, path::String)
    df = _share_bluenote!(d)

    # !!!! helper function to read this map. Need to check for user-defined vs. default,
    # make sure column names are there, etc. Can find number of unique code entries to
    # figure out which is aggr/disaggr if improperly labeled. Still print warning maybe.
    # 
    # If multiple levels, maybe take :detail from input args/kwargs.
    x = Map(path,[:disagg_code],[:aggr_code],[:disagg],[:aggr],:inner)
    d[:share_detail] = edit_with(df, [Rename(:detail,:disagg),x])
    
    return d[:share_detail]
end

function _share_bluenote_summary!(d::Dict, set::Dict, path::String)
    x = Map(path,[:disagg_code],[:disagg_code,:aggr_code],[:summary],[:disagg,:aggr],:inner)
    df_sum = fill_with((yr=set[:yr_det], summary=set[:s]), 1.)
    
    df_det = _share_bluenote_detail!(d,path)

    if !isempty(df_det)
    # !!!! Could make this function iterative if we add more sectoral levels.
    # !!!! Could be the start of a fun, general approacch for regional aggregqtion.
    # Here, combine isn't really neccessary. But this will be SO helpful for cases when
    # there are multiple detail levels being edited.
        df_sum = df_sum - edit_with(df_det, Combine("sum", propertynames(df_sum)))
    end

    d[:share_summary] = edit_with(df_sum, x)
    return d[:share_summary]
end


function _share_aggregate!(d::Dict, set::Dict, path::String)
    col = [:yr,:aggr,:disagg,:summary,:value]
    d[:share] = vcat(_share_bluenote_summary!(d,set,path), d[:share_detail])
    return sort!(select!(d[:share], col), col[[1,4,3,2]])
end


function _compound_sectoral_sharing(df::DataFrame, cols::Any)
    # cols = intersect(propertynames(df), [:g,:s])
    df = [edit_with(df, Rename.([:disagg,:aggr],[col,append(col,:aggr)]))
        for col in ensurearray(cols)]
    df = length(df)==1 ? df[1] : Base.:*(df...)
    return df
end


function _compound_sectoral_sharing(df::DataFrame)
    return Dict(k => _compound_sectoral_sharing(df, ensurearray(k))
        for k in [:g,:s,(:g,:s),(:g,:m)])
end


function _aggregate_with(df::DataFrame, df_map::DataFrame)
    # Sectoral sharing dataframes. Can definitely do this once for each of the things we'll
    # iterate over.
    cols = intersect([:g,:m,:s], propertynames(df))
    isempty(cols) && (return df)

    if !isempty(setdiff(cols,propertynames(df_map)))
        df_map = _compound_sectoral_sharing(df_map, cols)
    end

    df = dropmissing(df*df_map)
    df = combine_over(df,cols)

    df = edit_with(df, Rename.(append.(cols,:aggr), cols))

    return df
end

function _aggregate_with(df::DataFrame, maps::Dict)
    cols = intersect([:g,:m,:s], propertynames(df))
    cols = length(cols)==1 ? cols[1] : Tuple(cols)
    return haskey(maps, cols) ? _aggregate_with(df, maps[cols]) : df
end

function _aggregate!(d::Dict)
    shr = _compound_sectoral_sharing(d[:share_])
    df = copy(d[:ld0]);
end


# Symbol(string(k)[1:end-1],:_,:0)
# shr = _compound_sectoral_sharing(d[:share_])
# d_new = Dict(k => _aggregate_with(d[k], shr) for k in keys(d) if k !== :share_)





# dropmissing(df * edit_with(dfmap,Rename.([:disagg,:aggr],[col,append(col,:aggr)])))


# !!!! update Map to work for file OR dataframe
# df = copy(d[:share_detail])




    # df_sum = fill_with((yr=[2007,2012],summary=set[:s]), 1.)

    # # !!!! check that user-defined scheme has correct naming.
    # # will also need to make sure path is relative to data/coremaps directory.

    # df_det = edit_with(df_det, [Rename(:detail,:disagg),x])

    # df_sum = df_sum - combine_over(df_det, [:disagg,:aggr])
    # df_sum = edit_with(df_sum, [Rename(:summary,:disagg),x])

    # d[:share_] = vcat(df_sum[:,col], df_det[:,col])
    # return sort!(d[:share_])
# end


# _mix_sector_levels!(d, joinpath("scale","sector","eem_sectors.csv"))

# set[:yr_det] = unique(d[:y0][:,:yr])

# set[:yr] = unique([set[:yr]; 2017:2020])
# set[:yr_det] = unique([set[:yr_det]; 2017])

# Extrapolate years divided at the mean.





# Dict(cut[ii,:det] => ensurearray(cut[ii,:min]:cut[ii,:max]) for ii in 1:size(cut,1))



# cols = Symbol.(yr_det[1:end-1])
# [yr[!,col] .= yr[:,:sum] .< yr[:,col] for col in cols]

# cut = DataFrame(det=yr_det[1:end-1], max=yr_max)
# ii = 1
# jj = 1

# # for ii in 1:size(yr,2)
# yr[ii,:sum] .< cut[jj,:max]

# while jj
#     yr[]
#     jj+=1
#     jj>size(yr,2) && break
# end




# # Sets and things?

# dfmap = read_file(joinpath("data","coremaps","scale","sector","bluenote.csv"))

# col = :disagg_code

# df_det = filter_with(df, (disagg_code=set[:s_det],))

# set[:ms_all] = df[:,col]
# set[:ms_det] = df_det[:,col]




# set[:s] = set[:s_det]
# set[:as] = set[:s]

# SLiDE._partition_io!(d, set_det)
# SLiDE._partition_fd!(d, set_det)
# SLiDE._partition_va0!(f, set_det)
# SLiDE._partition_x0!(f, set_det)
# SLiDE._partition_m0!(f, set_det)
# SLiDE._partition_fs0!(f, set_det)
# SLiDE._partition_y0!(d, set_det)
# SLiDE._partition_a0!(f, set_det){P<}