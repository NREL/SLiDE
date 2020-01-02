using CSV
using DataFrames
using Dates
using XLSX
using YAML

import YAML

"""
    convert_type(type::String, x::Any)
Converts input values x to the type specified in the string type. This was
written as a work-around for the convert function, which cannot convert to strings or
symbols. Making these conversions ensures the yaml file info is the correct DataType for
DataFrame manipulation.
"""
function convert_type(type::String, x::Any)
    
    type = lowercase(type)

    if     occursin("symbol", type);  x = Symbol.(x)
    elseif occursin("string", type);  x = string.(strip.(string.(x)))
    elseif occursin("float",  type);  x = parse.(Float64, string.(x))
    elseif occursin("int",    type)
        x = (typeof(x[1]) == Date) ? map(k -> Dates.year(k), x) :
            parse.(Int64, string.(x))
    end
    return x
end

"""
    convert_yaml_structure(x, y)
This function converts data in the YAML input dictionary y into the types specified in the
yaml structure dictionary x. This will simplify future DataFrame manipulation.
"""
function convert_yaml_structure(x, y)
    
    shared_keys = intersect(keys(x), keys(y))

    for s in shared_keys

        df = (typeof(y[s]) == Dict{Any,Any}) ? DataFrame(y[s]) :
            DataFrame(Dict(k => [d[k] for d in y[s]] for k in keys(y[s][1])))
    
        y[s] = [Dict(string(k) => convert_type(x[s][string(k)], row[k])
            for k in names(row)) for row in eachrow(df)]
    end

    return y
end

"""
    read_dataframe_from_yaml(filepath::String, file::Dict)
This function imports a file into a DataFrame. The methodology differs depending on the file
type (.csv, .xlsx), but the result will be the same.
"""
function read_dataframe_from_yaml(filepath::String, file::Dict)
    
    input = string(filepath, "/", file["name"])
    
    if occursin(".xlsx", input)
        xf = XLSX.readdata(input, file["sheet"], file["range"])
        df = DataFrame(xf[2:end,:], Symbol.(xf[1,:]), makeunique = true)
    else

        # CSV.read() called with 'silencewarnings' enabled to prevent warnings
        # for empty cells. These will be read as 'missing'.
        df = CSV.read(input, silencewarnings = true)
        if "foot" in keys(file);  df = df[1:end-file["foot"],:];  end

    end

    return df
end

"""
    read_yaml(filename::String)
This function reads a YAML file and converts it to fit the structure in 
"""
function read_yaml(filename::String)
    """
    """
    global yaml_structure
    y = YAML.load(open("readfiles/$filename.yml"))
    y = convert_yaml_structure(yaml_structure, y)
    return y
end


"""
    map_with_dataframe(input, mapfile::DataFrame; from::Symbol = :from, to::Symbol = :to)
    map_with_dataframe(input, mapfile::String; from::Symbol = :from, to::Symbol = :to)
This function maps a dataframe column into a new column based on values read from a map
stored in a .csv file.
"""
function map_with_dataframe(input, mapfile::String; from::Symbol = :from, to::Symbol = :to)

    # CSV.read() called with 'silencewarnings' enabled to prevent warnings
    # for empty cells. These will be read as 'missing'.
    df_map = CSV.read("core_maps/$mapfile.csv", silencewarnings = true)
    dict_map = Dict(k => v for (k, v) in zip(df_map[!, from], df_map[!, to]))

    output = map(x -> dict_map[x], input);
    return output
end

function map_with_dataframe(input, mapfile::DataFrame; from::Symbol = :from, to::Symbol = :to)

    df_map = mapfile
    dict_map = Dict(k => v for (k, v) in zip(df_map[!, from], df_map[!, to]))

    output = map(x -> dict_map[x], input);
    
    return output
end

"""
    join_to_dataframe(df::DataFrame, mapfile::String; input::String, on::Symbol)
This function joins the input DataFrame to one from the DataFrame in the indicated file.
The "from" column in "df" will be joined on the "on" column in the dataframe from the
indicated file.
"""
function join_to_dataframe(df::DataFrame, mapfile::String;
    input::Symbol, on::Symbol)

    # CSV.read() called with 'silencewarnings' enabled to prevent warnings
    # for empty cells. These will be read as 'missing'.
    df_map = CSV.read("core_maps/$mapfile.csv", silencewarnings = true)

    df_join = join(df_map, rename(df, input => on), on = on)
    return unique!(df_join)

end

"""
    dataframe_joining(df::DataFrame, y::Dict)
Joins the input DataFrame df to another based on the key values in the dictionary
y["joining"].
"""
function dataframe_joining(df::DataFrame, y::Dict)

    for d in y["joining"]
        
        df[!, d["input"]][completecases(df, d["input"])] .= string.(strip.(
            df[:, d["input"]][completecases(df, d["input"])]))

        df = join_to_dataframe(df, d["file"]; input = d["input"], on = d["from"])
        df = df[!, setdiff(names(df), [d["from"]])]
        rename!(df, d["to"] => d["output"])
    end
    return df
end

"""
    dataframe_renaming(df::DataFrame, y::Dict)
Renames columns 'from' -> 'to' in the DataFrame 'df' based on key values in the dictionary
y["renaming"].
"""
function dataframe_renaming(df::DataFrame, y::Dict)
    
    if "col" in keys(y["renaming"][1])
        rename!(df, [d["from"] => d["to"] for d in y["renaming"]
            if d["from"] in [names(df)[d["col"]]]])
    else
        rename!(df, [d["from"] => d["to"] for d in y["renaming"]
            if d["from"] in names(df)])
    end

    return df
end

"""
    dataframe_melting(df::DataFrame, y::Dict)
Normalize the dataframe by 'melting' columns into rows. This will lengthen the dataframe by
duplicating values in the column 'on' into new rows. This will define two new columns.
    (1) 'var' (of 'type') with header names from the original dataframe.
    (2) 'val' with column values from the original dataframe.
"""
function dataframe_melting(df::DataFrame, y::Dict)
    
    d = copy(y["melting"][1])
    # println(d)

    if size(y["melting"])[1] > 1
        d["on"] = intersect([c["on"] for c in y["melting"]], names(df))
    end

    # println(d["on"])

    df = melt(df, d["on"], variable_name = d["var"], value_name = d["val"])
    df[!, d["var"]] = convert_type(d["type"], df[!, d["var"]])

    return df
end

"""
    dataframe_setting(df::DataFrame, y::Dict)
Define a column 'col' and set all elements to the value 'val'.
"""
function dataframe_setting(df::DataFrame, y::Dict)
    
    [df[!, d["col"]] .= d["val"] for d in y["setting"]]
    return df
end

"""
    dataframe_mapping(df::DataFrame, y::Dict)
Define an 'output' column containing values based on those in an 'input' column. The mapping
columns 'from' -> 'to' are contained in a .csv 'file' in the core_maps directory. The
columns 'input' and 'from' should contain the same values, as should 'output' and 'to'.
"""
function dataframe_mapping(df::DataFrame, y::Dict)
    
    # CSV.read() called with 'silencewarnings' enabled to prevent warnings
    # for empty cells. These will be read as 'missing'.
    df_maps = Dict(k => CSV.read("core_maps/$k.csv", silencewarnings = true)
        for k in unique([v for d in y["mapping"] for v in [d["file"]]]))
    
    for d in y["mapping"]
        df[!, d["input"]]  .= string.(strip.(df[!, d["input"]]))
        df[!, d["output"]] .= map_with_dataframe(df[!, d["input"]], df_maps[d["file"]];
            from = d["from"], to = d["to"])

        # This code works if the dictionary of map dataframes was NOT
        # defined, using the method of map_with_dataframe() that takes a
        # dataframe as an argument in place of the core_map file name.
        # df[!, d["output"]] .= map_with_dataframe(df[!, d["input"]], d["file"];
        #     from = d["from"], to = d["to"])
    end

    # This code can replace the for loop if the values to replace have
    # already been stripped of excess white space.
    # [df[!, d["output"]] .= map_with_dataframe(df[!, d["input"]], d["file"];
        # from = d["from"], to = d["to"]) for d in y["mapping"]]
    return df
end

"""
    dataframe_replacing(df::DataFrame, y::Dict)
Replace values 'from' in the column 'col' with values 'to'.
"""
function dataframe_replacing(df::DataFrame, y::Dict)
    
    # # This works if there are no missing values in the column to replace.
    # [df[!, d["col"]][df[:, d["col"]] .== d["from"]] .= d["to"]
    #     for d in y["replacing"]]
    
    # This is clunkier, but works when there are missing values. Other options:
    # (1) Create a separate "missing" dictionary in the YAML read file to
    #     handle missing values before attempting to replace other values.
    # (2) Automatically set missing values to 0 in this function.
    [df[!, d["col"]][occursin.(string(d["from"]), convert_type("string", df[:, d["col"]]))] .= d["to"]
        for d in y["replacing"]]

    return df
end

"""
    dataframe_grouping(df::DataFrame, y::Dict)
Split a DataFrame into groups indicated by the value in a new column based on the key values
in the dictionary y["grouping"].
"""
function dataframe_grouping(df::DataFrame, y::Dict)

    for d in y["grouping"]

        df[!,:start] = (1:size(df)[1]) .+ 1

        # Make matrix with info on where to split.
        df_split = join_to_dataframe(df, d["file"];
            input = d["input"], on = d["from"])
        
        sort!(unique!(df_split), :start)
        df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

        # Initialize output column.
        df[!, d["output"]] .= ""

        for row in eachrow(df_split)
            df[row[:start]:row[:stop], d["output"]] .= row[d["to"]]
        end
    end
    return df
end

"""
    dataframe_appending(df::DataFrame, df_temp::DataFrame, y::Dict, f::Dict)
This function appends a dataframe 'df_temp' to a dataframe 'df' and returns
'df', first adding the necessary columns to 'df_temp' (for example, if the
slice of data is specific to a year, a column containing that year should be
added.)
"""
function dataframe_appending(df::DataFrame, df_temp::DataFrame, y::Dict, f::Dict)

    [df_temp[!, d["col"]] .= f[d["val"]] for d in y["appending"]]
    df = vcat(df, df_temp)
    return df
end

"""
This function reorders the dataframe columns and updates their types.
"""
function dataframe_reordering(df::DataFrame, y::Dict)

    # Reorder columns.
    cols = [Symbol(k) for c in y["col_out"] for k in keys(c)]
    df = df[!, cols]

    # Set columns to the correct type.
    types = Dict(Symbol(k) => v for c in y["col_out"] for (k,v) in c)
    [df[!, c] .= convert_type(types[c], df[!, c]) for c in cols]
    return df
end

# ------------------------------------------------------------------------------
function edit_dataframe_from_yaml(df::DataFrame, y::Dict)
    """
    """
    
    if "renaming" in keys(y);  df = dataframe_renaming(df, y);  end
    if "melting" in keys(y);   df = dataframe_melting(df, y);   end
    if "setting" in keys(y);   df = dataframe_setting(df, y);   end
    if "replacing" in keys(y); df = dataframe_replacing(df, y); end
    if "mapping" in keys(y);   df = dataframe_mapping(df, y);   end

    return df
end

# ------------------------------------------------------------------------------
#               MAIN
# ------------------------------------------------------------------------------
yaml_structure = YAML.load(open("readfiles/read_structure.yml"));
yaml_all = YAML.load(open("readfiles/read_all.yml"));

# for yaml in yaml_all["file"]

#     println("reading ", yaml)

#     y = read_yaml(yaml);
#     df = DataFrame()

#     for f in y["file_in"]

#         df_temp = read_dataframe_from_yaml(y["path_in"], f);
#         df_temp = edit_dataframe_from_yaml(df_temp, y);
        
#         if "appending" in keys(y); df = dataframe_appending(df, df_temp, y, f)
#         else;                      df = df_temp
#         end

#     end

#     # df = dataframe_reordering(df, y)
#     # CSV.write(string(yaml_all["path_out"], "/" ,y["file_out"]), df)
# end

y = read_yaml("read_usatrade");
f = y["file_in"][1];

df_temp = read_dataframe_from_yaml(y["path_in"], f);
df_temp = edit_dataframe_from_yaml(df_temp, y);