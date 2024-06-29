# CaseSkeleton

[![Build Status](https://gitlab.sintef.no/clean_export/CaseSkeleton.jl/badges/main/pipeline.svg)](https://gitlab.sintef.no/clean_export/CaseSkeleton.jl/pipelines)
[![Coverage](https://gitlab.sintef.no/clean_export/CaseSkeleton.jl/badges/main/coverage.svg)](https://gitlab.sintef.no/clean_export/CaseSkeleton.jl/commits/main)

CaseSkeleton is a package developed to have a consistent case study design in all cases. It can be extended to account for different functionalities required in the case studies.


## Usage
The base case can be solved from the Julia REPL. Activate the package from the main folder and then run the following code in the REPL

```julia
# Load all functions from the case
using CaseSkeleton
const CS = CaseSkeleton

# Load the input files used in the case study
input_nodes = joinpath(pwd(),"cases","input_nodes.yml")
input_transmission = joinpath(pwd(),"cases","input_transmission.yml")

# Run the model using the default HiGHS solver
m, case, modeltype = CS.run_base_case(input_nodes, input_transmission);
```
There are several built-in functions that can be used for analysing the output. The output of most of the functions is a named tuple where the individual elements can be found in the docstrings in `src\processing_functions.jl`. These functions can be called as

```julia
# Extract the capacity usage of the CCGT power plant. 
usage, capacity_factor = CS.extract_capacity_usage(m, case, modeltype, "CCGT");

# Extract the emissions
CO2 = case[:products][3];   # Can be found in l.14 (products = [Power, NG, CO2]) `in src\model_functions.jl`
emissions = CS.extract_emissions(m, case, modeltype, CO2);
```
The base case has problems with respect to the CO<sub>2</sub> limit in the last strategic period, which can be seen with the call
```julia
using JuMP
deficit = value.(m[:sink_deficit]);
```
where the values in the variable `deficit` are positive for some of the strategic periods. Another approach is to look at the total CO<sub>2</sub> emissions through the following call
```julia
CO2_emissions = value.(m[:emissions_strategic]);
```
We can see that we are limited by the defined `CO2_limit` in `case\input_nodes.yml`.
## Funding
CaseSkeleton was funded by the Norwegian Research Council in the project Clean Export, project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)