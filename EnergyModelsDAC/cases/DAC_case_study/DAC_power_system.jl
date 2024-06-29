""" Computing the daily-averaged grid power prices for all strategic periods for a given country """
function power_prices_daily(country::String)
    power_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/power_system.csv") |> DataFrame
    period_mapping = Dict(
        "2025-2030" => 1,
        "2030-2035" => 2,
        "2035-2040" => 3,
        "2040-2045" => 4,
        "2045-2050" => 5,
        "2050-2055" => 6)
    transform!(power_data, :Period => ByRow(period -> period_mapping[period]) => :SP)

    group = power_data[power_data.Country .== country, :]
  
    price_array = zeros(6, 30)
  
    for period in unique(group[:, :SP])
        period_data = group[group.SP .== period, :]
        for day in 1:30
            day_data = period_data[(day - 1) * 24 .< period_data.Hour .<= day * 24, :]
            avg_price = mean(day_data.Price_EURperMWh)
            price_array[period, day] = avg_price
        end
    end

    return price_array
end

""" Computing the daily-averaged grid power carbon intensities for all strategic periods for a given country """
function power_emissions_daily(country::String)
    power_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/power_system.csv") |> DataFrame
    period_mapping = Dict(
        "2025-2030" => 1,
        "2030-2035" => 2,
        "2035-2040" => 3,
        "2040-2045" => 4,
        "2045-2050" => 5,
        "2050-2055" => 6)
    transform!(power_data, :Period => ByRow(period -> period_mapping[period]) => :SP)

    group = power_data[power_data.Country .== country, :]
  
    emissions_array = zeros(6, 30)
  
    for period in unique(group[:, :SP])
        period_data = group[group.SP .== period, :]
        for day in 1:30
            day_data = period_data[(day - 1) * 24 .< period_data.Hour .<= day * 24, :]
            avg_emissions = mean(day_data.AvgCO2_kgCO2perMWh)
            emissions_array[period, day] = avg_emissions
        end
    end

    return emissions_array
end

""" Computing the hourly power prices for all strategic periods for a given country """
function power_prices_hourly(country::String)
    power_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/power_system.csv") |> DataFrame
    period_mapping = Dict(
        "2025-2030" => 1,
        "2030-2035" => 2,
        "2035-2040" => 3,
        "2040-2045" => 4,
        "2045-2050" => 5,
        "2050-2055" => 6)
    transform!(power_data, :Period => ByRow(period -> period_mapping[period]) => :SP)

    group = power_data[power_data.Country .== country, :]
  
    price_array = zeros(6, 720)
  
    for i in eachrow(group[:, :Hour])
        for j in unique(group[:, :SP])
            group_period = group[group.SP .== j, :]
            price_array[j, i] = group_period[group_period.Hour .== i, :Price_EURperMWh]
        end
    end

    return price_array
end 

""" Computing the hourly grid power carbon intensities for all strategic periods for a given country """
function power_emissions_hourly(country::String)
    power_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/power_system.csv") |> DataFrame
    period_mapping = Dict(
        "2025-2030" => 1,
        "2030-2035" => 2,
        "2035-2040" => 3,
        "2040-2045" => 4,
        "2045-2050" => 5,
        "2050-2055" => 6)
    transform!(power_data, :Period => ByRow(period -> period_mapping[period]) => :SP)

    group = power_data[power_data.Country .== country, :]
  
    emissions_array = zeros(6, 720)
  
    for i in eachrow(group[:, :Hour])
        for j in unique(group[:, :SP])
            group_period = group[group.SP .== j, :]
            emissions_array[j, i] = group_period[group_period.Hour .== i, :AvgCO2_kgCO2perMWh]
        end
    end

    return emissions_array
end 

function natural_gas_price(input::Dict, region, year)
    price_2022 = input["NG"]["price"][region]

    n = 1 + (year.sp - 1) * year.duration
    NG_price = price_2022 * ((1 + input["NG"]["growth_rate"])^n)

    return NG_price
end

function power_prices_countries(year, input_regions)
    price_array = Dict(country => 0.0 for country in keys(input_regions["Countries"]))
    period_mapping = Dict(
        2025 => 1,
        2030 => 2,
        2035 => 3,
        2040 => 4,
        2045 => 5,
        2050 => 6)

    for country in keys(input_regions["Countries"])
        power_prices = power_prices_daily(country)
        price_array[country] = mean(power_prices[period_mapping[year],1:28]) # without peak days
    end
   
    return price_array
end

function power_emissions_countries(year, input_regions)
    price_array = Dict(country => 0.0 for country in keys(input_regions["Countries"]))
    period_mapping = Dict(
        2025 => 1,
        2030 => 2,
        2035 => 3,
        2040 => 4,
        2045 => 5,
        2050 => 6)

    for country in keys(input_regions["Countries"])
        power_emissions = power_emissions_daily(country)
        price_array[country] = mean(power_emissions[period_mapping[year],1:28]) # without peak days
    end
   
    return price_array
end

