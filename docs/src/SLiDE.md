# SLiDE

```@meta
CurrentModule = SLiDE
DocTestSetup  = quote
    using SLiDE
end
```

```@docs
SLiDE
```

## DataStream

### Types

```@docs
SLiDE.Add
SLiDE.Drop
SLiDE.Describe
SLiDE.Group
SLiDE.Map
SLiDE.Match
SLiDE.Melt
SLiDE.Operate
SLiDE.Order
SLiDE.Rename
SLiDE.Replace
```

```@docs
SLiDE.CSVInput
SLiDE.XLSXInput
```

### Functions

```@docs
SLiDE.edit_with
SLiDE.load_from
SLiDE.read_file
SLiDE.write_yaml
SLiDE.run_yaml
SLiDE.gams_to_dataframe
```