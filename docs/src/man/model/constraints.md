# Model Constraints

## Zero profit conditions

**A**

```math
\begin{aligned}
\left(1 - \bar{ta}_{g} \right) \bar{a}_{g} + \bar{x}_{g}
&=
\left(1 + \bar{tm}_{g} \right) \bar{m}_{g}
    + \sum_{m}\bar{md}_{m,g}
    + \bar{y}_{g}
\\&\\
\left(1 - \tilde{ta}_{r,g}\right) \tilde{a}_{r,g} + \tilde{rx}_{r,g}
&=
\left(1 + \tilde{tm}_{r,g}\right) \tilde{m}_{r,g}
    + \sum_{m}\tilde{md}_{r,m,g}
    + \tilde{nd}_{r,g} + \tilde{dd}_{r,g}
\end{aligned}
```

**Y**

```math
\begin{aligned}
\sum_{g} \bar{ys}_{s,g}
&=
\sum_{g} \bar{id}_{g,s} + \sum_{va} \bar{va}_{va,s}
\\&\\
\left( 1-\tilde{ty}_{r,s} \right) \sum_{g}\tilde{ys}_{r,s,g}
&=
\sum_{g}\tilde{id}_{r,g,s} + \tilde{ld}_{r,s} + \tilde{kd}_{r,s}
\end{aligned}
```

**MS**

```math
\sum_{s} \left( \tilde{nm}_{r,s,m} + \tilde{dm}_{r,s,m} \right)
=
\sum_{g} \tilde{md}_{r,m,g}
```

**X**
```math
\tilde{s}_{r,g} + \tilde{rx}_{r,g} = \tilde{x}_{r,g} + \tilde{xn}_{r,g} + \tilde{xd}_{r,g}
```

## Market clearing conditions

**PY**

```math
\begin{aligned}
\sum_{m} \bar{ms}_{g,m} + \bar{y}_{g}
&=
\sum_{s} \bar{ys}_{s,g} + \bar{fs}_{g}
\\&\\
\tilde{s}_{r,g} &= \sum_{s}\tilde{ys}_{r,s,g} + \tilde{yh}_{r,g}
\end{aligned}
```

**PA**

```math
\begin{aligned}
\bar{a}_{g} &= \sum_{s} \bar{id}_{g,s} + \sum_{fd} \bar{fd}_{g,fd}
\\&\\
\tilde{a}_{r,g} &= \sum_{s}\tilde{id}_{r,g,s} + \tilde{cd}_{r,g} + \tilde{g}_{r,g} + \tilde{i}_{r,g}
\end{aligned}
```

**PM**

```math
\sum_{g} \bar{ms}_{g,m} = \sum_{g} \bar{md}_{m,d}
```

**PD**
```math
\tilde{xd}_{r,g} = \sum_{m}\tilde{dm}_{r,g,m} + \tilde{dd}_{r,g}
```

**PN**
```math
\sum_{r}\tilde{xn}_{r,g}
=
\sum_{r} \left( \tilde{nd}_{r,g} + \sum_{m}\tilde{nm}_{r,g,n} \right)
```

**PFX**
```math
\sum_{r,g}\tilde{m}_{r,g}
=
\sum_{r} \left( \tilde{bopdef}_{r} + \tilde{hhadj}_{r} + \sum_{g}\tilde{x}_{r,g} \right)
```

## Others

**Gross Exports**
```math
\tilde{x}_{r,g} \geq \tilde{rx}_{r,g}
```

**Income balance**
```math
\begin{aligned}
\sum_{g} \left( \tilde{cd}_{r,g} + \tilde{g}_{r,g} + \tilde{i}_{r,g} \right)
=
\sum_{g}&\tilde{yh}_{r,g} + \tilde{bopdef}_{r} + \tilde{hhadj}_{r}
\\    &+ \sum_{s} \left( \tilde{ld}_{r,s} + \tilde{kd}_{r,s} \right)
\\    &+ \sum_{g} \left( \tilde{ta}_{r,g}\tilde{a}_{r,g} + \tilde{tm}_{r,g}\tilde{m}_{r,g} \right)
\\    &+ \sum_{s} \left( \tilde{ty}_{r,s} + \sum_{g}\tilde{ys}_{r,s,g}\right)
\end{aligned}
```

**Value share**
```math
\begin{aligned}
\tilde{ld}_{r,s} &\geq \dfrac{1}{2} \tilde{fvs}_{r,s,ld} \sum_{g}\tilde{ys}_{r,s,g}
\\&\\
\tilde{kd}_{r,s} &\geq \dfrac{1}{2} \tilde{fvs}_{r,s,kd} \sum_{g}\tilde{ys}_{r,s,g}
\end{aligned}
```

**Net generation of electricity balancing**
```math
0.8 \left| \tilde{netgen}_{r} \right|
\leq
\left| \tilde{nd}_{r,g=ele} - \tilde{xn}_{r,g=ele} \right|
\leq
1.2 \left| \tilde{netgen}_{r} \right|
```

**Regional totals equal national totals**
```math
\begin{aligned}
\\
\sum_{r}\tilde{x}_{r,nat\in g} &= \bar{x}_{nat\in g}
\\
\sum_{r}\tilde{m}_{r,nat\in g} &= \bar{m}_{nat\in g}
\\
\sum_{r}\tilde{g}_{r,nat\in g} &= \bar{g}_{nat\in g}
\\
\sum_{r}\tilde{i}_{r,nat\in g} &= \bar{i}_{nat\in g}
\\
\sum_{r}\tilde{c}_{r,nat\in g} &= \bar{c}_{nat\in g}
\\
\sum_{r}\left(\tilde{ld}_{r,nat\in s} + \tilde{kd}_{r,nat\in s} \right) &= \bar{va}_{nat\in s}
\\
\sum_{r,nat\in g}\tilde{ys}_{r,nat\in s,nat\in g} &= \sum_{nat\in g}\bar{ys}_{nat\in s,nat\in g}
\end{aligned}
```