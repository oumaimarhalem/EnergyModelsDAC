"""CO2 removal by all DAC technologies for CO2 sequestration in Europe"""
function DAC_removal_Europe(input_DAC::Dict, year)
    n1 = 26.25
    A_sat = input_DAC["capacity_2100"] * input_DAC["share_Europe_2100"]
    A_base = sum(values(input_DAC["installed_capacity_Europe"]))
    A_n1 = input_DAC["storage_target"] * input_DAC["share_Europe_2050"]
    growth_rate =  log((A_base * (A_sat / A_n1 - 1)) / (A_sat - A_base)) / - n1
    
    n2 = 1 + (year.sp - 1) * year.duration
    A_n2 = A_sat / (1 + (exp(-growth_rate * n2) * (A_sat - A_base) / A_base))
    removal = A_n2 * 1e3 

    return removal # ktCO2/yr
end

"""Global DAC-S deployment, for all CO2 uses"""
function DACS_deployment_global(input_DAC::Dict, year)
    n1 = 26.5
    A_sat = input_DAC["capacity_2100"] * input_DAC["share_DAC-S"] 
    A_base = input_DAC["installed_capacity_global"]["DAC-S"]
    A_n1 = input_DAC["removal_target"] * input_DAC["share_DAC-S"] 
    growth_rate =  log((A_base * (A_sat / A_n1 - 1)) / (A_sat - A_base)) / - n1
    
    n2 = 1 + (year.sp - 1) * year.duration
    An_2 = A_sat / (1 + (exp(-growth_rate * n2) * (A_sat - A_base)/ A_base))

    deployment =  An_2 / input_DAC["DAC-S"]["capacity_factor"]

    return deployment # MtCO2/yr
end

"""Global DAC-L deployment, for all CO2 uses"""
function DACL_deployment_global(input_DAC::Dict, year)
    n1 = 26.5
    A_sat = input_DAC["capacity_2100"] * input_DAC["share_DAC-L"] 
    A_base = input_DAC["installed_capacity_global"]["DAC-L"] 
    A_n1 = input_DAC["removal_target"] * input_DAC["share_DAC-L"] 
    growth_rate =  log((A_base * (A_sat / A_n1 - 1)) / (A_sat - A_base)) / - n1
    
    n2 = 1 + (year.sp - 1) * year.duration
    An_2 = A_sat / (1 + (exp(-growth_rate * n2) * (A_sat - A_base)/ A_base))

    deployment =  An_2 / input_DAC["DAC-L"]["capacity_factor"]

    return deployment # MtCO2/yr
end

"""Global DAC-M deployment, for all CO2 uses"""
function DACM_deployment_global(input_DAC::Dict, year)
    n1 = 16.5
    A_sat = input_DAC["capacity_2100"] * input_DAC["share_DAC-M"] 
    A_base = input_DAC["installed_capacity_global"]["DAC-M"]
    A_n1 = input_DAC["removal_target"] * input_DAC["share_DAC-M"] 
    growth_rate =  log((A_base * (A_sat / A_n1 - 1)) / (A_sat - A_base)) / - n1

    n2 = (1 + ((year.sp-2) - 1) * year.duration)
    An_2 = A_sat / (1 + (exp(-growth_rate * n2) * (A_sat - A_base)/ A_base))
    deployment = An_2 / input_DAC["DAC-M"]["capacity_factor"]

    if (year.sp < 3)
        final_deployment = 1e-5
    else
        final_deployment = deployment
    end
    
    return final_deployment # MtCO2/yr
end

""" Country-based CO2 removal targets by all DAC technologies for CO2 sequestration """
function DAC_country_responsibility(input_DAC::Dict, region::String, T)
    ## Country-level CDR targets: Cumulative emissions per person-year (Fyson et al. 2020; Pozo et al. 2020)
    hist_data_beginning = 1990
    hist_data_end = 2021
    years_hist = (hist_data_end-hist_data_beginning) + 1
    hist_years = collect(hist_data_beginning:hist_data_end)

    country_codes = ["SVN", "ESP", "GBR", "LUX", "HUN", "CHE", "DEU", "SWE", "FRA", "POL", "FIN", "ITA", "HRV",
                    "AUT", "NOR", "LTU", "PRT", "LVA", "NLD", "BEL", "IRL", "ROU", "BGR", "CZE", "SVK", "DNK", 
                        "EST", "GRC", "BIH", "SRB", "MKD"]
    country_names = Dict{String, String}()
    country_names = Dict("SVN" => "Slovenia", "ESP" => "Spain", "GBR" => "United Kingdom of Great Britain and Northern Ireland", "LUX" => "Luxembourg", "HUN" => "Hungary", "CHE" => "Switzerland", "DEU" => "Germany", "SWE" => "Sweden",
                        "FRA" => "France", "POL" => "Poland", "FIN" => "Finland", "ITA" => "Italy", "HRV" => "Croatia", "AUT" => "Austria", "NOR" => "Norway", "LTU" => "Lithuania", 
                        "PRT" => "Portugal", "LVA" => "Latvia", "NLD" => "Netherlands (Kingdom of the)", "BEL" => "Belgium", "BELLUX" => "Belgium-Luxembourg", "IRL" => "Ireland", "ROU" => "Romania", "BGR" => "Bulgaria", "CZE" => "Czechia",
                            "SVK" => "Slovakia", "DNK" => "Denmark", "EST" => "Estonia", "GRC" => "Greece", "BIH" => "Bosnia and Herzegovina", "SRB" => "Serbia", "SRBMT" => "Serbia and Montenegro", "MKD" => "North Macedonia")
                          
    # Historical emissions data (cumulative total CO2-eq emissions)
    primap_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/Guetschow_et_al_2024-PRIMAP-hist_v2.5.1_final_27-Feb-2024.csv") |> DataFrame
    scen = "HISTCR"
    gas = "KYOTOGHG (AR6GWP100)"
    cat = "M.0.EL"

    hist_emis_data = select(filter(row -> row.scenario == scen &&
                                row.area in country_codes &&
                                row.entity == gas &&
                                row.category == cat, 
                                primap_data), 
                                :area, names(primap_data)[end-years_hist:end-1])
            
    fao_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/Emissions_Totals_E_Europe.csv") |> DataFrame
    item = "LULUCF"
    element = "Emissions (CO2eq) (AR5)"
    source = "FAO TIER 1"

    hist_land_emis_data = select(filter(row -> row.Item == item &&
                                    row.Element == element &&
                                    row.Source == source &&
                                    row.Area in values(country_names),
                                    fao_data), 
                                    :Area, [col for col in names(fao_data) if in(col, ["Y$year" for year in hist_years])])
    hist_land_emis_data[hist_land_emis_data.Area .== "Belgium", 2:11] = hist_land_emis_data[hist_land_emis_data.Area .== "Belgium-Luxembourg", 2:11]    
    hist_land_emis_data[hist_land_emis_data.Area .== "Serbia", 2:17] = hist_land_emis_data[hist_land_emis_data.Area .== "Serbia and Montenegro", 2:17]
    filter!(row -> row.Area != "Belgium-Luxembourg" && row.Area != "Serbia and Montenegro", hist_land_emis_data)                                   
    delete!(country_names, "SRBMT")
    delete!(country_names, "BELLUX")

    hist_emis_data = coalesce.(hist_emis_data,0)   
    hist_land_emis_data = coalesce.(hist_land_emis_data,0)                                  

    hist_emis = Dict{String, Real}()
    hist_emis = Dict(code => ((sum(eachcol(hist_emis_data[hist_emis_data.area .== code, 2:end])) .+ 
                                sum(eachcol(hist_land_emis_data[hist_land_emis_data.Area .== name, 2:end]))))[1]* 1e-3 for (code, name) in country_names)

    # Historical population data (cumulative person-years)
    hist_pop_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/WB_population.csv") |> DataFrame
    hist_pop_data = coalesce.(hist_pop_data,0)   

    hist_pop = Dict{String, Real}()
    hist_pop = Dict(code => (sum(eachcol(hist_pop_data[hist_pop_data.Country_Code .== code, 5:end])))[1] for (code,name) in country_names)

    # Excess emissions per country
    excess_emis =  Dict{String, Real}()
    for code in keys(country_names)
    excess_emis[code] = hist_emis[code] - (sum(values(hist_emis))/(sum(values(hist_pop)))) * hist_pop[code]
    end

    # Annual share of cumulative CDR
    share_CDR = Dict{String, Array{Real, 1}}()
    total_excess_emis = sum(values([excess_emis[code] for (code,name) in country_names if excess_emis[code]>0]))
    for code in keys(country_names)
        if excess_emis[code]>0
            share_CDR[code] = [(DAC_removal_Europe(input_DAC, year) * (excess_emis[code]/total_excess_emis)) for year in strategic_periods(T)] 
        else
            share_CDR[code] = zeros(T.len)
        end
    end

    return share_CDR[region]
end 

function DAC_country_ability(input_DAC::Dict, region::String, T)
    ## Country-level CDR targets: Ability to pay (Fyson et al. 2020; Pozo et al. 2020)
    # Current and projected population data
    pop_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/UN_world_pop.csv") |> DataFrame

    country_names = Dict{String, String}()
    country_names = Dict("SVN" => "Slovenia", "ESP" => "Spain", "GBR" => "United Kingdom", "LUX" => "Luxembourg", "HUN" => "Hungary", "CHE" => "Switzerland", "DEU" => "Germany", "SWE" => "Sweden",
                        "FRA" => "France", "POL" => "Poland", "FIN" => "Finland", "ITA" => "Italy", "HRV" => "Croatia", "AUT" => "Austria", "NOR" => "Norway", "LTU" => "Lithuania", 
                        "PRT" => "Portugal", "LVA" => "Latvia", "NLD" => "Netherlands", "BEL" => "Belgium", "IRL" => "Ireland", "ROU" => "Romania", "BGR" => "Bulgaria", "CZE" => "Czechia",
                            "SVK" => "Slovakia", "DNK" => "Denmark", "EST" => "Estonia", "GRC" => "Greece", "BIH" => "Bosnia and Herzegovina", "SRB" => "Serbia", "MKD" => "North Macedonia")

    pop_per_sp = Dict{String, Array{Real, 1}}()
    for (code, name) in country_names
        pop_per_sp[code] = [pop_data[(pop_data.Location .== name) .& (pop_data.Time .== year), :TPopulation1Jan][1] for year in 2025:5:2050]
    end

    # Current and projected GDP data
    GDP_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/WB_GDP.csv") |> DataFrame
    GDP_data = GDP_data[1:31, :]

    GDP_per_sp = Dict{String, Array{Real, 1}}()
    for code in keys(country_names)
        GDP_per_sp[code] = [GDP_data[GDP_data.Country_Code .== code, :GDP_2022][1] *
                            (1 + (year < 2040 && code in ["BIH", "SRB", "MKD", "BGR"] ? 
                                  (year < 2040 ? 0.040 : 0.019) : 
                                  (year < 2040 ? 0.014 : 0.009)))^(year - 2022)
                            for year in 2025:5:2050]
    end

    total_GDP_per_sp = zeros(6)
    for series in values(GDP_per_sp)
        for (i, gdp) in enumerate(series)
            total_GDP_per_sp[i] += gdp
        end
    end

    # Select countries with above-average GDP/cap
    GDP_cap_per_sp = Dict{String, Array{Real, 1}}()
    for code in keys(country_names)
        GDP_cap_per_sp[code] = zeros(6)
        for year in strategic_periods(T)
            GDP_cap_per_sp[code][year.sp] = GDP_per_sp[code][year.sp] / (pop_per_sp[code][year.sp]*1e3)
        end
    end

    mean_GDP_cap = zeros(6)
    for year in strategic_periods(T)
        total_GDP_cap = 0.0
        total_population = 0.0
        for code in keys(country_names)
            total_GDP_cap += GDP_per_sp[code][year.sp]
            total_population += pop_per_sp[code][year.sp]
        end
        mean_GDP_cap[year.sp] = total_GDP_cap / (total_population * 1e3)
    end
   
    # Annual share of cumulative CDR
    share_CDR = Dict{String, Array{Real, 1}}()
    for code in keys(country_names)
        share_CDR[code] = zeros(T.len)
        for year in strategic_periods(T)
            if GDP_cap_per_sp[code][year.sp] >= mean_GDP_cap[year.sp]
                share_CDR[code][year.sp] = (DAC_removal_Europe(input_DAC, year) * (GDP_per_sp[code][year.sp]/total_GDP_per_sp[year.sp]))
            else
                share_CDR[code][year.sp] = 0.0
            end
         end
    end

    return share_CDR[region]
end

function DAC_country_equality(input_DAC::Dict, region::String, T)
    ## Country-level CDR targets: Equal per capita (Pozo et al. 2020)
    pop_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/UN_world_pop.csv") |> DataFrame

    country_names = Dict{String, String}()
    country_names = Dict("SVN" => "Slovenia", "ESP" => "Spain", "GBR" => "United Kingdom", "LUX" => "Luxembourg", "HUN" => "Hungary", "CHE" => "Switzerland", "DEU" => "Germany", "SWE" => "Sweden",
                        "FRA" => "France", "POL" => "Poland", "FIN" => "Finland", "ITA" => "Italy", "HRV" => "Croatia", "AUT" => "Austria", "NOR" => "Norway", "LTU" => "Lithuania", 
                        "PRT" => "Portugal", "LVA" => "Latvia", "NLD" => "Netherlands", "BEL" => "Belgium", "IRL" => "Ireland", "ROU" => "Romania", "BGR" => "Bulgaria", "CZE" => "Czechia",
                            "SVK" => "Slovakia", "DNK" => "Denmark", "EST" => "Estonia", "GRC" => "Greece", "BIH" => "Bosnia and Herzegovina", "SRB" => "Serbia", "MKD" => "North Macedonia")

    pop_per_sp = Dict{String, Array{Real, 1}}()
    for (code, name) in country_names
        pop_per_sp[code] = [pop_data[(pop_data.Location .== name) .& (pop_data.Time .== year), :TPopulation1Jan][1] for year in 2025:5:2050]
    end

    total_pop_per_sp = zeros(6)
    for series in values(pop_per_sp)
        for (i, pop) in enumerate(series)
            total_pop_per_sp[i] += pop
        end
    end

    share_CDR = Dict{String, Array{Real, 1}}()
    for code in keys(country_names)
        share_CDR[code] = [(DAC_removal_Europe(input_DAC, year) * (pop_per_sp[code][year.sp]./total_pop_per_sp[year.sp])) for year in strategic_periods(T)] 
    end

    return share_CDR[region]
end 

function EU_pop_share(year) # 2050 or 2100
    pop_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/UN_world_pop.csv") |> DataFrame

    world_pop_2050 = pop_data[(pop_data.Location .== "World") .& (pop_data.Time .== 2050), :TPopulation1Jan][1]
    world_pop_2100 = pop_data[(pop_data.Location .== "World") .& (pop_data.Time .== 2100), :TPopulation1Jan][1]

    country_names = Dict("SVN" => "Slovenia", "ESP" => "Spain", "GBR" => "United Kingdom", "LUX" => "Luxembourg", "HUN" => "Hungary", "CHE" => "Switzerland", "DEU" => "Germany", "SWE" => "Sweden",
                        "FRA" => "France", "POL" => "Poland", "FIN" => "Finland", "ITA" => "Italy", "HRV" => "Croatia", "AUT" => "Austria", "NOR" => "Norway", "LTU" => "Lithuania", 
                        "PRT" => "Portugal", "LVA" => "Latvia", "NLD" => "Netherlands", "BEL" => "Belgium", "IRL" => "Ireland", "ROU" => "Romania", "BGR" => "Bulgaria", "CZE" => "Czechia",
                            "SVK" => "Slovakia", "DNK" => "Denmark", "EST" => "Estonia", "GRC" => "Greece", "BIH" => "Bosnia and Herzegovina", "SRB" => "Serbia", "MKD" => "North Macedonia")

    EU_pop_2050 = 0.0
    for country in values(country_names)
        EU_pop_2050 += pop_data[(pop_data.Location .== country) .& (pop_data.Time .== 2050), :TPopulation1Jan][1]
    end
    EU_pop_2100 = 0.0
    for country in values(country_names)
        EU_pop_2100 += pop_data[(pop_data.Location .== country) .& (pop_data.Time .== 2100), :TPopulation1Jan][1]
    end

    if year == 2050
        EU_pop_share = (EU_pop_2050/world_pop_2050)
    elseif year == 2100
        EU_pop_share = (EU_pop_2100/world_pop_2100)
    end

    return EU_pop_share
end