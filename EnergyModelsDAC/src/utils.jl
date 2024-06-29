
"""
    create_transmission_mode(mode_type::Type{TransmissionMode}, corr_id::String, data, resource::EMB.Resource, power::EMB.Resource, T, multiplier::Dict)

Creates the instances for the transmission modes depending on the chosen Type.
The function is currently limited to the types `PipeSimple`, `RefDynamic`, and `RefStatic`.
"""
function create_transmission_mode(mode_type::Type{PipeSimple},
    corr_id::String,
    data,
    resource::EMB.Resource,
    power::EMB.Resource,
    T,
    multiplier::Dict,
)

    if haskey(data, "trans_max_add") && data["trans_max_add"] > 0
        inv_data = create_transmission_invest(data, multiplier, T)
    else
        inv_data = []
    end

    tmp = PipeSimple(
        Name = corr_id*"_"*data["name"],
        Inlet = resource,
        Outlet = resource,
        Consuming = power,
        Consumption_rate = time_profile(data["consumption_rate"], T),
        Trans_cap = time_profile(data["trans_capacity"], T),
        Trans_loss = time_profile(data["trans_loss"], T),
        Opex_var = time_profile(data["trans_OPEX_variable"]*multiplier["dist"], T),
        Opex_fixed = time_profile(data["trans_OPEX_fixed"]*multiplier["dist"], T),
        Data = inv_data,
    )

    return [tmp]
end

function create_transmission_mode(mode_type::Type{RefStatic},
    corr_id::String,
    data,
    resource::EMB.Resource,
    power::EMB.Resource,
    T,
    multiplier::Dict,
)
    if haskey(data, "trans_max_add") && data["trans_max_add"] > 0
        inv_data = create_transmission_invest(data, multiplier, T)
    else
        inv_data = []
    end

    tmp = EMG.RefStatic(
        corr_id*"_"*data["name"],
        resource,
        time_profile(data["trans_capacity"], T),
        time_profile(data["trans_loss"], T),
        time_profile(data["trans_OPEX_variable"]*multiplier["dist"], T),
        time_profile(data["trans_OPEX_fixed"]*multiplier["dist"], T),
        data["direction"],
        inv_data,
    )

    return [tmp]
end

function create_transmission_mode(mode_type::Type{CO2_Pipe},
    corr_id::String,
    data,
    corr,
    resource::EMB.Resource,
    power::EMB.Resource,
    T,
    multiplier::Dict,
)
    if haskey(data, "trans_max_add") && data["trans_max_add"] > 0
        inv_data = create_transmission_invest(data, multiplier, T)
    else
        inv_data = []
    end

    tmp = CO2_Pipe(
        corr_id*"_"*data["name"],
        resource,
        time_profile(data["trans_capacity"], T),
        time_profile(data["trans_loss"], T),
        time_profile([CO2_transport_cost(corr, data["name"], year) for year ∈ strategic_periods(T)], T),
        FixedProfile(0),
        data["direction"],
        inv_data,
    )

    return [tmp]
end

function create_transmission_mode(mode_type::Type{RefDynamic},
    corr_id::String,
    data,
    resource::EMB.Resource,
    power::EMB.Resource,
    T,
    multiplier::Dict,
)

    if haskey(data, "trans_max_add") && data["trans_max_add"] > 0
        inv_data = create_transmission_invest(data, multiplier, T)
    else
        inv_data = []
    end

    tmp = EMG.RefDynamic(
        corr_id*"_"*data["name"],
        resource,
        time_profile(data["trans_capacity"], T),
        time_profile(data["trans_loss"], T),
        time_profile(data["trans_OPEX_variable"]*multiplier["dist"], T),
        time_profile(data["trans_OPEX_fixed"]*multiplier["dist"], T),
        data["direction"],
        inv_data,
    )

    return [tmp]
end

function create_transmission_mode(mode_type::Type{CO2_Ship},
    corr_id::String,
    data,
    corr,
    resource::EMB.Resource,
    power::EMB.Resource,
    T,
    multiplier::Dict,
)

    if haskey(data, "trans_max_add") && data["trans_max_add"] > 0
        inv_data = create_transmission_invest(data, multiplier, T)
    else
        inv_data = []
    end

    tmp = EMG.RefDynamic(
        corr_id*"_"*data["name"],
        resource,
        time_profile(data["trans_capacity"], T),
        time_profile(data["trans_loss"], T),
        time_profile([CO2_transport_cost(corr, data["name"], year) for year ∈ strategic_periods(T)], T),
        FixedProfile(0),
        data["direction"],
        inv_data,
    )

    return [tmp]
end

"""
    create_transmission_invest(data, multiplier)

Creates the transmission investment data based on the provided input data.
"""
function create_transmission_invest(data, multiplier, T)
    
    if haskey(data, "investment_mode")
        inv_mode = map_inv_mode(data["investment_mode"])
    else
        inv_mode = EMI.ContinuousInvestment()
    end
    inv_data = [EMI.TransInvData(
                Capex_trans     = time_profile(data["trans_CAPEX"]*multiplier["capex"]*multiplier["dist"], T), # CAPEX [€/kW]
                Capex_trans_offset = time_profile(data["trans_CAPEX_offset"]*multiplier["capex_offset"]*multiplier["dist"], T), # CAPEX [€]
                Trans_max_inst  = time_profile(data["trans_max_installed"], T),    # max installed capacity [kW]
                Trans_max_add   = time_profile(data["trans_max_add"], T),          # max_add [kW]
                Trans_min_add   = time_profile(data["trans_min_add"], T),          # min_add [kW]
                Inv_mode        = inv_mode,
                Trans_increment = time_profile(data["trans_increment"], T),
                Trans_start     = data["trans_start"],
    )]

    return inv_data
end

"""
    map_inv_mode(string)

Provides a map from string to investment mode
"""
function map_inv_mode(string)
    inv_mode = Dict(
        "SemiContinuous" => EMI.SemiContinuousInvestment(),
        "SemiContinuousOffset" => EMI.SemiContinuousOffsetInvestment(),
        "Continuous"     => EMI.ContinuousInvestment(),
        "Discrete"  => EMI.DiscreteInvestment(),
    )
    return inv_mode[string]
end

"""
    map_trans_mode(string)

Provides a map from string to reference transmission mode
"""
function map_trans_mode(string)
    trans_mode = Dict(
        "El" => "power_line",
        "NG" => "natural_gas_pipe",
    )
    return trans_mode[string]
end

""" 
    map_trans_type(string)

Provides a mapping of the transmission mode type names to the technology julia
types necessary to create the correct instances when reading input data.
"""
function map_trans_type(string)
    trans_type = Dict(
        "PipeSimple" => EMG.PipeSimple,
        "RefStatic"  => EMG.RefStatic,
        "RefDynamic"  => EMG.RefDynamic,
        "CO2_Pipe" => CO2_Pipe,
        "CO2_Ship" => CO2_Ship,
    )
    return trans_type[string]
end

""" 
    map_trans_resource(cm)

Returns the transported resource for a given corridor_mode.
"""
function map_trans_resource(cm::EMG.TransmissionMode)
    return cm.Resource
end
function map_trans_resource(cm::EMG.PipeMode)
    return cm.Inlet
end

"""
    map_multiplier(corr_p, offshore)

Returns the multipliers used in the calculation of the pipeline investments
"""
function map_multiplier(corr_p, corr, dist, input_trans, offshore)
    
    # Initiate the dictionary
    multiplier = Dict()
    multiplier["capex"] = 1
    multiplier["capex_offset"] = 1

      # Multiplier for the distance
      multiplier["dist"] = 1
      #if corr_p["full"]
         # multiplier["dist"] = 1
      if haskey(corr, "distance") && corr_p["type"] == "CO2_Pipe" && offshore == true 
          multiplier["dist"] = corr["distance"] * input_trans["pipe_multiplier_offshore"]
      elseif haskey(corr, "distance") && corr_p["type"] == "CO2_Pipe" && offshore == false 
          multiplier["dist"] = corr["distance"] * input_trans["pipe_multiplier_onshore"]
      elseif haskey(corr, "distance") && corr_p["type"] == "CO2_Ship"
          multiplier["dist"] = corr["distance"]
      elseif !haskey(corr, "distance") && corr_p["type"] == "CO2_Pipe" && offshore == true 
          multiplier["dist"] = dist * input_trans["pipe_multiplier_offshore"]
      elseif !haskey(corr, "distance") && corr_p["type"] == "CO2_Pipe" && offshore == false 
          multiplier["dist"] = dist * input_trans["pipe_multiplier_onshore"]
      elseif !haskey(corr, "distance") && corr_p["type"] == "CO2_Ship"
          multiplier["dist"] = dist
      end  

    # # Multiplier for onshore vs. offshore
    # if offshore
    #     multiplier["capex"] = corr_p["multiplier_CAPEX"]
    #     multiplier["capex_offset"] = corr_p["multiplier_CAPEX_offset"]
    # end

    return multiplier
end

"""
    node_sub(𝒩, string::String)

Returns all nodes that include in the name the `string`
"""
function node_sub(𝒩, string::String)

    sub_nodes = Array{EMB.Node}([])
    for n ∈ 𝒩
        if occursin(string, n.id)
            append!(sub_nodes, [n])
        end
    end
    sub_nodes = convert(Array{typejoin(typeof.(sub_nodes)...)}, sub_nodes)

    return sub_nodes
end

"""
    node_not_av(𝒩::Array{Node})

Return nodes that are not availability nodes for a given Array `::Array{Node}`.
"""
function node_not_av(𝒩::Array{<:EMB.Node})
    return 𝒩[findall(x -> ~isa(x, Availability), 𝒩)]
end


"""
    link_sub(ℒ, string::String)

Returns all links that include in the name the `string`.
"""
function link_sub(ℒ, string::String)

    sub_links = Array{EMB.Link}([])
    for l ∈ ℒ
        if occursin(string, l.id)
            append!(sub_links, [l])
        end
    end

    return sub_links
end

"""
    mode_corr(ℒᵗʳᵃⁿˢ, from::String)

Returns all transmission corridors that orginate in the area with the name `from`.
"""
function mode_corr(ℒᵗʳᵃⁿˢ, from::String)

    sub_corr = Array{EMG.Transmission}([])
    for l ∈ ℒᵗʳᵃⁿˢ
        if occursin(from, l.From.Name)
            append!(sub_corr, [l])
        end
    end

    return sub_corr
end

"""
    mode_corr(ℒᵗʳᵃⁿˢ, from::String)

Returns the transmission corridor that orginates in the area with the name `from`
and ends in the area with the name `to`.
"""
function mode_corr(ℒᵗʳᵃⁿˢ, from::String, to::String)

    sub_corr = nothing
    for l ∈ ℒᵗʳᵃⁿˢ
        if occursin(from, l.From.Name) && occursin(to, l.To.Name)
            sub_corr = l
        end
    end

    return sub_corr
end


"""
    mode_sub(𝒞ℳ, string::String)

Returns all transmission modes that include in the name the `string`.
"""
function mode_sub(𝒞ℳ, string::String)

    sub_modes = Array{EMG.TransmissionMode}([])
    for cm ∈ 𝒞ℳ
        if occursin(string, cm.Name)
            append!(sub_modes, [cm])
        end
    end

    return sub_modes
end

"""
    mode_sub(𝒞ℳ, string_array::Array{String})

Returns all transmission modes that include in the name all entries of
the array `string_array`.
"""
function mode_sub(𝒞ℳ, string_array::Array{String})

    sub_modes = Array{EMG.TransmissionMode}([])
    for cm ∈ 𝒞ℳ
        if all(occursin(string, cm.Name) for string ∈ string_array)
            append!(sub_modes, [cm])
        end
    end

    return sub_modes
end

"""
    unique_resources(nodes)

Returns all resources in the array `nodes` that are either an `Input` or `Output`.
These `unique` resources can then be used as input to the availability node.
"""
function unique_resources(nodes)

    products = []
    for n ∈ nodes
        try 
            append!(products, collect(keys(n.Input)))
        catch
            nothing
        end
        try 
            append!(products, collect(keys(n.Output)))
        catch
            nothing
        end
    end
    products = unique(products)
    
    return products
end


"""
    remove_empty_keys(dict::Dict{String, Union{Array, Matrix}}})

Removes all key-value pairs that correspond to investments. The additional parameter
`atol` correspond to the absolute value as tolerance
"""
function remove_empty_values(dict::Dict{String, Array}; atol=1e-8)
    
    for key ∈ keys(dict)
        if  any(abs.(dict[key]) .> atol)
            nothing
        else
            delete!(dict, key)
        end
    end
    return dict
end
function remove_empty_values(dict::Dict{String, Matrix}; atol=1e-8)
    
    for key ∈ keys(dict)
        if  any(abs.(dict[key]) .> atol)
            nothing
        else
            delete!(dict, key)
        end
    end
    return dict
end

function remove_empty_values(dict::Dict{String,<:Dict}; atol=1e-8)
    
    for key ∈ keys(dict)
        dict[key] = remove_empty_values(dict[key]; atol=atol)
        if isempty(dict[key])
            delete!(dict, key)
        end
    end
    return dict
end

""" 
    time_profile(x,T::TimeStructure)

Transform a given input x into a Timeprofile as defines in the Timestructures package.
The type of time_profile returned depends on the form of x

- Real                      -> FixedProfile
- Array{<:Real,1}           -> StrategicProfile or OperationalProfile; based on length of array
- Array{<:Real,2}           -> DynamicProfile
- AbstractArray{<:Real,2}   -> DynamicProfile
- AbstractMatrix            -> DynamicProfile
- Nothing                   -> FixedProfile(0)
"""
function time_profile()
    return FixedProfile(0)
end
function time_profile(x::Nothing, T::TimeStructure)
    return FixedProfile(0)
end

function time_profile(x::Real, T::TimeStructure)
    return FixedProfile(x)
end

function time_profile(x::Array{<:Real,1}, T::TimeStructure)
    if length(x) == T.len
        return StrategicProfile(x)
    else
        return OperationalProfile(x)
    end
end

function time_profile(x::Array{<:String,1}, T::TimeStructure)
    if length(x) == T.len
        return StrategicProfile(x)
    else
        return OperationalProfile(x)
    end
end

# function time_profile(x::Array{<:Real,2}, T::TimeStructure)
#     return DynamicProfile(x)
# end

# function time_profile(x::AbstractArray{<:Real,2}, T::TimeStructure)
#     return DynamicProfile(x)
# end

function time_profile(x::AbstractMatrix, T::TimeStructure)
    profile = []
    if T.len != size(x)[1]
        x = x'
    end
    for k ∈ range(1, T.len)
        push!(profile, OperationalProfile(x[k,:]))
    end
    profile = convert(Array{typejoin(typeof.(profile)...)}, profile)
    return StrategicProfile(profile)
end


"""
    order_time_periods(string::String)

Creates an operational period based on the input from a string for loading .csv data
and ordering them in the case of a `SparseAxisArray`
"""
function order_time_periods(string)
    sp, tmp = parse_time_period(string, 4)
    op = parse(Int64, string[tmp+2:end])

    return OperationalPeriod(sp, op)
end


"""
    parse_time_period(tp::String, tmp::Int)

Identifies the strategic period of a string representing an `OperationalPeriod` originating 
from `TimeStructures`
"""
function parse_time_period(tp, tmp)
    sp = nothing
    try 
        sp = parse(Int64, tp[2:tmp])
    catch
        if tmp < 2
            return nothing, nothing
        end
        sp, tmp = parse_time_period(tp, tmp-1)
    end
    return sp, tmp
end
"""
    save_case_modeltype(case::Dict, modeltype::EnergyModel; filename=joinpath(pwd(),"case.JLD2"))

Saves both the `case` dictionary and `modeltype` in a JLD2 format in the file case.JLD2.
If no `directory` is specified, it saves it as `case` in in the current working directory.
"""
function save_case_modeltype(case::Dict, modeltype::EnergyModel; directory=pwd())
    jldopen(joinpath(directory,"case.JLD2"), "w") do file
        file["case"] = case
        file["modeltype"] = modeltype
    end
end

"""
    save_results(model::Model; directory=joinpath(pwd(),"csv_files"))

Saves the model results of all variables as CSV files. The model results are saved in a new directory.
If no directory is specified, it will create, if necessary, a new directory "csv_files" in the current
working directory and save the files in said directory.    
"""
function save_results(model::Model; directory=joinpath(pwd(),"csv_files"))
    vars = collect(keys(object_dictionary(model)))

    if !ispath(directory)
        mkpath(directory)
    end

    Threads.@threads for v ∈ vars
        fn = joinpath(directory, string(v) * ".csv")
        CSV.write(fn, JuMP.Containers.rowtable(value, model[v]))
    end
end