"""
    edit_with(y::Dict{Any,Any}; kwargs...)
    edit_with(df::DataFrame, editor::T) where T<:Edit
    edit_with(df::DataFrame, lst::Array{T}) where T<:Edit
    edit_with(df::DataFrame, x::Describe, file::T) where T<:File
    edit_with(file::T, y::Dict{Any,Any}; kwargs...)
    edit_with(files::Array{T,N} where N, y::Dict{Any,Any}; kwargs...) where T<:File

This function edits the input DataFrame `df` and returns the resultant DataFrame.

# Arguments

- `df::DataFrame`: The DataFrame on which to perform the edit.
- `editor::T where T<:Edit`: DataType containing information about which edit to perform. The following edit options are available and detailed below:
    - [`SLiDE.Add`](@ref): Add new column `col` filled with `val`.
    - [`SLiDE.Describe`](@ref): This DataType is required when multiple DataFrames will be
        appended into one output file (say, if multiple sheets from an XLSX file are
        included). Before the DataFrames are appended, a column `col` will be added and
        filled with the value in the file descriptor.
    - [`SLiDE.Group`](@ref): Use to edit files containing data in successive dataframes with
        an identifying header cell or row.
    - [`SLiDE.Join`](@ref): Contains the information to join a mapping DataFrame to another
        DataFrame (`df`), with a `prefix` prepended to the column names in `df_map`.
        The dataframes will be joined on the column `on`
        (see [DataFrames join documentation](https://juliadata.github.io/DataFrames.jl/stable/man/joins/))
    - [`SLiDE.Map`](@ref): Define an `output` column containing values based on those in an
        `input` column. The mapping columns `from` -> `to` are contained in a .csv `file` in
        the coremaps directory. The columns `input` and `from` should contain the same
        values, as should `output` and `to`.
    - [`SLiDE.Melt`](@ref): Normalize the dataframe by 'melting' columns into rows, 
        lengthening the dataframe by duplicating values in the column `on` into new rows and
        defining 2 new columns:
        1. `var` with header names from the original dataframe.
        2. `val` with column values from the original dataframe.
    - [`SLiDE.Order`](@ref): Rearranges columns in the order specified by `cols` and sets
        them to the specified type.
    - [`SLiDE.Rename`](@ref): Change column name `from` -> `to`.
    - [`SLiDE.Replace`](@ref): Replace values in `col` `from` -> `to`.
    - [`SLiDE.Split`](@ref)
- `file::T where T <: File`: Data file containing information to read.
- `files::Array{T} where T <: File`: List of data files.
- `y::Dict{Any,Any}`: Dictionary containing all editing structures among other values read
    from the yaml file. Dictionary keys must correspond EXACTLY with SLiDE.Edit DataType
    names, or the edits will not be made.

# Keywords

- `shorten::Bool = false`: if true, a shortened form of the dataframe will be read.
    This is meant to aid troubleshooting during development.

# Returns

- `df::DataFrame`: Including edit(s).
"""
function edit_with(df::DataFrame, x::Add)
    df[!, x.col] .= x.val
    return df
end

function edit_with(df::DataFrame, x::Drop)
    
    if x.col in names(df)
        if occursin(lowercase(x.val), "all")
            df = df[:, setdiff(names(df), [x.col])]

        else

            if typeof(x.val) == String
                occursin(lowercase(x.val), "all") ? df = df[:, setdiff(names(df), [x.col])] :
                    occursin(lowercase(x.val), "missing") ? dropmissing!(df, x.col) :
                        occursin(lowercase(x.val), "unique") ? unique!(df, x.col) : nothing
            end
            # !!!! Add error if broadcast not possible.
            df = df[.!broadcast(datatype(x.operation), df[:,x.col], x.val), :]
        end
    end
    return df
end

function edit_with(df::DataFrame, x::Group)
    # First, add a column to the original DataFrame indicating where the data set begins.
    cols = unique(push!(names(df), x.output))
    df[!,:start] = (1:size(df)[1]) .+ 1

    # Next, create a DataFrame describing where to "split" the input DataFrame.
    # Editing with a map will remove all rows that do not contain relevant information.
    # Add a column indicating where each data set STOPS, assuming all completely blank rows
    # were removed by read_file().
    df_split = edit_with(copy(df), Map(x.file, x.from, x.to, x.input, x.output); kind = :inner);
    sort!(unique!(df_split), :start)
    df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

    # Add a new, blank output column to store identifying information about the data block.
    # Then, fill this column based on the identifying row numbers in df_split.
    df[!,x.output] .= ""
    [df[row[:start]:row[:stop], x.output] .= row[x.output] for row in eachrow(df_split)]

    # Finally, remove header rows (these will be blank in the output column),
    # as well as the column describing where the sub-DataFrames begin.
    df = df[df[:,x.output] .!= "", :]
    return df[:, cols]
end

function edit_with(df::DataFrame, x::Join)
    # Prepend the column names of the mapping DataFrame with the Join prefix.
    df_map = read_file(x)
    df_map = edit_with(df_map, Rename.(names(df_map), Symbol.(x.prefix, "_", names(df_map))))

    # Remove excess blank space from the input column to ensure consistency when joining.
    df[!, x.on] .= strip.(df[:, x.on])
    df = join(df, df_map, on = x.on, makeunique = true)
    return df
end

function edit_with(df::DataFrame, x::Map2)
    df_map = read_file(x)
    df_map = dropmissing(unique(df_map[:,unique([x.from; x.to])]))

    [df[!,col] .= convert_type.(unique(typeof.(df_map[:,col_map])), df[:,col])
        for (col_map, col) in zip(x.from, x.input)]
            
    df = join(df, df_map, on = collect(zip(x.input, x.from));
        kind = :left, makeunique = true)
    return df
end



function edit_with(df::DataFrame, x::Map; kind = :left)
    # Save the column names in the input dataframe and add the output column. This will
    # avoid including unnecessary output columns from the map file in the result.
    cols = unique(push!(names(df), x.output))
    df_map = read_file(x);

    # Rename the input column in the DataFrame to edit to match that in the mapping df.
    # This approach was taken as opposed to editing the mapping df to avoid errors in case
    # the input and output column names are the same. Such is the case if mapping is used to
    # edit column values for consistency without adding a new column to the DataFrame.
    # A left join is used to prevent data loss in the case that a value in the input df is
    # NOT in the input mapping column. If this is the case, this value will map to "missing".
    # Remove excess blank space from the input column to ensure consistency when joining.

    # !!!! Warning when renaming doesn't happen?
    x.input == x.from ? nothing : df = edit_with(df, Rename(x.input, x.from));
    # show(first(df,3))

    all(typeof.(df_map[:,x.from]) .== String) ?
        df[!,x.from] .= convert_type.(String, df[:,x.from]) : nothing

    df[!, x.from] .= strip.(df[:, x.from]);
    df = join(df, df_map, on = x.from, kind = kind, makeunique = true);

    # df[ismissing.(df[:,x.to]), x.to] .=
    #     convert_type.(String, df[ismissing.(df[:,x.to]), x.from])

    # Return the DataFrame with the columns saved at the top of the method.
    df = x.input == x.output ? edit_with(df, Rename(x.to, x.output)) :
                               edit_with(df, Rename.([x.from, x.to], [x.input, x.output]))

    return df[:, cols]
    # !!!! ALTERNATE APPROACH: In the current approach, any row in df that is NOT in df_map
    # will be removed. This is beneficial when using edit_with(df, x::Group).
    # In the commented approached, this will return an error. This could prevent data loss
    # when using edit_with(df, x::Map), where Map is defined in the input yaml file.
    # dict_map = Dict(k => v for (k, v) in zip(df_map[!, xfrom], df_map[!, xto]))
    # df[!, x.output] = map(x -> dict_map[x], df[!, x.input])
end

function edit_with(df::DataFrame, x::Match)
    !all(typeof(df[:,x.input]).==String) ?
        df[!,x.input] .= convert_type.(String, df[:,x.input]) : nothing

    cols = setdiff(x.output, names(df))
    df = edit_with(df, Add.(cols, fill("", size(cols))))
    m = match.(x.on, df[:, x.input])
    [m[ii] != nothing ? [df[ii,out] = m[ii][out] for out in x.output] : nothing
        for ii in 1:length(m)]
    return df
end

function edit_with(df::DataFrame, x::Melt)
    on = intersect(x.on, names(df))  # Melt on present.
    df = melt(df, on, variable_name = x.var, value_name = x.val)
    df[!, x.var] .= convert_type.(String, df[:, x.var])
    return df
end

function edit_with(df::DataFrame, x::Order)
    # If not all columns are present, return the DataFrame as is. Such is the case when a
    # descriptor column must be added when appending multiple data sets in one DataFrame.
    if size(intersect(x.col, names(df)))[1] < size(x.col)[1]
        return df
    # If all of the columns are present in the original DataFrame,
    # reorder the DataFrame columns and set them to the specified type.
    else
        df = df[!, x.col]  # reorder
        [df[!, c] .= convert_type.(t, df[!, c]) for (c, t) in zip(x.col, x.type)]  # convert
        return df
    end
end

function edit_with(df::DataFrame, x::Rename)
    # Explicitly rename the specified column if it exists in the dataframe.
    x.from in names(df) ? rename!(df, x.from => x.to) :

        # If we are, instead, changing the CASE of all column names...
        lowercase(x.to) == :lower ?
            df = edit_with(df, Rename.(names(df), lowercase.(names(df)))) :
            lowercase(x.to) == :upper ?
                df = edit_with(df, Rename.(names(df), uppercase.(names(df)))) :
                nothing
    return df
end

function edit_with(df::DataFrame, x::Replace)
    any(typeof.(df[:,x.col]) .== Missing) ?
        df[!,x.col] .= convert_type.(String, df[:,x.col]) : nothing

    x.col in names(df) ? df[!, x.col][strip.(df[:, x.col]) .== x.from] .= x.to : nothing
    return df
end

function edit_with(df::DataFrame, x::Split)
    
    df = edit_with(df, Add.(x.output, fill("",size(x.output))))
    lst = split.(df[:, x.input], Regex(x.on));

    [df[!, x.output[ii]] .= strip.([length(m) >= ii ? m[ii] : "" for m in lst])
        for ii in 1:length(x.output)]

    x.remove ? df[!,x.input] .= [strip(string(string.(strip.(el)," ")...))
        for el in lst] : nothing

    return df
end

function edit_with(df::DataFrame, lst::Array{T}) where T<:Edit
    [df = edit_with(df, x) for x in lst]
    return df
end

function edit_with(df::DataFrame, x::Describe, file::T) where T<:File
    df = edit_with(df, Add(x.col, file.descriptor))
    return df
end

function edit_with(file::T, y::Dict{Any,Any}; shorten::Bool=false) where T<:File
    df = read_file(y["Path"], file; shorten=shorten);

    # Specify the order in which edits must occur.
    EDITS = ["Drop", "Rename", "Group", "Match", "Melt", "Add", "Map", "Map2", "Join", "Replace", "Drop"];

    # Find which of these edits are represented in the yaml file of defined edits.
    KEYS = intersect(EDITS, [k for k in keys(y)]);
    "Drop" in KEYS ? push!(KEYS, "Drop") : nothing

    [df = edit_with(df, y[k]) for k in KEYS];
    
    # Add a descriptor to identify the data from the file that was just added.
    # Then, reorder the columns and set them to the correct types.
    # This ensures consistency when concattenating.
    df = "Describe" in keys(y) ? edit_with(df, y["Describe"], file) : df;
    df = "Order" in keys(y) ? edit_with(df, y["Order"]) : df;
    return df
end

function edit_with(files::Array{T}, y::Dict{Any,Any}; shorten::Bool=false) where T<:File
    df = DataFrame();
    [df = vcat(df, edit_with(file, y; shorten=shorten)) for file in files]
    return df
end

function edit_with(y::Dict{Any,Any}; shorten::Bool = false)
    file = [v for (k,v) in y
        if isarray(v) ? any(broadcast(<:, typeof.(v), File)) : typeof(v)<:File]
    file = length(file) == 1 ? file[1] : vcat(file...)
    df = edit_with(file, y; shorten=shorten)
    return df
end