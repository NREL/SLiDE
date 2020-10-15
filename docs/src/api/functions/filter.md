# Filter and Resize

# Filter
```@docs
filter_with
extrapolate_year
extrapolate_region
```

# Fill
```@docs
fill_zero
```

**Initialize a new DataFrame or dictionary.**

```@setup fill_zero
using SLiDE
```

```@repl fill_zero
years = 2015:2016; regions = ["md","va"];
fill_zero((years, regions))
fill_zero((yr = years, r = regions))
```

**Edit an existing DataFrame or dictionary.**

```@repl fill_zero
df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","fill_use.csv"))
fill_zero(df)
```

```@repl fill_zero
d = convert_type(Dict, df)
fill_zero(d)
```

```@docs
fill_with
```