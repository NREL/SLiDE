"""
    _inp_key(x::Any)
This function is a standardized method for generating dictionary keys for
[`SLiDE.read_from`](@ref) based on the type of information that is being read.
"""
function _inp_key(paths::Array{String,1})
    # !!!! check where this is used and see if it's doing what we want.
    dir = splitdir.(paths)

    while length(unique(getindex.(dir, 2))) > 1
        dir = splitdir.(getindex.(dir, 1))
    end

    return convert_type(Symbol, dir[1][end])
end

function _inp_key(x::AbstractArray)
    x = if length(x) == 0; nothing
    elseif length(x) == 1; x[1]
    else;                  Tuple(x)
    end
    return x
end

_inp_key(x::SetInput) = length(split(x.descriptor)) > 1 ? Tuple(split(x.descriptor)) : x.descriptor
_inp_key(x::T) where {T <: File} = Symbol(x.descriptor)
_inp_key(x::Parameter) = Symbol(x.parameter)
_inp_key(x::String) = convert_type(Symbol, splitext(splitdir(x)[end])[1])


"""
If no id is specified, default to `id = [x1,x2,...,xN]`
where `N` is the length of the input array `x`
"""
_generate_id(N::Int, id::Symbol=:x) = Symbol.(id, 1:N)
_generate_id(x::Array, id::Symbol=:x) = _generate_id(length(x), id)


"""
"""
_add_id(x::Symbol, id::Symbol) = (id == :value) ? x : append(x, id)
_add_id(x::String, id::Symbol) = _add_id(Symbol(x), id)


"""
"""
_with_id(df::DataFrame, id::Symbol) = (id == :value) ? findvalue(df) : propertynames_with(df, id)


"""
"""
_remove_id(x::Symbol, id::Symbol) = (x == id) ? x : getid(x, id)
_remove_id(x::AbstractArray, id::Symbol) = _remove_id.(x, id)


"""
"""
getid(x::Symbol, id::Symbol) = Symbol(getid(string(x), string(id)))
getid(x::String, id::String) = replace(x, Regex("_*$id" * "_*") => "")
# !!!! function name??? elsewhere, find* selects df columns based on some criteria.
# !!!! replace findunits with general findcol or something.