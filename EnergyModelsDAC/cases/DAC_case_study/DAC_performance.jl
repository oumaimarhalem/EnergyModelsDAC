"""" Estimating the required electric power for an air blower """
function fan_load(input_DAC::Dict)
    η = 0.60
    Δp = input_DAC["DAC-S"]["pressure_drop"]        # Pa/module
    V_air = input_DAC["DAC-S"]["inlet_air_flow"]    # m3/s/module

    W_blower = (1 / η) * Δp * V_air 
    W_final = W_blower / 1e3 

    return W_final # kWe per module
end
    
""" Estimating the required electric power for a vacuum pump"""
function vacuum_pump_load(input_DAC::Dict)
η = 0.60
m = input_DAC["DAC-S"]["productivity"] * input_DAC["DAC-S"]["contactor_volume"] / 3600 # kg/s/module
T = 378 # K
P1 = 0.10 # MPa
P2 = input_DAC["DAC-S"]["vacuum_pressure"] # MPa

W_vacuum = ((1 / η) * m * 0.918 * T * ((P2 / P1)^0.21875 - 1)) * -1 

    return W_vacuum # kWe per module
end
    
 """ Functions to calculate the costs of DAC-S"""
function initial_DACS_capex_base(input_DAC::Dict)
    EPC_cost = input_DAC["DAC-S_initial"]["EPC"] # M$2022
    TPC_cost = EPC_cost * (1 + input_DAC["DAC-S_initial"]["project_contingency"] + input_DAC["DAC-S_initial"]["process_contingency"])

    overnight_cost = (TPC_cost * (1 + input_DAC["DAC-S_initial"]["owners_cost"] + input_DAC["DAC-S_initial"]["spare_parts"] +
                                    input_DAC["DAC-S_initial"]["startup_capital"])) + input_DAC["DAC-S_initial"]["startup_cost"]

    return (TPC_cost * 1e3), (overnight_cost * 1e3) # k$2022
end

function initial_DACS_opex_fixed_base(input_DAC::Dict)
    TPC_cost = initial_DACS_capex_base(input_DAC)[1]/1e3 # M$2022
    labour = input_DAC["DAC-S_initial"]["opex_fixed"]["labour"]/1e6 # M$2022/yr
    maintenance = TPC_cost * input_DAC["DAC-S_initial"]["opex_fixed"]["maintenance"] # M$2022/yr
    indirect_labour = (labour + maintenance) * input_DAC["DAC-S_initial"]["opex_fixed"]["indirect_labour"] # M$2022/yr

    opex_fixed = (TPC_cost * input_DAC["DAC-S_initial"]["opex_fixed"]["maintenance"]) +
                    (TPC_cost * input_DAC["DAC-S_initial"]["opex_fixed"]["insurance"]) +
                        (TPC_cost * input_DAC["DAC-S_initial"]["opex_fixed"]["taxes"]) +
                            labour + maintenance + indirect_labour

    return (opex_fixed * 1e3) # k$2022/yr
end

function DACS_unit_cost(input_DAC)
    compressor_load = 0.40 * 1e6 * (input_DAC["DAC-S"]["plant_size"]/8760/3600) * 1e3 # kWe
    plant_load = input_DAC["DAC-S"]["plant_power_consumption"] * (input_DAC["DAC-S"]["plant_size"]/8760) * 1e6 # kWe
    total_load = compressor_load + plant_load + 
                                (fan_load(input_DAC) + vacuum_pump_load(input_DAC)) * input_DAC["DAC-S"]["modules"] # kWe

    component_costs = Dict(
        "contactors" => (exp(5.6334 + 0.4599 * log(482.27) + 0.00582 * log(482.27)^2) + 48 * (3.835 * 2.37 + 0.158 * 1.8)) * input_DAC["DAC-S"]["modules"],          
        "vacuum_pumps" => exp(11.23543) * ((input_DAC["DAC-S"]["vacuum_factor"])^0.750473) * input_DAC["DAC-S"]["modules"],  
        "fans" => exp(9.6487 - 0.97566 * log(input_DAC["DAC-S"]["inlet_air_flow"] * 2118.88) + 0.08532 * log(input_DAC["DAC-S"]["inlet_air_flow"] * 2118.88)^2) * input_DAC["DAC-S"]["modules"],                                        
        "compressor" => 2.908e6 * (compressor_load/1490)^0.41,                                                          
        "control" => 6.01e5 * (total_load/50e3)^0.15,                                                                            
        "heat_exchanger" => 1.1e5,                                                                                                
        "desorption" => ((1.011e6/20) * (28.6875/570.776)^0.60) * input_DAC["DAC-S"]["modules"],                                          
        "steam_distribution" => ((1.734e6/20) * (7.2/4.3)^0.70) * input_DAC["DAC-S"]["modules"],
        "storage_tank" => ((input_DAC["DAC-S"]["modules"] * (input_DAC["DAC-S"]["productivity"] * input_DAC["DAC-S"]["cycle_time"] * input_DAC["DAC-S"]["contactor_volume"]/1.98) * 2 * (1+0.20)) / 5000) * 
                            (5000/6.49)^0.30 * 13549.28,
    )

    DAC_unit_cost = sum(values(component_costs))/1e3 

    return DAC_unit_cost # k$
end

function DACS_capex_base(input_DAC::Dict)  
    DAC_unit_cost = DACS_unit_cost(input_DAC) # k$
    bare_erected_cost = sum(values(input_DAC["DAC-S"]["plant_costs"])) + DAC_unit_cost # k$

    total_plant_cost = bare_erected_cost +
        bare_erected_cost * (input_DAC["DAC-S"]["ECM_fee"] + input_DAC["DAC-S"]["project_contingency"]) +
            input_DAC["DAC-S"]["process_contingency"]["control"] * input_DAC["DAC-S"]["plant_costs"]["control"] +
                input_DAC["DAC-S"]["process_contingency"]["DAC_unit"] * DAC_unit_cost

    overnight_cost = total_plant_cost + sum(values(input_DAC["DAC-S"]["owners_costs"]))

    capex = overnight_cost * input_DAC["DAC-S"]["TASC_multiplier"]

    return capex # k$
end

function DACS_opex_fixed_base(input_DAC::Dict)
    labor_cost = sum(values(input_DAC["DAC-S"]["opex_fixed"]["labor"]))
    opex_fixed = labor_cost + input_DAC["DAC-S"]["opex_fixed"]["tax_and_insurance"] + input_DAC["DAC-S"]["opex_fixed"]["maintenance_material"] 

    return opex_fixed # k$/yr
end

function DACS_capex(input_DAC::Dict, year)
    learning_coeff_capex = - log(1 - input_DAC["DAC-S"]["learning_rate"]["capex"]) / log(2)
    capacity_base = values(input_DAC["installed_capacity_global"]["DAC-S"])
    capacity = DACS_deployment_global(input_DAC, year)
    capex_base = DACS_capex_base(input_DAC) # k$

    capex = capex_base * (capacity / capacity_base)^-learning_coeff_capex # k$
    capex_unit = (capex / values(input_DAC["DAC-S"]["plant_size"]))

    exchange_2019 = 0.893 # Annual-averaged exchange rate (OECD)
    capex_unit = capex_unit * exchange_2019
    price_index_1922 = 122.78/105.78 # European harmonised price index (CBS) 
    capex_unit = capex_unit * price_index_1922

    initial_capex_base = initial_DACS_capex_base(input_DAC)[2] # k$2022
    initial_capex = initial_capex_base * (capacity / capacity_base)^-learning_coeff_capex
    initial_capex_unit = (initial_capex * exchange_2019)/values(input_DAC["DAC-S_initial"]["plant_size"]) 

    (year.sp == 1) ? final_capex = initial_capex_unit : final_capex = capex_unit 

    return final_capex # kEUR-2022 per ktCO2/yr installed
end

function DACS_opex_fixed(input_DAC::Dict, year)
    learning_coeff_capex = - log(1 - input_DAC["DAC-S"]["learning_rate"]["capex"]) / log(2)
    capacity_base = input_DAC["installed_capacity_global"]["DAC-S"]
    capacity = DACS_deployment_global(input_DAC, year)
    opex_fixed_base = DACS_opex_fixed_base(input_DAC)

    opex_fixed = opex_fixed_base * (capacity / capacity_base) ^ -learning_coeff_capex
    opex_fixed_unit = (opex_fixed / input_DAC["DAC-S"]["plant_size"])

    exchange_2019 = 0.893 # Annual-averaged exchange rate (OECD)
    opex_fixed_unit = opex_fixed_unit * exchange_2019
    price_index_1922 = 122.78/105.78 # European harmonised price index (CBS) 
    opex_fixed_unit = opex_fixed_unit * price_index_1922

    initial_opex_fixed_base = initial_DACS_opex_fixed_base(input_DAC) * exchange_2019 # kEUR-2022/yr
    initial_opex_fixed = initial_opex_fixed_base * (capacity / capacity_base) ^ -learning_coeff_capex
    initial_opex_fixed_unit = initial_opex_fixed / input_DAC["DAC-S_initial"]["plant_size"]

    (year.sp == 1) ? final_opex_fixed = initial_opex_fixed_unit : final_opex_fixed = opex_fixed_unit 

    return final_opex_fixed # kEUR-2022/yr per ktCO2/yr installed
end

function DACS_opex_var(input_DAC::Dict, year)
    initial_sorbent = input_DAC["DAC-S"]["sorbent_consumption"]["initial"]
    future_sorbent = input_DAC["DAC-S"]["sorbent_consumption"]["future"]
    target_year = input_DAC["target_year"]["DAC-S"] - 2024
    
    rate = (future_sorbent/initial_sorbent)^(1/(target_year)) - 1
    ((1 + (year.sp - 1) * year.duration) < target_year) ? sorbent_consumption = initial_sorbent * (1 + rate)^(1 + (year.sp - 1) * year.duration) : sorbent_consumption = future_sorbent

    sorbent_cost = sorbent_consumption * (input_DAC["DAC-S"]["opex_variable"]["sorbent"] + 
        input_DAC["DAC-S"]["opex_variable"]["sorbent_disposal"])

    learning_coeff_opex_var = - log(1 - input_DAC["DAC-S"]["learning_rate"]["opex_variable"]) / log(2)
    capacity_base = input_DAC["installed_capacity_global"]["DAC-S"]
    capacity = DACS_deployment_global(input_DAC, year)
    opex_var_base = input_DAC["DAC-S"]["opex_variable"]["water"] * input_DAC["DAC-S"]["water_demand"] +
        input_DAC["DAC-S"]["opex_variable"]["chemicals"] * input_DAC["DAC-S"]["chemicals_demand"]

    opex_var = sorbent_cost +
        opex_var_base * (capacity / capacity_base) ^ -learning_coeff_opex_var

    exchange_2019 = 0.893 # Annual-averaged exchange rate (OECD)
    opex_var = opex_var * exchange_2019
    price_index_1922 = 122.78/105.78 # European harmonised price index (CBS) 
    opex_var = opex_var * price_index_1922

    return opex_var # kEUR-2022 per ktCO2 captured
end

""" Functions to calculate the costs of DAC-L """
function initial_DACL_capex_base(input_DAC::Dict)  
    material_installation_cost = sum(values(input_DAC["DAC-L_initial"]["plant_cost"])) * 
                                    (1 + input_DAC["DAC-L_initial"]["installation_cost"]) # M$2022

    EPC_cost = material_installation_cost * (1 + input_DAC["DAC-L_initial"]["EPC_factor"])

    TPC_cost = EPC_cost * (1 + input_DAC["DAC-L_initial"]["project_contingency"] + input_DAC["DAC-L_initial"]["process_contingency"])

    overnight_cost = (TPC_cost * (1 + input_DAC["DAC-L_initial"]["owners_cost"] + input_DAC["DAC-L_initial"]["spare_parts"] +
                                    input_DAC["DAC-L_initial"]["startup_capital"])) + input_DAC["DAC-L_initial"]["startup_cost"]

    return (TPC_cost * 1e3), (overnight_cost * 1e3) # k$2022
end

function initial_DACL_opex_fixed_base(input_DAC::Dict)
    TPC_cost = initial_DACL_capex_base(input_DAC)[1]/1e3 # M$2022
    labour = input_DAC["DAC-L_initial"]["opex_fixed"]["labour"] # M$2022/yr
    maintenance = TPC_cost * input_DAC["DAC-L_initial"]["opex_fixed"]["maintenance"] # M$2022/yr
    indirect_labour = (labour + maintenance) * input_DAC["DAC-L_initial"]["opex_fixed"]["indirect_labour"] # M$2022/yr

    opex_fixed = (TPC_cost * input_DAC["DAC-L_initial"]["opex_fixed"]["maintenance"]) +
                    (TPC_cost * input_DAC["DAC-L_initial"]["opex_fixed"]["insurance"]) +
                        (TPC_cost * input_DAC["DAC-L_initial"]["opex_fixed"]["taxes"]) +
                            labour + maintenance + indirect_labour

    return (opex_fixed * 1e3) # k$2022/yr
end

function DACL_capex_base(input_DAC::Dict)  
    bare_erected_cost = sum(values(input_DAC["DAC-L"]["plant_costs"])) + sum(values(input_DAC["DAC-L"]["DAC_unit_costs"])) # k$

    total_plant_cost = bare_erected_cost + 
        (bare_erected_cost * (input_DAC["DAC-L"]["ECM_fee"] + input_DAC["DAC-L"]["project_contingency"])) +
            input_DAC["DAC-L"]["plant_costs"]["control"] * input_DAC["DAC-L"]["process_contingency"]["control"] +
                sum(values(input_DAC["DAC-L"]["DAC_unit_costs"])) * input_DAC["DAC-L"]["process_contingency"]["DAC_unit"]

    overnight_cost = total_plant_cost + sum(values(input_DAC["DAC-L"]["owners_costs"]))

    capex = overnight_cost * input_DAC["DAC-L"]["TASC_multiplier"]

    return capex # k$
end

function DACL_opex_fixed_base(input_DAC::Dict)
    labor_cost = sum(values(input_DAC["DAC-L"]["opex_fixed"]["labor"]))
    opex_fixed = labor_cost + input_DAC["DAC-L"]["opex_fixed"]["tax_and_insurance"] + input_DAC["DAC-L"]["opex_fixed"]["maintenance_material"] 

    return opex_fixed # k$/yr
end

function DACL_capex(input_DAC::Dict, year)
    learning_coeff_capex = - log(1 - input_DAC["DAC-L"]["learning_rate"]["capex"]) / log(2)
    capacity_base = input_DAC["installed_capacity_global"]["DAC-L"]
    capacity = DACL_deployment_global(input_DAC, year) 
    capex_base = DACL_capex_base(input_DAC) # k$

    capex = capex_base * (capacity / capacity_base) ^ -learning_coeff_capex
    capex_unit = (capex / input_DAC["DAC-L"]["plant_size"])

    exchange_2019 = 0.893 # Annual-averaged exchange rate (OECD)
    capex_unit = capex_unit * exchange_2019
    price_index_1922 = 122.78/105.78 # European harmonised price index (CBS) 
    capex_unit = capex_unit * price_index_1922

    initial_capex_base = initial_DACL_capex_base(input_DAC)[2] * exchange_2019 # kEUR-2022
    initial_capex = initial_capex_base * (capacity / capacity_base) ^ -learning_coeff_capex
    initial_capex_unit = initial_capex / input_DAC["DAC-L_initial"]["plant_size"]

    (year.sp < 3) ? final_capex = initial_capex_unit : final_capex = capex_unit

    return  final_capex # kEUR-2022 per ktCO2/yr installed
end

function DACL_opex_fixed(input_DAC::Dict, year)
    learning_coeff_capex = - log(1 - input_DAC["DAC-L"]["learning_rate"]["capex"]) / log(2)
    capacity_base = input_DAC["installed_capacity_global"]["DAC-L"]
    capacity = DACL_deployment_global(input_DAC, year)
    opex_fixed_base = DACL_opex_fixed_base(input_DAC)

    opex_fixed = opex_fixed_base * (capacity / capacity_base) ^ -learning_coeff_capex
    opex_fixed_unit = (opex_fixed / input_DAC["DAC-L"]["plant_size"])

    exchange_2019 = 0.893 # Annual-averaged exchange rate (OECD)
    opex_fixed_unit = opex_fixed_unit * exchange_2019
    price_index_1922 = 122.78/105.78 # European harmonised price index (CBS) 
    opex_fixed_unit = opex_fixed_unit * price_index_1922

    initial_opex_fixed_base = initial_DACL_opex_fixed_base(input_DAC) * exchange_2019 # kEUR-2022
    initial_opex_fixed = initial_opex_fixed_base * (capacity / capacity_base) ^ -learning_coeff_capex
    initial_opex_fixed_unit = initial_opex_fixed / input_DAC["DAC-L_initial"]["plant_size"]

    (year.sp < 3) ? final_opex_fixed = initial_opex_fixed_unit : final_opex_fixed = opex_fixed_unit

    return final_opex_fixed # kEUR-2022/yr per ktCO2/yr installed
end

function DACL_opex_var(input_DAC::Dict, year)
    sorbent_consumption = input_DAC["DAC-L"]["sorbent_consumption"]
    carbonate_consumption = input_DAC["DAC-L"]["carbonate_consumption"]

    opex_var_base = sorbent_consumption * input_DAC["DAC-L"]["sorbent_price"] + 
        carbonate_consumption * input_DAC["DAC-L"]["carbonate_price"] + 
            input_DAC["DAC-L"]["water_demand"] * input_DAC["DAC-L"]["water_price"] +
                input_DAC["DAC-L"]["waste_disposal"] +
                    input_DAC["DAC-L"]["chemicals_cost"]

    learning_coeff_opex_var = - log(1 - input_DAC["DAC-L"]["learning_rate"]["opex_var"]) / log(2)
    capacity_base = input_DAC["installed_capacity_global"]["DAC-L"]
    capacity = DACL_deployment_global(input_DAC, year)

    opex_var = opex_var_base * (capacity / capacity_base) ^ -learning_coeff_opex_var

    exchange_2019 = 0.893 # Annual-averaged exchange rate (OECD)
    opex_var = opex_var * exchange_2019
    price_index_1922 = 122.78/105.78 # European harmonised price index (CBS) 
    opex_var = opex_var * price_index_1922

    return opex_var # kEUR-2022 per ktCO2 captured
end

""" Functions to calculate the costs of DAC-M """
function DACM_capex_base(input_DAC::Dict)  
    stacks = (input_DAC["DAC-M"]["plant_size"] / (input_DAC["DAC-M"]["productivity"] * 8760 / 1e6)) / 
        input_DAC["DAC-M"]["cell_area"] / input_DAC["DAC-M"]["cells"]
    stack_cost = stacks * input_DAC["DAC-M"]["BPMED_unit_costs"]["stack"] # M$
    membrane_cost = stacks * input_DAC["DAC-M"]["cells"] * input_DAC["DAC-M"]["cell_area"] * 
        ((input_DAC["DAC-M"]["BPMED_unit_costs"]["IEM"] + input_DAC["DAC-M"]["BPMED_unit_costs"]["BPM"]) / 1e6) # M$

    bare_erected_cost = stack_cost + membrane_cost + sum(values(input_DAC["DAC-M"]["plant_costs"])) # M$

    total_plant_cost = bare_erected_cost + (input_DAC["DAC-M"]["installation_cost"] * bare_erected_cost) * 
        (1 + input_DAC["DAC-M"]["indirect_cost"])
    
    capex = total_plant_cost * (1 + input_DAC["DAC-M"]["contingency"] + input_DAC["DAC-M"]["owner's cost"])

    return stack_cost, membrane_cost, capex # M$
end

function DACM_capex(input_DAC::Dict, year)
    learning_coeff = - log(1 - input_DAC["DAC-M"]["learning_rate"]["capex"]) / log(2)
    capacity_base = input_DAC["installed_capacity_global"]["DAC-M"]
    capacity = DACM_deployment_global(input_DAC, year)
    capex_base = DACM_capex_base(input_DAC)[3] * 1e3 # k$

    capex = capex_base * (capacity / capacity_base) ^ -learning_coeff
    capex_unit = (capex / input_DAC["DAC-M"]["plant_size"])

    exchange_2019 = 0.893 # Annual-averaged exchange rate (OECD)
    capex_unit = capex_unit * exchange_2019
    price_index_1922 = 122.78/105.78 # European harmonised price index (CBS) 
    capex_unit = capex_unit * price_index_1922

    if (year.sp < 4)
        final_capex = (capex_base/input_DAC["DAC-M"]["plant_size"]) * exchange_2019 * price_index_1922
    else 
        final_capex = capex_unit
    end

    return final_capex # kEUR-2022 per ktCO2/yr installed
end

function DACM_opex_fixed(input_DAC::Dict, year)
    initial_lifetime = input_DAC["DAC-M"]["membrane_lifetime"]["initial"]
    future_lifetime = input_DAC["DAC-M"]["membrane_lifetime"]["future"]
    target_year = input_DAC["target_year"]["DAC-M"] - 2024

    rate_lifetime = (future_lifetime/initial_lifetime)^(1/(target_year)) - 1
    ((1 + ((year.sp-3) - 1) * year.duration) < target_year) ? membrane_lifetime = initial_lifetime * (1 + rate_lifetime)^(1 + ((year.sp-3) - 1) * year.duration) : membrane_lifetime = future_lifetime

    if (year.sp < 4)
        membrane_lifetime_final = initial_lifetime
    else
        membrane_lifetime_final = membrane_lifetime
    end

    stack_cost, membrane_cost = DACM_capex_base(input_DAC)[1:2] # M$
    annual_replacement_cost = (stack_cost + membrane_cost) * 1e3 / membrane_lifetime_final # k$/yr

    opex_fixed = ((annual_replacement_cost + (input_DAC["DAC-M"]["OPEX_fixed"]["labor"] * 1e3)) / input_DAC["DAC-M"]["plant_size"])  # k$/yr per ktCO2/yr installed
    opex_fixed_total = opex_fixed + 
        (input_DAC["DAC-M"]["OPEX_fixed"]["maintenance"] + input_DAC["DAC-M"]["OPEX_fixed"]["insurance"]) *  DACM_capex(input_DAC, year)

    exchange_2019 = 0.893 # Annual-averaged exchange rate (OECD)
    opex_fixed_total = opex_fixed_total * exchange_2019
    price_index_1922 = 122.78/105.78 # European harmonised price index (CBS) 
    opex_fixed_total = opex_fixed_total * price_index_1922

    return opex_fixed_total # kEUR-2022 per ktCO2/yr installed
end

function DACM_opex_var(input_DAC::Dict)
    opex_var = input_DAC["DAC-M"]["water_demand"] * input_DAC["DAC-M"]["OPEX_var"]["water"]

    exchange_2019 = 0.893 # Annual-averaged exchange rate (OECD)
    opex_var = opex_var * exchange_2019
    price_index_1922 = 122.78/105.78 # European harmonised price index (CBS) 
    opex_var = opex_var * price_index_1922

    return opex_var # kEUR-2022 per ktCO2 captured
end   

""" Estimating the power consumption of DAC-S over time """
function DACS_power(input_DAC::Dict, year)
    initial_power = input_DAC["DAC-S"]["power_consumption"]
    minimum_power = (input_DAC["minimum_thermodynamic_work"] / input_DAC["second_law_efficiency_limit"]) *
                        (1 - input_DAC["share_heat"])
    target_year = input_DAC["target_year"]["DAC-S"] - 2024
    
    rate = (minimum_power/initial_power)^(1/(target_year)) - 1
    
    ((1 + (year.sp - 1) * year.duration) < target_year) ? power = initial_power * (1 + rate)^(1 + (year.sp - 1) * year.duration) : power = minimum_power
    final_power = power + input_DAC["DAC-S"]["plant_power_consumption"]

        return final_power # GWhel/ktCO2
    end    

""" Estimating the heat consumption of DAC-S over time """
function DACS_heat(input_DAC::Dict, year)
    initial_heat = input_DAC["DAC-S"]["heat_consumption"]
    minimum_heat = (input_DAC["minimum_thermodynamic_work"] / input_DAC["second_law_efficiency_limit"]) *
                        (input_DAC["share_heat"]) / (1 - (293/373))    
    target_year = input_DAC["target_year"]["DAC-S"] - 2024
    
    rate = (minimum_heat/initial_heat)^(1/(target_year)) - 1
    
    ((1 + (year.sp - 1) * year.duration) < target_year) ? heat = initial_heat * (1 + rate)^(1 + (year.sp - 1) * year.duration) : heat =  minimum_heat
    
        return heat # GWhth/ktCO2
end     
    

""" Estimating the natural gas consumption of DAC-L over time """
function DACL_NG(input_DAC::Dict, year)
    initial_power = input_DAC["DAC-L"]["power_consumption"]
    minimum_power = (input_DAC["minimum_thermodynamic_work"] / input_DAC["second_law_efficiency_limit"]) *
                        (1 - input_DAC["share_heat"])
    target_year = input_DAC["target_year"]["DAC-L"] - 2024
    
    rate = (minimum_power/initial_power)^(1/(target_year)) - 1
    
    ((1 + (year.sp - 1) * year.duration) < target_year) ? power = initial_power * (1 + rate)^(1 + (year.sp - 1) * year.duration) : power = minimum_power
    final_power = power + sum(values(input_DAC["DAC-L"]["plant_power_consumption"])) - input_DAC["DAC-L"]["power_output"]

    initial_heat = input_DAC["DAC-L"]["heat_consumption"]
    minimum_heat = (input_DAC["minimum_thermodynamic_work"] / input_DAC["second_law_efficiency_limit"]) *
                        (input_DAC["share_heat"])
    
    rate = (minimum_heat/initial_heat)^(1/(target_year)) - 1
    
    ((1 + (year.sp - 1) * year.duration) < target_year) ? heat = initial_heat * (1 + rate)^(1 + (year.sp - 1) * year.duration) : heat =  minimum_heat
    
    final_NG = heat + (final_power * 2.7027)

        return final_NG # GWhth/ktCO2
end      

""" Estimating the power consumption of DAC-M over time """
function DACM_power(input_DAC::Dict, year)
    initial_power = input_DAC["DAC-M"]["power_consumption"]
    minimum_power = (input_DAC["minimum_thermodynamic_work"] / input_DAC["second_law_efficiency_limit"]) 
    target_year = input_DAC["target_year"]["DAC-M"] - 2024   

    rate = (minimum_power/initial_power)^(1/(target_year)) - 1
    
    ((1 + ((year.sp-3) - 1) * year.duration) < target_year) ? power = initial_power * (1 + rate)^(1 + ((year.sp-3) - 1) * year.duration) : power = minimum_power
    
    if (year.sp < 4)
        power_final = initial_power
    else
        power_final = power
    end
    
        return power_final # GWhel/ktCO2
end          


""" Cost of CO2 transport per transmission corridor """
function CO2_transport_cost(corr, mode, year)

    volume = year.sp == 1 ? 1 : year.sp == 2 ? 5 : year.sp == 3 ? 10 : 20 # MtCO2/yr
    transport_cost = corr["mode"][mode]["cost_$(volume)_MtCO2"]
    
    return transport_cost
end
