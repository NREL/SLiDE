# Energy Parameters

```@docs
SLiDE.partition_seds
```

```@docs
SLiDE.partition_elegen!
```

```@docs
SLiDE.partition_energy!
SLiDE._partition_energy_supply
SLiDE._partition_energy_ref
SLiDE._partition_energy_ind
SLiDE._partition_energy_price
```

```@docs
SLiDE._partition_convfac!
SLiDE._partition_cprice!
SLiDE._partition_prodbtu!
SLiDE._partition_pedef!
SLiDE._partition_pe0!
SLiDE._partition_ps0!
SLiDE._partition_prodval!
SLiDE._partition_shrgas!
SLiDE._partition_netgen!
SLiDE._partition_trdele!
SLiDE._partition_pctgen!
SLiDE._partition_eq0!
SLiDE._partition_ed0!
SLiDE._partition_emarg0!
SLiDE._partition_ned0!
```

## pe0

## netgen

## pctgen

```math
id_{yr,r,g,s} =
\begin{cases}
\sum_{sec} \left( ed_{yr,r,src\rightarrow g, sec} \cdot \alpha^{inp}_{yr,r,g,s,sec} \right) & e \in g
\\
id_{yr,r,g,s} & e\ni g
\end{cases}
```