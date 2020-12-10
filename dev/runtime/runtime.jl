
# https://discourse.julialang.org/t/very-slow-pre-compiling-and-using-of-custom-julia-package/24708
# @time Base.convert(::Type{T}, cs::Array{DataFrame,1}) where {T<:Array}
# @time Base.convert(::Type{Array}, cs::Array{C,1}) where C<:ChainDataFrame

# @time convert_type(::Type{T}, x::Any) where T<:AbstractString = string(x)
# @time convert_type(::Type{Array}, x::Any) = string(x)