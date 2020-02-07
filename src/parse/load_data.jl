"""
    read_file(path::Array{String,1}, file::CSVInput)
"""
function read_file(path::Array{String,1}, file::CSVInput)
    filepath = joinpath(path..., file.name)
    df = CSV.read(filepath, silencewarnings = true)

    # Delete empty rows from the DataFrame before returning by searching for an deleting
    # rows only when the first column is empty. This should avoid deleting instances when
    # null values are `missing`.
    df = dropmissing(df, 1);

    return df
end

"""
    read_file(path::Array{String,1}, x::XLSXInput)
"""
function read_file(path::Array{String,1}, file::XLSXInput)
    filepath = joinpath(path..., file.name)
    xf = XLSX.readdata(filepath, file.sheet, file.range)
    df = DataFrame(xf[2:end,:], Symbol.(xf[1,:]), makeunique = true)

    # Delete empty rows from the DataFrame before returning by searching for an deleting
    # rows only when the first column is empty. This should avoid deleting instances when
    # null values are `missing`.
    df = dropmissing(df, 1);

    return df
end

"""
    read_file(path::String, x::T) where T<:File
"""
read_file(path::String, x::T) where T<:File = read_file([path], x)

"""
    read_from(x::T) where T <: Edit
This method to reads .csv mapping files required for editing. These files must be stored in
the `data/coremaps` directory. It returns a .csv file.
"""
# !!!! Is this method too niche?
function read_file(x::T) where T <: Edit
    DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")),
        "..", "data", "coremaps"))
    df = read_file(joinpath(DIR, x.file))
    return df
end

"""
    read_file(file::String)
This method reads a file given a string to a location alone, with no information specific to
any file type other than in the file extension. This means that the method cannot be used
for xlsx documents since, for example, there is no information about the sheet.
It IS, however, useful for:
 * yaml file: the method returns a dictionary from the YAML file.
   If any of the keys in the dictionary are IDENTICAL to a datatype,
   the dictionary value will be of this type or a list of this type.
 * csv file: the method returns a dataframe of the csv file.
"""
function read_file(file::String)
    
    if occursin(".yml", file) | occursin(".yaml", file)

        y = YAML.load(open(file))

        # Here, we first list all sub-subtypes of DataStream (DataTypes that are used in
        # editing datasource files). Then, we find where they overlap with keys in the
        # dictionary read from the YAML file.
        TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...;])
        # !!!! Not sure why only using subtypes without the module name gets UndefVarError.
        KEYS = intersect(TYPES, [k for k in keys(y)]);

        # These are the values to convert into DataFrames
        # (necessary before converting into DataStream types).
        [y[k] = convert_type(DataFrame, y[k]) for k in KEYS]

        # Next, load each key entry into lists of Edit structures.
        # This can generally be passed into the SLiDE.edit_with() function.
        [y[k] = load_from(datatype(k), y[k]) for k in KEYS];
        return y

    elseif occursin(".csv", file)
        df = CSV.read(file, silencewarnings = true)
        return df
    end

end

############################################################################################

"""
    load_from(::Type{T}, df::DataFrame) where T <: Any
This function loads a DataFrame `df` into a structure of type T.
This requires that all structure fieldnames are also DataFrame column names.

# Example:
```julia
df = DataFrame(from = ["State"], to = ["region"])
load_from(Rename, df)
```
"""
function load_from(::Type{T}, df::DataFrame) where T <: Any

    # Define an iterator that pairs field names and their associated types.
    it = zip(fieldnames(T), T.types)

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
    
    # If each row in the input df fills one and only one struct...
    else
        # Create a list of structures from each DataFrame row.
        cols = [field for (field, type) in it]
        lst = [T(values(row)...) for row in eachrow(df[:,cols])]
    end
    
    # !!!! If there is one instance of the struct, this function returns only that struct.
    # Otherwise, it returns a full list. Would it be less confusing to return a single
    # element list in this case?
    size(lst)[1] == 1 ? lst = lst[1] : nothing
    return lst

end