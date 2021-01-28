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
function read_file(path::Any, file::GAMSInput; remove_notes::Bool=false)
    filepath = _joinpath(path, file)
    xf = readlines(filepath)
    df = split_gams(xf; colnames=file.col)
    return df
end


function read_file(path::Any, file::CSVInput; remove_notes::Bool=false)
    filepath = _joinpath(path, file)
    df = SLiDE._read_csv(filepath)
    
    if remove_notes && size(df, 1) > 1
        df = SLiDE._remove_header(df, filepath)
        df = SLiDE._remove_footer(df)
        df = SLiDE._remove_empty(df)
    end
    return df
end


function read_file(path::Any, file::XLSXInput; remove_notes::Bool=false)
    filepath = _joinpath(path, file)
    xf = XLSX.readdata(filepath, file.sheet, file.range)
    
    # Delete rows containing only missing values.
    xf = xf[[!all(row) for row in eachrow(ismissing.(xf))],:]
    return convert_type(DataFrame, xf)
end


function read_file(path::Any, file::DataInput; remove_notes::Bool=false)
    df = read_file(path, convert_type(CSVInput, file))
    df = edit_with(df, Rename.(propertynames(df), file.col))

    (:value in propertynames(df)) && (df[!,:value] .= convert_type.(Float64, df[:,:value]))
    return df
end


function read_file(path::Any, file::SetInput; remove_notes::Bool=false)
    filepath = _joinpath(path, file)
    df = _read_csv(filepath)
    return sort(df[:,1])
end


# function read_file(path::Array{String,1}, file::T; remove_notes::Bool=false) where T <: File
#     return read_file(_joinpath(path), file; remove_notes=remove_notes)
# end


function read_file(editor::T) where T <: Edit
    filepath = _joinpath("data", "coremaps", editor.file)
    df = read_file(filepath)
    return df
end


function read_file(file::String; colnames=[])

    if occursin(".map", file) | occursin(".set", file)
        # return gams_to_dataframe(readlines(file); colnames=colnames)
        return split_gams(readlines(file); colnames=colnames)
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


function read_file(path::Union{Array{String,1}, String}...; colnames=[])
    return read_file(_joinpath(path); colnames=colnames)
end


"""
"""
_joinpath(path::String) = path
_joinpath(path::Array{String,1}) = joinpath(path...)
_joinpath(path::Union{Array{String,1}, String}...) = _joinpath(vcat(path...))
_joinpath(path::Union{Array{String,1}, String}, file::T) where T<:File = _joinpath(path, file.name)


"""
"""
function _read_csv(filepath::String; header::Int=1)
    df = CSV.read(filepath, DataFrame,
        silencewarnings=true,
        ignoreemptylines=true,
        comment="#",
        missingstrings=["","\xc9","..."];
        header=header)
    
    (header > 0 && isempty(df)) && (df = _read_csv(filepath; header=0))

    return df
end


"""
This function removes footer rows. These are identified by rows at the bottom of the sheet
that are empty with the exception of the first column.
"""
function _remove_footer(df::DataFrame)
    N = size(df, 1)
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
    if size(df, 2) == 1
        # @warn("Removing header WITH reading ($filepath)")
        xf = DelimitedFiles.readdlm(filepath, ',', Any, '\n')
        HEAD = _find_header(xf)
        df = _read_csv(filepath; header=HEAD)

    elseif sum(missing_cols) > 0
        # @warn("Removing header without reading ($filepath)")
        HEAD = _find_header(df)
        df = rename(df[HEAD + 1:end,:], Pair.(cols, Symbol.(ensurearray(df[HEAD,:]))))
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
function _remove_empty(df::DataFrame)
    LAST = size(df, 2)
    while eltype(df[:,LAST]) === Missing
        LAST -= 1
    end
    return df[:,1:LAST]
end
# _remove_empty(df::DataFrame) = df[:,eltype.(eachcol(df)) .!== Missing]


"""
    split_gams(xf::Array{String,1}; colnames = false)
This function converts a GAMS map or set to a DataFrame, expanding sets into multiple rows.

# Arguments
- `xf::Array{String,1}`: A list of rows of text from a .map or a .set input file.

# Keywords
- `colnames = []`: A user has the option to specify the column propertynames of the output
    DataFrame. If none are specified, a default of `[missing, missing_1, ...]` will be used,
    consistent with the default column headers for `CSV.read()` if column propertynames are missing.

# Returns
- `df::DataFrame`: A dataframe representation of the GAMS map or set.
"""
function split_gams(x::String)
    matches = collect(eachmatch(r"((?<=\").*(?=\")|\((?>[^()]|(?R))*\)|[\w\d]+)", x))
    return [_expand_set(matches[jj][1]) for jj in 1:length(matches)]
end


function split_gams(xf::Array{String,1}; colnames=[])
    xf = xf[xf .!== ""]                             # blank lines
    xf = xf[match.(r"^\s*SET", xf) .=== nothing]    # set definitions
    xf = xf[match.(r"^\s*\*", xf) .=== nothing]     # commented lines
    length(xf) == 0 && (return nothing)

    data = split_gams.(xf)

    if length(unique(length.(data))) == 1
        COLS = length(data[1])
        cols = isempty(colnames) ? _generate_id(COLS) : colnames
        data = if all(typeof.(data) .== Array{String,1})
            DataFrame(permutedims(hcat(data...)), cols)
        else
            vcat([DataFrame(Pair.(cols, row)) for row in data]...)
        end
    end

    return data
end


"""
"""
function _expand_set(x)
    m = match(r"^\((.*)\)$", x)
    x = (m !== nothing) ? string.(strip.(split(m[1], ","))) : string(x)
    return x
end


"""
    read_from(path::String)
This function reads information as specified by the path argument.

# Arguments
- `path::String` to a directory containing files to read *or* to a yaml file with
    information on what to read and how.

# Returns
- `d::Dict` of file contents.
"""
function read_from(path::String; ext=".csv", run_bash::Bool=false)
    d = if any(occursin.([".yml",".yaml"], path))
        _read_from_yaml(path; run_bash=run_bash)
    elseif isdir(path)
        _read_from_dir(path; ext=ext, run_bash=run_bash)
    else
        @error("Cannot read from $path. Function input must point to an existing directory or yaml file.")
    end
    return d
end


"""
    _read_from_dir(dir::String; kwargs...)
This function reads all of the files from the input directory and returns the contents of
those of the specified extension.

# Arguments
- `dir::String`: Relative path to directory to read

# Keywords
- `ext::String = ".csv"`: File extension to read and return
- `run_bash::Bool = false`: If there's a shell script in `dir`, run it to generate/update
    directory contents before reading the files.

# Returns
- `d::Dict{Symbol,Any}` of file contents where the key references the source file name.
"""
function _read_from_dir(dir::String; ext::String=".csv", run_bash::Bool=false)
    files = readdir(dir)

    # If the path contains both a .gdx file and a bash shell script, assume that the script
    # is there to execute "gdxdump" on the shell files.
    run_bash && (files = _run_bash(dir, files))

    @info("Reading $ext files from $dir.")
    files = Dict(_inp_key(f) => f for f in files if occursin(ext, f))
    d = Dict(k => read_file(joinpath(dir, f)) for (k, f) in files)

    _delete_empty!(d)

    return d
end


"""
    _delete_empty!(d::Dict)
This function removes dictionary entries with empty values.
"""
function _delete_empty!(d::Dict)
    for k in keys(d)
        if isempty(d[k])
            @warn("Removing empty entry with key $k from the dictionary.")
            delete!(d, k)
        end
    end
    return d
end

_delete_empty!(d::Any) = d


"""
    _read_from_yaml(path::String)
"""
function _read_from_yaml(path::String; run_bash::Bool=false)
    y = read_file(path)

    # If the yaml file includes the key "Path", this indicates that the yaml file 
    if "Path" in keys(y)
        # Look for shell scripts in this path, and run them if they are there.
        # If none are found, nothing will happen.
        run_bash && _run_bash(joinpath(SLIDE_DIR, ensurearray(y["Path"])...))
        
        files = ensurearray(values(find_oftype(y, File)))
        inp = "Input" in keys(y) ? y["Input"] : files
        d = SLiDE._read_from_yaml(SLiDE._joinpath(y["Path"]), inp)
        d = _edit_from_yaml(d, y, inp)
    else
        inp = ensurearray(values(find_oftype(y, CGE)))
        d = _read_from_yaml(inp)
    end
    return d
end

function _read_from_yaml(path::String, files::Dict)
    path = SLiDE._joinpath(SLIDE_DIR, path)
    d = Dict(SLiDE._inp_key(k) => read_file(SLiDE._joinpath(path, f)) for (k, f) in files)
    return SLiDE._delete_empty!(d)
end

function _read_from_yaml(path::String, files::Array{T,1}) where {T <: File}
    path = SLiDE._joinpath(SLIDE_DIR, path)
    d = Dict(SLiDE._inp_key(f) => read_file(SLiDE._joinpath(path, f)) for f in files)
    return SLiDE._delete_empty!(d)
end

# _read_from_yaml(path::Array{String,1}, file::Any) = _read_from_yaml(joinpath(path...), file)
_read_from_yaml(lst::Array{Parameter,1}) = _delete_empty!(Dict(_inp_key(x) => x for x in lst))


"""
"""
_edit_from_yaml(d::Dict, editor::Dict, files::Array) = d

_edit_from_yaml(d::Dict{Symbol,DataFrame}, editor::Dict, files::Dict) = d
# function _edit_from_yaml(d::Dict{Symbol,DataFrame}, editor::Dict, files::Dict)
#     # For when the yaml file only points to files to read and doesn't contain any edits.    
#     return Dict(k => edit_with(y) for (k,y) in d)
# end

function _edit_from_yaml(d::Dict{Symbol,Dict{Any,Any}}, editor, files)
    # For when the yaml file read contains a list of yaml files, each containing edits.
    # See: src/readfiles/build/shareinp.yml.
    return Dict(k => edit_with(y) for (k, y) in d)
    # !!!! Maybe use _read_from_yaml again here hahah.
end

function _edit_from_yaml(d::Dict{Symbol,DataFrame}, editor::Dict, files::Array{T,1}) where {T <: File}
    # For when the yaml file defines files AND edits that should be made to ALL data inputs.
    [d[_inp_key(f)] = edit_with(d[_inp_key(f)], editor, f) for f in files]
    return d
end

function _edit_from_yaml(d::Dict{Symbol,DataFrame}, editor::Dict, files::Array{DataInput,1})
    # For when the yaml file defines files AND edits that should be made to ALL data inputs.
    # This is the same as when editing an array of files EXCEPT that we order the columns
    # as specified. See: dev/readfiles/1_data_out.yml.
    [d[_inp_key(f)] = select(edit_with(d[_inp_key(f)], editor, f), f.col) for f in files]
    return d
end


"""
    _run_bash(dir::String, files)
    _run_bash(path::String)
This function runs a shell script if one is found.

# Arguments
- `path::String`: Relative path to a specific shell script to run or to a directory that
    might contain a shell script.
- `file::String` or `files::Array{String,1}`: A list of files in the specified directory.

# Returns
- `files::Array{String,1}`: An updated list of files in the specified directory after
    running the shell script if a list of files is given as an argument.
"""
function _run_bash(path::String, files::Array{String,1})
    scripts = files[occursin.(".sh", files)]
    isempty(scripts) && return
    
    # Save the current directory so we can return to it later. Enter the directory
    # containing the bash file(s), run it/them, and return to the original directory.
    # We default to iterating over a loop of an array of files, even if that array contains
    # only one file, to minimize changing directories.
    curr_dir = pwd()
    cd(path)
    for s in scripts
        @info("Running bash script $s in $path.")
        run(`bash $s`)
    end
    cd(curr_dir)
    files = readdir(path)
    return readdir(path)
end


function _run_bash(path::String)
    if isdir(path)
        _run_bash(path, readdir(path))
    elseif isfile(path) && (path[end - 2:end] == ".sh")
        dir = joinpath(splitpath(path)[1:end - 1]...)
        file = splitpath(path)[end]
        _run_bash(dir, file)
    end
end


_run_bash(path::String, file::String) = _run_bash(path, ensurearray(file))