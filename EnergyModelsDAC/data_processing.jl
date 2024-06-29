using YAML
using DataFrames
using CSV
using Statistics
using DelaunayTriangulation

""" Data processing """
## CO2 storage reservoirs
storage_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/Hydrocarbon_Storage_Units.csv") |> DataFrame
storage_dict = Dict{Any, Dict{String, Any}}()
for site ∈ unique(storage_data.OBJECTID)
    site_dict = Dict{String, Any}(string(parameter) => storage_data[storage_data.OBJECTID .== site, parameter][1] for parameter ∈ propertynames(storage_data))
        storage_dict[site] = site_dict
end
# YAML.write_file("./EnergyModelsDAC/cases/DAC_case_study/input_storage.yml", storage_dict)

## Geothermal power plants
geo_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/Geothermal_Power_Plants.csv") |> DataFrame
geo_dict = Dict{Int, Dict{String, Any}}()
country_code_map = Dict("Iceland" => "IS", "Italy" => "IT", "Romania" => "RO", "Hungary" => "HU", "Portugal" => "PT", "Austria" => "AT", "Germany" => "DE", "France" => "FR")

for plant in unique(geo_data.id_powerplant)
    plant_dict = Dict{String, Any}()
    country_name = geo_data[geo_data.id_powerplant .== plant, :name_country][1]

    if haskey(country_code_map, country_name)
        plant_dict["country_code"] = country_code_map[country_name]
    end

    for parameter in propertynames(geo_data)
        plant_dict[string(parameter)] = geo_data[geo_data.id_powerplant .== plant, parameter][1]
    end

    geo_dict[plant] = plant_dict
end
YAML.write_file("./EnergyModelsDAC/cases/DAC_case_study/input_geo.yml", geo_dict)

## Nuclear power plants
inst_power_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/Generation_installed_capacity.csv") |> DataFrame
inst_power_data = filter(row -> !(row.Period in ["2055-2060", "2020-2025"] || 
                                  row.Node in ["Hornsea", "SorligeNordsjoII", "FirthofForth", "NO5", "DoggerBank", "OuterDowsing", 
                                  "MorayFirth", "HelgolanderBucht", "Norfolk", "NO4", "UtsiraNord", "SorligeNordsjoI", "HollandseeKust", 
                                  "Nordsoen", "NO2", "NO3", "Borssele", "EastAnglia"]) &&
                                  row.GeneratorType == "Nuclear", 
                                  inst_power_data)

country_names = Dict("SVN" => "Slovenia", "ESP" => "Spain", "GBR" => "GreatBrit.", "LUX" => "Luxemb.", "HUN" => "Hungary", "CHE" => "Switzerland", "DEU" => "Germany", "SWE" => "Sweden",
"FRA" => "France", "POL" => "Poland", "FIN" => "Finland", "ITA" => "Italy", "HRV" => "Croatia", "AUT" => "Austria", "NOR" => "NO1", "LTU" => "Lithuania", 
"PRT" => "Portugal", "LVA" => "Latvia", "NLD" => "Netherlands", "BEL" => "Belgium", "IRL" => "Ireland", "ROU" => "Romania", "BGR" => "Bulgaria", "CZE" => "CzechR",
    "SVK" => "Slovakia", "DNK" => "Denmark", "EST" => "Estonia", "GRC" => "Greece", "BIH" => "BosniaH", "SRB" => "Serbia", "MKD" => "Macedonia")

function get_key(dict, value)
    return [k for (k, v) in dict if v == value][1]
end
  
inst_power_data.Node .= map(node -> get_key(country_names, node), inst_power_data.Node)

nucl_dict = Dict{String, Array{Real, 1}}()
for country in keys(country_names)
  nucl_dict[country] = zeros(6)
  if country in unique(inst_power_data.Node)
    for (i, sp) in enumerate(unique(inst_power_data.Period))
      nucl_dict[country][i] = inst_power_data[(inst_power_data.Period .== sp) .& (inst_power_data.Node .== country), :genInstalledCap_MW][1]/1e3 # GWel
    end
  end
end

YAML.write_file("./EnergyModelsDAC/cases/DAC_case_study/input_nuclear.yml", nucl_dict)

## Ports
port_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/location_ports.csv") |> DataFrame
select!(port_data, Not(:Country))

port_dict = Dict{String, Dict{String, Any}}()
for port ∈ unique(port_data.Name)
  location_dict = Dict{String, Any}()
  for parameter ∈ propertynames(port_data)
      location_dict[string(parameter)] = port_data[port_data.Name .== port, parameter][1]
  end
  port_dict[port] = location_dict
end

YAML.write_file("./EnergyModelsDAC/cases/DAC_case_study/input_ports.yml", port_dict)

## Shore-to-shore shipping distances
ship_data =  CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/distances_ship_transport.csv") |> DataFrame
cost_data = YAML.load_file("./EnergyModelsDAC\\cases\\DAC_case_study\\data\\CO2_transmission_costs.yml")

ship_dict = Dict{String, Dict{String, Any}}()
for from_port in ship_data.Column1
    for to_port in propertynames(ship_data)[2:end]
        distance_value = round(ship_data[ship_data.Column1 .== from_port, to_port][1] * 1.852, digits=2)
        if (!ismissing(distance_value) && !iszero(distance_value))
            location_dict = Dict{String, Any}()
            location_dict["from"] = string(from_port)
            location_dict["to"] = string(to_port)
            location_dict["distance"] = distance_value
            location_dict["offshore"] = true
            location_dict["direction"] = 2
            location_dict["mode"] = Dict{String, Any}()  
            location_dict["mode"]["CO2_ship_onshore"] = Dict{String, Any}()
            location_dict["mode"]["CO2_ship_onshore"]["cost_1_MtCO2"] = cost_data[string(from_port, "-", to_port)]["costs"]["ship"][1]["cost"]
            location_dict["mode"]["CO2_ship_onshore"]["cost_5_MtCO2"] = cost_data[string(from_port, "-", to_port)]["costs"]["ship"][2]["cost"]
            location_dict["mode"]["CO2_ship_onshore"]["cost_10_MtCO2"] = cost_data[string(from_port, "-", to_port)]["costs"]["ship"][3]["cost"]
            location_dict["mode"]["CO2_ship_onshore"]["cost_20_MtCO2"] = cost_data[string(from_port, "-", to_port)]["costs"]["ship"][4]["cost"]
            ship_dict[string(from_port, "-", to_port)] = location_dict
        end
    end
end

YAML.write_file("./EnergyModelsDAC/cases/DAC_case_study/input_costs.yml", ship_dict)

## Creating dict for transport model: shore-to-shore shipping corridors
ship_dict = Dict{String, Dict{String, Any}}()
for from_port ∈ ship_data.Column1
  for to_port ∈ propertynames(ship_data)[2:end]
  distance_value = round(ship_data[ship_data.Column1 .== from_port, to_port][1] * 1.852, digits=3)
    if (!ismissing(distance_value) && !iszero(distance_value))
      location_dict = Dict{String, Any}()
      location_dict["distance"] = distance_value
      location_dict["offshore"] = true
      to_area = string(to_port)
      for Name in port_data.Name
        if from_port == Name
          location_dict["x_from"] = port_data[port_data.Name .== from_port, :Lon][1]
          location_dict["y_from"] = port_data[port_data.Name .== from_port, :Lat][1]
        end
      end
      for Name in port_data.Name
        if to_area == Name
          location_dict["x_to"] = port_data[port_data.Name .== to_area, :Lon][1]
          location_dict["y_to"] = port_data[port_data.Name .== to_area, :Lat][1]
        end
        ship_dict[string(from_port, "-", to_port)] = location_dict
      end
  end
end 
end 

## Routes between ports and offshore storage areas
route_data =  CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/offshore_connections.csv") |> DataFrame
port_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/location_ports.csv") |> DataFrame
cost_data = YAML.load_file("./EnergyModelsDAC\\cases\\DAC_case_study\\data\\CO2_transmission_costs.yml")

route_dict = Dict{String, Dict{String, Any}}()
for to_area in route_data.to_area
  location_dict = Dict{String, Any}()
  location_dict["offshore"] = true
  location_dict["mode"] = "CO2_pipeline_offshore"
  location_dict["to"] = string(to_area)
  lon_port = route_data[route_data.to_area .== to_area, :x_port][1]
  port_name = port_data[port_data.Lon .== lon_port, :Name][1]
  location_dict["from"] = string(port_name)
  location_dict["mode"] = Dict{String, Any}()  
  location_dict["mode"]["CO2_ship_offshore"] = Dict{String, Any}()
  location_dict["mode"]["CO2_ship_offshore"]["cost_1_MtCO2"] = cost_data[string(port_name, "-", string(to_area))]["costs"]["ship"][1]["cost"]
  location_dict["mode"]["CO2_ship_offshore"]["cost_5_MtCO2"] = cost_data[string(port_name, "-", string(to_area))]["costs"]["ship"][2]["cost"]
  location_dict["mode"]["CO2_ship_offshore"]["cost_10_MtCO2"] = cost_data[string(port_name, "-", string(to_area))]["costs"]["ship"][3]["cost"]
  location_dict["mode"]["CO2_ship_offshore"]["cost_20_MtCO2"] = cost_data[string(port_name, "-", string(to_area))]["costs"]["ship"][4]["cost"]
  location_dict["mode"]["CO2_pipeline_offshore"] = Dict{String, Any}()
  location_dict["mode"]["CO2_pipeline_offshore"]["cost_1_MtCO2"] = cost_data[string(port_name, "-", string(to_area))]["costs"]["offshore-pipeline"][1]["cost"]
  location_dict["mode"]["CO2_pipeline_offshore"]["cost_5_MtCO2"] = cost_data[string(port_name, "-", string(to_area))]["costs"]["offshore-pipeline"][2]["cost"]
  location_dict["mode"]["CO2_pipeline_offshore"]["cost_10_MtCO2"] = cost_data[string(port_name, "-", string(to_area))]["costs"]["offshore-pipeline"][3]["cost"]
  location_dict["mode"]["CO2_pipeline_offshore"]["cost_20_MtCO2"] = cost_data[string(port_name, "-", string(to_area))]["costs"]["offshore-pipeline"][4]["cost"]
  key = string(port_name, "-", string(to_area))
  route_dict[key] = location_dict
end 

YAML.write_file("./EnergyModelsDAC/cases/DAC_case_study/input_costs.yml", route_dict)

## Creating dict for transport model: ports-offshore storage
route_dict = Dict{String, Dict{String, Any}}()
for to_area in route_data.to_area
    location_dict = Dict{String, Any}()
    location_dict["offshore"] = true
    location_dict["x_to"] = route_data[route_data.to_area .== to_area, :x_offshore][1]
    location_dict["y_to"] = route_data[route_data.to_area .== to_area, :y_offshore][1]
    location_dict["x_from"] = route_data[route_data.to_area .== to_area, :x_port][1]
    location_dict["y_from"] = route_data[route_data.to_area .== to_area, :y_port][1]
    lon_port = route_data[route_data.to_area .== to_area, :x_port][1]
    port_name = port_data[port_data.Lon .== lon_port, :Name][1]
    key = string(port_name, "-", string(to_area))
    location_dict["distance"] = haversine((location_dict["x_to"], location_dict["y_to"]),
                                           (location_dict["x_from"], location_dict["y_from"]), 6371)
    route_dict[key] = location_dict
end 

## Delaunay triangulation between country centroids
input_regions = YAML.load_file("./EnergyModelsDAC/cases/DAC_case_study/input_regions.yml")
countries = input_regions["Countries"]

lon_lat_tuple = Tuple{Float64, Float64}
country_areas = Dict{Symbol, NTuple{2, Float64}}()
pts_EU = NTuple{2, Float64}[]

for (key, value) in countries
  lon_lat_tuple = (round(value["lon"], digits=4), round(value["lat"], digits=4))
  push!(pts_EU, lon_lat_tuple)
  symbol_name = Symbol(key)
  @eval $symbol_name = lon_lat_tuple
  country_areas[symbol_name] = lon_lat_tuple
end

tri_EU = triangulate(pts_EU)

route_coord_EU = NTuple{2, NTuple{2, Float64}}[]
for (vertex_1, vertex_2) in get_edges(tri_EU)
  area_1, area_2 = get_point(tri_EU, vertex_1, vertex_2)
  push!(route_coord_EU, (area_1, area_2))
end

## Final selection of onshore pipeline connections 
pipe_data = CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/onshore_countries_centroids.csv") |> DataFrame
pipe_connections = NTuple{2, NTuple{2, Float64}}[]
for (x1, y1, x2, y2) in eachrow(pipe_data[!, ["x1", "y1", "x2", "y2"]])
  area_1 = (round(x1, digits=4), round(y1, digits=4))
  area_2 = (round(x2, digits=4), round(y2, digits=4))
  push!(pipe_connections, (area_1, area_2))
end 

pipeline_coord = NTuple{2, Symbol}[]
for coord_pair in pipe_connections
  area1 = nothing
  area2 = nothing
    for (symbol, area) in country_areas
      if coord_pair[1] == area
        area1 = symbol
      end
      if coord_pair[2] == area
        area2 = symbol 
      end
    end 
    if area1 === nothing || area2 === nothing
      println("Warning: No matching symbols found for coordinates $coord_pair")
    else
      push!(pipeline_coord, (area1, area2))
    end
end 

cost_data = YAML.load_file("./EnergyModelsDAC\\cases\\DAC_case_study\\data\\CO2_transmission_costs.yml")

connection_dict = Dict{String, Dict{String, Any}}()
for (from_area, to_area) ∈ pipeline_coord
  location_dict = Dict{String, Any}()
  location_dict["from"] = string(from_area)
  location_dict["to"] = string(to_area)
  location_dict["offshore"] = false
  location_dict["direction"] = 2
  location_dict["mode"] = Dict{String, Any}()  
  location_dict["mode"]["CO2_pipeline_onshore"] = Dict{String, Any}()
  location_dict["mode"]["CO2_pipeline_onshore"]["cost_1_MtCO2"] = cost_data[string(from_area, "-", to_area)]["costs"]["onshore-pipeline"][1]["cost"]
  location_dict["mode"]["CO2_pipeline_onshore"]["cost_5_MtCO2"] = cost_data[string(from_area, "-", to_area)]["costs"]["onshore-pipeline"][2]["cost"]
  location_dict["mode"]["CO2_pipeline_onshore"]["cost_10_MtCO2"] = cost_data[string(from_area, "-", to_area)]["costs"]["onshore-pipeline"][3]["cost"]
  location_dict["mode"]["CO2_pipeline_onshore"]["cost_20_MtCO2"] = cost_data[string(from_area, "-", to_area)]["costs"]["onshore-pipeline"][4]["cost"]
  connection_dict[string(from_area, "-", to_area)] = location_dict
end 

YAML.write_file("./EnergyModelsDAC/cases/DAC_case_study/input_costs.yml", connection_dict)

## Creating dict for transport model: country centroids onshore pipeline network
corridor_dict = Dict{String, Dict{String, Any}}()
for (from_area, to_area) ∈ pipe_connections
  location_dict = Dict{String, Any}()
  location_dict["x_from"] = from_area[1]
  location_dict["y_from"] = from_area[2]
  location_dict["x_to"] = to_area[1]
  location_dict["y_to"] = to_area[2]
  location_dict["offshore"] = false
  location_dict["distance"] = haversine((from_area[1], from_area[2]), (to_area[1], to_area[2]), 6371)
  from = nothing
  to = nothing
  for (symbol, area) in country_areas
    if from_area == area
      from = symbol
    end
    if to_area == area
      to = symbol 
    end
    if from !== nothing && to !== nothing
      corridor_dict[string(from, "-", to)] = location_dict
    end
  end 
end 

## Pipeline routes between ports and country centroids
port_data =  CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/location_ports.csv") |> DataFrame
cost_data = YAML.load_file("./EnergyModelsDAC\\cases\\DAC_case_study\\data\\CO2_transmission_costs.yml")

port_dict = Dict{String, Dict{String, Any}}()
for from_area ∈ port_data.Name
      location_dict = Dict{String, Any}()
      location_dict["from"] = string(from_area)
      location_dict["to"] = string(port_data[port_data.Name .== from_area, :Country][1])
      location_dict["offshore"] = false
      location_dict["direction"] = 2
      location_dict["mode"] = Dict{String, Any}()  
      location_dict["mode"]["CO2_pipeline_onshore"] = Dict{String, Any}()
      location_dict["mode"]["CO2_pipeline_onshore"]["cost_1_MtCO2"] = cost_data[string(from_area, "-", location_dict["to"])]["costs"]["onshore-pipeline"][1]["cost"]
      location_dict["mode"]["CO2_pipeline_onshore"]["cost_5_MtCO2"] = cost_data[string(from_area, "-", location_dict["to"])]["costs"]["onshore-pipeline"][2]["cost"]
      location_dict["mode"]["CO2_pipeline_onshore"]["cost_10_MtCO2"] = cost_data[string(from_area, "-", location_dict["to"])]["costs"]["onshore-pipeline"][3]["cost"]
      location_dict["mode"]["CO2_pipeline_onshore"]["cost_20_MtCO2"] = cost_data[string(from_area, "-", location_dict["to"])]["costs"]["onshore-pipeline"][4]["cost"]
      port_dict[string(from_area, "-", location_dict["to"])] = location_dict
end 

YAML.write_file("./EnergyModelsDAC/cases/DAC_case_study/input_costs.yml", port_dict)


## Creating dict for transport model: country centroids-ports connections
port_dict = Dict{String, Dict{String, Any}}()
for from_area ∈ port_data.Name
  location_dict = Dict{String, Any}()
  location_dict["offshore"] = false
  location_dict["x_from"] = port_data[port_data.Name .== from_area, :Lon][1]
  location_dict["y_from"] = port_data[port_data.Name .== from_area, :Lat][1]
  for (symbol, area) in country_areas
    if port_data[port_data.Name .== from_area, :Country][1] == string(symbol)
      location_dict["x_to"] = area[1]
      location_dict["y_to"] = area[2] 
      location_dict["distance"] = haversine((port_data[port_data.Name .== from_area, :Lon][1], port_data[port_data.Name .== from_area, :Lat][1]), (area[1], area[2]), 6371)
    end
  end 
  port_dict[string(from_area, "-", port_data[port_data.Name .== from_area, :Country][1])] = location_dict
end

## Pipeline routes between onshore storage sites and nearby country centroids 
site_data =  CSV.File("./EnergyModelsDAC/cases/DAC_case_study/data/onshore_storage_pipelines.csv") |> DataFrame
route_dict = Dict{String, Dict{String, Any}}()
for to_area ∈ site_data.OBJECTID
      location_dict = Dict{String, Any}()
      location_dict["from"] = string(site_data[site_data.OBJECTID .== to_area, :country][1])
      location_dict["to"] = string(to_area)
      location_dict["offshore"] = false
      location_dict["mode"] = "CO2_pipeline_onshore_stor"
      route_dict[string(location_dict["from"], "-", string(to_area))] = location_dict
end 

## Creating dict for transport model: country centroids-onshore storage
route_dict = Dict{String, Dict{String, Any}}()
for to_area ∈ site_data.OBJECTID
      location_dict = Dict{String, Any}()
      location_dict["offshore"] = false
      location_dict["x_to"] = site_data[site_data.OBJECTID .== to_area, :LONG][1]
      location_dict["y_to"] = site_data[site_data.OBJECTID .== to_area, :LAT][1]
      location_dict["x_from"] = site_data[site_data.OBJECTID .== to_area, :x][1]
      location_dict["y_from"] = site_data[site_data.OBJECTID .== to_area, :y][1]
      location_dict["distance"] = haversine((site_data[site_data.OBJECTID .== to_area, :LONG][1], site_data[site_data.OBJECTID .== to_area, :LAT][1]), (site_data[site_data.OBJECTID .== to_area, :x][1], site_data[site_data.OBJECTID .== to_area, :y][1]), 6371)
      route_dict[string(string(site_data[site_data.OBJECTID .== to_area, :country][1]), "-", string(to_area))] = location_dict
end 

## Generate distances for offshore storage sites of Norway
sites = Dict("Farsundbassenget" => (7.06, 57.65), 
            "Bryne_uten_Farsund" => (3.88, 58.02), 
            "Sognefjorddelta" => (4.25, 60.68), 
            "Gassum" => (7.31, 57.59), 
            "Hugin_østUtsira" => (3.04, 59.77), 
            "Johansen" => (3.68, 60.85), 
            "Siritrenden" => (5.52, 56.89), 
            "Omriss_Statfjord_modell" => (4.13, 59.66), 
            "Utsira_Skade_tilvolum" => (2.6, 60.03))
distances_NO_stor = Dict(site => 0.0 for site in keys(sites))
r_earth = 6371 

x_from_area = 5.305589183
y_from_area = 60.38975161
for site in keys(sites)
    distances_NO_stor[site] = haversine((x_from_area, y_from_area), (sites[site][1], sites[site][2]), r_earth)
end

