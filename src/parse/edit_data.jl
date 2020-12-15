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
function edit_with(df::DataFrame, x::Add; file = nothing)
    # If adding the length of a string...
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


function edit_with(df::DataFrame, x::Combine; file = nothing)
    return combine_over(df, setdiff(findindex(df), x.output))
end


function edit_with(df::DataFrame, x::Deselect; file = nothing)
    if x.operation == "occursin"
        x.col = propertynames(df)[occursin.(x.col[1], propertynames(df))]
    end
    return select(df, setdiff(propertynames(df), x.col))
end


function edit_with(df::DataFrame, x::Drop; file = nothing)
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


function edit_with(df::DataFrame, x::Group; file = nothing)
    # First, add a column to the original DataFrame indicating where the data set begins.
    cols = unique([propertynames(df); x.output])
    df[!,:start] = (1:size(df)[1]) .+ 1

    # Next, create a DataFrame describing where to "split" the input DataFrame.
    # Editing with a map will remove all rows that do not contain relevant information.
    # Add a column indicating where each data set STOPS, assuming all completely blank rows
    # were removed by read_file().
    df_split = edit_with(copy(df), convert_type(Map, x); kind = :inner)
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


function edit_with(df::DataFrame, x::Map; kind = :left, file = nothing)
    cols = unique([propertynames(df); x.output])

    # Rename columns in the mapping DataFrame to temporary values in case any of these
    # columns were already present in the input DataFrame.
    from = _generate_id(x.from, :from)
    to = _generate_id(x.to, :to)

    df_map = copy(read_file(x))
    df_map = unique(hcat(
        edit_with(df_map[:,x.from], Rename.(x.from, from)),
        edit_with(df_map[:,x.to], Rename.(x.to, to)),
    ))

    # Ensure the input and mapping DataFrames are consistent in type. Types from the mapping
    # DataFrame are used since all values in each column should be of the same type.
    if findtype(df[:,x.input]) !== findtype(df_map[:,from])
        for (ii, ff) in zip(x.input, from)
            try
                df[!,ii] .= convert_type.(findtype(df_map[:,ff]), df[:,ii])
            catch
                df[!,ii] .= convert_type.(String, df[:,ii])
                df_map[!,ff] .= convert_type.(String, df_map[:,ff])
            end
        end
    end
    
    join_cols = Pair.(x.input, from)
    
    x.kind == :inner && (df = innerjoin(df, df_map, on = join_cols; makeunique = true))
    x.kind == :outer && (df = outerjoin(df, df_map, on = join_cols; makeunique = true))
    x.kind == :left  && (df = leftjoin(df, df_map,  on = join_cols; makeunique = true))
    x.kind == :right && (df = rightjoin(df, df_map, on = join_cols; makeunique = true))
    x.kind == :semi  && (df = semijoin(df, df_map,  on = join_cols; makeunique = true))
    
    # Remove all output column propertynames that might already be in the DataFrame.
    # These will be overwritten by the columns from the mapping DataFrame. Finally,
    # remane mapping "to" columns from their temporary to output values.
    df = df[:, setdiff(propertynames(df), x.output)]
    df = edit_with(df, Rename.(to, x.output))
    return df[:,cols]
end


function edit_with(df::DataFrame, x::Match; file = nothing)
    if x.on == r"expand range"
        ROWS, COLS = size(df)
        cols = propertynames(df)
        df = [[DataFrame(Dict(cols[jj] =>
                cols[jj] == x.input ? _expand_range(df[ii,jj]) : df[ii,jj]
            for jj in 1:COLS)) for ii in 1:ROWS]...;]
    else
        # Ensure all row values are strings and can be matched with a Regex, and do so.
        # Temporarily remove missing values, just in case.
        df[:,x.input] .= convert_type.(String, df[:,x.input])
        col = edit_with(copy(df), Replace(x.input, missing, ""))[:,x.input]
        m = match.(x.on, col)
        
        # Add empty columns for all output columns not already in the DataFrame.
        # Where there is a match, fill empty cells. If values in the input column,
        # leave cells without a match unchanged.
        df = edit_with(df, Add.(setdiff(x.output, propertynames(df)), ""))
        [m[ii] !== nothing && ([df[ii,out] = m[ii][out] for out in x.output])
            for ii in 1:length(m)]
    end
    return df
end


function edit_with(df::DataFrame, x::Melt; file = nothing)
    on = intersect(x.on, propertynames(df))
    df = melt(df, on, variable_name = x.var, value_name = x.val)
    df[!, x.var] .= convert_type.(String, df[:, x.var])
    return df
end


function edit_with(df::DataFrame, x::Operate; file = nothing)
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
            df[!, append(from,0)] .= df[:,from]
            df = edit_with(df, Replace.(from, df_comment[:,from], df_comment[:,to]))
        end
    end
    return round!(df, x.output)
end


function edit_with(df::DataFrame, x::Order; file = nothing)
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


function edit_with(df::DataFrame, x::Rename; file = nothing)
    cols = propertynames(df)
    x.from in cols && (df = rename(df, x.from => x.to))
    x.to == :upper && (df = edit_with(df, Rename.(cols, uppercase.(cols))))
    x.to == :lower && (df = edit_with(df, Rename.(cols, lowercase.(cols))))
    return df
end


function edit_with(df::DataFrame, x::Replace; file = nothing)
    !(x.col in propertynames(df)) && (return df)

    if x.from === missing && Symbol(x.to) in propertynames(df)
        df[ismissing.(df[:,x.col]),x.col] .= df[ismissing.(df[:,x.col]), Symbol(x.to)]
        return df
    end

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
    return df
end


function edit_with(df::DataFrame, x::Stack; file = nothing)
    df = [[edit_with(df[:, occursin.(indicator, propertynames(df))],
        [Rename.(propertynames(df)[occursin.(indicator, propertynames(df))], x.col);
            Add(x.var, replace(string(indicator), "_" => " "))]
    ) for indicator in x.on]...;]
    return dropmissing(df)
end


function edit_with(df::DataFrame, x::Describe, file; print_status::Bool = false)
    return edit_with(df, Add(x.col, file.descriptor))
end


# ----- SUPPORT FOR MULTIPLE EDITS ---------------------------------------------------------

# THIS is for those other functions 
function edit_with(df::DataFrame, x::T, file; print_status::Bool=false) where T<:Edit
    print_status && _print_status(x)
    return edit_with(df, x)
end

# function edit_with(df::DataFrame, x::T; print_status::Bool = false) where T<:Edit
#     # print_status && _print_status(x)
#     return edit_with(df, x)
# end


function edit_with(
    df::DataFrame,
    lst::Array{T,1};
    print_status::Bool = false) where T<:Edit

    # [df = edit_with(df, x; print_status = print_status) for x in lst]
    [df = edit_with(df, x) for x in lst]
    return df
end


function edit_with(
    df::DataFrame,
    lst::Array{T,1},
    file;
    print_status::Bool = false) where T<:Edit

    [df = edit_with(df, x, file; print_status = print_status) for x in lst]
    return df
end


# ----- EDIT FROM FILE ---------------------------------------------------------------------

function edit_with(
    df::DataFrame,
    y::Dict{Any,Any},
    file::T;
    print_status::Bool = false) where T<:File

    # Specify the order in which edits must occur and which of these edits are included
    # in the yaml file of defined edits.
    EDITS = ["Deselect", "Rename", "Group", "Stack", "Match", "Melt",
        "Add", "Map", "Replace", "Drop", "Operate", "Combine", "Describe", "Order"]
    KEYS = intersect(EDITS, collect(keys(y)))
    [df = edit_with(df, y[k], file; print_status = print_status) for k in KEYS]
    return df
end


function edit_with(
    file::T,
    y::Dict{Any,Any};
    print_status::Bool = false) where T<:File

    df = read_file(y["PathIn"], file)
    return edit_with(df, y, file)
end


function edit_with(
    files::Array{T},
    y::Dict{Any,Any};
    print_status::Bool = false) where T<:File
    
    df = [[edit_with(file, y; print_status = print_status) for file in files]...;]
    df = dropzero(df)

    df = _filter_datastream(df, y)
    df = _sort_datastream(df, y)
    return df
end


function edit_with(y::Dict{Any,Any}; print_status::Bool = false)
    # Find all dictionary keys corresponding to file names and save these in a list to
    # read, edit, and concattenate.
    files = ensurearray(values(find_oftype(y, File)))
    return edit_with(files, y; print_status = print_status)
end


"""
Allows for *basic* filtering over years. Will need to expand to include regions.
"""
function _filter_datastream(df::DataFrame, y::Dict)
    path = joinpath("data","coresets")
    set = Dict()
    if "Filter" in keys(y)
        y["Filter"] in [true,"year"]  && push!(set, :yr => read_file(joinpath(path,"yr.csv"))[:,1])
        y["Filter"] in [true,"state"] && push!(set, :r => read_file(joinpath(path,"r","state.csv"))[:,1])
    end

    !isempty(set) && (df = filter_with(df, set; extrapolate = true))
    return df
end


"""
    _sort_datastream(df::DataFrame)
Returns the edited DataFrame, stored in a nicely-sorted order. This is most helpful for
mapping and developing. Sorting isn't *necessary* and we could remove this function to save
some time for users.
"""
function _sort_datastream(df::DataFrame, y::Dict{Any,Any})
    sorting = "Sort" in keys(y) ? y["Sort"] : true

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
        if all(string(strip(x)) .!= ["31-33", "44-45", "48-49"])
            x = split(x, "-")
            x = ensurearray(convert_type(Int, x[1]):convert_type(Int, x[1][1:end-1] * x[end][end]))
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
    fill_zero(keys_unique::NamedTuple; value_colnames)
    fill_zero(keys_unique::NamedTuple, df::DataFrame)
    fill_zero(df::DataFrame...)
    fill_zero(d::Dict...)
    fill_zero(keys_unique, d::Dict)

This function can be used to fill zeros in either a dictionary or DataFrame.
- Options for dictionary editing:
    - If only (a) dictionary/ies is/are input, the dictionaries will be edited such that
        they all contain all permutations of their key values. All dictionaries in a
        resultant list of dictionaries will be the same length.
    - If a dictionary is input with a list of keys, it will be edited to ensure that it
        includes all permutations.
    - If only a list of keys is input, a new dictionary will be created, containing all key
        permutations with values initialized to zero.
- Options for DataFrame editing:
    - If only (a) DataFrame(s) is/are input, the DataFrame(s) will be edited such that
        they all contain all permutations of their key values. All DataFrames in a
        resultant list of DataFrames will be the same length.
    - If a DataFrame is input with a NamedTuple, it will be edited to ensure that it
        includes all permutations of the NamedTuple's values.
    - If only a NamedTuple is input, a new DataFrame will be created, containing all key
        permutations with values initialized to zero.

# Arguments
- `keys_unique::Tuple`: A list of arrays whose permutations should be included in the
    resultant dictionary.
- `keys_unique::NamedTuple`: A list of arrays whose permutations should be included in the
    resultant dictionary. The NamedTuple's keys correspond to the DataFrame columns where
    they will be stored.
- `d::Dict...`: The dictionary/ies to edit.
- `df::DataFrame...`: The DataFrame(s) to edit.

# Keywords
- `value_colnames::Any = :value`: "value" column labels to add and set to zero when creating
    a new DataFrame. Default is `:value`.

# Returns
- `d::Dict...` if input included dictionaries and/or Tuples
- `df::DataFrame...` if input included DataFrames and/or NamedTuples
"""
function fill_zero(keys_fill::NamedTuple; value_colnames = :value)
    df_fill = DataFrame(permute(keys_fill))
    return edit_with(df_fill, Add.(convert_type.(Symbol, value_colnames), 0.))
end


function fill_zero(keys_fill::Any; permute_keys::Bool = true)
    permute_keys && (keys_fill = permute(keys_fill))
    return Dict(k => 0. for k in keys_fill)
end


function fill_zero(keys_fill::Vararg{Any}; permute_keys::Bool = true)
    permute_keys && (keys_fill = permute(keys_fill))
    return Dict(k => 0. for k in keys_fill)
end


# ----- EDIT EXISTING ----------------------------------------------------------------------

function fill_zero(df::Vararg{DataFrame}; permute_keys::Bool = true)
    df = ensurearray(df)
    df_fill = sort(indexjoin(df))
    idx = findindex(df_fill)

    permute_keys && (df_fill = indexjoin(permute(df_fill[:,idx]), df_fill))
    
    val = findvalue(df_fill)
    
    [df[ii] = edit_with(df_fill[:,[idx;val[ii]]], Rename(val[ii],:value))
        for ii in 1:length(df)]
    return length(df) == 1 ? df[1] : Tuple(df)
end


function fill_zero(d::Vararg{Dict}; permute_keys::Bool = true)
    d = copy.(ensurearray(d))
    # Find all keys present in the input dictionary/ies and ensure all are present.
    keys_fill = unique([collect.(keys.(d))...;])
    d = [fill_zero(keys_fill, x; permute_keys = permute_keys) for x in d]
    return length(d) == 1 ? d[1] : Tuple(d)
end


# ----- GIVEN SET LIST ---------------------------------------------------------------------

function fill_zero(keys_fill::NamedTuple, df::DataFrame)
    @warn("Depreciated!")
    df = copy(df)
    df_fill = fill_zero(keys_fill)
    df = fill_zero(df, df_fill; permute_keys = false)[1]
    return df
end


function fill_zero(set::Dict, df::DataFrame)
    @warn("Depreciated!")
    idx = intersect(findindex(df), collect(keys(set)))
    val = [set[k] for k in idx]
    return fill_zero(NamedTuple{Tuple(idx,)}(val,), df)
end


function fill_zero(keys_fill::Any, d::Dict; permute_keys::Bool = true)
    @warn("Depreciated!")
    d = copy(d)
    # If permuting keys, find all possible permutations of keys that should be present
    # and determine which are missing. Then add missing keys to the dictionary and return.
    permute_keys && (keys_fill = permute(keys_fill))
    keys_missing = setdiff(keys_fill, collect(keys(d)))

    [push!(d, k => 0.) for k in keys_missing]
    return d
end


"""
Initialize a new DataFrame and fills it with the specified input value.
"""
function fill_with(keys_fill::NamedTuple, value::Any; value_colnames = :value)
    df = fill_zero(keys_fill; value_colnames = value_colnames)
    df = edit_with(df, Replace.(value_colnames, 0.0, value))
    return df
end


"""
    extrapolate_year(df::DataFrame, yr::Array{Int64,1}; kwargs...)
    extrapolate_year(df::DataFrame, set::Any; kwargs...)

# Arguments
- `df::DataFrame` that might be in need of extrapolation.
- `yr::Array{Int64,1}`: List of years overwhich extrapolation is possible (depending on the kwargs)
- `set::Dict` or `set::NamedTuple` containing list of years, identified by the key `:yr`.

# Keywords
- `backward::Bool = true`: Do we extrapolate backward in time?
- `forward::Bool = true`: Do we extrapolate forward in time?

# Returns
- `df::DataFrame` extrapolated in time.

# Example
Continuing with the DataFrame from [`SLiDE.filter_with`](@ref),

```jldoctest extrapolate_year; setup = :(df = filter_with(read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","filter_use.csv")), (i = ["agr","fbp"], j = ["agr","fbp"])))
julia> df
8×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2015  │ agr    │ agr    │ 69.42   │
│ 2   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2016  │ agr    │ agr    │ 60.197  │
│ 6   │ 2016  │ agr    │ fbp    │ 264.173 │
│ 7   │ 2016  │ fbp    │ agr    │ 47.739  │
│ 8   │ 2016  │ fbp    │ fbp    │ 205.21  │

julia> extrapolate_year(df, Dict(:yr => 2014:2017))
16×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2014  │ agr    │ agr    │ 69.42   │
│ 2   │ 2014  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2014  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2014  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2015  │ agr    │ agr    │ 69.42   │
│ 6   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 7   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 8   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 9   │ 2016  │ agr    │ agr    │ 60.197  │
│ 10  │ 2016  │ agr    │ fbp    │ 264.173 │
│ 11  │ 2016  │ fbp    │ agr    │ 47.739  │
│ 12  │ 2016  │ fbp    │ fbp    │ 205.21  │
│ 13  │ 2017  │ agr    │ agr    │ 60.197  │
│ 14  │ 2017  │ agr    │ fbp    │ 264.173 │
│ 15  │ 2017  │ fbp    │ agr    │ 47.739  │
│ 16  │ 2017  │ fbp    │ fbp    │ 205.21  │
```
"""
function extrapolate_year(
    df::DataFrame,
    yr::Array{Int64,1};
    backward::Bool = true,
    forward::Bool = true
)
    df = copy(df)
    yr_diff = setdiff(yr, unique(df[:,:yr]))
    length(yr_diff) == 0 && (return df)
    
    cols = setdiff(propertynames(df), [:yr])
    cols_ans = propertynames(df)

    df_ext = []

    if backward
        yr_min = minimum(df[:,:yr])
        df_min = filter_with(df, (yr = yr_min,))[:,cols]

        yr_back = yr_diff[yr_diff .< yr_min]
        df_back = crossjoin(DataFrame(yr = yr_back), df_min)[:,cols_ans]

        push!(df_ext, df_back)
    end
    
    if forward
        yr_max = maximum(df[:,:yr])
        df_max = filter_with(df, (yr = yr_max,))[:,cols]

        yr_forward = yr_diff[yr_diff .> yr_max]
        df_forward = crossjoin(DataFrame(yr = yr_forward), df_max)[:,cols_ans]

        push!(df_ext, df_forward)
    end
    return sort([df_ext...; df])
end


function extrapolate_year(
    df::DataFrame,
    set;
    backward::Bool = true,
    forward::Bool = true
)
    extrapolate_year(df, set[:yr]; forward = forward, backward = backward)
end


function extrapolate_year(
    df::DataFrame,
    yr::UnitRange{Int64};
    backward::Bool = true,
    forward::Bool = true
)
    extrapolate_year(df, ensurearray(yr); forward = forward, backward = backward)
end


"""
    extrapolate_region(df::DataFrame; kwargs...)
    extrapolate_region(df::DataFrame, r::Pair; kwargs...)

Fills in missing data in the input DataFrame `df` by filling it with existing information in
`df`. Here, "extrapolate" makes a direct copy of the data.

# Arguments
- `df::DataFrame` that might be in need of extrapolation.
- `r::Pair = "md" => "dc"`: `Pair` indicating a region (`r.first`) to extrapolate to another
    region (`r.second`). A suggested regional extrapolation: MD data will be used to
    approximate DC data in the event that it is missing. To fill multiple regions with data,
    use "md" => ["dc","va"].

# Keyword Argument:
- `overwrite::Bool = false`: If data in the target region `r.second` is already present,
    should it be overwritten?

# Returns
- `df::DataFrame` extrapolated in region.

# Example

```jldoctest extrapolate_region
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","filter_utd.csv"))
8×5 DataFrame
│ Row │ yr    │ r      │ s      │ t       │ value     │
│     │ Int64 │ String │ String │ String  │ Float64   │
├─────┼───────┼────────┼────────┼─────────┼───────────┤
│ 1   │ 2015  │ md     │ agr    │ exports │ 0.0390152 │
│ 2   │ 2015  │ md     │ agr    │ imports │ 0.778159  │
│ 3   │ 2015  │ va     │ agr    │ exports │ 1.11601   │
│ 4   │ 2015  │ va     │ agr    │ imports │ 0.88253   │
│ 5   │ 2016  │ md     │ agr    │ exports │ 0.0330508 │
│ 6   │ 2016  │ md     │ agr    │ imports │ 0.762089  │
│ 7   │ 2016  │ va     │ agr    │ exports │ 1.16253   │
│ 8   │ 2016  │ va     │ agr    │ imports │ 0.86741   │

julia> extrapolate_region(df)
12×5 DataFrame
│ Row │ r      │ yr    │ s      │ t       │ value     │
│     │ String │ Int64 │ String │ String  │ Float64   │
├─────┼────────┼───────┼────────┼─────────┼───────────┤
│ 1   │ dc     │ 2015  │ agr    │ exports │ 0.0390152 │
│ 2   │ dc     │ 2015  │ agr    │ imports │ 0.778159  │
│ 3   │ dc     │ 2016  │ agr    │ exports │ 0.0330508 │
│ 4   │ dc     │ 2016  │ agr    │ imports │ 0.762089  │
│ 5   │ md     │ 2015  │ agr    │ exports │ 0.0390152 │
│ 6   │ md     │ 2015  │ agr    │ imports │ 0.778159  │
│ 7   │ md     │ 2016  │ agr    │ exports │ 0.0330508 │
│ 8   │ md     │ 2016  │ agr    │ imports │ 0.762089  │
│ 9   │ va     │ 2015  │ agr    │ exports │ 1.11601   │
│ 10  │ va     │ 2015  │ agr    │ imports │ 0.88253   │
│ 11  │ va     │ 2016  │ agr    │ exports │ 1.16253   │
│ 12  │ va     │ 2016  │ agr    │ imports │ 0.86741   │
```

If we instead want to copy VA data into DC, specify:

```jldoctest extrapolate_region
julia> extrapolate_region(df, "va" => "dc")
12×5 DataFrame
│ Row │ r      │ yr    │ s      │ t       │ value     │
│     │ String │ Int64 │ String │ String  │ Float64   │
├─────┼────────┼───────┼────────┼─────────┼───────────┤
│ 1   │ dc     │ 2015  │ agr    │ exports │ 1.11601   │
│ 2   │ dc     │ 2015  │ agr    │ imports │ 0.88253   │
│ 3   │ dc     │ 2016  │ agr    │ exports │ 1.16253   │
│ 4   │ dc     │ 2016  │ agr    │ imports │ 0.86741   │
│ 5   │ md     │ 2015  │ agr    │ exports │ 0.0390152 │
│ 6   │ md     │ 2015  │ agr    │ imports │ 0.778159  │
│ 7   │ md     │ 2016  │ agr    │ exports │ 0.0330508 │
│ 8   │ md     │ 2016  │ agr    │ imports │ 0.762089  │
│ 9   │ va     │ 2015  │ agr    │ exports │ 1.11601   │
│ 10  │ va     │ 2015  │ agr    │ imports │ 0.88253   │
│ 11  │ va     │ 2016  │ agr    │ exports │ 1.16253   │
│ 12  │ va     │ 2016  │ agr    │ imports │ 0.86741   │
```
"""
function extrapolate_region(df::DataFrame, r::Pair = "md" => "dc"; overwrite = false)
    df = copy(df)
    if !overwrite
        r = r.first => setdiff(ensurearray(r.second), unique(df[:,:r]))
        length(r.second) == 0 && (return df)
    else
        df = edit_with(df, Drop.(:r, r.second, "=="))
    end
    
    cols = setdiff(propertynames(df), [:r])
    df_close = crossjoin(DataFrame(r = r.second), filter_with(df, (r = r.first,))[:,cols])
    
    return sort([df_close; df])
end


"""
filter_with(df::DataFrame, set::Any; kwargs...)

# Arguments
- `df::DataFrame` to filter.
- `set::Dict` or `set::NamedTuple`: Values to keep in the DataFrame.

# Keywords
- `extrapolate::Bool = false`: Add missing regions/years to the DataFrame?
    If `extrapolate` is set to true, the following `kwargs` become relevant:
    - When extrapolating over years,
        - `backward::Bool = true`: Do we extrapolate backward in time?
        - `forward::Bool = true`: Do we extrapolate forward in time?
        Currently, "extrapolating" means copying the closest 
    - When extrapolating across regions,
        - `r::Pair = "md" => "dc"`: `Pair` indicating a region (`r.first`) to extrapolate to
            another region (`r.second`). A suggested regional extrapolation: MD data will be
            used to approximate DC data in the event that it is missing.
        - `overwrite::Bool = false`: If data in the target region `r.second` is already present,
            should it be overwritten?

# Returns
- `df::DataFrame` with only the desired keys.

# Examples

```jldoctest filter_with
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","filter_use.csv"))
14×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2015  │ agr    │ agr    │ 69.42   │
│ 2   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2015  │ uti    │ agr    │ 4.846   │
│ 6   │ 2015  │ uti    │ fbp    │ 10.102  │
│ 7   │ 2015  │ uti    │ uti    │ 35.093  │
│ 8   │ 2016  │ agr    │ agr    │ 60.197  │
│ 9   │ 2016  │ agr    │ fbp    │ 264.173 │
│ 10  │ 2016  │ fbp    │ agr    │ 47.739  │
│ 11  │ 2016  │ fbp    │ fbp    │ 205.21  │
│ 12  │ 2016  │ uti    │ agr    │ 4.548   │
│ 13  │ 2016  │ uti    │ fbp    │ 9.152   │
│ 14  │ 2016  │ uti    │ uti    │ 27.47   │

julia> df = filter_with(df, (i = ["agr","fbp"], j = ["agr","fbp"]))
8×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2015  │ agr    │ agr    │ 69.42   │
│ 2   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2016  │ agr    │ agr    │ 60.197  │
│ 6   │ 2016  │ agr    │ fbp    │ 264.173 │
│ 7   │ 2016  │ fbp    │ agr    │ 47.739  │
│ 8   │ 2016  │ fbp    │ fbp    │ 205.21  │

julia> filter_with(df, (yr = 2016,); drop = true)
4×3 DataFrame
│ Row │ i      │ j      │ value   │
│     │ String │ String │ Float64 │
├─────┼────────┼────────┼─────────┤
│ 1   │ agr    │ agr    │ 60.197  │
│ 2   │ agr    │ fbp    │ 264.173 │
│ 3   │ fbp    │ agr    │ 47.739  │
│ 4   │ fbp    │ fbp    │ 205.21  │
```
"""
function filter_with(
    df::DataFrame,
    set::Any;
    drop::Bool = false,
    extrapolate::Bool = false,
    forward::Bool = true,
    backward::Bool = true,
    r::Pair = "md" => "dc",
    overwrite::Bool = false
)
    cols = propertynames(df)

    # Find keys that reference both column names in the input DataFrame df and
    # values in the set Dictionary. Then, created a DataFrame containing all permutations.
    idx = findindex(df)
    idx_set = intersect(idx, collect(keys(set)))
    val_set = [intersect(unique(df[:,k]), ensurearray(set[k])) for k in idx_set]
    
    if length(idx_set) == 0
        @warn("Returning filtered dataframe. No overlap between dataframe index and set keys.")
        return df
    end

    if any(length.(val_set) .== 0)
        cols_err = idx_set[length.(val_set) .== 0]
        error("Cannot filter DataFrame. No overlap with input set. 
            - Check set key(s): $cols_err
            - Use extrapolate_year() or extrapolate_region() to extend the dataset")
    end

    # Drop values that are not in the current set.
    df_set = DataFrame(permute(NamedTuple{Tuple(idx_set,)}(val_set,)))
    df = innerjoin(df, df_set, on = idx_set)
    
    if extrapolate
        :yr in idx_set && (df = extrapolate_year(df, set; forward = forward, backward = backward))
        :r in idx_set  && (df = extrapolate_region(df, r; overwrite = overwrite))
    end

    # If one of the filtered DataFrame columns contains only one unique value, drop it.
    # However, DO NOT DROP UNITS. EVER.
    idx_set = setdiff(idx_set,[:units])
    drop && setdiff!(cols, idx_set[length.(unique.(eachcol(df[:,idx_set]))) .=== 1])

    return sort(df[:,cols])
end

# function filter_with(
#     df::DataFrame,
#     set::NamedTuple;
#     drop::Bool = false,
#     extrapolate::Bool = false,
#     forward::Bool = true,
#     backward::Bool = true,
#     r::Pair = "md" => "dc",
#     overwrite::Bool = false
# )
#     if any(typeof.(collect(values(set))) .<: Pair)
#         x = [Rename.(set[k].first, k) for k in keys(set) if typeof(set[k]) <: Pair]
#         df = edit_with(df, x)
#     end
    
#     set = Dict(k => (typeof(set[k]) <: Pair) ? set[k].second : set[k] for k in keys(set))
#     return filter_with(df, set; drop = drop, extrapolate = extrapolate, forward = forward, backward = backward, r = r, overwrite = overwrite)
# end