# Sets

| Item | Description |
|:-----|:------------|
| `yr`    | *Years* -- 1997-2016 |
| `r`     | *Regions* -- currently includes 50 U.S. states and Washington, D.C. |
| `s`,`g` | *Sectors/Goods* -- 71 sets from BEA summary data |
| `m`     | *Margin type* for trade and transport adjustments |
| `va`    | *Value added components*, including 
| `fd`    | *Final demand accounts* related to personal consumption expenditures. These are aggregated into consumption (`C`), government (`G`), and investment (`I`) demand in [`SLiDE._disagg_fdcat!`](@ref) |

# Model Input

| Parameter | Indices | Description | References |
|--------:|:-------------|:------------------------------------------------|:--|
| `ys`    | `(yr,r,s,g)` | *Sectoral supply (with byproducts)*             | [`SLiDE._partition_io!`](@ref) [`SLiDE._disagg_ys0!`](@ref) |
| `id`    | `(yr,r,g,s)` | *Intermediate demand*                           | [`SLiDE._partition_io!`](@ref) [`SLiDE._disagg_id0!`](@ref) |
| `ld`    | `(yr,r,s)`   | *Labor demand*                                  | [`SLiDE._disagg_ld0!`](@ref) |
| `kd`    | `(yr,r,s)`   | *Capital demand*                                | [`SLiDE._disagg_kd0`](@ref) |
| `cd`    | `(yr,r,g)`   | *Final demand*                                  | [`SLiDE._disagg_cd0!`](@ref) |
| `yh`    | `(yr,r,g)`   | *Household production*                          | [`SLiDE._disagg_yh0!`](@ref) |
| `g`     | `(yr,r,g)`   | *Government demand*                             | [`SLiDE._disagg_g0!`](@ref) |
| `i`     | `(yr,r,g)`   | *Investment demand*                             | [`SLiDE._disagg_i0!`](@ref) |
| `s`     | `(yr,r,g)`   | *Aggregate supply*                              | [`SLiDE._disagg_s0!`](@ref) |
| `xn`    | `(yr,r,g)`   | *National supply*                               | [`SLiDE._disagg_xn0!`](@ref) |
| `xd`    | `(yr,r,g)`   | *National demand*                               | [`SLiDE._disagg_xd0!`](@ref) |
| `x`     | `(yr,r,g)`   | *Foreign exports*                               | [`SLiDE._partition_x0!`](@ref) [`SLiDE._disagg_x0!`](@ref) |
| `a`     | `(yr,r,g)`   | *Armington supply*                              | [`SLiDE._partition_a0!`](@ref) [`SLiDE._disagg_a0!`](@ref) |
| `m`     | `(yr,r,g)`   | *Imports*                                       | [`SLiDE._partition_m0!`](@ref) [`SLiDE._disagg_x0!`](@ref) |
| `nd`    | `(yr,r,g)`   | *National demand*                               | [`SLiDE._disagg_nd0!`](@ref) |
| `dd`    | `(yr,r,g)`   | *State-level demand*                            | [`SLiDE._disagg_dd0!`](@ref) |
| `bop`   | `(yr,r)`     | *Balance of payments*                           | [`SLiDE._partition_bop!`](@ref) [`SLiDE._disagg_bop!`](@ref) |
| `ta`    | `(yr,r,g)`   | *Tax (net subsidy) rate on intermediate demand* | [`SLiDE._partition_ta0!`](@ref) [`SLiDE._disagg_ta0!`](@ref) |
| `tm`    | `(yr,r,g)`   | *Import tariff*                                 | [`SLiDE._partition_tm0!`](@ref) [`SLiDE._disagg_tm0!`](@ref) |
| `md`    | `(yr,r,m,g)` | *Margin demand*                                 | [`SLiDE._partition_md0!`](@ref) [`SLiDE._disagg_md0!`](@ref) |
| `nm`    | `(yr,r,g,m)` | *National margin supply*                        | [`SLiDE._disagg_nm0!`](@ref) |
| `dm`    | `(yr,r,g,m)` | *State-level margin supply*                     | [`SLiDE._disagg_dm0!`](@ref) |
| `c`     | `(yr,r)`     |                                                 | [`SLiDE._disagg_c0!`](@ref) |
| `rx`    | `(yr,r,g)`   |                                                 | [`SLiDE._disagg_rx0!`](@ref) |
| `ty`    | `(yr,r,g)`   |                                                 | [`SLiDE._disagg_ty0`](@ref) |
| `hhadj` | `(yr,r)`     |                                                 | [`SLiDE._disagg_hhadj!`](@ref) |