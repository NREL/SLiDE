#!/bin/bash

rm data_*.jld2

cd ..

julia --project=. ./model/cli_recurse_bmkyr.jl 2016

julia --project=. ./model/cli_recurse_loop.jl 2017 2016
