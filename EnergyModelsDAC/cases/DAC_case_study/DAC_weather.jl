""" Computing the daily-averaged air temperature for all strategic periods for a given country """
function peak_temp_days()
    air_data =  CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/T2M_NUTS0_Europe_popweight_rcp45_hourly_2001-2050.csv") |> DataFrame
    sp_mapping = Dict(
      2025 => 1,
      2030 => 2,
      2035 => 3,
      2040 => 4,
      2045 => 5,
      2050 => 6)
    model_data = filter(row -> row.year in keys(sp_mapping), air_data)
    transform!(model_data, :year => ByRow(period -> sp_mapping[period]) => :SP)
  
    temp_array = zeros(6,365)
    for period in unique(model_data[:, :SP])
      period_data = model_data[model_data.SP .== period, :]
      for day in 1:365
          day_data = period_data[((day - 1) * 24 .< (1:size(period_data, 1))) .& ((1:size(period_data, 1)) .<= day * 24), :]
          temp_data = select(day_data, Not(:year, :month, :day, :hour, :SP))
          avg_temp = mean(mean(eachcol(temp_data)))
          temp_array[period, day] = avg_temp
      end
    end
  
    peak_days = mapslices(x -> begin
                              idx_max = argmax(x)
                              val_max = x[idx_max]
                              x[idx_max] = -Inf
                              idx_second_max = argmax(x)
                              val_second_max = x[idx_second_max]
                              (idx_max, idx_second_max)
                          end, temp_array, dims=2)
  
    return peak_days
end 

function air_temp(country::String)
    air_data =  CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/T2M_NUTS0_Europe_popweight_rcp45_hourly_2001-2050.csv") |> DataFrame
    sp_mapping = Dict(
        2025 => 1,
        2030 => 2,
        2035 => 3,
        2040 => 4,
        2045 => 5,
        2050 => 6)
    month_mapping = Dict(
        "winter" => 1,
        "spring" => 5,
        "summer" => 8, 
        "fall" => 11) 

    country_data = select(filter(row -> row.year in keys(sp_mapping) && 
                                        row.month in values(month_mapping) && 
                                        row.day in 20:26, 
                                        air_data), 
                                        [:year, :month, :day, Symbol(country)])
    transform!(country_data, :year => ByRow(period -> sp_mapping[period]) => :SP)

    temp_array = zeros(6, 30)

    for period in unique(country_data[:, :SP])
        period_data = country_data[country_data.SP .== period, :]
        for day in 1:28
            day_data = period_data[((day - 1) * 24 .< (1:size(period_data, 1))) .& ((1:size(period_data, 1)) .<= day * 24), :]
            avg_temp = mean(day_data[:, Symbol(country)])
            temp_array[period, day] = avg_temp
        end
    end
    
    peak_days = peak_temp_days()
    country_temp = select(filter(row -> row.year in keys(sp_mapping),
                                        air_data), 
                                        [:year, :month, :day, Symbol(country)])
    transform!(country_temp, :year => ByRow(period -> sp_mapping[period]) => :SP)    
    
    for period in unique(country_temp[:, :SP])
        period_data = country_temp[country_temp.SP .== period, :]
        (day_1, day_2) = peak_days[period]

        day_1_data = period_data[((day_1 - 1) * 24 .< (1:size(period_data, 1))) .& ((1:size(period_data, 1)) .<= day_1 * 24), :]
        day_2_data = period_data[((day_2 - 1) * 24 .< (1:size(period_data, 1))) .& ((1:size(period_data, 1)) .<= day_2 * 24), :]
        avg_temp_peak_1 = mean(day_1_data[:, Symbol(country)])
        avg_temp_peak_2 = mean(day_2_data[:, Symbol(country)])
        temp_array[period, 29] =  avg_temp_peak_1
        temp_array[period, 30] =  avg_temp_peak_2
    end 

    return temp_array
end

function cop_hp(T1, T2)
    Lorentz_efficiency = 0.5
    T_inlet = T1 + 273 # K
    T_outlet = T2 + 273 # K

    COP_HP = (T_outlet / (T_outlet - T_inlet)) * 1.07 * Lorentz_efficiency

    return COP_HP
end

function avg_cop(year)
    cop_array = Dict(country => 0.0 for country in keys(input_regions["Countries"]))
    period_mapping = Dict(
        2025 => 1,
        2030 => 2,
        2035 => 3,
        2040 => 4,
        2045 => 5,
        2050 => 6)

    for country in keys(input_regions["Countries"])
        air_temps = air_temp(country)
        cop_array[country] = cop_hp(mean(air_temps[period_mapping[year],1:28]), 100) # without peak days
    end

    return cop_array
end

""" Computing the daily-averaged solar irradiance for all strategic periods for a given country """

function peak_solar_days()
    solar_data =  CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/GLO_NUTS0_Europe_popweight_rcp45_hourly_2001-2050.csv") |> DataFrame
    sp_mapping = Dict(
      2025 => 1,
      2030 => 2,
      2035 => 3,
      2040 => 4,
      2045 => 5,
      2050 => 6)
    model_data = filter(row -> row.year in keys(sp_mapping), solar_data)
    transform!(model_data, :year => ByRow(period -> sp_mapping[period]) => :SP)
  
    solar_array = zeros(6,365)
    for period in unique(model_data[:, :SP])
      period_data = model_data[model_data.SP .== period, :]
      for day in 1:365
          day_data = period_data[((day - 1) * 24 .< (1:size(period_data, 1))) .& ((1:size(period_data, 1)) .<= day * 24), :]
          solar_data = select(day_data, Not(:year, :month, :day, :hour, :SP))
          avg_solar = mean(mean(eachcol(solar_data)))
          solar_array[period, day] = avg_solar
      end
    end
  
    peak_days = mapslices(x -> begin
                                idx_min = argmin(x)
                                val_min = x[idx_min]
                                x[idx_min] = Inf
                                idx_second_min = argmin(x)
                                val_second_min = x[idx_second_min]
                                (idx_min, idx_second_min)
                            end, solar_array, dims=2)

    return peak_days
end 

function solar_irradiance(country::String)
    solar_data =  CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/GLO_NUTS0_Europe_popweight_rcp45_hourly_2001-2050.csv") |> DataFrame
    sp_mapping = Dict(
        2025 => 1,
        2030 => 2,
        2035 => 3,
        2040 => 4,
        2045 => 5,
        2050 => 6)
    month_mapping = Dict(
        "winter" => 1,
        "spring" => 5,
        "summer" => 8, 
        "fall" => 11) 

    country_data = select(filter(row -> row.year in keys(sp_mapping) && 
                                        row.month in values(month_mapping) && 
                                        row.day in 20:26, 
                                        solar_data), 
                                        [:year, :month, :day, Symbol(country)])
    transform!(country_data, :year => ByRow(period -> sp_mapping[period]) => :SP)

    solar_array = zeros(6, 30)

    for period in unique(country_data[:, :SP])
        period_data = country_data[country_data.SP .== period, :]
        for day in 1:28
            day_data = period_data[((day - 1) * 24 .< (1:size(period_data, 1))) .& ((1:size(period_data, 1)) .<= day * 24), :]
            avg_solar = mean(day_data[:, Symbol(country)])
            solar_array[period, day] = avg_solar
        end
    end
    
    peak_days = peak_solar_days()
    country_solar = select(filter(row -> row.year in keys(sp_mapping),
                                        solar_data), 
                                        [:year, :month, :day, Symbol(country)])
    transform!(country_solar, :year => ByRow(period -> sp_mapping[period]) => :SP)    
    
    for period in unique(country_solar[:, :SP])
        period_data = country_solar[country_solar.SP .== period, :]
        (day_1, day_2) = peak_days[period]

        day_1_data = period_data[((day_1 - 1) * 24 .< (1:size(period_data, 1))) .& ((1:size(period_data, 1)) .<= day_1 * 24), :]
        day_2_data = period_data[((day_2 - 1) * 24 .< (1:size(period_data, 1))) .& ((1:size(period_data, 1)) .<= day_2 * 24), :]
        avg_solar_peak_1 = mean(day_1_data[:, Symbol(country)])
        avg_solar_peak_2 = mean(day_2_data[:, Symbol(country)])
        solar_array[period, 29] =  avg_solar_peak_1
        solar_array[period, 30] =  avg_solar_peak_2
    end 

    return solar_array
end