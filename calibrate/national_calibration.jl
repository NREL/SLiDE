

################################################
# 
# Calibration exercise to create balanced SAM
#
################################################


using SLiDE
using CSV
using JuMP
using DataFrames


# -- Functions

##########
# FUNCTIONS
##########

#replace here with "collect"
function key_to_vec(d::Dict,index_num::Int64)
    return [k[index_num] for k in keys(d)]
  end
  
  function fill_zero(source::Dict,tofill::Dict)
    for k in keys(source)
        if !haskey(tofill,k)
            push!(tofill,k=>0)
        end
    end
  end
  
  function fill_zero(source::Tuple, tofill::Dict)
  # Assume all possible permutations of keys should be present
  # and determine which are missing.
    allkeys = vcat(collect(Base.Iterators.product(source...))...)
    missingkeys = setdiff(allkeys, collect(keys(tofill)))
  
  # Add
    [push!(tofill, fill=>0) for fill in missingkeys]
    return tofill
  end
  
  #function here simplifies the loading and subsequent subsetting of the dataframes
  function read_data_temp(file::String,year::Int64,dir::String,desc::String)
    df = SLiDE.read_file(dir,CSVInput(name=string(file,".csv"),descriptor=desc))
    df = df[df[!,:yr].==year,:]
    return df
  end
  
  function df_to_dict(df::DataFrame,remove_column::Symbol,value_column::Symbol)
    colnames = setdiff(names(df),[value_column,remove_column])
    if length(colnames) == 1 
        return Dict((row[colnames]...)=>row[:Val] for row in eachrow(df))
    end 

    if length(colnames) > 1 
        return Dict(tuple(row[colnames]...)=>row[:Val] for row in eachrow(df))
    end 

    
  end
  

##################
# -- Load Data --
##################

data_temp_dir = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "calibrate", "data_temp"))

mod_year = 2016


cal = Dict(
    :y0 => df_to_dict(read_data_temp("y0",mod_year,data_temp_dir,"Gross output"),:yr,:Val),
    :ys0 => df_to_dict(read_data_temp("ys0",mod_year,data_temp_dir,"Sectoral supply"),:yr,:Val),
    :fs0 => df_to_dict(read_data_temp("fs0",mod_year,data_temp_dir,"Household supply"),:yr,:Val),
    :id0 => df_to_dict(read_data_temp("id0",mod_year,data_temp_dir,"Intermediate demand"),:yr,:Val),
    :fd0 => df_to_dict(read_data_temp("fd0",mod_year,data_temp_dir,"Final demand"),:yr,:Val),
    :va0 => df_to_dict(read_data_temp("va0",mod_year,data_temp_dir,"Value added"),:yr,:Val),
    :m0 => df_to_dict(read_data_temp("m0",mod_year,data_temp_dir,"Imports"),:yr,:Val),
    :x0 => df_to_dict(read_data_temp("x0",mod_year,data_temp_dir,"Exports of goods and services"),:yr,:Val),
    :ms0 => df_to_dict(read_data_temp("ms0",mod_year,data_temp_dir,"Margin supply"),:yr,:Val),
    :md0 => df_to_dict(read_data_temp("md0",mod_year,data_temp_dir,"Margin demand"),:yr,:Val),
    :a0 => df_to_dict(read_data_temp("a0",mod_year,data_temp_dir,"Armington supply"),:yr,:Val),
    :ta0 => df_to_dict(read_data_temp("ta0",mod_year,data_temp_dir,"Tax net subsidy rate on intermediate demand"),:yr,:Val),
    :tm0 => df_to_dict(read_data_temp("tm0",mod_year,data_temp_dir,"Import tariff"),:yr,:Val)
)


calib = Model()

@variable(calib,ys0_est[j,i]>=0,start=)
@variable(calib,fs0_est[i]>=0,start=)
@variable(calib,ms0_est[i,m]>=0,start=)
@variable(calib,y0_est[i]>=0,start=)
@variable(calib,id0_est[i,j]>=0,start=)
@variable(calib,fd0_est[i,fd]>=0,start=)
@variable(calib,va0_est[va,j]>=0,start=)
@variable(calib,a0_est[i]>=0,start=)
@variable(calib,x0_est[i]>=0,start=)
@variable(calib,m0_est[i]>=0,start=)
@variable(calib,md0_est[m,i]>=0,start=)








