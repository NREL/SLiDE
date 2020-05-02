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
function read_file(path::Array{String,1}, file::GAMSInput; shorten = false)
    filepath = joinpath(SLIDE_DIR, path..., file.name)
    xf = readlines(filepath)
    df = gams_to_dataframe(xf; colnames = file.col)
    return df
end

function read_file(path::Array{String,1}, file::CSVInput; shorten = false)
    filepath = joinpath(SLIDE_DIR, path..., file.name)
    df = CSV.read(filepath; silencewarnings = true, ignoreemptylines = true)
    NUMTEST = min(10, size(df,1))

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
            header = HEAD)
    end

    # Remove footer rows. These are identified by rows at the bottom of the sheet that are
    # empty with the exception of the first column.
    if all(ismissing.(values(df[end,2:end])))
        x = sum.([Int.(ismissing.(values(row))) for row in eachrow(df[end-NUMTEST:end,:])])
        FOOT = size(df)[1] - (length(x) - (findmax(x)[2]-1))
        df = df[1:FOOT,:]
    end

    shorten != false && (df = df[1:shorten,:])
    return unique(df)
end

function read_file(path::Array{String,1}, file::XLSXInput; shorten = false)
    filepath = joinpath(SLIDE_DIR, path..., file.name)
    xf = XLSX.readdata(filepath, file.sheet, file.range)
    
    # Delete rows containing only missing values.
    xf = xf[[!all(row) for row in eachrow(ismissing.(xf))],:]
    df = DataFrame(xf[2:end,:], Symbol.(xf[1,:]), makeunique = true)

    shorten != false && (df = df[1:shorten,:])
    return df
end

function read_file(path::String, file::T; shorten = false) where T <: File
    return read_file([path], file; shorten = shorten)
end

# !!!! Is this method too niche?
function read_file(editor::T) where T <: Edit
    # !!!! Should we avoid including specific paths within functions?
    # !!!! Need to throw error if this is called when "file" is not a field.
    # DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data", "coremaps"))
    DIR = joinpath("data", "coremaps")
    df = read_file(joinpath(DIR, editor.file))
    return df
end

function read_file(file::String; colnames = false)
    file = joinpath(SLIDE_DIR, file)

    if occursin(".map", file) | occursin(".set", file)
        return gams_to_dataframe(readlines(file); colnames = colnames)
    end

    if occursin(".yml", file) | occursin(".yaml", file)
        y = YAML.load(open(file))
        # Here, we first list all sub-subtypes of DataStream (DataTypes that are used in
        # editing datasource files). Then, we find where they overlap with keys in the
        # dictionary read from the YAML file.
        TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...;])
        KEYS = intersect(TYPES, collect(keys(y)))
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
    lst = if all(isarray.(T.types))
        ensurearray(load_from(T, convert_type(DataFrame, d)))
    else
        vcat(ensurearray(load_from.(T, d))...)
    end
    return size(lst)[1] == 1 ? lst[1] : lst
end

function load_from(::Type{T}, d::Dict{Any,Any}) where T <: Any
    # Fill the datatype with the values in the dictionary keys, ensuring correct t.
    (fields, types) = (string.(fieldnames(T)), T.types)
    d = _load_path(d)

    # Fill the datatype with the input.
    # if length(unique(isarray.(types))) == 2
    if any(isarray.(types)) && !all(isarray.(types))
        # Restructure data into a list of inputs in the order and type required when
        # creating the datatype. Ensure that all array entries should, in fact, be arrays.
        inps = [_load_as_type(T, d[f], t) for (f,t) in zip(fields, types)]
        inpscorrect = isarray.(inps) .== isarray.(types)

        # If all inputs are of the correct structure, fill the data type.
        if all(inpscorrect)
            lst = [T(inps...)]
        # If some inputs are arrays when they shouldn't be, expand these into a new list of
        # dictionaries to create a list of datatypes, including all array values.
        # First, create a dictionary determining whether the entry needs to be split.
        # Then, split the dictionary into a list of arrays where necessary.
        else
            LEN = length(inps[findmax(.!inpscorrect)[2]])
            splitarray = Dict(fields[ii] => !inpscorrect[ii] for ii in 1:length(inps))
            lst = [Dict{Any,Any}(k => splitarray[k] ? d[k][ii] : d[k] for k in keys(d))
                for ii in 1:LEN]
            lst = ensurearray(load_from(T, lst))
        end
    else
        lst = ensurearray(load_from(T, convert_type(DataFrame, d)))
    end
    return size(lst)[1] == 1 ? lst[1] : lst
end

function load_from(::Type{T}, df::DataFrame) where T <: Any
    (fields, types) = (fieldnames(T), T.types)

    # Print warning if DataFrame is missing required columns.
    missing_fields = setdiff(fields, names(df))
    if length(missing_fields) > 0
        @warn(string("DataFrame columns missing required fields to fill DataType ", Rename),
            missing_fields)
    end

    # If one of the struct fields is an ARRAY, we here assume that it is the length of the
    # entire DataFrame, and all other fields are duplicates.
    if any(isarray.(T.types))
        inps = [_load_as_type(T, df[:, f], t) for (f,t) in zip(fields, types)]
        lst = [T(inps...)]
    # If each row in the input df fills one and only one struct,
    # create a list of structures from each DataFrame row.
    else
        lst = [T((_load_as_type(T, row[f], t) for (f,t) in zip(fields, types))...)
            for row in eachrow(df)]
    end
    return size(lst)[1] == 1 ? lst[1] : lst
end

"""
    _load_path(d::Dict)
Edits directories containing a list of directories ending in a file name as one path.
"""
function _load_path(d::Dict)
    FILES = [".csv", ".xlsx", ".txt", ".map", ".set"]
    for (k, lst) in d
        if typeof(lst) .== Array{String,1}
            ii_file = [any(occursin.(FILES, x)) for x in lst]
            (ii_file[end] && .!any(ii_file[1:end-1])) && (d[k] = joinpath(lst...))
        end
    end
    return d
end

"""
    _load_as_type(::Type{Any}, entry, type::DataType)
Converts an entry to the required DataType
"""
function _load_as_type(entry, type::DataType)
    entry = ensurearray(convert_type.(type, entry))
    (!isarray(type) && length(entry) == 1) && (entry = entry[1])
    return entry
end

_load_as_type(::Type{T}, entry, type::DataType) where T<:Any = _load_as_type(entry, type)
_load_as_type(::Type{Drop},    entry, type::Type{Any})    = _load_as_type(_load_case(entry), type)
_load_as_type(::Type{Rename},  entry, type::Type{Symbol}) = _load_as_type(_load_case(entry), type)
_load_as_type(::Type{Replace}, entry, type::Type{Any})    = _load_as_type(_load_case(entry), type)
_load_as_type(::Type{Operate}, entry, type::Type{Symbol}) = _load_as_type(_load_axis(entry), type)


"""
    _load_case(entry::AbstractString)
Standardizes string identifiers that indicate a case change (upper-to-lower or vice-versa)
for easier editing.
"""
function _load_case(entry::AbstractString)
    occursin("upper", lowercase(entry)) && (entry = "upper")
    occursin("lower", lowercase(entry)) && (entry = "lower")

    "all" == lowercase(entry)    && (entry = "all")
    "unique" == lowercase(entry) && (entry = "unique")
    return entry
end

_load_case(entry::Any) = entry

"""
    _load_axis(entry::Any)
"""
function _load_axis(entry::AbstractString)
    entry = convert_type(String, entry)
    ("1" == entry || occursin("row", lowercase(entry))) && (entry = "row")
    ("2" == entry || occursin("col", lowercase(entry))) && (entry = "col")
    return entry
end

_load_axis(entry::Any) = _load_axis(convert_type.(String, entry))



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
        open(joinpath(SLIDE_DIR, filenames[COL]), "w") do f
            println(f, string("# Autogenerated from ", file.name))
            for line in lines
                any(occursin.(KEYS, line)) && (println(f, ""))
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
        CSV.write(joinpath(SLIDE_DIR, y["PathOut"]...), df)
        return nothing
    else
        return filename
    end
end

function run_yaml(filenames::Array{String,1})
    filenames = [run_yaml(f) for f in filenames]
    filenames = filenames[filenames .!== nothing]
    if length(filenames) > 0
        @warn(string("run_yaml() generated no output for:", string.("\n  ", filenames)...,
            "\nAdd \"Editable: true\" to yaml file to run automatically."))
    end
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
    colnames != false && (df = edit_with(df, Rename.(names(df), colnames)))
    return COLS > 1 ? sort(df, reverse(names(df)[1:2])) : sort(df)
end