# -------------------------------------------------------------------------------
# name:        runbatch.py
# purpose:     to handle input and output from GAMS models
#
# author:      jon becker (jon.becker@nrel.gov)
#
# copyright:    free to share
# -----------------------------------------------------------------------------
# To run this script, adjust the environment to the current PC in
# setupEnvironment(), source the file, then run main() -- instructions to
# generalize this script to other models are below
#

# import packages
import os
import sys
import argparse
import csv
import pandas as pd
import numpy as np

def setupEnv():
    InputDir = os.getcwd()

    print(" ")
    GAMSDir = r"C:\GAMS\win64\24.2"
    print("GAMS directory: " + str(GAMSDir))
    print(" ")

    print("-- Specify the run name -- ")
    print(" ")

    df_cases = pd.read_csv('cases.csv', dtype=object, index_col=0)

    # initiate the empty lists which will be filled with info from cases
    caseList = []
    caseSwitches = []
    caseNames = df_cases.columns[2:].tolist()
    print("Cases being run:")
    print(" ")
    for case in casenames:
        print(case)
        # Fill any missing switches with defaults in cases.csv
        df_cases[case] = df_cases[case].fillna(df_cases['Default Value'])
        shcom = ' --case=' + case
        for i,v in df_cases[case].iteritems():
            shcom = shcom + ' --' + i + '=' + v
        caseList.append(shcom)
        caseSwitches.append(df_cases[case].to_dict())
    df_cases.drop(['Description','Default Value'], axis='columns', inplace=True)
# .... stopped here .... incomplete    
           
