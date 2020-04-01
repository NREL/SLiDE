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
    - [`SLiDE.Map`](@ref)

# Keywords

- `shorten::Bool = false` or `shorten::Int`: if an integer length is specified, the
    DataFrame will be shortened to the input value. This is meant to aid troubleshooting
    during development.

# Returns

- `df::DataFrame`: If the input is a csv or xlsx file, this method will return a DataFrame.
- `yml::Dict{Any,Any}`: If the input file is a yaml file, this method will return a
    dictionary. All keys that correspond with SLiDE DataStream DataTypes will be converted
    to (lists of) those types.
"""
function read_file(path::Array{String,1}, file::GAMSInput)
    filepath = joinpath(path..., file.name)
    xf = readlines(filepath)
    df = gams_to_dataframe(xf; colnames = file.col)
    return df
end

function read_file(path::Array{String,1}, file::CSVInput; shorten = false)
    filepath = joinpath(path..., file.name)
    df = CSV.read(filepath; silencewarnings = true, ignoreemptylines = true)

    NUMTEST = 10;

    # A column name containing the word "Column" indicates that the input csv file was
    # missing a column header. Multiple (more than 2?) columns with missing header suggests
    # that the first row in the .csv was not the header, but rather, the file began with
    # comments. Here, we find the header and reread .csv into a DataFrame.
    # CSV.read() was used rather than converting the 2-D Array read using  dlmread()
    # because this was faster, and includes the option to ignore missing rows.
    if sum(Int.(occursin.("Column", string.(names(df))))) > 2 || size(df)[2] == 1
        xf = DelimitedFiles.readdlm(filepath, ',', Any, '\n')
        xf = xf[1:NUMTEST,:]

        HEAD = findmax(sum.(collect(eachrow(Int.(length.(xf) .!= 0)))) .> 1)[2]
        df = CSV.read(filepath, silencewarnings = true, ignoreemptylines = true; 
            header = HEAD);
    end

    # Remove footer rows. These are identified by rows at the bottom of the sheet that are
    # empty with the exception of the first column.
    if all(ismissing.(values(df[end,2:end])))
        x = sum.([Int.(ismissing.(values(row))) for row in eachrow(df[end-NUMTEST:end,:])]);
        FOOT = size(df)[1] - (length(x) - (findmax(x)[2]-1))
        df = df[1:FOOT,:]
    end

    shorten != false ? df = df[1:shorten,:] : nothing
    return unique(df)
end

function read_file(path::Array{String,1}, file::XLSXInput; shorten = false)
    filepath = joinpath(path..., file.name)
    xf = XLSX.readdata(filepath, file.sheet, file.range)
    
    # Delete rows containing only missing values.
    xf = xf[[!all(row) for row in eachrow(ismissing.(xf))],:]
    df = DataFrame(xf[2:end,:], Symbol.(xf[1,:]), makeunique = true)

    shorten != false ? df = df[1:shorten,:] : nothing
    return df
end

function read_file(path::String, file::T; shorten = false) where T <: File
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

function read_file(file::String; colnames = false)

    if occursin(".map", file) | occursin(".set", file)
        return gams_to_dataframe(readlines(file); colnames = colnames)
    end

    if occursin(".yml", file) | occursin(".yaml", file)
        y = YAML.load(open(file))

        # Here, we first list all sub-subtypes of DataStream (DataTypes that are used in
        # editing datasource files). Then, we find where they overlap with keys in the
        # dictionary read from the YAML file.
        TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...;])
        # !!!! Not sure why only using subtypes without the module name gets UndefVarError.
        KEYS = intersect(TYPES, collect(keys(y)))
        
        # [y[k] = convert_type(DataFrame, y[k]) for k in KEYS]
        [y[k] = load_from(datatype(k), y[k]) for k in KEYS]
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
    Extra dataframe columns are acceptable, although that information will not be used.

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
function load_from(::Type{T}, d::Array{Dict{Any,Any},1}) where T <: Any
    lst = all(isarray.(T.types)) ? ensurearray(load_from(T, convert_type(DataFrame, d))) :
        vcat(ensurearray(load_from.(T, d))...)
    return size(lst)[1] == 1 ? lst[1] : lst
end

function load_from(::Type{T}, d::Dict{Any,Any}) where T <: Any
    # Is this a list to a filename? If given a list of directories ending in a filename,
    # join those directories in one path. This capability mac and windows compatability.
    FILES = [".csv", ".xlsx", ".txt", ".map", ".set"]
    [(typeof(lst) .== Array{String,1}) &&
            (any(occursin.(FILES, lst[end]))) &&
            (!all([any(occursin.(FILES, v)) for v in lst[1:end-1]])) ?
        d[k] = joinpath(lst...) : nothing for (k,lst) in d]

    # Fill the datatype with the values in the dictionary keys, ensuring correct type.
    it = zip(string.(fieldnames(T)), T.types)

    if any(isarray.(T.types)) & !all(isarray.(T.types))
        inps = [isarray(type) ? ensurearray(convert_type.(type, d[field])) :
            convert_type.(type, d[field]) for (field,type) in it]
        lst = [T(inps...)]
    else
        lst = ensurearray(load_from(T, convert_type(DataFrame, d)))
    end
    return size(lst)[1] == 1 ? lst[1] : lst
end

function load_from(::Type{T}, df::DataFrame) where T <: Any
    it = zip(fieldnames(T), T.types)

    # Convert the necessary DataFrame columns into the correct type,
    # and save the column names to include. This ensures the dataframe columns are imported
    # into the struct type in the correct order.
    [df[!, field] .= convert_type.(type, df[:, field])
        for (field,type) in it if field in names(df)]

    # If one of the struct fields is an ARRAY, we here assume that it is the length of the
    # entire DataFrame, and all other fields are duplicates.
    if any(isarray.(T.types))
    # if all(isarray.(T.types))
        # inps = [df[:,field] for (field,type) in it]
        inps = [isarray(type) ? df[:,field] : df[1,field] for (field,type) in it]
        lst = [T(inps...)]
    # If each row in the input df fills one and only one struct,
    # create a list of structures from each DataFrame row.
    else
        cols = [field for (field, type) in it]
        lst = [T(values(row)...) for row in eachrow(df[:,cols])]
    end
    return size(lst)[1] == 1 ? lst[1] : lst
end


"""
    write_yaml(path, file::XLSXInput)

This function reads an XLSX file and writes a new yaml file containing the information in
each spreadsheet column. Sheet names in the XLSX file correspond to the directory where new
files will be printed (`path/file.sheet/`). Yaml files will be named after the text in the
column's first row.

# Arguments

- `path::String` or `path::Array{String,1}`: XLSX file location. New yaml files will be
    printed here, as well.
- `file::XLSXInput` or `files::Array{XLSXInput,1}`: XLSX file information (file name, sheet name, sheet range) or list of multiple sheets.

# Returns
- `filenames::Array{String,1}`: List of yaml files

"""
function write_yaml(path, file::XLSXInput)

    # List all key words in the yaml file and use to add (purely aesthetic) spacing.
    KEYS = string.([IU.subtypes.(IU.subtypes(DataStream))...; ["Path", "PathOut"]], ":")
    
    # Read the XLSX file, identify relevant (not "missing"), and generate list of resultant
    # yaml file names.
    df_all = read_file(path, file)
    df_all = df_all[:, .!occursin.(:missing, names(df_all))]
    filenames = joinpath.(path, file.sheet, string.(names(df_all), ".yml"))

    # Iterate through columns. For each column, create a new yaml file and fill it with
    # the column text. Mark the yaml file as "Autogenerated" and ensure one space only
    # between each input file element that corresponds with a SLiDE Datastream subtype.
    for COL in 1:size(df_all,2)
        println("Generating ", filenames[COL])
        lines = dropmissing(df_all, COL)[:,COL]
        open(filenames[COL], "w") do f
            println(f, string("# Autogenerated from ", file.name))
            for line in lines
                any(occursin.(KEYS, line)) ? println(f, "") : nothing
                println(f, line)
            end
        end
    end
    return filenames
end

write_yaml(path::Array{String,1}, file::XLSXInput) = write_yaml(joinpath(path...), file)
write_yaml(path, files::Array{XLSXInput,1}) = vcat([write_yaml(path, f) for f in files]...)

"""
    run_yaml(filename::String)
    run_yaml(filenames::Array{String,1})

This file runs (a) yaml file(s) if it includes the line `Editable: true`. If given a list of
input files, the function will print a list of yaml files that were not marked as editable.
A file might not be "editable" if SLiDE functionality cannot make all of the specified edits.

# Arguments

- `filename::String` or `filenames::Array{String,1}`: yaml file name (or list of names) to run

# Return

- `filename::String` or `filenames::Array{String,1}`: yaml file name (or list of names) that
    was/were not ran by the function because they were annotated with `Editable: false`
"""
function run_yaml(filename::String)
    y = read_file(filename)
    if haskey(y, "Editable") && y["Editable"]
        println(string("Standardizing ", filename))
        df = unique(edit_with(y))
        CSV.write(joinpath(y["PathOut"]...), df)
        return nothing
    else
        return filename
    end
end

function run_yaml(filenames::Array{String,1})
    filenames = [run_yaml(f) for f in filenames]
    filenames = filenames[filenames .!== nothing]
    length(filenames) > 0 ? @warn(string("run_yaml() generated no output for:",
        string.("\n  ", filenames)...,
        "\nAdd \"Editable: true\" to yaml file to run automatically.")) : nothing
    return filenames
end

"""
    gams_to_dataframe(xf::Array{String,1}; colnames = false)

This function converts a GAMS map or set to a DataFrame, expanding sets into multiple rows.

# Arguments

- `xf::Array{String,1}`: A list of rows of text from a .map or a .set input file.

# Keywords

- `colnames = false`: A user has the option to specify the column names of the output
    DataFrame. If none are specified, a default of `[missing, missing_1, ...]` will be used,
    consistent with the default column headers for `CSV.read()` if column names are missing.

# Returns

- `df::DataFrame`: A dataframe representation of the GAMS map or set.

"""
function gams_to_dataframe(xf::Array{String,1}; colnames = false)
    # Convert the input array into a DataFrame and use SLiDE editing capabilities to split
    # each rows into columns, based on the syntax.
    df = DataFrame(missing = xf)
    df = edit_with(df, Match(Regex("^(?<missing>\\S+)\\.(?<missing_1>[\\S^,]*)\\s*\"*(?<missing_2>[^\"]*),?"),
        :missing, [:missing, :missing_1, :missing_2]))
    ROWS, COLS = size(df)

    # Does the DataFrame row contain a set (indicated by parentheses)?
    df_set = match.(r"^\((.*)\)", df)
    df_isset = df_set .!== nothing

    # If so, expand into multiple rows by converting the row into a dictionary -- with
    # column names as keys and the set divided into a list -- and back into a DataFrame.
    df = [[DataFrame(Dict(k => df_isset[ii,k] ? string.(split(df_set[ii,k][1], ",")) : df[ii,k]
        for k in names(df))) for ii in 1:ROWS]...;]
    
    # If the user specified column names, apply those here and
    # return a DataFrame sorted based on the mapping values.
    df = colnames != false ? edit_with(df, Rename.(names(df), colnames)) : df
    return COLS > 1 ? sort(df, reverse(names(df)[1:2])) : sort(df)
end