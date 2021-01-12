using SLiDE
using DataFrames

# fbn = read_from("dev/readfiles/7_sectordisagg_int.yml"; run_bash=true)

f_set = joinpath(SLIDE_DIR,"src","build","readfiles","setlist_1.0.1.yml");
set = read_from(f_set);
set[:s_sum] = copy(set[:s])
set[:g_sum] = copy(set[:g])

set_det = copy(set)
set_det[:g] = set[:g_det]
set_det[:s] = set[:s_det]

d = Dict()
d[:use_det] = read_file(path*"use_det.csv")
d[:supply_det] = read_file(path*"supply_det.csv")
d[:sector] = :detail

d = partition("state_model_det", d, set_det; save_build=true)


function _share_sector!(d::Dict)
    df = copy(d[:y0])
    col = [:yr,:summary,:detail,:value]

    x = [
        Rename(:g,:detail);
        Map("scale/sector/bluenote.csv",[:detail_code],[:summary_code],[:detail],[:summary],:left);
    ]

    df = select(edit_with(df,x),col)
    d[:share] = df / combine_over(df,:detail)
    return d[:share]
end




df_det = _share_sector!(d)

df_sum = fill_with((yr=[2007,2012],summary=set[:s]), 1.)


x_det = [
    Rename.([:detail,:summary],:disagg);
    Map(joinpath("scale","sector","eem_sectors.csv"),[:disagg_code],[:disagg_code],[:disagg],[:disagg],:inner);
]
# x_sum = Map(joinpath("scale","sector","eem_sectors.csv"),[:disagg_code],[:aggr_code],[:summary],[:aggr],:inner)
df_det = edit_with(df_det, x_det)


df_sum = df_sum - combine_over(df_det, [:detail,:aggr])




# split_with / something from the eem utils? I think this will help!
# 
# start with all shares = 1.
# 


# df_share = fill_with((yr=[2007,2012],summary=set[:s]), 1.)

# LET'S SEE.. Do these things add up?
# d[:use]


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
# SLiDE._partition_a0!(f, set_det)