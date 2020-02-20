"""
    read_file(file::String)
    read_file(path::Array{String,1}, file<:File; kwargs...)
    read_file(path::Array{String,1}, file::XLSXInput)
    read_file(path::String, x::T) where T<:File
    read_from(editor::T) where T<:Edit

This method to reads .csv mapping files required for editing. These files must be stored in
the `data/coremaps` directory. It returns a .csv file.

# Arguments

- `path::Array{String,1}` or `path::String`: Path to file *location*;
    does not include file name.
- `file::String`: Full path to file, including file name.
- `file<:File`: A SLiDE DataType used to store information about a file. Options include:
    - [`SLiDE.CSVInput`](@ref)
    - [`SLiDE.XLSXInput`](@ref)
- `editor<:Edit`: A SLiDE DataType used to store information about an edit to make in a
    DataFrame. Specifically, this function might be called for edit types that include the
    field `file` in reference to 
    - [`SLiDE.Group`](@ref)
    - [`SLiDE.Join`](@ref)
    - [`SLiDE.Map`](@ref)

# Keywords

- `shorten::Bool = false`: if true, a shortened form of the dataframe will be read.
    This is meant to aid troubleshooting during development.

# Returns

- `df::DataFrame`: If the input is a csv or xlsx file, this method will return a DataFrame.
- `yml::Dict{Any,Any}`: If the input file is a yaml file, this method will return a
    dictionary. All keys that correspond with SLiDE DataStream DataTypes will be converted
    to (lists of) those types.
"""
function read_file(path::Array{String,1}, file::CSVInput; shorten::Bool=false)
    filepath = joinpath(path..., file.name)
    df = CSV.read(filepath, silencewarnings = true, ignoreemptylines=true)

    df = shorten ? df[1:min(2,size(df)[1]),1:min(4,size(df)[2])] : df;  # dev utility
    # 
    # # Delete empty rows from the DataFrame before returning by searching for an deleting
    # # rows only when the first column is empty. This should avoid deleting instances when
    # # null values are `missing`.
    # df = dropmissing(df, 1);
    df = df[.![all(ismissing.(values(row))) for row in eachrow(df)],:]
    return df
end

function read_file(path::Array{String,1}, file::XLSXInput; shorten::Bool=false)
    filepath = joinpath(path..., file.name)
    xf = XLSX.readdata(filepath, file.sheet, file.range)
    df = DataFrame(xf[2:end,:], Symbol.(xf[1,:]), makeunique = true)

    df = shorten ? df[1:min(2,size(df)[1]),1:min(4,size(df)[2])] : df;  # dev utility
    
    # Delete empty rows from the DataFrame before returning by searching for an deleting
    # rows only when the first column is empty. This should avoid deleting instances when
    # null values are `missing`.
    df = dropmissing(df, 1);
    return df
end

function read_file(path::String, file::T; shorten::Bool=false) where T <: File
    return read_file([path], file; shorten = shorten)
end

# !!!! Is this method too niche?
function read_file(editor::T) where T <: Edit
    # !!!! Should we avoid including specific paths within functions?
    # !!!! Need to throw error if this is called when "file" is not a field.
    DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "coremaps"))
    df = read_file(joinpath(DIR, editor.file))
    return df
end

function read_file(file::String)
    if occursin(".yml", file) | occursin(".yaml", file)
        y = YAML.load(open(file))

        # Here, we first list all sub-subtypes of DataStream (DataTypes that are used in
        # editing datasource files). Then, we find where they overlap with keys in the
        # dictionary read from the YAML file.
        TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...;])
        # !!!! Not sure why only using subtypes without the module name gets UndefVarError.
        KEYS = intersect(TYPES, [k for k in keys(y)]);

        [y[k] = convert_type(DataFrame, y[k]) for k in KEYS]
        [y[k] = load_from(datatype(k), y[k]) for k in KEYS];
        return y

    elseif occursin(".csv", file)
        df = CSV.read(file, silencewarnings = true, ignoreemptylines=true)
        return df
    end
end

"""
    load_from(::Type{T}, df::DataFrame) where T <: Any
Load a DataFrame `df` into a structure of type T.

!!! note

    This requires that all structure fieldnames are also DataFrame column names.

# Arguments

- `::Type{T} where T <: Any`: Any DataType.
- `df::DataFrame`: The DataFrame storing the information to store as a DataType.

# Returns

- `x<:Any`: The DataType specified as an argument.
- `lst::Array{T} where T<:Any`: A list of elements of the DataType specified as an argument
    given a multi-row DataFrame.

# Example

```julia
df = DataFrame(from = ["State"], to = ["region"])
load_from(Rename, df)
```
"""
function load_from(::Type{T}, df::DataFrame) where T <: Any
    it = zip(fieldnames(T), T.types);

    # Convert the necessary DataFrame columns into the correct type,
    # and save the column names to include. This ensures the dataframe columns are imported
    # into the struct type in the correct order.
    [df[!, field] .= convert_type.(type, df[:, field])
        for (field,type) in it if field in names(df)]

    # If one of the struct fields is an ARRAY, we here assume that it is the length of the
    # entire DataFrame, and all other fields are duplicates.
    if any(isarray.(T.types))
        inps = [isarray(type) ? df[:,field] : df[1,field] for (field,type) in it]
        lst = [T(inps...)]
    
    # If each row in the input df fills one and only one struct,
    # create a list of structures from each DataFrame row.
    else
        cols = [field for (field, type) in it]
        lst = [T(values(row)...) for row in eachrow(df[:,cols])]
    end
    
    size(lst)[1] == 1 ? lst = lst[1] : nothing  # Don't return a single-element list
    return lst
end