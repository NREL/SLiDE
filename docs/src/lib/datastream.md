# Data Stream

*Overview of how DataStream works*

## Example 1: Operations


#### [`SLiDE.Rename`](@ref)

```@setup ex1_datastream_rename
using SLiDE, DataFrames
df = DataFrame(IOCode = ["22", "23"], Name = ["Utilities", "Construction"])
```

```@repl ex1_datastream_rename
df
editor = [Rename(from = :IOCode, to = :input_code),
          Rename(from = :Name,   to = :input_desc)];
edit_with(df, editor)
```

#### [`SLiDE.Group`](@ref)

```@setup ex1_datastream_group
using SLiDE, DataFrames
df = DataFrame(input_code = ["Colorado", "Utilities", "Construction", "Wisconsin", "Utilities", "Construction"],
    value = [missing,1,2,missing,3,4]);
```

```@repl ex1_datastream_group
df
editor = Group(
    file   = joinpath("parse", "regions.csv"),
    from   = :from,
    to     = :to,
    input  = :input_code,
    output = :region);
edit_with(df, editor)
```

#### [`SLiDE.Drop`](@ref)

```@setup ex1_datastream_drop
using SLiDE, DataFrames
df = DataFrame(
    linenum = 1:4,
    input_code = ["Utilities", "Construction", "Utilities", "Construction"],
    value = [1,2,3,-1]);
```
```@repl ex1_datastream_drop
df
editor = [Drop(col = :linenum, val = "all", operation = "=="),
          Drop(col = :value,   val = 0,     operation = "<")];
edit_with(df, editor)
```


## Example 2: Edit data set

```@setup ex2
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
```

```@repl ex2
df
```

#### [`SLiDE.Drop`](@ref)

```@setup ex2_datastream_drop_1
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
```

```@repl ex2_datastream_drop_1
editor = Drop(
    col = :linenum,
    val = "all",
    operation = "==");
df = edit_with(df, editor)
```

#### [`SLiDE.Rename`](@ref)

```@setup ex2_datastream_rename
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
df = edit_with(df, [[y[k] for k in ["Drop"]]...;])
```

```@repl ex2_datastream_rename
editor = Rename(
    from = :IOCode,
    to   = :n);
df = edit_with(df, editor)
```

#### [`SLiDE.Group`](@ref)

```@setup ex2_datastream_group
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
df = edit_with(df, [[y[k] for k in ["Drop", "Rename"]]...;])
```

```@repl ex2_datastream_group
editor = Group(
    file   = joinpath("parse", "regions.csv"),
    from   = :from,
    to     = :to,
    input  = :n,
    output = :r);
df = edit_with(df, editor)
```

#### [`SLiDE.Match`](@ref)

```@setup ex2_datastream_match
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
df = edit_with(df, [[y[k] for k in ["Drop", "Rename", "Group"]]...;])
```

```@repl ex2_datastream_match
editor = Match(
    on     = r"\((?<n>.*)\)",
    input  = :n,
    output = [:n]);
df = edit_with(df, editor)
```

#### [`SLiDE.Melt`](@ref)

```@setup ex2_datastream_melt
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
df = edit_with(df, [[y[k] for k in ["Drop", "Rename", "Group", "Match"]]...;])
```

```@repl ex2_datastream_melt
editor = Melt(
    on  = [:n, :r],
    var = :yr,
    val = :value);
df = edit_with(df, editor)
```

#### [`SLiDE.Add`](@ref)

```@setup ex2_datastream_add
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
df = edit_with(df, [[y[k] for k in ["Drop", "Rename", "Group", "Match", "Melt"]]...;])
```

```@repl ex2_datastream_add
editor = Add(
    col = :units,
    val = "thousands of us dollars (USD)");
df = edit_with(df, editor)
```

#### [`SLiDE.Map`](@ref)

```@setup ex2_datastream_map
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
df = edit_with(df, [[y[k] for k in ["Drop", "Rename", "Group", "Match", "Melt", "Add"]]...;])
```

```@repl ex2_datastream_map
editor = [Map(
    file   = joinpath("parse", "bea.csv"),
    from   = [:bea_code],
    to     = [:bea_desc, :bea_windc],
    input  = [:n],
    output = [:desc, :i]),
Map(
    file = joinpath("parse", "units.csv"),
    from = [:from],
    to = [:to, :factor, :units_factor],
    input = [:units],
    output = [:to, :factor, :units_factor]
)];
df = edit_with(df, editor)
```

#### [`SLiDE.Replace`](@ref)

```@setup ex2_datastream_replace
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
df = edit_with(df, [[y[k] for k in ["Drop", "Rename", "Group", "Match", "Melt", "Add", "Map"]]...;])
```

```@repl ex2_datastream_replace
editor = Replace(
    col  = :value,
    from = missing,
    to   = 0);
df = edit_with(df, editor)
```

#### [`SLiDE.Drop`](@ref)

```@setup ex2_datastream_drop_2
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
df = edit_with(df, [[y[k] for k in ["Drop", "Rename", "Group", "Match", "Melt", "Add", "Map", "Replace"]]...;])
```

```@repl ex2_datastream_drop_2
editor = Drop(
    col  = :value,
    val = 0,
    operation = "<");
df = edit_with(df, editor)
```

#### [`SLiDE.Operate`]

```@setup ex2_datastream_operate
using SLiDE, DataFrames
y = read_file(joinpath("tests", "data", "test_datastream.yml"))
df = read_file(joinpath("tests", "data", "test_datastream.csv"))
df = edit_with(df, [[y[k] for k in ["Drop", "Rename", "Group", "Match", "Melt", "Add", "Map", "Replace", "Drop"]]...;])
```

```@repl ex2_datastream_operate
editor = Operate(
    axis = :col,
    operation = "*"
    from = [:units],
    to = [:units_factor]
    input = [:value, :factor],
    output = [:value]);
df = edit_with(df, editor)
```