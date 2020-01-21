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
    # and save the column names to include.
    [df[!, field] .= convert_type.(type, df[:, field])
        for (field,type) in it if field in names(df)]
    cols = [field for (field, type) in it]

    # Create a list of structures from each DataFrame row.
    lst = [T(values(row)...) for row in eachrow(df[:,cols])]
    
    # !!!! If there is one instance of the struct, this function returns only that struct.
    # Otherwise, it returns a full list. Would it be less confusing to return a single
    # element list in this case?
    size(lst)[1] == 1 ? lst = lst[1] : nothing
    return lst

end