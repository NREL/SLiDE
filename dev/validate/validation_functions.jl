"""
This function reads files specified in the input yaml file. BUT WITH A CATCH! If there is
a gdx and its affiliated shell script in the directory we're reading from, it will first
execute that shell script to extract the data from the gdx file before we can read the csv
files it produces.
"""
function read_with_gdx(file::String)
    y = read_file(file)
    path = joinpath(SLIDE_DIR, ensurearray(y["Path"])...)
    files = readdir(path)
    script = files[occursin.(".sh", files)][1]

    curr_dir = pwd()
    cd(path)
    run(`bash $script`)
    cd(curr_dir)

    return read_from(file)
end

"""
Given a comparison dictionary generated by `benchmark_against`, return 2 dictionaries:
    1. DataFrames indicating which indices are missing vs. present.
    2. The maximum value present where, in the benchmark DataFrame, this value is missing.
        This will tell us where we might need to cut off small values.
"""
function SLiDE.compare_keys(d::Dict)
    d = copy(d)
    [d[k] = any(.!df[:,:equal_keys]) ? df[.!df[:,:equal_keys],:] : true
        for (k,df) in d if df !== true]
    d_max = Dict(k => maximum(df[:,:calc_value]) for (k,df) in d if df !== true)
    return (d, d_max)
end

"""
This function returns a DataFrame comparing the minimum values in each input DataFrame.
A column "attn" marks minimum values of different orders of magnitude.
"""
function compare_minimum(d_calc::Dict, d_bench::Dict)
    df = DataFrame()
    for k in intersect(keys(d_calc), keys(d_bench))
        df_temp = DataFrame(param=k,
            calc=minimum(abs.(d_calc[k][:,:value])),
            bench=minimum(abs.(d_bench[k][:,:value])),
        )
        df = [df; df_temp]
    end
    df[!,:attn] .= length.(unique.(eachrow(floor.(log10.(df[:,findvalue(df)]))))) .> 1
    return df
end

function compare_tolerance(d_calc::Dict, d_bench::Dict)
    df = DataFrame()
    tols = [1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1]
    for tol in tols
        comp = benchmark_against(d_calc, d_bench; tol = tol)
        summ = Dict(k => v !== true ? size(v,1) : 0 for (k,v) in comp)
        df = [df; [DataFrame(tol = tol) DataFrame(summ)]]
    end
    return df
end