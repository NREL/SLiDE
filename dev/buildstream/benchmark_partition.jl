
ks = collect(setdiff(intersect(keys(io), keys(bluenote)), [:supply,:use]))
x = Drop.(:value, [missing, 0.0], "==")

for k in ks
    cols = intersect(propertynames(bluenote[k]), propertynames(io[k]))    
    io_temp = edit_with(copy(io[k]), x)[:, cols]
    bluenote_temp = edit_with(copy(bluenote[k]), x)[:, cols]
    
    compare_values([io_temp, bluenote_temp], [:slide,:bluenote])
end