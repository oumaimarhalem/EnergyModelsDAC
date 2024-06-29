module EnergyModelsDAC

using JuMP
using Gurobi
using YAML
using TimeStruct
using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsInvestments
using Dates
using Revise
using Distances
using CSV
using DataFrames
using Statistics
using FileIO
using JLD2

const TS = TimeStruct
const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography
const EMI = EnergyModelsInvestments

# General functions
include("datastructures.jl")
include("utils.jl")
include("model.jl")
include("constraint_functions.jl")
include("processing_functions.jl")
include("read_functions.jl")
include("model_functions.jl")

# Export the processing functions-
export extract_capacity_usage, extract_capacity_invest
export extract_transmission_usage, extract_transmission_invest
export extract_area_exchange
export extract_emissions

# DAC case study
include("../cases/DAC_case_study/base_case.jl")
include("../cases/DAC_case_study/DAC_deployment.jl")
include("../cases/DAC_case_study/DAC_performance.jl")
include("../cases/DAC_case_study/DAC_power_system.jl")
include("../cases/DAC_case_study/DAC_weather.jl")

run_base_case(
  "./EnergyModelsDAC/cases/DAC_case_study/input_nodes.yml",
    "./EnergyModelsDAC/cases/DAC_case_study/input_transmission.yml",
      "./EnergyModelsDAC/cases/DAC_case_study/input_regions.yml",
        "./EnergyModelsDAC/cases/DAC_case_study/input_DAC.yml",
            "./EnergyModelsDAC/cases/DAC_case_study/input_storage.yml",
                "./EnergyModelsDAC/cases/DAC_case_study/input_geo.yml",
                    "./EnergyModelsDAC/cases/DAC_case_study/input_nuclear.yml",

)

end
