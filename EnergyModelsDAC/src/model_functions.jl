function create_resources(input, input_DAC)
    Power             = ResourceCarrier("Power", 0.0)
    Heat_LT           = ResourceCarrier("Heat_LT", 0.0)    
    CO2               = ResourceEmit("CO2", 1.0)
    NG                = ResourceCarrier("NG", 0.0)
    products = [Power, Heat_LT, CO2, NG]
               
    map_res = Dict(
        "Power"             => Power,
        "Heat_LT"           => Heat_LT,
        "CO2"               => CO2,
        "NG"                => NG,
    )
    return products, map_res
end

function create_region_countries(region, counter, input, input_regions, input_DAC, input_geo, input_nuclear, products, T)
    # Creation of a dictionary with entries of 0 for all emission resources
    𝒫ᵉᵐ₀ = Dict(k => 0.0 for k ∈ products if typeof(k) == ResourceEmit{Float64})

    # Extraction of products from the array
    Power, Heat_LT, CO2, NG = products

    # Classify the geothermal power plants
    geo_plants = Dict([key => [] for key ∈ ["Dry steam", "Single flash", "Double flash", "Binary"]])
    for (key, value) ∈ input_geo 
        if haskey(value, "name_turbine_type")
            turbine_type = value["name_turbine_type"]
            has_type = false
            for type ∈ ["Dry steam", "Single flash", "Double flash"]
                if turbine_type == type
                    push!(geo_plants[type], key)
                    has_type = true
                    break
                end
            end
            if !has_type
                push!(geo_plants["Binary"], key)
            end
        end
    end

    # Declare the data for the investments
    inv_DACS = InvData(
        Capex_cap       = time_profile([DACS_capex(input_DAC, year) for year ∈ strategic_periods(T)], T),   
        Cap_max_inst    = time_profile(input_DAC["capacity_max_installed"], T),      
        Cap_max_add     = time_profile(input_DAC["capacity_max_added"], T),                   
        Cap_min_add     = FixedProfile(0),
        Inv_mode        = EMI.DiscreteInvestment(),
        Cap_increment   = time_profile([4.0, 100, 100, 100, 100, 100], T),                                           
        Life_mode       = EMI.StudyLife(),
        Lifetime        = time_profile(input_DAC["DAC-S"]["plant_lifetime"], T),                                                 
    )
    inv_DACL = InvData(
        Capex_cap       = time_profile([DACL_capex(input_DAC, year) for year ∈ strategic_periods(T)], T),   
        Cap_max_inst    = time_profile(input_DAC["capacity_max_installed"], T),      
        Cap_max_add     = time_profile(input_DAC["capacity_max_added"], T),                   
        Cap_min_add     = FixedProfile(0),
        Inv_mode        = EMI.DiscreteInvestment(),
        Cap_increment   = time_profile([100, 100, 904, 904, 904, 904], T),  
        Life_mode       = EMI.StudyLife(),
        Lifetime        = time_profile(input_DAC["DAC-L"]["plant_lifetime"], T),                                                 
    )
    inv_DACM = InvData(
        Capex_cap       = time_profile([DACM_capex(input_DAC, year) for year ∈ strategic_periods(T)], T),   
        Cap_max_inst    = time_profile(input_DAC["capacity_max_installed"], T),      
        Cap_max_add     = time_profile(input_DAC["capacity_max_added"], T),                   
        Cap_min_add     = FixedProfile(0),
        Inv_mode        = EMI.DiscreteInvestment(),
        Cap_increment   = time_profile([1000, 1000, 1000, 1000, 1000, 1000], T),                                       
        Life_mode       = EMI.StudyLife(),
        Lifetime        = time_profile(input_DAC["DAC-M"]["plant_lifetime"], T),                                                 
    )
    inv_HP = InvData(
        Capex_cap       = time_profile(input["Heat_pump"]["CAPEX"], T),                              
        Cap_max_inst    = time_profile(input["Heat_pump"]["capacity_max_installed"], T),   
        Cap_max_add     = time_profile(input["Heat_pump"]["capacity_max_add"], T),                  
        Cap_min_add     = time_profile(input["Heat_pump"]["capacity_min_add"], T), 
        Inv_mode        = EMI.DiscreteInvestment(),
        Cap_increment   = time_profile(input["Heat_pump"]["cap_increment"], T),    
        Life_mode       = EMI.StudyLife(),
        Lifetime        = time_profile(input["Heat_pump"]["Lifetime"], T),                                                 
    )
    inv_geoheating_EGS = InvData(
        Capex_cap       = time_profile(input["Geothermal_heating_EGS"]["CAPEX"], T),                              
        Cap_max_inst    = time_profile(input["Geothermal_heating_EGS"]["capacity_max_installed"], T),   
        Cap_max_add     = time_profile(input["Geothermal_heating_EGS"]["capacity_max_add"], T),                   
        Cap_min_add     = time_profile(input["Geothermal_heating_EGS"]["capacity_min_add"], T),                  
        Inv_mode        = EMI.DiscreteInvestment(),
        Cap_increment   = time_profile(input["Geothermal_heating_EGS"]["cap_increment"], T),    
        Life_mode       = EMI.StudyLife(),                                                 
        Lifetime        = time_profile(input["Geothermal_heating_EGS"]["Lifetime"], T),                                                 
    )
    inv_solar_thermal = InvData(
        Capex_cap       = time_profile(input["Solar_thermal"]["CAPEX"], T),                              
        Cap_max_inst    = time_profile(input["Solar_thermal"]["capacity_max_installed"], T),   
        Cap_max_add     = time_profile(input["Solar_thermal"]["capacity_max_add"], T),                   
        Cap_min_add     = time_profile(input["Solar_thermal"]["capacity_min_add"], T),  
        Inv_mode        = EMI.DiscreteInvestment(),
        Cap_increment   = time_profile(input["Solar_thermal"]["cap_increment"], T),         
        Life_mode       = EMI.StudyLife(),                                                  
        Lifetime        = time_profile(input["Solar_thermal"]["Lifetime"], T),                                                 
    )
    inv_heat_stor = InvDataStorage(
        Capex_rate      = FixedProfile(0.001),
        Rate_max_inst   = time_profile(input["Heat_storage"]["rate_max_installed"], T),   
        Rate_max_add    = time_profile(input["Heat_storage"]["rate_max_add"], T),   
        Rate_min_add    = time_profile(input["Heat_storage"]["rate_min_add"], T),  
        Capex_stor      = FixedProfile(0.001),
        Stor_max_inst   = time_profile(input["Heat_storage"]["stor_max_installed"], T),  
        Stor_max_add    = time_profile(input["Heat_storage"]["stor_max_add"], T),
        Stor_min_add    = time_profile(input["Heat_storage"]["stor_min_add"], T),
        Inv_mode        = EMI.DiscreteInvestment(),
        Rate_increment = time_profile(input["Heat_storage"]["rate_cap_increment"], T),
        Stor_increment = time_profile(input["Heat_storage"]["stor_cap_increment"], T),
        Life_mode       = EMI.StudyLife(),
        Lifetime        = time_profile(input["Solar_thermal"]["Lifetime"], T), 
    )
    inv_SMR = InvData(
        Capex_cap       = time_profile(input["SMR"]["CAPEX"], T),                            
        Cap_max_inst    = time_profile(input["SMR"]["capacity_max_installed"], T),   
        Cap_max_add     = time_profile(input["SMR"]["capacity_max_add"], T),                  
        Cap_min_add     = time_profile(input["SMR"]["capacity_min_add"], T),  
        Inv_mode        = EMI.DiscreteInvestment(),
        Cap_increment   = time_profile(input["SMR"]["cap_increment"], T),     
        Life_mode       = EMI.StudyLife(),                                                  
        Lifetime        = time_profile(input["SMR"]["Lifetime"], T),                                                 
    )
    
    # Declare the different nodes available in the region
    nodes = Array{EMB.Node}([
        RefSource(region * " - NG_supply",
            FixedProfile(1e3),             
            time_profile(input["NG"]["price"][region], T),
            # time_profile([natural_gas_price(input, region, year) for year ∈ strategic_periods(T)], T),
            FixedProfile(0),
            Dict(NG => 1),
            [],
            Dict(CO2 => ((input["NG"]["CO2_intensity"] * (1 - input_DAC["DAC-L"]["share_CO2_capture"])) + 
                            (input["NG"]["CO2_intensity"] * input["NG"]["leakage_fraction"]))
                )             
        ),
        DACS(region * " - DACS",                             
            FixedProfile(0),
            input_DAC["DAC-S"]["capacity_factor"],
            input_DAC["DAC-S"]["capacity_factor_min"],     
            time_profile([DACS_opex_var(input_DAC, year) for year ∈ strategic_periods(T)], T),                
            time_profile([DACS_opex_fixed(input_DAC, year) for year ∈ strategic_periods(T)], T),                 
            Dict(
                Power => time_profile([DACS_power(input_DAC, year) for year ∈ strategic_periods(T)], T), 
                Heat_LT => time_profile([DACS_heat(input_DAC, year) for year ∈ strategic_periods(T)], T),
                ),                       
            Dict(CO2 => 1),                                                 
            [inv_DACS],                               
        ),
        DACL(region * " - DACL",                             
            FixedProfile(0),
            input_DAC["DAC-L"]["capacity_factor"], 
            input_DAC["DAC-L"]["capacity_factor_min"],     
            time_profile([DACL_opex_var(input_DAC, year) for year ∈ strategic_periods(T)], T),                
            time_profile([DACL_opex_fixed(input_DAC, year) for year ∈ strategic_periods(T)], T),           
            Dict(
                NG => time_profile([DACL_NG(input_DAC, year) for year ∈ strategic_periods(T)],T),
                ),                       
            Dict(CO2 => 1),                                                 
            [inv_DACL],
            Dict(CO2 => 0),                                                                                
        ),
        DACM(region * " - DACM",                             
            FixedProfile(0),
            input_DAC["DAC-M"]["capacity_factor"], 
            input_DAC["DAC-M"]["capacity_factor_min"],     
            time_profile(DACM_opex_var(input_DAC), T),                
            time_profile([DACM_opex_fixed(input_DAC, year) for year ∈ strategic_periods(T)], T),              
            Dict(
                Power => time_profile([DACM_power(input_DAC, year) for year ∈ strategic_periods(T)],T),
                ),                       
            Dict(CO2 => 1),                                                 
            [inv_DACM],                               
        ),
        HeatPump(region * " - Heat_pump",                             
            time_profile(input["Heat_pump"]["capacity"], T),                  
            time_profile(input["Heat_pump"]["OPEX_variable"], T),                     
            time_profile(input["Heat_pump"]["OPEX_fixed"], T),                         
            Dict(Power => 1),                       
            Dict(Heat_LT => 1),  
            time_profile(air_temp(input_regions["Countries"][region]["name"]), T),
            input_DAC["DAC-S"]["regeneration_temperature"],                              
            [inv_HP],
        ),
        RefSource(region * " - Geothermal_heating_EGS",
            time_profile(input["Geothermal_heating_EGS"]["capacity"], T),         
            time_profile(input["Geothermal_heating_EGS"]["OPEX_variable"], T),            
            time_profile(input["Geothermal_heating_EGS"]["OPEX_fixed"], T),              
            Dict(Heat_LT => 1),
            [inv_geoheating_EGS],
        ),
        SolarThermal(region * " - Solar_thermal",
            time_profile(input["Solar_thermal"]["capacity"], T),                 
            time_profile(input["Solar_thermal"]["OPEX_variable"], T),            
            time_profile(input["Solar_thermal"]["OPEX_fixed"], T), 
            time_profile(solar_irradiance(input_regions["Countries"][region]["name"]), T),
            time_profile(input["Solar_thermal"]["efficiency"],T),
            input["Solar_thermal"]["heat_capacity"],
            Dict(Heat_LT => 1),
            [inv_solar_thermal],
        ),
        HeatStorage(region * " - Heat_storage",
             time_profile(input["Heat_storage"]["rate_capacity"], T),                 
             time_profile(input["Heat_storage"]["storage_capacity"], T),            
             time_profile(input["Heat_storage"]["OPEX_variable"], T),   
             time_profile(input["Heat_storage"]["OPEX_fixed"], T),
             Heat_LT,   
             Dict(Heat_LT => 1),
             Dict(Heat_LT => input["Heat_storage"]["Cycle_efficiency"]),
             input["Heat_storage"]["Storage_loss_coeff_1"],
             input["Heat_storage"]["Storage_loss_coeff_2"],
             input["Heat_storage"]["Minimum_temperature"],
             input["Heat_storage"]["Maximum_temperature"],
             FixedProfile(12),
             #time_profile(air_temp(input_regions["Countries"][region]["name"]), T),
             [inv_heat_stor],
        ),
        SMR(region * " - SMR",
             time_profile(input["SMR"]["capacity"], T),  
             time_profile(input["SMR"]["OPEX_variable"], T),            
             time_profile(input["SMR"]["OPEX_fixed"], T),
             Dict(Heat_LT => input["SMR"]["Output"]["Heat"], Power => input["SMR"]["Output"]["Power"]),
             input["SMR"]["Loss_factor"],
             [inv_SMR],
             Dict(CO2 => input["SMR"]["CO2_intensity"])
        ),
        GeothermalPowerPlant(region * " - Dry_steam",
            time_profile(sum(values(input_geo[plant]["gross_cap_ele"]) for plant ∈ geo_plants["Dry steam"] if input_geo[plant]["country_code"] == region; init=0)/1e3,T),         
            input["Geothermal_power_plant"]["capacity_factor"],
            FixedProfile(0), 
            FixedProfile(0), 
            Dict(Heat_LT => 1),
            input["Geothermal_power_plant"]["electrical_flow_ratio"]["Dry_steam"],
            [], 
            Dict(CO2 => input["Geothermal_power_plant"]["CO2_intensity"]),
        ),
        GeothermalPowerPlant(region * " - Single_flash",
            time_profile(region in ["CZ", "DE", "FR", "EL", "HU", "LV", "SK", "HR"] ?
                input_geo["future_cap"][region]/1e3 :
                    sum(values(input_geo[plant]["gross_cap_ele"]) for plant ∈ geo_plants["Single flash"] if input_geo[plant]["country_code"] == region; init=0)/1e3,
                        T),         
            input["Geothermal_power_plant"]["capacity_factor"],
            FixedProfile(0), 
            FixedProfile(0), 
            Dict(Heat_LT => 1),
            input["Geothermal_power_plant"]["electrical_flow_ratio"]["Single_flash"],
            [],
            Dict(CO2 => input["Geothermal_power_plant"]["CO2_intensity"]),
        ),
        GeothermalPowerPlant(region * " - Double_flash",
            time_profile(sum(values(input_geo[plant]["gross_cap_ele"]) for plant ∈ geo_plants["Double flash"] if input_geo[plant]["country_code"] == region; init=0)/1e3,T),         
            input["Geothermal_power_plant"]["capacity_factor"],
            FixedProfile(0), 
            FixedProfile(0), 
            Dict(Heat_LT => 1),
            input["Geothermal_power_plant"]["electrical_flow_ratio"]["Double_flash"],
            [],
            Dict(CO2 => input["Geothermal_power_plant"]["CO2_intensity"]),
        ),
        GeothermalPowerPlant(region * " - Binary",
            time_profile(sum(values(input_geo[plant]["gross_cap_ele"]) for plant ∈ geo_plants["Binary"] if input_geo[plant]["country_code"] == region; init=0)/1e3,T),         
            input["Geothermal_power_plant"]["capacity_factor"],
            FixedProfile(0), 
            FixedProfile(0), 
            Dict(Heat_LT => 1),
            input["Geothermal_power_plant"]["electrical_flow_ratio"]["Binary"],
            [],
            Dict(CO2 => input["Geothermal_power_plant"]["CO2_intensity"]),
        ),
        NuclearPowerPlant(region * " - Nuclear",
            time_profile(input_nuclear[input_regions["Countries"][region]["code"]], T),         
            input["Nuclear_power_plant"]["capacity_factor"],
            FixedProfile(0), 
            FixedProfile(0), 
            Dict(Heat_LT => 1.3),
            [],           
        ),
        Grid(region * " - Power_grid",                                  
            FixedProfile(1e6),              
            time_profile(power_prices_daily(input_regions["Countries"][region]["name"]),T),
            FixedProfile(0),
            Dict(Power => 1),                                                                                                                                                          
            [], 
            Dict(CO2 => time_profile(power_emissions_daily(input_regions["Countries"][region]["name"]),T)),
            ),
        RefSink(region * " - Power_sink",                                  
            FixedProfile(1e6),                 
            Dict(
                :Surplus => FixedProfile(0),    
                :Deficit => FixedProfile(0),
                ),
            Dict(Power => 1),                                                                                                        
            Dict(CO2 => 0),
        ),
        RefSink(region * " - Heat_sink",                                  
            FixedProfile(1e6),                 
            Dict(
                :Surplus => FixedProfile(0),    
                :Deficit => FixedProfile(0),
                ),
            Dict(Heat_LT => 1),                                                                                                        
            Dict(CO2 => 0),
        ), 
    ])

    # Creation of a dictionary with entries of 0 for all resources in the area for the availability node 
    𝒫₀ = Dict(k => 0 for k ∈ products)
    append!(nodes, [GeoAvailability(region, 𝒫₀, 𝒫₀)])

    # Create the links between the individual cells
    links = [
        Direct(region * " - NG_supply-DACL", nodes[1], nodes[3]),
        Direct(region * " - DACS-Av", nodes[2], nodes[end]),
        Direct(region * " - DACL-Av", nodes[3], nodes[end]),
        Direct(region * " - DACM-Av", nodes[4], nodes[end]),
        Direct(region * " - Heat_pump-DACS", nodes[5], nodes[2]),
        Direct(region * " - Power_grid-Heat_pump", nodes[15], nodes[5]),
        Direct(region * " - Geothermal_heating_EGS-DACS", nodes[6], nodes[2]),
        Direct(region * " - Solar_thermal-DACS", nodes[7], nodes[2]),
        Direct(region * " - Solar_thermal-Heat_storage", nodes[7], nodes[8]),
        Direct(region * " - Heat_storage-DACS", nodes[8], nodes[2]),
        Direct(region * " - SMR-DACS", nodes[9], nodes[2]),
        Direct(region * " - SMR-Power_sink", nodes[9], nodes[16]),
        Direct(region * " - Dry_steam-DACS", nodes[10], nodes[2]),
        Direct(region * " - Single_flash-DACS", nodes[11], nodes[2]),
        Direct(region * " - Double_flash-DACS", nodes[12], nodes[2]),
        Direct(region * " - Binary-DACS", nodes[13], nodes[2]),
        Direct(region * " - Dry_steam-Av", nodes[10], nodes[end]),
        Direct(region * " - Single_flash-Av", nodes[11], nodes[end]),
        Direct(region * " - Double_flash-Av", nodes[12], nodes[end]),
        Direct(region * " - Binary-Av", nodes[13], nodes[end]),
        Direct(region * " - Nuclear-DACS", nodes[14], nodes[2]),
        Direct(region * " - Nuclear-Av", nodes[14], nodes[end]),
        Direct(region * " - Av-Power_sink", nodes[end], nodes[16]),
        Direct(region * " - Av-Heat_sink", nodes[end], nodes[17]),
        Direct(region * " - Power_grid-DACS", nodes[15], nodes[2]),
        Direct(region * " - Power_grid-DACM", nodes[15], nodes[4]),
    ]
    
    # Create the area
    area = Array{Area}([
        Country(
            counter,
            input_regions["Countries"][region]["name"],
            input_regions["Countries"][region]["lon"],
            input_regions["Countries"][region]["lat"],
            nodes[end],
            time_profile(DAC_country_equality(input_DAC, input_regions["Countries"][region]["code"], T), T),
        )
    ])

    return area, nodes, links
end

# function create_region_onshore(region, counter, input, input_storage, products, T)
#     # Creation of a dictionary with entries of 0 for all emission resources
#     𝒫ᵉᵐ₀ = Dict(k => 0.0 for k ∈ products if typeof(k) == ResourceEmit{Float64})

#     # Extraction of products from the array
#     CO2 = products[3]

#     # Declare the data for the investments
#     hours_per_year = 8760

#     inv_storage = InvDataStorage(
#         Capex_rate = FixedProfile(0),
#         Rate_max_inst = time_profile((input_storage[region]["TOTAL_STORE_CAP"]/40)*1e3/hours_per_year, T),
#         Rate_max_add = time_profile((input_storage[region]["TOTAL_STORE_CAP"]/40)*1e3/hours_per_year, T),
#         Rate_min_add = FixedProfile(0),
#         Capex_stor = FixedProfile(0),
#         Stor_max_inst = time_profile((input_storage[region]["TOTAL_STORE_CAP"]*1e3*(duration(T.operational[1])/hours_per_year)), T),
#         Stor_max_add = time_profile((input_storage[region]["TOTAL_STORE_CAP"]*1e3*(duration(T.operational[1])/hours_per_year)), T),
#         Stor_min_add = FixedProfile(0),
#         Inv_mode        = EMI.DiscreteInvestment(),
#         Rate_increment = time_profile((input_storage[region]["TOTAL_STORE_CAP"]/40)*1e3/hours_per_year, T),
#         Stor_increment = time_profile((input_storage[region]["TOTAL_STORE_CAP"]*1e3*(duration(T.operational[1])/hours_per_year)), T),
#         Life_mode = EMI.UnlimitedLife(),
#         Lifetime = FixedProfile(40),
#     )

#     # Declare the different nodes available in the region
#     nodes = Array{EMB.Node}([
#         CO2_storage(string(region) * " - Onshore_storage",
#             FixedProfile(0),
#             FixedProfile(0),     
#             #FixedProfile(input_storage[region]["STORAGE_COST"]),   
#             FixedProfile(10),
#             FixedProfile(0),                     
#             CO2,
#             Dict(CO2 => 1), 
#             Dict(CO2 => 1),
#             [inv_storage],
#             Dict(CO2 => input["CO2_storage"]["CO2_emissions"]["onshore"]),
#             ),
#         ])

#     # Creation of a dictionary with entries of 0 for all resources in the area for the availability node 
#     𝒫₀ = Dict(k => 0 for k ∈ products)
#     append!(nodes, [GeoAvailability(region, 𝒫₀, 𝒫₀)])

#     # Create the links between the individual cells
#     links = [
#         Direct(string(region) * " - Av-Onshore_storage", nodes[end], nodes[1]),
#     ]
    
#     # Create the area
#     area = Array{Area}([
#         Onshore(
#             counter,
#             string(input_storage[region]["OBJECTID"]),
#             input_storage[region]["COUNTRYCODE"],
#             input_storage[region]["LONG"],
#             input_storage[region]["LAT"],
#             nodes[end],
#             nodes[1],
#         )
#     ])

#     return area, nodes, links
# end
function create_region_offshore(region, counter, input, input_storage, products, T)
    # Creation of a dictionary with entries of 0 for all emission resources
    𝒫ᵉᵐ₀ = Dict(k => 0.0 for k ∈ products if typeof(k) == ResourceEmit{Float64})

    # Extraction of products from the array
    CO2 = products[3]

    # Declare the data for the investments
    hours_per_year = 8760 

    inv_storage_off = InvDataStorage(
        Capex_rate = FixedProfile(0),
        Rate_max_inst = time_profile((input_storage[region]["TOTAL_STORE_CAP"]/40)*1e3/hours_per_year, T),
        Rate_max_add = time_profile((input_storage[region]["TOTAL_STORE_CAP"]/40)*1e3/hours_per_year, T),
        Rate_min_add = FixedProfile(0),
        Capex_stor = FixedProfile(0),
        Stor_max_inst = time_profile((input_storage[region]["TOTAL_STORE_CAP"]*1e3), T),
        Stor_max_add = time_profile((input_storage[region]["TOTAL_STORE_CAP"]*1e3), T),
        Stor_min_add = FixedProfile(0),
        Inv_mode        = EMI.DiscreteInvestment(),
        # Rate_increment = time_profile(((1/hours_per_year)*1e3), T), # Capacity assumption of 1 MtCO2/yr/well 
        Rate_increment = time_profile(((input_storage[region]["TOTAL_STORE_CAP"]/40)*1e3/hours_per_year), T),
        Stor_increment = time_profile((input_storage[region]["TOTAL_STORE_CAP"]*1e3), T),
        Life_mode = EMI.UnlimitedLife(),
        Lifetime = FixedProfile(40),
    )

    # Declare the different nodes available in the region
    nodes = Array{EMB.Node}([
        CO2_storage(string(region) * " - Offshore_storage",
            FixedProfile(0),
            FixedProfile(0),     
            time_profile(input_storage[region]["STORAGE_COST"], T),   
            FixedProfile(0),                     
            CO2,
            Dict(CO2 => 1),
            Dict(CO2 => 1),
            [inv_storage_off],
            Dict(CO2 => input["CO2_storage"]["CO2_emissions"]["offshore"]),
        ),
    ])

    # Creation of a dictionary with entries of 0 for all resources in the area for the availability node 
    𝒫₀ = Dict(k => 0 for k ∈ products)
    append!(nodes, [GeoAvailability(region, 𝒫₀, 𝒫₀)])

    # Create the links between the individual cells
    links = [
        Direct(string(region) * " - Av-Offshore_storage",   nodes[end], nodes[1]),
    ]
    
    # Create the area
    area = Array{Area}([
        Offshore(
            counter,
            string(input_storage[region]["OBJECTID"]),
            input_storage[region]["COUNTRYCODE"],
            input_storage[region]["LONG"],
            input_storage[region]["LAT"],
            nodes[end],
            nodes[1],
        )
    ])

    return area, nodes, links
end

function create_region_port(region, counter, input_regions, products, T)
    # Creation of a dictionary with entries of 0 for all emission resources
    𝒫ᵉᵐ₀ = Dict(k => 0.0 for k ∈ products if typeof(k) == ResourceEmit{Float64})

    # Extraction of products from the array
    CO2 = products[3]

    # Declare the different nodes available in the region
    nodes = Array{EMB.Node}([])

    # Creation of a dictionary with entries of 0 for all resources in the area for the availability node 
    𝒫₀ = Dict(k => 0 for k ∈ products)
    append!(nodes, [GeoAvailability(region, 𝒫₀, 𝒫₀)])

    # Create the links between the individual cells
    links = []
    
    # Create the area
    area = Array{Area}([
        Port(
            counter,
            input_regions["Ports"][region]["Name"],
            input_regions["Ports"][region]["Country"],
            input_regions["Ports"][region]["Lon"],
            input_regions["Ports"][region]["Lat"],
            nodes[end],
        )
    ])

    return area, nodes, links
end

function read_data(input, input_trans, input_regions, input_DAC, input_geo, input_nuclear, input_storage)
    @debug "Read case data"

    # Read the used products
    products, map_res = create_resources(input, input_DAC)
    Power, Heat_LT, CO2, NG = products

    # Identify the desired regions in the analysis
    region_countries = collect(keys(input_regions["Countries"]))
    region_port = collect(keys(input_regions["Ports"]))
    # region_onshore_storage = collect([key for (key, value) ∈ input_storage if value["ONSHORE"] == 1])
    region_offshore_storage = collect([key for (key, value) ∈ input_storage if value["ONSHORE"] == 0])

    # Creation of the time structure
    hours_per_year = 8760
    T = TwoLevel(6, 5, SimpleTimes(30, hours_per_year/30))

    # Create the individual areas, nodes, and links and collect them into single arrays
    areas = []
    nodes = []
    links = []
    counter = 1
    for region ∈ region_countries
        a, n, l = create_region_countries(region, counter, input, input_regions, input_DAC, input_geo, input_nuclear, products, T)
        append!(areas, a)
        append!(nodes, n)
        append!(links, l)
        counter += 1
    end
    for region ∈ region_port
        a, n, l = create_region_port(region, counter, input_regions, products, T)
        append!(areas, a)
        append!(nodes, n)
        append!(links, l)
        counter += 1
    end
    # for region ∈ region_onshore_storage
    #     a, n, l = create_region_onshore(region, counter, input, input_storage, products, T)
    #     append!(areas, a)
    #     append!(nodes, n)
    #     append!(links, l)
    #     counter += 1
    # end
    for region ∈ region_offshore_storage
        a, n, l = create_region_offshore(region, counter, input, input_storage, products, T)
        append!(areas, a)
        append!(nodes, n)
        append!(links, l)
        counter += 1
    end
 
    # Create the individual transmission corridors
    areas_names = [areas[k].Name for k ∈ eachindex(areas)]
    transmission = []
    for corr_id ∈ keys(input_trans["corridors"])
        corr = input_trans["corridors"][corr_id]

        from_index = findall(x -> x == corr["from"], areas_names)
        from_area  = try areas[from_index][1] catch; nothing end
        to_index   = findall(x -> x == corr["to"], areas_names)
        to_area    = try areas[to_index][1] catch; nothing end

        if from_area ∈ areas && to_area ∈ areas
            if haskey(corr, "distance")
                dist = corr["distance"]
            else
                r_earth = 6371  #km
                dist    = haversine((from_area.Lon, from_area.Lat), (to_area.Lon, to_area.Lat), r_earth)
            end
         
            # Creating transport corridors
            modes = []
            p = "CO2"
            transport_modes = keys(corr["mode"])
            for mode in transport_modes
                corr_p = input_trans[mode]
        
                multiplier = map_multiplier(corr_p, corr, dist, input_trans, corr["offshore"])
                append!(modes, create_transmission_mode(map_trans_type(corr_p["type"]),
                                                        corr_id,
                                                        corr_p,
                                                        corr,
                                                        map_res[p],
                                                        Power,
                                                        T,
                                                        multiplier,
                                                        )
                )
            end 
            trans = EMG.Transmission(from_area, to_area, modes)
            append!(transmission, [trans])   
        end
    end

    # Reading the emission limits, price for emissions, and CDR target
    CDR_target = time_profile([DAC_removal_Europe(input_DAC, year) for year ∈ strategic_periods(T)], T)
    emission_limits = Dict(CO2 => time_profile(input["CO2_limits"], T))
    emission_costs = Dict(CO2 => time_profile(input["CO2_price"], T))

    CO2_ramp_up_constraint = [9.5, 58.8, 95.5, 242.9, 244.0, 247.2] # MtCO2/yr
    CO2_stor_rate = time_profile(CO2_ramp_up_constraint/8760*1e3,T)

    # Reading the predefined shares for a given DAC technology
    equal_DACM_min = time_profile([0.0, 0.0, 0.0, 0.10, 0.25, 0.33],T)
    equal_DAC_min = time_profile([0.50, 0.50, 0.50, 0.45, 0.375, 0.33],T)

    DACS_maj_DACM_min = time_profile([0.0, 0.0, 0.0, 0.10, 0.20, 0.20],T)
    DACS_maj_DACL_min = time_profile([0.33, 0.33, 0.33, 0.25, 0.20, 0.20],T)
    DACS_maj_DACS_min = time_profile([0.67, 0.67, 0.67, 0.65, 0.60, 0.60],T)

    DACL_maj_DACM_min = time_profile([0.0, 0.0, 0.0, 0.10, 0.20, 0.20],T)
    DACL_maj_DACL_min = time_profile([0.67, 0.67, 0.67, 0.65, 0.60, 0.60],T)
    DACL_maj_DACS_min = time_profile([0.33, 0.33, 0.33, 0.25, 0.20, 0.20],T)
 
    # Creating the modeltype and the global data
    modeltype = DACDeploymentModel(
                                    CDR_target,
                                    emission_limits, 
                                    emission_costs, 
                                    CO2, 
                                    CO2_stor_rate,

                                    equal_DACM_min,
                                    equal_DAC_min,

                                    DACS_maj_DACM_min,
                                    DACS_maj_DACL_min,
                                    DACS_maj_DACS_min,
                                    
                                    DACL_maj_DACM_min,
                                    DACL_maj_DACL_min,
                                    DACL_maj_DACS_min,

                                    input["Discount_rate"]
                                    )           
    # Creating the case data
    case = Dict(
                :areas          => Array{EMG.Area}(areas),
                :transmission   => Array{EMG.Transmission}(transmission),
                :nodes          => Array{EMB.Node}(nodes),
                :links          => Array{EMB.Link}(links),
                :products       => products,
                :T              => T,
                )
    return case, modeltype
end
