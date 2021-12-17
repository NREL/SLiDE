"""
    edit_with(y::Dict{Any,Any}; kwargs...)
    edit_with(df::DataFrame, editor::T) where T<:Edit
    edit_with(df::DataFrame, lst::Array{T}) where T<:Edit
    edit_with(df::DataFrame, x::Describe, file::T) where T<:File
    edit_with(file::T, y::Dict{Any,Any}; kwargs...)
    edit_with(files::Array{T,N} where N, y::Dict{Any,Any}; kwargs...) where T<:File
This function edits the input DataFrame `df` and returns the resultant DataFrame.

# Arguments
- `df::DataFrame` on which to perform the edit.
- `editor::T where T<:Edit`: DataType containing information about which edit to perform.
    The following edit options are available and detailed below. If given a dictionary of
    edits, they will be made in this order:
    - [`SLiDE.Drop`](@ref): Remove information from the DataFrame -- either an entire column
        or rows containing specified values.
    - [`SLiDE.Rename`](@ref): Change column name `from` -> `to`.
    - [`SLiDE.Group`](@ref): Use to edit files containing data in successive dataframes with
        an identifying header cell or row.
    - [`SLiDE.Match`](@ref): Extract values from the specified column into a column or
        columns based on the specified regular expression.
    - [`SLiDE.Melt`](@ref): Normalize the dataframe by 'melting' columns into rows, 
        lengthening the dataframe by duplicating values in the column `on` into new rows and
        defining 2 new columns:
        1. `var` with header names from the original dataframe.
        2. `val` with column values from the original dataframe.
    - [`SLiDE.Add`](@ref): Add new column `col` filled with `val`.
    - [`SLiDE.Map`](@ref): Define an `output` column containing values based on those in an
        `input` column. The mapping columns `from` -> `to` are contained in a .csv `file` in
        the coremaps directory. The columns `input` and `from` should contain the same
        values, as should `output` and `to`.
    - [`SLiDE.Replace`](@ref): Replace values in `col` `from` -> `to`.
    - [`SLiDE.Operate`](@ref): Perform an arithmetic operation across multiple DataFrame columns or rows.
    - [`SLiDE.Describe`](@ref): This DataType is required when multiple DataFrames will be
        appended into one output file (say, if multiple sheets from an XLSX file are
        included). Before the DataFrames are appended, a column `col` will be added and
        filled with the value in the file descriptor.
    - [`SLiDE.Order`](@ref): Rearranges columns in the order specified by `cols` and sets
        them to the specified type.
- `file::T where T <: File`: Data file containing information to read.
- `files::Array{T} where T <: File`: List of data files.
- `y::Dict{Any,Any}`: Dictionary containing all editing structures among other values read
    from the yaml file. Dictionary keys must correspond EXACTLY with SLiDE.Edit DataType
    names, or the edits will not be made.

# Returns
- `df::DataFrame` including edit(s)
"""
function edit_with(df::DataFrame, x::Add; file=nothing)
    # If adding the length of a string... (!!!! doc this option; used for naics code scaling)
    if typeof(x.val) == String && occursin("length", x.val)
        m = match(r"(?<col>\S*) length", x.val)

        # If this is not indicating a column length to add, add the value and exit.
        if (m === nothing || !(Symbol(m[:col]) in propertynames(df)))
            df[!, x.col] .= x.val
            return df
        end
        # If possible, return the length of characters  in the string.
        col_len = Symbol(m[:col])
        df[!, x.col] .= [ismissing(val_len) ? missing : length(convert_type(String, val_len))
            for val_len in df[:,col_len]]
    else
        df[!, x.col] .= x.val
    end
    return df
end


function edit_with(df::DataFrame, x::Combine; file=nothing)
    return combine_over(df, setdiff(findindex(df), x.output))
end


function edit_with(df::DataFrame, x::Deselect; file=nothing)
    if x.operation == "occursin"
        x.col = propertynames(df)[occursin.(x.col[1], propertynames(df))]
    end
    return select(df, setdiff(propertynames(df), x.col))
end


function edit_with(df::DataFrame, x::Drop; file=nothing)
    if x.val === "all" && x.operation == "occursin"
        df = edit_with(df, Drop.(propertynames(df)[occursin.(x.col, propertynames(df))], "all", "=="))
    end

    !(x.col in propertynames(df)) && (return df)
    if x.val === "all"  # Drop entire column to remove dead weight right away.
        df = df[:, setdiff(propertynames(df), [x.col])]
    else  # Drop rows using an operation or based on a value.
        if x.val === missing
            df = dropmissing(df, x.col)
        elseif x.val === "unique"
            df = unique(df, x.col)
        else
            df[!,x.col] .= convert_type.(typeof(x.val), df[:,x.col])
            df = if x.operation == "occursin"
                df[.!broadcast(datatype(x.operation), x.val, df[:,x.col]), :]
            else
                df[.!broadcast(datatype(x.operation), df[:,x.col], x.val), :]
            end
        end
    end
    return df
end


function edit_with(df::DataFrame, x::OrderedGroup)
    # !!!! can we merge this with Group? So we can group on either?
    # !!!! Can we group when we just need to fill columns with what's below them? (think: sctg codes)
    [df = _group_by(df, OrderedGroup(x.on, x.var, [val])) for val in x.val]
    return df
end


function edit_with(df::DataFrame, x::Group; file=nothing)
    # First, add a column to the original DataFrame indicating where the data set begins.
    cols = unique([propertynames(df); x.output])
    df[!,:start] = (1:size(df)[1]) .+ 1

    # Next, create a DataFrame describing where to "split" the input DataFrame.
    # Editing with a map will remove all rows that do not contain relevant information.
    # Add a column indicating where each data set STOPS, assuming all completely blank rows
    # were removed by read_file().
    df_split = edit_with(copy(df), convert_type(Map, x))
    df_split = sort(unique(df_split), :start)
    df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

    # Add a new, blank output column to store identifying information about the data block.
    # Then, fill this column based on the identifying row numbers in df_split.
    for out in x.output
        df[!,out] .= ""
        [df[row[:start]:row[:stop], out] .= row[out] for row in eachrow(df_split)]
    end

    # Finally, remove header rows (these will be blank in the output column),
    # as well as the column describing where the sub-DataFrames begin.
    df = edit_with(df, Drop.(x.output, "", "=="))
    return df[:, cols]
end


edit_with(df::DataFrame, x::Map; file=nothing) = _map_with(df, x.file, x)


function edit_with(df::DataFrame, x::Match; file=nothing)
    if !(x.input in propertynames(df))
        @warn("$(x.input) not found in DataFrame propertynames.")
        return df
    end
    
    if x.on == r"expand range"
        ROWS, COLS = size(df)
        cols = propertynames(df)
        df = [[DataFrame(Dict(cols[jj] =>
                cols[jj] == x.input ? SLiDE._expand_range(df[ii,jj]) : df[ii,jj]
            for jj in 1:COLS)) for ii in 1:ROWS]...;]
    else
        # Ensure all row values are strings and can be matched with a Regex, and do so.
        # Temporarily remove missing values, just in case.
        convert_type!(df, x.input, String)
        col = coalesce.(df[:,x.input],"")
        m = match.(x.on, col)
        
        # Extract the names of all captures from the input regex (x.on)
        # and ensure that the DataFrame contains a column for each.
        captures = intersect(
            convert_type.(Symbol, values(Base.PCRE.capture_names(x.on.regex))),
            x.output,
        )
        # df = edit_with(df, Add.(captures,""))
        ii = .!isnothing.(m)
        for cap in captures
            !(cap in propertynames(df)) && edit_with(df, Add(cap,""))
            df[ii,cap] .= getindex.(m[ii], cap)
        end
    end
    
    !(x.input in x.output) && select!(df, Not(x.input))
    :value in x.output     && convert_type!(df, :value, Float64)
    return df
end


function edit_with(df::DataFrame, x::Melt; file=nothing)
    # !!!! @warn("Melt <: Edit is depreciated. Use Stack instead.")
    on = intersect(x.on, propertynames(df))
    df = melt(df, on, variable_name=x.var, value_name=x.val)
    df[!, x.var] .= convert_type.(String, df[:, x.var])
    return df
end


function edit_with(df::DataFrame, x::Stack; file=nothing)
    on = intersect(x.on, propertynames(df))
    df = stack(df, Not(on); variable_name=x.var, value_name=x.val, variable_eltype=String)
    return df
end


function edit_with(df::DataFrame, x::Operate; file=nothing)
    # Append columns from before the operation with 0 if they might be replaced.
    # This is useful for debugging purposes.
    df_val = convert_type.(Float64, df[:,x.input])
    x.output in x.input && (df = edit_with(df, Rename(x.output, append(x.output, 0))))
    df[!,x.output] .= broadcast(datatype(x.operation), [col for col in eachcol(df_val)]...)

    # Adjust labeling columns: If both from/to descriptive columns are distinct and
    # in the DataFrame, Replace the column values from -> to.
    for (from, to) in zip(x.from, x.to)
        if length(intersect(propertynames(df), [from,to])) == 2
            df_comment = dropmissing(unique(df[:, [from; to]]))
            df[!, append(from, 0)] .= df[:,from]
            df = edit_with(df, Replace.(from, df_comment[:,from], df_comment[:,to]))
        end
    end
    return round!(df, x.output)
end


function edit_with(df::DataFrame, x::Order; file=nothing)
    # If not all columns are present, return the DataFrame as is. Such is the case when a
    # descriptor column must be added when appending multiple data sets in one DataFrame.
    if size(intersect(x.col, propertynames(df)))[1] < size(x.col)[1]
        return df
    # If all of the columns are present in the original DataFrame,
    # reorder the DataFrame columns and set them to the specified type.
    else
        df = df[!, x.col]
        [df[!, c] .= convert_type.(t, df[!, c]) for (c, t) in zip(x.col, x.type)]
        return df
    end
end


function edit_with(df::DataFrame, x::Rename; file=nothing)
    cols = propertynames(df)
    x.from in cols && (df = rename(df, x.from => x.to))
    x.to == :upper && (df = edit_with(df, Rename.(cols, uppercase.(cols))))
    x.to == :lower && (df = edit_with(df, Rename.(cols, lowercase.(cols))))

    # x.to == :value && (df[!,x.to] .= convert_type.(Float64, df[:,x.to]))
    return df
end


function edit_with(df::DataFrame, x::Replace; file=nothing)
    !(x.col in propertynames(df)) && (return df)

    # Check if we want to replace a value x.from in the column x.col with a value in the
    # from another column in the same row. !!!! add this option to the documentation.
    m = match(r"(?<col>\S*) value", string(x.to))
    if !isnothing(m) && (m[:col] in names(df))
        ii = df[:,x.col] .=== x.from
        df[ii,x.col] .= df[ii,Symbol(m[:col])]

    else
        if x.from === missing && Symbol(x.to) in propertynames(df)
            df[ismissing.(df[:,x.col]),x.col] .= df[ismissing.(df[:,x.col]), Symbol(x.to)]
            return df
        end

        # !!!! find out where we use this (i think check share_gsp, labor) and doc this option!
        if x.to === Not && eltype(df[:,x.col]) == Bool
            df[!,x.col] .= .!df[:,x.col]
        end

        df[!,x.col] .= if x.to === "lower"  lowercase.(df[:,x.col])
        elseif x.to === "upper"             uppercase.(df[:,x.col])
        elseif x.to === "uppercasefirst"    uppercasefirst.(lowercase.(df[:,x.col]))
        elseif x.to === "titlecase"         titlecase.(df[:,x.col])
        else
            replace(strip.(copy(df[:,x.col])), x.from => x.to)
        end
    end

    return df
end


function edit_with(df::DataFrame, x::Concatenate; file=nothing)
    df = [[edit_with(df[:, occursin.(indicator, propertynames(df))],
        [Rename.(propertynames(df)[occursin.(indicator, propertynames(df))], x.col);
            Add(x.var, replace(string(indicator), "_" => " "))]
    ) for indicator in x.on]...;]
    return dropmissing(df)
end


function edit_with(df::DataFrame, x::Describe, file; print_status::Bool=false)
    return edit_with(df, Add(x.col, file.descriptor))
end


# ----- SUPPORT FOR MULTIPLE EDITS ---------------------------------------------------------

# THIS is for those other functions 
function edit_with(df::DataFrame, x::T, file; print_status::Bool=false) where T <: Edit
    print_status && _print_status(x)
    return edit_with(df, x)
end


function edit_with(
    df::DataFrame,
    lst::Array{T,1};
    print_status::Bool=false) where T <: Edit

    # [df = edit_with(df, x; print_status = print_status) for x in lst]
    [df = edit_with(df, x) for x in lst]
    return df
end


function edit_with(
    df::DataFrame,
    lst::Array{T,1},
    file;
    print_status::Bool=false) where T <: Edit

    [df = edit_with(df, x, file; print_status=print_status) for x in lst]
    return df
end


# ----- EDIT FROM FILE ---------------------------------------------------------------------

function edit_with(df::DataFrame, y::Dict, file::T; print_status::Bool=false) where T <: File
    # EDITS = ["Deselect","Rename","OrderedGroup","Group","Concatenate","Match","Melt","Stack",
    #     "Add","Map","Replace","Drop","Operate","Combine","Describe","Order",
    # ]
    # KEYS = intersect(EDITS, collect(keys(y)))
    KEYS = _collect_edits(y)
    [df = edit_with(df, y[k], file; print_status=print_status) for k in KEYS]
    return df
end


function edit_with(file::T, y::Dict; print_status::Bool=false) where T <: File
    df = read_file(y["PathIn"], file; remove_notes=true)
    return edit_with(df, y, file)
end


function edit_with(files::Array{T}, y::Dict; print_status::Bool=false) where T <: File
    
    df = vcat([edit_with(file, y; print_status=print_status) for file in files]...; cols=:union)
    
    if haskey(y,"Order")
        df = edit_with(df, y["Order"])
    end

    df = dropzero(df)

    df = _filter_datastream(df, y)
    df = _sort_datastream(df, y)
    return df
end


function edit_with(y::Dict; print_status::Bool=false)
    # Find all dictionary keys corresponding to file names and save these in a list to
    # read, edit, and concattenate.
    files = ensurearray(values(find_oftype(y, File)))
    return edit_with(files, y; print_status=print_status)
end


"""
Specify the order in which edits must occur and which of these edits are included
in the yaml file of defined edits.
"""
function _collect_edits(y::Dict)
    EDITS = ["Deselect","Rename","OrderedGroup","Group","Concatenate","Match","Melt","Stack",
        "Add","Map","Replace","Drop","Operate","Combine","Describe","Order",
    ]
    return intersect(EDITS, collect(keys(y)))
end


"""
Allows for *basic* filtering over years. Will need to expand to include regions.
"""
function _filter_datastream(df::DataFrame, y::Dict)
    path = joinpath("data", "coresets")
    set = Dict()
    if haskey(y, "Filter")
        y["Filter"] in [true,"year"]  && push!(set, :yr => read_file(joinpath(path, "yr.csv"))[:,1])
        y["Filter"] in [true,"state"] && push!(set, :r => read_file(joinpath(path, "r", "state.csv"))[:,1])
    end

    !isempty(set) && (df = filter_with(df, set; extrapolate=false))
    return df
end


"""
    _sort_datastream(df::DataFrame)
Returns the edited DataFrame, stored in a nicely-sorted order. This is most helpful for
mapping and developing. Sorting isn't *necessary* and we could remove this function to save
some time for users.
"""
function _sort_datastream(df::DataFrame, y::Dict)
    sorting = haskey(y, "Sort") ? y["Sort"] : true

    sorting == false && (return df)

    df = if sorting == true
        sort(df, findindex(df))
    elseif occursin("unique", sorting)
        sort_unique(df, sorting)
    end

    return df
end


"This function prints an editing status message."
function _print_status(x::Add)
    println("\tAdding ", x.col, " = ", x.val)
end

function _print_status(x::Drop)
    if x.val === "all"
        println("\tDropping ", x.col)
    else
        println("\tDropping ", x.col, " = ", x.val)
    end
end

function _print_status(x::Map)
    println("\tMapping ", x.input, " -> ", x.output, " using ", x.file)
end

function _print_status(x::Rename)
    println("\tRenaming ", x.from, " -> ", x.to)
end

function _print_status(x::Replace)
    println("\tReplacing ", x.col, ": ", x.from, " -> ", x.to)
end

function _print_status(x::Any)
    println("\tEditing with ", typeof(x))
end


"""
    _expand_range()
"""
function _expand_range(x::T) where T <: AbstractString
    if occursin("-", x)
        x = string(strip(x))
        if all(x .!= ["31-33", "44-45", "48-49"])
            x = split(x, "-")
            x = ensurearray(convert_type(Int, x[1]):convert_type(Int, x[1][1:end - 1] * x[end][end]))
        end
    else
        x = convert_type(Int, x)
    end
    return x
end

function _expand_range(x::String)
    if match(r"\D", x) !== nothing
        m = String.([m.match for m in collect(eachmatch(r"\D.*?", x))])
        x = if length(setdiff(m, [",","-"," "])) .== 0
            [_expand_range.(split(x, ","))...;]
        else
            missing
        end
    else
        x = convert_type(Int, x)
    end
    return x
end

_expand_range(x::Missing) = x
_expand_range(x::Int) = x


"""
"""
function _group_by(df::DataFrame, x::OrderedGroup)
    id = x.val[1]
    colid = append.(convert_type(Symbol, id), x.on)
    cols = unique([propertynames(df); colid])
    
    # Find the line where each group begins and ends.
    if length(unique(df[:,x.var])) > 1
        N = size(df, 1)
        df[!,:line] .= (1:N)
        df_split = df[df[:,x.var] .== id, :]
        df_split = edit_with(df_split, Rename.(x.on, colid))
        df_split[!,:start] .= df_split[:,:line] .+ 1
        df_split[!,:stop] .= [df_split[:,:line][2:end] .- 1; N]
        
        # Can probably change a little to fill in values.
        [df[!,col] .= "" for col in colid]
        [df[row[:start]:row[:stop], col] .= row[col] for row in eachrow(df_split)
            for col in colid]

        # Drop "headers" that indicated where groups stopped and started.
        df = df[df[:,colid[1]] .!== "", cols]
    else
        df = edit_with(df, [Rename.(x.on, colid); Deselect([x.var], "==")])
    end

    return df
end


"""
Edits input DataFrame given either a DataFrame or file path.
"""
function _map_with(df::DataFrame, df_map::DataFrame, x::Map)
    cols = unique([propertynames(df); x.output])

    # Rename columns in the mapping DataFrame to temporary values in case any of these
    # columns were already present in the input DataFrame.
    from = SLiDE._generate_id(x.from, :from)
    to = SLiDE._generate_id(x.to, :to)

    df_map = unique(hcat(
        edit_with(df_map[:,x.from], Rename.(x.from, from)),
        edit_with(df_map[:,x.to], Rename.(x.to, to)),
    ))

    # Ensure the input and mapping DataFrames are consistent in type. Types from the mapping
    # DataFrame are used since all values in each column should be of the same type.
    # [convert_type!(df, ii, SLiDE.findtype(df_map[:,ff])) for (ii,ff) in zip(x.input,from)]
    for (ii,ff) in zip(x.input,from)
        try
            convert_type!(df, ii, SLiDE.findtype(df_map[:,ff]))
        catch
            convert_type!(df, ii, String)
            convert_type!(df_map, ff, String)
        end
    end
    
    on = x.input .=> from
    
    if x.kind==:anti
        df = antijoin(df, df_map,  on=on; makeunique=true)
    else
        x.kind in [:inner,:sum] && (df = innerjoin(df, df_map, on=on; makeunique=true))
        x.kind == :outer && (df = outerjoin(df, df_map, on=on; makeunique=true))
        x.kind == :left  && (df = leftjoin(df, df_map,  on=on; makeunique=true))
        x.kind == :right && (df = rightjoin(df, df_map, on=on; makeunique=true))
        x.kind == :semi  && (df = semijoin(df, df_map,  on=on; makeunique=true))
        
        # Remove all output column propertynames that might already be in the DataFrame.
        # These will be overwritten by the columns from the mapping DataFrame. Finally,
        # remane mapping "to" columns from their temporary to output values.
        df = df[:, setdiff(propertynames(df), x.output)]
        df = edit_with(df, Rename.(to, x.output))

        if x.kind==:sum
            @info("summing!")
            convert_type!(df, :value, Float64)
            df = combine_over(df, x.input; digits=false)
            setdiff!(cols, x.input)
        end
    end

    return df[:,cols]
end

_map_with(df::DataFrame, file::String, x::Map) = _map_with(df, read_file(x), x)


"""
"""
function sort_unique(df::DataFrame, idx::Array{Symbol,1})
    idx = idx[sortperm(nunique(df[:,idx]))]
    return sort(df, idx)
end

function sort_unique(df::DataFrame, id::String)
    (id == "unique") && (return sort_unique(df))

    m = match.(r"unique\s+(\S+)", id)
    id = m !== nothing ? Symbol(m[1]) : Symbol(id)

    return sort_unique(df, id)
end

function sort_unique(df::DataFrame, id::Symbol)
    idx = propertynames(df)
    subidx = idx[occursin.(id, idx)]

    length(subidx) > 0 && (idx = subidx)

    return sort_unique(df, idx)
end

sort_unique(df::DataFrame) = sort_unique(df, findindex(df))


"""
"""
function DataFrames.select!(df::DataFrame, x::Parameter)
    return select!(df, intersect([x.index; :value], propertynames(df)))
end


"""
    _unstack(df::DataFrame, colkey, value)
This function enables unstacking DataFrames (long -> wide) given one or multiple variable
and/or value columns.

This is helpful when preparing input for calculations during which units are preserved.

# Arguments
- `df::DataFrame` to stack
- `colkey::Symbol` or `colkey::Array{Symbol,1}`: variable column(s)
- `value::Symbol` or `value::Array{Symbol,1}`: value column(s)

# Returns

"""
function _unstack(df, colkey::Symbol, value::Vector{Symbol}; kwargs...)
    idx = setdiff(propertynames(df), [colkey;value])
    lst = [_unstack(df[:,[idx;[colkey,val]]], colkey, val; kwargs...) for val in value]
    return indexjoin(lst...)
end


function _unstack(df::DataFrame, colkey::Symbol, value::Symbol; fillmissing=false)
    val = convert_type.(Symbol, unique(df[:,colkey]))
    df = unstack(df, colkey, value; renamecols=x -> SLiDE._add_id(value, x))

    fillmissing!==false && (df = edit_with(df, Replace.(val, missing, 0.0)))
    
    return df
end


function _unstack(df, colkey::Vector{Symbol}, value::Union{Symbol,Vector{Symbol}}; kwargs...)
    df[!,:variable] .= append.(convert_type(Array{Tuple}, df[:,colkey]))
    df = select(df, Not(colkey))

    return _unstack(df, :variable, value; kwargs...)
end


"""
    _stack(df::DataFrame, colkey, value)
This function enables stacking DataFrames (wide -> long) given one or multiple variable
and/or value columns.

This is helpful when normalizing a DataFrame after a calculation during which units were
preserved.

# Arguments
- `df::DataFrame` to stack
- `colkey::Symbol` or `colkey::Array{Symbol,1}`: variable column(s)
- `value::Symbol` or `value::Array{Symbol,1}`: value column(s)

# Returns
- `df::DataFrame` where colkeys

# Example
!!!!docs
"""
function _stack(df::DataFrame, colkey::Symbol, value::Symbol)
    return stack(df; variable_name=colkey, value_name=value, variable_eltype=String)
end


function _stack(df::DataFrame, colkey::Array{Symbol,1}, value::Array{Symbol,1})
    df = _stack(df, :variable, value)
    N = length(colkey)

    x = [
        Rename.(Symbol.(1:N), colkey);
        Order([:variable;colkey], fill(String, N + 1));
    ]

    df_var = unique(df[:,[:variable]])
    df_var = hcat(df_var, DataFrame(Tuple.(split.(df_var[:,1], "_"))))
    df_var = edit_with(df_var, x)

    return innerjoin(df, df_var, on=:variable)
end


function _stack(df::DataFrame, colkey::Symbol, value::Array{Symbol,1})
    from = Dict(k => _with_id(df, k) for k in value)
    to = Dict(k => _remove_id.(v, k) for (k, v) in from)
    idx = setdiff(propertynames(df), values(from)...)

    lst = [edit_with(df[:,[idx;from[k]]], [
                Rename.(from[k], to[k]);
                Melt(idx, colkey, k);       # !!!! Melt relies on DataFrames.melt, which is depreciated
            ]) for k in keys(from)]

    return indexjoin(lst...)
end