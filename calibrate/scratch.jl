function new_edit_with!(df::DataFrame, lst::Array{T}) where T<:Edit
    [new_edit_with!(df, x) for x in lst]
    return df
end

function new_edit_with(df::DataFrame, lst::Array{T}) where T<:Edit
    [df = new_edit_with(df, x) for x in lst]
    return df
end

new_edit_with(df::DataFrame, x::T) where T<:Edit = new_edit_with!(copy(df), x)

# 
function new_edit_with!(df::DataFrame, x::Rename)
    x.from in propertynames(df) && (rename!(df, x.from => x.to))

    cols = propertynames(df)
    x.to == :upper && new_edit_with!(df, Rename.(cols, uppercase.(cols)))
    x.to == :lower && new_edit_with!(df, Rename.(cols, lowercase.(cols)))
    return df
end

function new_edit_with!(df::DataFrame, x::Add)
    # If adding the length of a string...
    if typeof(x.val) == String && occursin("length", x.val)
        m = match(r"(?<col>\S*) length", x.val)

        # If this is not indicating a column length to add, add the value and exit.
        # !!!! add warning/error
        # if (m === nothing || !(Symbol(m[:col]) in propertynames(df)))
        #     df[!, x.col] .= x.val
        #     return df
        # end

        # If possible, return the length of characters  in the string.
        col_len = Symbol(m[:col])
        df[!, x.col] .= [ismissing(val_len) ? missing : length(convert_type(String, val_len))
            for val_len in df[:,col_len]]
    else
        df[!, x.col] .= x.val
    end
    return df
end

function new_edit_with!(df::DataFrame, x::Order)
    missing_cols = setdiff(x.col, propertynames(df))
    if length(missing_cols) > 0
        @warn("Cannot reorder. %missing_cols not found in DataFrame")
    else
        select!(df, x.col)
        [df[!, col] .= convert_type.(type, df[!, col]) for (col, type) in zip(x.col, x.type)]
    end
    return df
end

function new_edit_with!(df::DataFrame, x::Describe, file::T) where T<:File
    new_edit_with!(df, Add(x.col, file.descriptor))
    return df
end

new_edit_with(df::DataFrame, x::Describe, file::T) where T<:File = new_edit_with!(copy(df), x, file)



df0 = DataFrame(state = ["MD","CO",missing], value = 1:3)
new_edit_with(df0, Drop(:state, "all", "=="))
new_edit_with!(df0, Drop(:state, "all", "=="))
# new_edit_with!(df0, Drop(:state, "MD", ""))


# function ahhhh(df::DataFrame)
#     df = 
# end

# RENAME
df0 = DataFrame(state = ["MD","CO",missing], value = 1:3)
new_edit_with(df0, Rename(:state,:r))
new_edit_with!(df0, Rename(:state,:r))

new_edit_with(df0, Rename(:lower,:upper))
# new_edit_with!(df0, Rename(:lower,:upper))

# new_edit_with(df0, Rename(:upper,:lower))
# new_edit_with!(df0, Rename(:upper,:lower))

# ADD
new_edit_with(df0, Add(:s, "agr"))
new_edit_with!(df0, Add(:s, "agr"))

# new_edit_with(df0, Add(:r_len, "r length"))
# new_edit_with!(df0, Add(:r_len, "r length"))