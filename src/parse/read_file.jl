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
function read_file(path, file::T; kwargs...) where T<:File
    return read_file(joinpath!(path, file); kwargs...)
end


function read_file(file::GAMSInput; kwargs...)
    return _read_gams(file.name; colnames=file.col, id=file.descriptor)
end


function read_file(file::CSVInput; remove_notes::Bool=false, kwargs...)
    df = SLiDE._read_csv(file.name)

    if remove_notes && size(df, 1) > 1
        df = SLiDE._remove_header(df, file.name)
        df = SLiDE._remove_footer(df)
        df = SLiDE._remove_empty(df)
    end
    return df
end


function read_file(file::TXTInput; kwargs...)
    return _read_txt(file.name; colnames=file.col)
end


function read_file(file::XLSXInput; kwargs...)
    xf = XLSX.readdata(file.name, file.sheet, file.range)
    
    # Delete rows containing only missing values.
    xf = xf[[!all(row) for row in eachrow(ismissing.(xf))],:]
    return convert_type(DataFrame, xf)
end


function read_file(file::DataInput; kwargs...)
    df = read_file(convert_type(CSVInput, file); kwargs...)
    df = edit_with(df, Rename.(propertynames(df), file.col))
    return convert_type!(df,:value,Float64)
end


function read_file(path::Any, file::SetInput; kwargs...)
    filepath = _joinpath(path, file)
    df = _read_csv(filepath)
    return sort(df[:,1])
end


function read_file(editor::T) where T<:Edit
    return read_file(_joinpath("data", "coremaps", editor.file))
end


function read_file(file::String; kwargs...)
    ext = splitext(file)[end]

    if ext in [".gms",".map",".set"]
        return _read_gams(file; kwargs...)
    end

    if ext in [".yml",".yaml"]
        y = YAML.load(open(file))
        # Here, we first list all sub-subtypes of DataStream (DataTypes that are used in
        # editing datasource files). Then, we find where they overlap with keys in the
        # dictionary read from the YAML file.
        TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...; IU.subtypes(CGE)])
        KEYS = intersect(TYPES, collect(keys(y)))
        [y[k] = load_from(datatype(k), y[k]) for k in KEYS]
        return y
        
    elseif ext in [".csv"]
        df = _read_csv(file)
        return df
    end
end


function read_file(path::Union{Array{String,1}, String}...; kwargs...)
    return read_file(_joinpath(path); kwargs...)
end


"""
"""
_joinpath(path::String) = path
_joinpath(path::Array{String,1}) = joinpath(path...)
_joinpath(path::Union{Array{String,1}, String}...) = _joinpath(vcat(path...))
_joinpath(path::Union{Array{String,1}, String}, file::T) where T<:File = _joinpath(path, file.name)

function joinpath!(path, file::T) where T<:File
    file.name = _joinpath(path, file)
    return file
end


# ----- CSV FILE SUPPORT -------------------------------------------------------------------

"""
"""
function _read_csv(filepath::String; header::Int=1, kwargs...)
    df = CSV.read(filepath, DataFrame,
        silencewarnings=true,
        ignoreemptylines=true,
        comment="#",
        missingstrings=["","\xc9","..."];
        header=header,
    )
    
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


# ----- GAMS FILE SUPPORT ------------------------------------------------------------------

"""
    _read_gams(xf::Array{String,1}; kwargs...)
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
function SLiDE._read_gams(filepath::String; id="", colnames=[], kwargs...)
    lines = readlines(filepath)
    lines = SLiDE._clean_gams(lines)
    lines = SLiDE._get_set(lines; id=id, kwargs...)
    lines = [reduce(replace, Pair.([r"\"","!",r",$",r";$"],""), init=x) for x in lines]

    header = lines[SLiDE._has_set.(lines, id)]
    lines = lines[.&(.!SLiDE._has_set.(lines, id),lines.!=="/")]

    lines = SLiDE._split_gams(lines)
    lines = SLiDE.unnest(lines, "()")
    lines = SLiDE.unnest(lines)

    M = length(first(lines))
    # header = SLiDE._gams_header(header, M; id=id)
    df = DataFrame([getindex.(lines,ii) for ii in 1:M])
    length(colnames)==size(df,2) && reduce(rename!, propertynames(df).=>colnames, init=df)
    return df
end


"""
"""
function _split_gams(row::String)
    # 1. Split at first space.
    m = match(r"(^\S+)\s+\"?(.*)\"*", row)
    row = isnothing(m) ? [row;] : string.(m.captures)
    
    # 2. Within captures, split at "." and expand any comma-separated sub-groups.
    row = vcat([occursin(".",x) ? split.(x,".") : x for x in row]...)
    row = SLiDE._expand_set.(row)
    return row
    # return row[row.!=="("]
end

_split_gams(rows::AbstractArray) = _split_gams.(rows)


"""
"""
function unnest(lines, id; fun=identity, kwargs...)
    N = size(lines,1)
    
    iibeg = (1:N)[.&(any.(broadcast.(in, id[1], lines)), .!any.(broadcast.(in, id[2], lines)))]
    iiend = (1:N)[.&(any.(broadcast.(in, id[2], lines)), .!any.(broadcast.(in, id[1], lines)))]
    
    if .&(.!isempty.([iibeg,iiend])...)
        iiunit = setdiff(1:N, UnitRange.(iibeg,iiend)...)  # all mapping contained to current row
        iiagg = iibeg                           # outer nesting level
        iidis = UnitRange.(iibeg.+1,iiend.-1)   # inner nesting level

        ids = string.(split(id,""))
        filter!.(x -> !(x in ids), lines)

        lines = vcat(
            lines[iiunit],
            _unnest(lines, iiagg, iidis),
        )
    end

    return lines
end


function unnest(rows)
    iinested = eltype.(rows).==Any

    if any(iinested)
        rows = vcat(
            vcat(_unnest.(rows[iinested])...),
            rows[.!iinested],
        )
    end
    return rows
end


"""
"""
function _unnest(row::Vector{T}) where T<:Any
    iidis = typeof.(row).<:AbstractArray
    
    if any(iidis)
        row_dis = row[iidis][1]
        row_agg = convert_type.(typeof.(row[.!iidis]), row[.!iidis])
        # row_agg = row[.!iidis]

        # Keep track of which row elements are inner/outer to preserve ordering.
        # This is necessary for concatenation later.
        idx = fill(0,size(row))
        idx[iidis] .= collect((1:sum(iidis)).+length(row_agg))
        idx[.!iidis] .= 1:length(row_agg)
        
        row = _unnest(row_agg, row_dis)
        row = [permute!(x,idx) for x in row]
    end
    
    return row
end

function _unnest(rows::AbstractVector, iiagg::Vector{Int}, iidis::Vector{UnitRange{Int}})
    return vcat([_unnest(rows,aa,dd) for (aa,dd) in zip(iiagg,iidis)]...)
end

function _unnest(rows::AbstractVector, iiagg::Int, iidis::UnitRange{Int})
    row_agg = rows[iiagg]
    row_dis = rows[iidis]
    return _unnest(row_agg, row_dis)
end

_unnest(row_outer, row_inner) = [vcat(row_outer,x) for x in row_inner]


"""
```jldoctest
lines = "SET mapog(as,s) \"Mapping between oil and gas sectors\" / gas.cng, cru.cng /;"
SLiDE._expand_set([lines])

# output

3-element Array{String,1}:
 "SET mapog(as,s) \"Mapping between oil and gas sectors\""
 "gas.cng"
 "cru.cng"
```
"""
function _expand_set(x::AbstractString)
    m = match(r"^\s*\((.*)\)\s*$", x)
    return string.(strip.((m !== nothing) ? split(m[1], ",") : x))
end


function _expand_set(lst::Vector{String})
    # If ending slash on following line???
    if length(lst)==2 && all(length.(findall.("/",lst)).==1)
        @error("FOUND IT.")
        lst = [*(lst...)]
    end
    
    if length(lst)==1
        # In a set/map defined in a single line, the set/map contents will be nested in / /
        x = match(r"(?<set>.*)/(?<lines>.*)/", first(lst))

        # Split at commas without separating lists inside parentheses.
        # https://stackoverflow.com/a/66912887
        xnonsep = "[^,]*"
        xreg = Regex("(" * join([
            xnonsep * "(?>(?>\\([^()]*(?R)?[^()]*\\)))" * xnonsep,
            "[\\w\\d\\.]+",
        ],"|") * ")")

        matches = collect(eachmatch(xreg, x[:lines]))
        lst = string.(strip.([x[:set]; getindex.(matches,1)]))
    end

    return lst
end


"""
"""
function _has_set(str::String, id::String)
    isempty(id) && (return false)

    # A separator indicates that this is NOT a set.
    occursin("!", str) && (return false)
    
    # matches = match.(Regex("(?<=[^sets|^SETS])?\\s+(?=$(id)\\W)"), str)
    xreg = Regex("^\\s*sets*\\s+" * id * "\\W|^\\s*" * id * "\\W")
    matches = match.(xreg, lowercase(str))
    return !isnothing(matches)
end


"""
"""
function _get_set(lines; id="", kwargs...)
    isempty(id) && (return lines)

    matches = SLiDE._has_set.(lines, id)
    all(.!matches) && (return lines)

    ii = (1:length(lines))[matches]
    # length(ii)>1 && error("multiple set matches found.")

    iistart = first(ii)
    str = lines[iistart]

    if occursin("/", str)
        # Are all set elements listed in one line?
        if length(findall("/", str))==2
            lines = SLiDE._expand_set([str])
        # Does set definition take multiple lines? If so, find the line ending in /
        # to indicate where it ends.
        else
            iistop = iistart + findmax(occursin.(r"/[,;]*\s*$", lines[iistart+1:end]))[2]
            lines = SLiDE._expand_set(lines[iistart:iistop])
            lines[end] = replace(lines[end], r"\s*/;$"=>"")
            lines = lines[.!isempty.(lines)]
            # return SLiDE._expand_set(lines[iistart:iistop])
        end

    else
        iistop = iistart + findmax(occursin.(r";\s*$", lines[iistart+1:end]))[2]
        # matches = match.(r";\s*$", lines[iistart+1:end])
        # iistop = iistart + findmax(.!isnothing.(matches))[2]
        lines = lines[iistart:iistop]
    end

    return lines
end


"""
"""
function _clean_gams(xf)
    xf = strip.(xf)
    xf = xf[xf .!== ""]                       # blank lines
    xf = xf[match.(r"^\*", xf) .=== nothing]  # commented lines
    return xf
end


"""
"""
function _gams_header(str, N; id="", colnames=[])
    !isempty(colnames) && (return colnames)

    # If no set is defined here...
    tmp = SLiDE._generate_id(N)
    !SLiDE._has_set(str, id) && (return tmp)

    xset = match(r"(\(\S*\))", lowercase(str))
    cols = Symbol.(ensurearray(isnothing(xset) ? id : SLiDE._expand_set(getindex(xset,1))))

    # Replace any implicitly named sets (labeled *) with x.
    iiundef = (1:length(cols))[cols.==Symbol(*)]
    cols[iiundef] .= tmp[iiundef]

    return length(cols)==N-1 ? [cols;:desc] : cols
end

# ----- TXT FILE SUPPORT -------------------------------------------------------------------

"""
"""
function _read_txt(path; kwargs...)
    mat = DelimitedFiles.readdlm(path, String)
    head = _txt_header(size(mat,2); kwargs...)
    return DataFrame(mat, head)
end


function _txt_header(N::Integer; colnames=[], kwargs...)
    tmp = SLiDE._generate_id(N)
    return |(isempty(colnames), N>length(colnames)) ? tmp : colnames[1:N]
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
        SLiDE._read_from_yaml(path; run_bash=run_bash)
    elseif isdir(path)
        SLiDE._read_from_dir(path; ext=ext, run_bash=run_bash)
    else
        @error("Cannot read from $path. Function input must point to an existing directory or yaml file.")
    end
    return Dict{Any,Any}(d)
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
    if haskey(y, "Path")
        # Look for shell scripts in this path, and run them if they are there.
        # If none are found, nothing will happen.
        run_bash && _run_bash(joinpath(SLIDE_DIR, ensurearray(y["Path"])...))
        
        files = ensurearray(values(find_oftype(y, File)))
        inp = haskey(y, "Input") ? y["Input"] : files
        d = _read_from_yaml(_joinpath(y["Path"]), inp)
        d = _edit_from_yaml(d, y, inp)
    else
        inp = ensurearray(values(find_oftype(y, CGE)))
        d = _read_from_yaml(inp)
    end
    return d
end

function _read_from_yaml(path::String, files::Dict)
    # needs to be a dictionary of paths.
    path = _joinpath(SLIDE_DIR, path)
    d = Dict(_inp_key(k) => read_file(_joinpath(path, f)) for (k, f) in files)
    return _delete_empty!(d)
end

function _read_from_yaml(path::String, files::Array{T,1}) where {T <: File}
    path = _joinpath(SLIDE_DIR, path)
    d = Dict(_inp_key(f) => read_file(path,f) for f in files)
    return _delete_empty!(d)
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