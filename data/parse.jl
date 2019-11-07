using CSV
using DataFrames
using Dates
using XLSX
using YAML

import YAML

# ------------------------------------------------------------------------------
#               FUNCTIONS
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
function convert_type(type::String, x::Any)
    """
    This function converts input values x to the type specified in the string
    type. This was written as a work-around for the convert function, which
    cannot convert to strings or symbols. Making these conversions ensures the
    yaml file info is the correct DataType for DataFrame manipulation.
    """
    type = lowercase(type)

    if     occursin("symbol", type);  x = Symbol.(x)
    elseif occursin("string", type);  x = string.(x)
    elseif occursin("float",  type);  x = parse.(Float64, string.(x))
    elseif occursin("int",    type)
        x = (typeof(x[1]) == Date) ? map(k -> Dates.year(k), x) :
            parse.(Int64, string.(x))
    end
    return x
end

# ------------------------------------------------------------------------------
function convert_yaml_structure(x, y)
    """
    This function converts data in the YAML input dictionary y into the types
    specified in the yaml structure dictionary x. This will simplify future
    DataFrame manipulation.
    """
    shared_keys = intersect(keys(x), keys(y))

    for s in shared_keys

        df = (typeof(y[s]) == Dict{Any,Any}) ? DataFrame(y[s]) :
            DataFrame(Dict(k => [d[k] for d in y[s]] for k in keys(y[s][1])))
    
        y[s] = [Dict(string(k) => convert_type(x[s][string(k)], row[k])
            for k in names(row)) for row in eachrow(df)]
    end

    return y
end

# ------------------------------------------------------------------------------
function read_dataframe_from_yaml(filepath::String, file::Dict)
    """
    This function imports a file into a DataFrame. The methodology differs
    depending on the file type (.csv, .xlsx), but the result will be the same.
    """
    input = string(filepath, "/", file["name"])
    
    if occursin(".xlsx", input)
        xf = XLSX.readdata(input, file["sheet"], file["range"])
        df = DataFrame(xf[2:end,:], Symbol.(xf[1,:]))
    elseif occursin(".csv", input)
        df = CSV.read(input)
    end

    return df
end

# ------------------------------------------------------------------------------
function read_yaml(filename::String)
    """
    """
    global yaml_structure
    y = YAML.load(open("readfiles/$filename.yml"))
    y = convert_yaml_structure(yaml_structure, y)
    return y
end

# ------------------------------------------------------------------------------
#               MORE FUNCTIONS
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
function map_with_dataframe(input, mapfile::String;
    from::Symbol = :from, to::Symbol = :to)
    """
    This function maps a dataframe column into a new column based on values
    read from a map stored in a .csv file.
    """

    df_map = CSV.read("core_maps/$mapfile.csv")
    dict_map = Dict(k => v for (k, v) in zip(df_map[!, from], df_map[!, to]))

    output = map(x -> dict_map[x], input);
    return output
end

# ------------------------------------------------------------------------------
function edit_dataframe_from_yaml(df::DataFrame, y::Dict)
    """
    """
    
    # RENAME -- Columns 'from' -> 'to'.
    try;   rename!(df, [d["from"] => d["to"] for d in y["renaming"]])
    catch; nothing
    end

    # MELT -- Normalize the dataframe by 'melting' columns into rows.
    # This will lengthen the dataframe by duplicating values in the column 'on'
    # into new rows. This will define two new columns.
    #   (1) 'var' (of 'type') with header names from the original dataframe.
    #   (2) 'val' with column values from the original dataframe.
    try
        for d in y["melting"]
            df = melt(df, d["on"], variable_name = d["var"], value_name = d["val"])
            df[!, d["var"]] = convert_type(d["type"], df[!, d["var"]])
        end
    catch; nothing
    end

    # SET -- Define a column 'col' and set all elements to the value 'val'.
    try;   [df[!, d["col"]] .= d["val"] for d in y["setting"]]
    catch; nothing
    end

    # MAP -- Define an 'output' column containing values based on those in an
    # 'input' column. The mapping columns 'from' -> 'to' are contained in a
    # .csv 'file' in the core_maps directory. The columns 'input' and 'from'
    # should contain the same values, as should 'output' and 'to'.
    try
        [df[!, d["output"]] .= map_with_dataframe(df[!, d["input"]], d["file"];
            from = d["from"], to = d["to"]) for d in y["mapping"]]
    catch; nothing
    end

    # REPLACE -- Values 'from' in the column 'col' with values 'to'.
    try
        [df[!, d["col"]][df[:, d["col"]] .== d["from"]] .= d["to"]
            for d in y["replacing"]]
    catch; nothing
    end

    return df
end

# ------------------------------------------------------------------------------
#               MAIN
# ------------------------------------------------------------------------------
yaml_structure = YAML.load(open("readfiles/read_structure.yml"))

y = read_yaml("read_bea_supply");
# y = read_yaml("read_bea_use");
# y = read_yaml("read_crude_oil");
# y = read_yaml("read_emissions");
# y = read_yaml("read_heatrate");

df = DataFrame()

for f in y["file_in"]

    df_temp = read_dataframe_from_yaml(y["path_in"], f);
    df_temp = edit_dataframe_from_yaml(df_temp, y);
    df_temp = first(df_temp, 3);

    try;   [df_temp[!, d["col"]] .= f[d["val"]] for d in y["appending"]];
    catch; nothing
    end

    global df = vcat(df, df_temp)

end

# Reorder columns.
cols = [Symbol(k) for c in y["col_out"] for k in keys(c)]
df = df[!, cols]

# Set columns to the correct type.
types = Dict(Symbol(k) => v for c in y["col_out"] for (k,v) in c)
[df[!, c] .= convert_type(types[c], df[!, c]) for c in cols]

df