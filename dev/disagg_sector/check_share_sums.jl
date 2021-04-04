# Here, we're looking at the original BEA make-use tables at the detail level,
# mapping to summary, and summing shares to see if they initially add up to one.

function compare_total(d::Dict, key::Symbol)
    df = indexjoin(d[key],d[append(key,:det)]; id=[:summary,:detail])
    df[!,:diff] .= df[:,:summary] .- df[:,:detail]
    
    return dropzero(df)
end

path = "data/input_1.0.1/"
io_names = [:use,:use_det,:supply,:supply_det]

# Read sets and things. Figure stuff out.
d = Dict(k => read_file(path*"$k.csv") for k in io_names)
chk = Dict()

x = Deselect([:units],"==")
chk[:use] = filter_with(edit_with(d[:use],x), (yr=[2007,2012],))
chk[:supply] = filter_with(edit_with(d[:supply],x), (yr=[2007,2012],))

x = [x;
    Rename.([:s,:g],[:s_det,:g_det]);
    Map("scale/sector/bluenote.csv",[:detail_code],[:summary_code],[:g_det],[:g],:left);
    Map("scale/sector/bluenote.csv",[:detail_code],[:summary_code],[:s_det],[:s],:left);
    Replace(:s,missing,"s_det value");
    Replace(:g,missing,"g_det value");
    Combine("sum", propertynames(d[:use]));
    Order(propertynames(d[:use]), eltype.(eachcol(d[:use])));
]

chk[:use_det] = sort(edit_with(d[:use_det], x))
chk[:supply_det] = sort(edit_with(d[:supply_det], x))

use = compare_total(chk,:use)
supply = compare_total(chk,:supply)

maximum(abs.(use[:,:diff]))
maximum(abs.(supply[:,:diff]))