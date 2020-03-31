# Data Stream

*Overview of how DataStream works*

## Examples

[`SLiDE.Rename`](@ref)

```jldoctest DataStreamRename
julia> using SLiDE, DataFrames

julia> df = DataFrame(
           Item = ["Colorado", "A", "B", "Wisconsin", "A", "B"],
           value = ["", 1, 2, "", 3, 4])
6×2 DataFrames.DataFrame
│ Row │ Item      │ value │
│     │ String    │ Any   │
├─────┼───────────┼───────┤
│ 1   │ Colorado  │       │
│ 2   │ A         │ 1     │
│ 3   │ B         │ 2     │
│ 4   │ Wisconsin │       │
│ 5   │ A         │ 3     │
│ 6   │ B         │ 4     │

julia> editor = SLiDE.Rename(from = :Item, to = :sector);

julia> df = SLiDE.edit_with(df, editor)
6×2 DataFrames.DataFrame
│ Row │ sector    │ value │
│     │ String    │ Any   │
├─────┼───────────┼───────┤
│ 1   │ Colorado  │       │
│ 2   │ A         │ 1     │
│ 3   │ B         │ 2     │
│ 4   │ Wisconsin │       │
│ 5   │ A         │ 3     │
│ 6   │ B         │ 4     │
```

[`SLiDE.Group`](@ref)

```jldoctest DataStreamGroup
julia> using SLiDE, DataFrames

julia> df = DataFrame(
           sector = ["Colorado", "A", "B", "Wisconsin", "A", "B"],
           value = ["", 1, 2, "", 3, 4]);

julia> editor = SLiDE.Group(
           file = joinpath("parse","regions.csv"),
           from = :from,
           to = :to,
           input = :sector,
           output = :region);

julia> df = SLiDE.edit_with(df, editor)
4×3 DataFrames.DataFrame
│ Row │ sector │ value │ region │
│     │ String │ Any   │ String │
├─────┼────────┼───────┼────────┤
│ 1   │ A      │ 1     │ co     │
│ 2   │ B      │ 2     │ co     │
│ 3   │ A      │ 3     │ wi     │
│ 4   │ B      │ 4     │ wi     │
```

[`SLiDE.Melt`](@ref)

[`SLiDE.Add`](@ref)

[`SLiDE.Map`](@ref)

[`SLiDE.Replace`](@ref)

[`SLiDE.Order`](@ref)