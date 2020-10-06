using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

using SLiDE

READ_DIR = joinpath("data", "readfiles")

function read_to_check(x::String)
    y = read_file(x)
    d = Dict(k => sort(read_file(joinpath(SLIDE_DIR, y["Path"]..., ensurearray(v["name"])...)))
        for (k,v) in y["Input"])
    return Dict(Symbol(k) => edit_with(v, Rename.(propertynames(v), Symbol.(y["Input"][k]["col"])))
        for (k,v) in d)
end

y = read_file(joinpath("data", "readfiles", "list_sets.yml"));
set = Dict((length(ensurearray(k)) == 1 ? Symbol(k) : Tuple(Symbol.(k))) =>
    sort(read_file(joinpath(y["Path"]..., ensurearray(v)...)))[:,1] for (k,v) in y["Input"])