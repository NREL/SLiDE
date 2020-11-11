"""
    read_file(file::String)
    read_file(path::Array{String,1}, file<:File; kwargs...)
    read_file(path::Array{String,1}, file::XLSXInput)
    read_file(path::String, x::T) where T<:File
    read_file(editor::T) where T<:Edit
This method to reads .csv mapping files required for editing. These files must be stored in
the `data/coremaps` directory. It returns a .csv file.

# Arguments
- `path::Array{String,1}` or `path::String`: Path to file *location*;
    does not include file name.
- `file::String`: Full path to file, including file name.
- `file<:File`: A SLiDE DataType used to store information about a file. Options include:
    - [`SLiDE.CSVInput`](@ref)
    - [`SLiDE.XLSXInput`](@ref)
    - [`SLiDE.GAMSInput`](@ref)
    - [`SLiDE.SetInput`](@ref)
    - [`SLiDE.DataInput`](@ref)
- `editor<:Edit`: A SLiDE DataType used to store information about an edit to make in a
    DataFrame. Specifically, this function might be called for edit types that include the
    field `file` in reference to 
    - [`SLiDE.Group`](@ref)
    - [`SLiDE.Map`](@ref)

# Returns
- `df::DataFrame`: If the input is a csv or xlsx file, this method will return a DataFrame.
- `yml::Dict{Any,Any}`: If the input file is a yaml file, this method will return a
    dictionary. All keys that correspond with SLiDE DataStream DataTypes will be converted
    to (lists of) those types.
"""
function read_file(path::Array{String,1}, file::GAMSInput)
    filepath = joinpath(path..., file.name)
    xf = readlines(filepath)
    df = gams_to_dataframe(xf; colnames=file.col)
    return df
end


function read_file(path::Array{String,1}, file::CSVInput)
    filepath = joinpath(path..., file.name)
    df = _read_csv(filepath)
    df = _remove_header(df, filepath)
    df = _remove_footer(df)
    df = _remove_empty(df)
    return df
end


function read_file(path::Array{String,1}, file::XLSXInput)
    filepath = joinpath(path..., file.name)
    xf = XLSX.readdata(filepath, file.sheet, file.range)
    
    # Delete rows containing only missing values.
    xf = xf[[!all(row) for row in eachrow(ismissing.(xf))],:]
    return convert_type(DataFrame, xf)
end


function read_file(path::Array{String,1}, file::DataInput)
    df = read_file(path, convert_type(CSVInput, file))
    df = edit_with(df, Rename.(propertynames(df), file.col))

    (:value in propertynames(df)) && (df[!,:value] .= convert_type.(Float64, df[:,:value]))
    return df
end


function read_file(path::Array{String,1}, file::SetInput)
    filepath = joinpath(path..., file.name)
    df = _read_csv(filepath)
    return sort(df[:,1])
end


function read_file(path::String, file::T) where T <: File
    return read_file([path], file)
end


function read_file(editor::T) where T <: Edit
    DIR = joinpath("data", "coremaps")
    df = read_file(joinpath(DIR, editor.file))
    return df
end


function read_file(file::String; colnames=false)
    file = joinpath(file)

    if occursin(".map", file) | occursin(".set", file)
        return gams_to_dataframe(readlines(file); colnames=colnames)
    end

    if occursin(".yml", file) | occursin(".yaml", file)
        y = YAML.load(open(file))
        # Here, we first list all sub-subtypes of DataStream (DataTypes that are used in
        # editing datasource files). Then, we find where they overlap with keys in the
        # dictionary read from the YAML file.
        TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...; IU.subtypes(CGE)])
        KEYS = intersect(TYPES, collect(keys(y)))
        [y[k] = load_from(datatype(k), y[k]) for k in KEYS]
        return y
        
    elseif occursin(".csv", file)
        df = _read_csv(file)
        return df
    end
end


"""
"""
function _read_csv(filepath::String; header::Int=1)
    return CSV.read(filepath, DataFrame,
        silencewarnings=true,
        ignoreemptylines=true,
        comment="#",
        missingstrings=["","\xc9","..."];
        header=header)
end


"""
This function removes footer rows. These are identified by rows at the bottom of the sheet
that are empty with the exception of the first column.
"""
function _remove_footer(df::DataFrame)
    N = size(df,1)
    while all(ismissing.(values(df[N,2:end])))
        N -= 1
    end
    return df[1:N,:]
end


"""
"""
function _remove_header(df::DataFrame, filepath::String)
    cols = propertynames(df)
    missing_cols = .|(occursin.(:Column, cols), occursin.(:missing, cols))

    # If only one column was read, maybe this is because there was a problem?
    if size(df,2) == 1
        @warn("Removing header WITH reading ($filepath)")
        xf = DelimitedFiles.readdlm(filepath, ',', Any, '\n')
        HEAD = _find_header(xf)
        df = _read_csv(filepath; header = HEAD)

    elseif sum(missing_cols) > 0
        @warn("Removing header without reading ($filepath)")
        HEAD = _find_header(df)
        df = rename(df[HEAD+1:end,:], Pair.(cols, Symbol.(ensurearray(df[HEAD,:]))))
    end
    return df
end


"""
"""
function _find_header(df::DataFrame)
    HEAD = 1
    while all(ismissing.(values(df[HEAD,2:end])))
        HEAD += 1
    end
    return HEAD
end

function _find_header(xf::Array{Any,2})
    HEAD = 1
    while all(length.(xf[HEAD,2:end]) .== 0)
        HEAD += 1
    end
    return HEAD
end


"""
Ensure there are no empty columns (those containing all missing values)
"""
_remove_empty(df::DataFrame) = df[:,eltype.(eachcol(df)) .!== Missing]


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
    # if any(isarray.(types)) && !all(isarray.(types))
    if any(isarray.(types))
        # Restructure data into a list of inputs in the order and type required when
        # creating the datatype. Ensure that all array entries should, in fact, be arrays.
        inps = [_load_as_type(T, d[f], t) for (f, t) in zip(fields, types)]
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
    isempty(df) && @error("Cannot load datatype $T from an empty DataFrame.")

    (fields, types) = (fieldnames(T), T.types)

    # Print warning if DataFrame is missing required columns.
    missing_fields = setdiff(fields, propertynames(df))
    if length(missing_fields) > 0
        @warn("DataFrame columns missing fields required to fill DataType $T" * missing_fields)
    end

    df = df[:, ensurearray(fields)]
    # If all of the struct fields are arrays, we assume all DataFrame rows should be saved.
    if all(isarray.(T.types))
        inps = [_load_as_type(T, df[:, f], t) for (f, t) in zip(fields, types)]
        lst = [T(inps...)]
    else
        lst = [T((_load_as_type(T, row[f], t) for (f, t) in zip(fields, types))...)
            for row in eachrow(df)]
    end
    return size(lst)[1] == 1 ? lst[1] : lst
end


function load_from(::Type{Dict{T}}, df::DataFrame) where T <: Any
    return Dict(_inp_key(x) => x for x in load_from(T, df))
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
            (ii_file[end] && .!any(ii_file[1:end - 1])) && (d[k] = joinpath(lst...))
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

_load_as_type(::Type{T}, entry, type::DataType) where T <: Any = _load_as_type(entry, type)
_load_as_type(::Type{Drop},    entry, type::Type{Any})    = _load_as_type(_load_case(entry), type)
_load_as_type(::Type{Rename},  entry, type::Type{Symbol}) = _load_as_type(_load_case(entry), type)
_load_as_type(::Type{Replace}, entry, type::Type{Any})    = _load_as_type(_load_case(entry), type)
_load_as_type(::Type{Operate}, entry, type::Type{Symbol}) = _load_as_type(_load_axis(entry), type)
_load_as_type(::Type{Parameter}, entry, type::Type{Array{Symbol,1}}) = _load_as_type(_load_index(entry), type)
_load_as_type(::Type{T}, entry::Missing, type::Type{String}) where T <: Any = _load_as_type(T, "", type)        # if we're reading in dataframe with missing values

"""
    _load_case(entry::AbstractString)
Standardizes string identifiers that indicate a case change (upper-to-lower or vice-versa)
for easier editing.
"""
function _load_case(entry::AbstractString)
    test = lowercase(entry)
    
    occursin("lower", test) && (entry = "lower")
    occursin("upper", test) && (entry = "uppercasefirst" == test ? "uppercasefirst" : "upper")
    occursin("titlecase", test) && (entry = "titlecase")

    "all" == test    && (entry = "all")
    "unique" == test && (entry = "unique")
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
"""
function _load_index(entry::String)
    m = match(r"^[\[|\(](?<idx>.*)[\]|\)]$", entry)
    m !== nothing && (entry = m[:idx])
    return string.(split(entry, ","))
end
_load_index(entry::Any) = entry


"""
    write_yaml(path, file::XLSXInput)
This function reads an XLSX file and writes a new yaml file containing the information in
each spreadsheet column. Sheet propertynames in the XLSX file correspond to the directory where new
files will be printed (`path/file.sheet/`). Yaml files will be named after the text in the
column's first row.

# Arguments
- `path::String` or `path::Array{String,1}`: XLSX file location. New yaml files will be
    printed here, as well.
- `file::XLSXInput` or `files::Array{XLSXInput,1}`: XLSX file information (file name, sheet name, sheet range) or list of multiple sheets.

# Returns
- `filenames::Array{String,1}`: List of yaml files
"""
function write_yaml(path, file::XLSXInput; overwrite::Bool = true)
    @info("Generating yaml files from " * file.name * "\n\tSheet: " * file.sheet)

    # Aesthetics: Define a message to print at the top of the YAML file and
    # list all key words in the yaml file and use to add (purely aesthetic) spacing.
    HEADER = "# Autogenerated from " * joinpath(path, file.name) * ", sheet: " * file.sheet
    KEYS = string.([IU.subtypes.(IU.subtypes(DataStream))...; "PathIn"], ":")
    
    # Read the XLSX file, identify relevant (not "missing") columns,
    # and generate list of resultant yaml file propertynames.
    println("  Reading ", file.name)
    df = read_file(path, file)
    df = df[:, .!occursin.(:missing, propertynames(df))]

    # Make sure the path exists and save the names of yaml files to generaate.
    # path = joinpath(SLIDE_DIR, path, file.sheet)
    path = joinpath(path, file.sheet)
    !isdir(path) && mkpath(path)

    files = [joinpath(path, "$k.yml") for k in propertynames(df)]
    
    # Iterate through columns. For each column, create a new yaml file and fill it with
    # the column text. Mark the yaml file as "Autogenerated" and ensure one space only
    # between each input file element that corresponds with a SLiDE Datastream subtype.
    for (col, yamlfile) in zip(propertynames(df), files)

        if overwrite == false && isfile(yamlfile)
            println("  Skipping overwrite. Found: $yamlfile")
        else
            println("  Generating $yamlfile")

            lines = dropmissing(df, col)[:,col]
            lines = lines[match.(r"\S.*", lines) .!== nothing]

            open(yamlfile, "w") do f
                println(f, HEADER)
                for line in lines
                    any(occursin.(KEYS, line)) && (println(f, ""))
                    println(f, line)
                end
            end
        end
    end
    return files
end


function write_yaml(path::Array{String,1}, file::XLSXInput; overwrite::Bool=true)
    write_yaml(joinpath(path...), file; overwrite=overwrite)
end


function write_yaml(path, files::Array{XLSXInput,1}; overwrite::Bool=true)
    if length(unique(get_descriptor.(files))) < length(files)
        @error("Input XLSX files must have unique descriptors.")
    end
    files = Dict(_inp_key(file) => file for file in files)
    files = Dict(k => write_yaml(path, file; overwrite=overwrite) for (k,file) in files)
    return files
end


"""
    run_yaml(filename::String)
    run_yaml(filenames::Array{String,1})
This file runs (a) yaml file(s) if it includes the line `Editable: true`. If given a list of
input files, the function will print a list of yaml files that were not marked as editable.
A file might not be "editable" if SLiDE functionality cannot make all of the specified edits.

# Arguments
- `filename::String` or `filenames::Array{String,1}`: yaml file name (or list of propertynames) to run

# Return
- `filename::String` or `filenames::Array{String,1}`: yaml file name (or list of propertynames) that
    was/were not ran by the function because they were annotated with `Editable: false`
"""
function run_yaml(filename::String; save::Bool=true)
    println("\n$filename")
    println("  Reading yaml file...")

    y = read_file(filename)

    if haskey(y, "Editable") && y["Editable"]
        # Iteratively make all edits and update output data file in accordance with
        # operations defined in the input YAML file.
        println("  Parsing and standardizing...")
        df = unique(edit_with(y))
        
        # Create the path where the output file will go if it doesn't already exist.
        if save !== false
            save_path = save == true ? "" : save

            # path = joinpath(SLIDE_DIR, save_path, ensurearray(y["PathOut"])...)
            path = joinpath(save_path, ensurearray(y["PathOut"])...)
            file = joinpath(path, y["FileOut"])
            !isdir(path) && mkpath(path)

            println("  Writing to $file")
            CSV.write(file, df)
        end
        return df
    else
        println("  Skipping... (not editable)")
        return filename
    end
end


function run_yaml(d::Dict; save::Bool=true)
    d_ans = Dict(k => run_yaml(d[k]; save = save) for k in keys(d))
    return d_ans
end


function run_yaml(files::Array{String,1}; save::Bool=true)
    @info("Standardize data files.")
    files = Dict(_inp_key(f, ".yml") => run_yaml(f) for f in files)
    unedited = [f for f in values(files) if typeof(f) == String]
    if length(unedited) > 0
        @warn(string("run_yaml() generated no output for:", string.("\n  ", unedited)...,
            "\nAdd \"Editable: true\" to yaml file to run automatically."))
    end
    return files
end


"""
    gams_to_dataframe(xf::Array{String,1}; colnames = false)
This function converts a GAMS map or set to a DataFrame, expanding sets into multiple rows.

# Arguments
- `xf::Array{String,1}`: A list of rows of text from a .map or a .set input file.

# Keywords
- `colnames = false`: A user has the option to specify the column propertynames of the output
    DataFrame. If none are specified, a default of `[missing, missing_1, ...]` will be used,
    consistent with the default column headers for `CSV.read()` if column propertynames are missing.

# Returns
- `df::DataFrame`: A dataframe representation of the GAMS map or set.
"""
function gams_to_dataframe(xf::Array{String,1}; colnames=false)
    # Convert the input array into a DataFrame and use SLiDE editing capabilities to split
    # each rows into columns, based on the syntax.
    df = DataFrame(missing=xf)
    df = edit_with(df, Match(Regex("^(?<missing>\\S+)\\.(?<missing_1>[\\S^,]*)\\s*\"*(?<missing_2>[^\"]*),?"),
        :missing, [:missing, :missing_1, :missing_2]))
    ROWS, COLS = size(df)
    
    # Does the DataFrame row contain a set (indicated by parentheses)?
    df_set = match.(r"^\((.*)\)", df)
    df_isset = df_set .!== nothing

    # If so, expand into multiple rows by converting the row into a dictionary -- with
    # column propertynames as keys and the set divided into a list -- and back into a DataFrame.
    df = [[DataFrame(Dict(k => df_isset[ii,k] ? string.(split(df_set[ii,k][1], ",")) : df[ii,k]
        for k in propertynames(df))) for ii in 1:ROWS]...;]
    
    # If the user specified column propertynames, apply those here and
    # return a DataFrame sorted based on the mapping values.
    colnames != false && (df = edit_with(df, Rename.(propertynames(df), colnames)))
    return COLS > 1 ? sort(df, reverse(propertynames(df)[1:2])) : sort(df)
end