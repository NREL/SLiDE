function _swap_names(df::DataFrame, a::Symbol, b::Symbol)
    return edit_with(df, Rename.([a,b,append(a,:temp)], [append(a,:temp),a,b]))
end

# maps[:og] = DataFrame(src=set[:as], s="cng")

df = [
    DataFrame(
        from_units = "trillion btu",
        factor = 1e3,
        operation = /,
        by_units = "btu per kilowatthour",
        units = "billion kilowatthours",
    );
    DataFrame(
        from_units = "us dollars (USD) per barrel",
        factor = 1.,
        operation = /,
        by_units = "million btu per barrel",
        units = "us dollars (USD) per million btu",
    );
    DataFrame(
        from_units = "billions of us dollars (USD)",
        factor = 1e3,
        operation = /,
        by_units = "trillion btu",
        units = "us dollars (USD) per million btu",
    );
    DataFrame(
        from_units = "billions of us dollars (USD)",
        factor = 1e3,
        operation = /,
        by_units = "billion kilowatthours",
        units = "us dollars (USD) per thousand kilowatthour",
    );
    DataFrame(
        from_units = "trillion btu",
        factor = 1e-3,
        operation = *,
        by_units = "kilograms CO2 per million btu",
        units = "million metric tons of carbon dioxide",
    );
    DataFrame(
        from_units = "us dollars (USD) per million btu",
        factor = 1E-3,
        operation = *,
        by_units = "trillion btu",
        units = "billions of us dollars (USD)",
    );
    DataFrame(
        from_units = "us dollars (USD) per thousand kilowatthour",
        factor = 1E-3,
        operation = *,
        by_units = "billion kilowatthours",
        units = "billions of us dollars (USD)",
    );
]

df = vcat(df, _swap_names(df[df[:,:operation].==*,:], :from_units, :by_units))

df = vcat(
    sort(df[df[:,:operation].==/,:], [order(:factor, rev=true), :units]),
    sort(df[df[:,:operation].==*,:], [order(:factor, rev=true), :units]),
)