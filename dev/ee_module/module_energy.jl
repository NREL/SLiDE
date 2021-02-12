year = 2016

secmap = read_file("data/mapsources/WiNDC/windc_build/seds_files/secmap.map")[:,1:2]
secmap = edit_with(secmap, Rename.([:missing,:missing_1], [:sec,:sector]))

dfout = copy(seds_out[:energy])
dfs = copy(d[:seds])
dfe = copy(d[:elegen])

