"""
    extract_capacity_usage(m, case, modeltype, name_string; remove_empty=true)

Extracts the capacity usage in each region and in total from the data.
The function assumes uses only the last type, if not specified in more detail

# Arguments
- `m:`: the JuMP model or alternatively the directory where all csvs are saved
- `case`: the case description
- `modeltype`: the modeltype
- `name_string`: the string of the name of the investigated technology

# Optional arguments
- `remove_empty:`: Logic whether empty values should be removed. The default is `true`

# Returns
- `usage.area_op`: a dictionary having the areas as keys and the values as matrix where
dimension 1 corresponds to the strategic period and 2 to the operational period
- `usage.area_sp`: a dictionary having the areas as keys and the values as array
- `usage.total_op`: a matrix where dimension 1 corresponds to the strategic period
and 2 to the operational period
- `usage.total_sp`: an array with the total in a strategic period as value

- `capacity.area_op`: a dictionary having the areas as keys and the values as matrix where
dimension 1 corresponds to the strategic period and 2 to the operational period
- `capacity.area_sp`: a dictionary having the areas as keys and the values as array
- `capacity.total_op`: a matrix where dimension 1 corresponds to the strategic period
and 2 to the operational period
- `capacity.total_sp`: an array with the total in a strategic period as value

- `capacity_factor_area`: an array whit the total import in a strategic period as value
"""
function extract_capacity_usage(m, case, modeltype, name_string; remove_empty=true)

    # Extract the required values from the types
    𝒩 = case[:nodes]
    𝒩ˢᵘᵇ = node_sub(𝒩, name_string)
    𝒯 = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    op_len = length(𝒯.operational[1])

    # Initialization of the individual dictionaries
    if typeof(𝒩ˢᵘᵇ) <: Array{<:Storage}

        usage_area_op = Dict{String, Dict{String, Matrix}}()
        usage_area_sp = Dict{String, Dict{String, Array}}()
        usage_total_op = Dict{String, Matrix}(
                            "rate" => zeros(Float64, 𝒯.len, op_len),
                            "level" => zeros(Float64, 𝒯.len, op_len))
        usage_total_sp = Dict{String, Array}(
                            "rate" => zeros(Float64, 𝒯.len),
                            "level" => zeros(Float64, 𝒯.len))
        
        capacity_area_op = Dict{String, Dict{String, Matrix}}()
        capacity_area_sp = Dict{String, Dict{String, Array}}()
        capacity_total_op = Dict{String, Matrix}(
                            "rate" => zeros(Float64, 𝒯.len, op_len),
                            "level" => zeros(Float64, 𝒯.len, op_len))
        capacity_total_sp = Dict{String, Array}(
                            "rate" => zeros(Float64, 𝒯.len),
                            "level" => zeros(Float64, 𝒯.len))
        
        capacity_factor_area = Dict{String, Dict{String, Array}}()
        
        # Initialization of the data files
        data = (rate_use = read_data(m, "stor_rate_use"),
                rate_inst = read_data(m, "stor_rate_inst"),
                level = read_data(m, "stor_level"),
                cap_inst = read_data(m, "stor_cap_inst"),
                )
    else
        usage_area_op = Dict{String, Matrix}()
        usage_area_sp = Dict{String, Array}()
        usage_total_op = zeros(Float64, 𝒯.len, op_len)
        usage_total_sp = zeros(Float64, 𝒯.len)
        
        capacity_area_op = Dict{String, Matrix}()
        capacity_area_sp = Dict{String, Array}()
        capacity_total_op = zeros(Float64, 𝒯.len, op_len)
        capacity_total_sp = zeros(Float64, 𝒯.len)
        
        capacity_factor_area = Dict{String, Array}()
        
        # Initialization of the data files
        data = (use = read_data(m, "cap_use"),
                inst = read_data(m, "cap_inst"),
                )
    end

    # Go through all areas and identifiy the respective resources
    if haskey(case, :areas)
        for area ∈ case[:areas]
            area_length = length(area.Name)
            𝒩ˢᵘᵇ⁻ᵃʳ =  node_sub(𝒩ˢᵘᵇ, area.Name)
            for n ∈ 𝒩ˢᵘᵇ⁻ᵃʳ
                if n.id[1:area_length] == area.Name
                    usage_area_op[area.Name], usage_area_sp[area.Name], capacity_area_op[area.Name], capacity_area_sp[area.Name] = 
                        extract_node_usage(m, n, 𝒯, data)
                end
            end
        end
    else
        for n ∈ 𝒩ˢᵘᵇ
            usage_area_op["Dummy"], usage_area_sp["Dummy"], capacity_area_op["Dummy"], capacity_area_sp["Dummy"] = 
                extract_node_usage(m, n, 𝒯, data)
        end
    end
    
    # Calculation of the the total imported resource
    if typeof(𝒩ˢᵘᵇ) <: Array{<:Storage}
        for key ∈ keys(usage_area_op)
            for sub_key ∈ keys(usage_area_op[key])
                usage_total_op[sub_key] += usage_area_op[key][sub_key]
                usage_total_sp[sub_key] += usage_area_sp[key][sub_key]

                capacity_total_op[sub_key] += capacity_area_op[key][sub_key]
                capacity_total_sp[sub_key] += capacity_area_sp[key][sub_key]
            end
        end
    else
        for key ∈ keys(usage_area_op)
            usage_total_op += usage_area_op[key]
            usage_total_sp += usage_area_sp[key]

            capacity_total_op += capacity_area_op[key]
            capacity_total_sp += capacity_area_sp[key]
            capacity_factor_area[key] = usage_area_sp[key]./(capacity_area_sp[key]*8760)
        end
    end

    # Removal of empty key-value pairs
    if remove_empty
        usage_area_op = remove_empty_values(usage_area_op)
        usage_area_sp = remove_empty_values(usage_area_sp)

        capacity_area_op = remove_empty_values(capacity_area_op)
        capacity_area_sp = remove_empty_values(capacity_area_sp)
        
        capacity_factor_area = remove_empty_values(capacity_factor_area)
    end

    return (area_op=usage_area_op, area_sp=usage_area_sp, total_op=usage_total_op, total_sp=usage_total_sp),
           (area_op=capacity_area_op, area_sp=capacity_area_sp, total_op=capacity_total_op, total_sp=capacity_total_sp), 
            capacity_factor_area
end


"""
    extract_capacity_invest(m, case, modeltype, name_string; remove_empty=true)

Extracts the added capacity in each region and in total from the data.

# Arguments
- `m:`: the JuMP model or alternatively the directory where all csvs are saved
- `case`: the case description
- `modeltype`: the modeltype
- `name_string`: the string of the name of the investigated technology

# Optional arguments
- `remove_empty:`: Logic whether empty values should be removed. The default is `true`

# Returns
- `invest.area`: a dictionary having the areas as keys and the invested capacities
as array with the strategic period as index
- `invest.total`: an array of the total invested capacities with the strategic period as index
- `capacity.area`: a dictionary having the areas as keys and the capacities
as array with the strategic period as index
- `capacity.total`: an array of the total capacities with the strategic period as index
"""
function extract_capacity_invest(m, case, modeltype, name_string; remove_empty=true)

    # Redefine variables
    𝒩 = case[:nodes]
    𝒩ˢᵘᵇ = node_sub(𝒩, name_string)
    𝒩ᴵⁿᵛ = EMI.has_investment(𝒩ˢᵘᵇ)    # Nodes with investments
    𝒯 = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Initialization of the individual dictionaries
    if typeof(𝒩ˢᵘᵇ) <: Array{<:Storage}
        invest_area = Dict{String, Dict{String, Array}}()
        capacity_area = Dict{String, Dict{String, Array}}()

        invest_total = Dict{String, Array}(
                        "rate" => zeros(Float64, 𝒯.len),
                        "level" => zeros(Float64, 𝒯.len))
        capacity_total = Dict{String, Array}(
                        "rate" => zeros(Float64, 𝒯.len),
                        "level" => zeros(Float64, 𝒯.len))
        
    # Initialization of the data files
    data = (rate_add = read_data(m, "stor_rate_add"),
            cap_add  = read_data(m, "stor_cap_add"),
            rate_current = read_data(m, "stor_rate_current"),
            cap_current  = read_data(m, "stor_cap_current"),
            rate_inst = read_data(m, "stor_rate_inst"),
            cap_inst  = read_data(m, "stor_cap_inst"),
            )
    else
        invest_area  = Dict{String, Array}()
        invest_total = zeros(Float64, 𝒯.len)
        capacity_area  = Dict{String, Array}()
        capacity_total = zeros(Float64, 𝒯.len)
        
    # Initialization of the data files
    data = (add = read_data(m, "cap_add"),
            current = read_data(m, "cap_current"),
            inst = read_data(m, "cap_inst"),
            )
    end
    
    # Go through all areas and receive the values
    if haskey(case, :areas)
        for area ∈ case[:areas]
            area_length = length(area.Name)
            𝒩ˢᵘᵇ⁻ᵃʳ =  node_sub(𝒩ˢᵘᵇ, area.Name)
            for n ∈ 𝒩ˢᵘᵇ⁻ᵃʳ
                if n.id[1:area_length] == area.Name
                    invest_area[area.Name], capacity_area[area.Name] = extract_node_invest(m, n, 𝒯, data)
                end
            end
        end
    else
        for n ∈ 𝒩ˢᵘᵇ
            invest_area["Dummy"], capacity_area["Dummy"] = extract_node_invest(m, n, 𝒯, data)
        end
    end

    # Calculation of the the total invested capacities
    if typeof(𝒩ˢᵘᵇ) <: Array{<:Storage}
        for key ∈ keys(invest_area)
            for sub_key ∈ keys(invest_area[key])
                invest_total[sub_key] += invest_area[key][sub_key]
                capacity_total[sub_key] += capacity_area[key][sub_key]
            end
        end
    else
        for key ∈ keys(invest_area)
            invest_total += invest_area[key]
            capacity_total += capacity_area[key]
        end
    end
    
    if remove_empty
        invest_area = remove_empty_values(invest_area)
        capacity_area = remove_empty_values(capacity_area)
    end

    return (area=invest_area, total=invest_total), (area=capacity_area, total=capacity_total)
end


"""
    extract_transmission_usage(m, case, modeltype, resource, remove_empty=true)

Extracts the usage in each corridor for a given resource.

# Arguments
- `m:`: the JuMP model or alternatively the directory where all csvs are saved
- `case`: the case description
- `modeltype`: the modeltype
- `resource`: the resource transported in a corridor

# Optional arguments
- `remove_empty:`: Logic whether empty values should be removed. The default is `true`

# Returns
- `usage.op`: a dictionary consisting of the corridor names as keys and a dictionary
as values. The dictionary has the mode as key and as value the usage as matrix where
dimension 1 corresponds to the strategic period and 2 to the operational period.
- `usage.sp`: a dictionary consisting of the corridor names as keys and a dictionary
as values. The dictionary has the mode as key and as value the usage as array
"""
function extract_transmission_usage(m, case, modeltype, resource; remove_empty=true)

    # Redefine variables
    ℒᵗʳᵃⁿˢ  = case[:transmission]
    𝒯 = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    op_len = length(𝒯.operational[1])

    # Initialization of the individual dictionaries
    usage_op = Dict{String,Dict{String, Array}}()
    usage_sp = Dict{String,Dict{String, Array}}()

    # Initialization of the data files
    data_usage = read_data(m, "trans_in")

    # Go through all areas and identifiy the respective resources
    for l ∈ ℒᵗʳᵃⁿˢ
        name = repr(l)
        usage_op[name]  = Dict{String, Matrix}()
        usage_sp[name]  = Dict{String, Array}()

        for cm ∈ l.Modes
            if map_trans_resource(cm) == resource
                # Extract the usage
                tmp_usage = read_two_indeces(m, cm, "trans_in", data_usage)
                cm_name   = cm.Name[length(name)+2:end]
                # cm_name   = cm.Name
                
                # Initialize the individual dictionary entries
                usage_op[name][cm_name] = Matrix{Float64}(undef, 0, op_len)
                usage_sp[name][cm_name] = Array{Float64}(undef, 0)

                # Assign the values to the dictionaries 
                for t_inv ∈ 𝒯ᴵⁿᵛ
                    iter = (t_inv.sp-1)*op_len+1 : t_inv.sp*op_len
                    tmp_use = [if val < 1e-3; 0 else val end for val ∈ tmp_usage[iter]]
                    usage_op[name][cm_name] = 
                        cat(usage_op[name][cm_name], tmp_use', dims=1)
                    append!(
                        usage_sp[name][cm_name],
                        sum(abs.(usage_op[name][cm_name][t_inv.sp, :]).*t_inv.operational.duration)
                    )
                    
                end
            end
        end
    end
    
    if remove_empty
        usage_op = remove_empty_values(usage_op)
        usage_sp = remove_empty_values(usage_sp)
    end

    return (op=usage_op, sp=usage_sp)
end

"""
    extract_transmission_invest(m, case, modeltype, resource; remove_empty=true)

Extracts the import of resource `resource` in each area.

# Arguments
- `m:`: the JuMP model or alternatively the directory where all csvs are saved
- `case`: the case description
- `modeltype`: the modeltype
- `resource`: the resource transported in a corridor

# Optional arguments
- `remove_empty:`: Logic whether empty values should be removed. The default is `true`

# Returns
- `invest_corridor`: a dictionary consisting of the corridors as keys and a dictionary
as values. The dictionary has the mode as key and as value the invested capacities as array with
the strategic period as index.
- `capacity_corridor`: a dictionary consisting of the corridors as keys and a dictionary
as values. The dictionary has the mode as key and as value the capacities as array with
the strategic period as index.
"""
function extract_transmission_invest(m, case, modeltype, resource; remove_empty=true)

    # Redefine variables
    ℒᵗʳᵃⁿˢ  = case[:transmission]
    𝒯 = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Initialization of the individual dictionaries
    invest_corridor     = Dict{String,Dict{String, Array}}()
    capacity_corridor   = Dict{String,Dict{String, Array}}()

    # Initialization of the data files
    data_addition = read_data(m, "trans_cap_add")
    data_current = read_data(m, "trans_cap_current")
    data_cap = read_data(m, "trans_cap")

    # Go through all areas and receive the values
    for l ∈ ℒᵗʳᵃⁿˢ
        name = repr(l)
        invest_corridor[name]  = Dict{String, Array}()
        capacity_corridor[name]  = Dict{String, Array}()

        for cm ∈ l.Modes
            cm_name = cm.Name[length(name)+2:end]
            if map_trans_resource(cm) == resource

                if EMI.has_investment(cm)
                    tmp_addition = read_two_indeces(m, cm, "trans_cap_add", data_addition)
                    tmp_capacity = read_two_indeces(m, cm, "trans_cap_current", data_current)
                    invest_corridor[name][cm_name] = [if val < 1e-3; 0 else val end for val ∈ tmp_addition]
                    capacity_corridor[name][cm_name] = [if val < 1e-3; 0 else val end for val ∈ tmp_capacity]
                else
                    invest_corridor[name][cm_name] = zeros(Int64, 𝒯.len)
                    capacity_corridor[name][cm_name] = zeros(Float64, 𝒯.len)
                    for t_inv ∈ 𝒯ᴵⁿᵛ
                        capacity_corridor[name][cm_name][t_inv.sp] =  read_two_indeces(m, n, "trans_cap", first_operational(t_inv), data_cap)
                    end
                end
            end
        end
    end

    if remove_empty
            invest_corridor = remove_empty_values(invest_corridor)
            capacity_corridor = remove_empty_values(capacity_corridor)
    end

    return invest_corridor, capacity_corridor
end


"""
    extract_area_exchange(m, case, modeltype)

Extracts the net import/export values from an area.

# Arguments
- `m:`: the JuMP model or alternatively the directory where all csvs are saved
- `case`: the case description
- `modeltype`: the modeltype

# Optional arguments
- `remove_empty:`: Logic whether empty values should be removed. The default is `true`

# Returns
- `exchange_area.op`: a dictionary having the areas as keys and the values
as matrix where dimension 1 corresponds to the strategic period and 2 to the operational
period
- `exchange_area.sp`: a dictionary having the areas as keys and the values as array
"""
function extract_area_exchange(m, case, modeltype; remove_empty=true)

    # Extract the required values from the types
    ℒᵗʳᵃⁿˢ = case[:transmission]
    𝒯 = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    op_len = length(𝒯.operational[1])

    # Initialization of the individual dictionaries
    exchange_area_op = Dict{String,Dict{String, Matrix}}()
    exchange_area_sp = Dict{String,Dict{String, Array}}()

    # Initialization of the data files
    data_exchange = read_data(m, "area_exchange")

    # Go through all areas and identifiy the respective resources
    for area ∈ case[:areas]
        exchange_area_op[area.Name] = Dict{String, Matrix}()
        exchange_area_sp[area.Name] = Dict{String, Array}()
        for p ∈ EMG.exchange_resources(ℒᵗʳᵃⁿˢ, area)
            # Extract the usage and capacity values
            tmp_ex       = read_three_indeces(m, area, "area_exchange", p, data_exchange)
            tmp_exchange = [if abs(val) < 1e-3; 0 else val end for val ∈ tmp_ex]

            # Initialize the individual dictionary entries
            exchange_area_op[area.Name][p.id] = Matrix{Float64}(undef, 0, op_len)
            exchange_area_sp[area.Name][p.id] = Array{Float64}(undef, 0)

            # Assign the values to the dictionaries 
            for t_inv ∈ 𝒯ᴵⁿᵛ
                iter = (t_inv.sp-1)*op_len+1 : t_inv.sp*op_len
                exchange_area_op[area.Name][p.id] = cat(exchange_area_op[area.Name][p.id], tmp_exchange[iter]', dims=1)
                append!(exchange_area_sp[area.Name][p.id], sum(exchange_area_op[area.Name][p.id][t_inv.sp, :].*t_inv.operational.duration))
            end
        end
    end
    

    if remove_empty
        exchange_area_op = remove_empty_values(exchange_area_op)
        exchange_area_sp = remove_empty_values(exchange_area_sp)
    end

    return (op=exchange_area_op, sp=exchange_area_sp)
end


"""
    extract_emissions(m, case, modeltype)

Extracts the net import/export values from an area.

# Arguments
- `m:`: the JuMP model or alternatively the directory where all csvs are saved
- `case`: the case description
- `modeltype`: the modeltype

# Optional arguments
- `remove_empty:`: Logic whether empty values should be removed. The default is `true`

# Returns
- `emissions.node`: a dictionary having the nodes as keys and the values as array
- `emissions.area`: a dictionary having the areas as keys and the values as array
- `emissions.total`: an array
"""
function extract_emissions(m, case, modeltype, p; remove_empty=true)

    # Extract the required values from the types
    𝒯 = case[:T]
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    op_len = length(𝒯.operational[1])
    sp_len = 𝒯.len

    # Initialization of the individual dictionaries
    emissions_node = Dict{String, Array}()
    emissions_area = Dict{String, Array}()
    
    # Initialization of the data files
    data_emissions = read_data(m, "emissions_node")

    # Go through all areas and nodes to calculate the emissions
    for area ∈ case[:areas]
        area_name = area.Name
        area_nodes = node_not_av(node_sub(case[:nodes], area_name))
        emissions_area[area_name] = zeros(sp_len)

        for node ∈ area_nodes
            # Extract the individual emissions of the node
            tmp_em =  read_three_indeces(m, node, "emissions_node", p, data_emissions)
            tmp_emissions = [if val < 1e-3; 0 else val end for val ∈ tmp_em]
            node_name = node.id[length(area_name)+4:end]*" - "*area_name

            # Initialize the individual dictionary entries
            emissions_node[node_name] = Array{Float64}(undef, 0)

            # Assign the values to the dictionaries 
            for t_inv ∈ 𝒯ᴵⁿᵛ
                iter = (t_inv.sp-1)*op_len+1 : t_inv.sp*op_len
                emissions_node[node_name] = cat(emissions_node[node_name],  sum(tmp_emissions[iter].*t_inv.operational.duration), dims=1)
                emissions_area[area_name][t_inv.sp] += emissions_node[node_name][t_inv.sp]
            end
        end
    end
    
    # Extract the total emissions
    data_emissions = read_data(m, "emissions_strategic")
    emissions_total = read_two_indeces(m, "emissions_strategic", p, data_emissions)
    
    if remove_empty
        emissions_node = remove_empty_values(emissions_node)
        emissions_area = remove_empty_values(emissions_area)
    end

    return (node=sort(emissions_node), area=sort(emissions_area), total=emissions_total)
end


"""
    extract_node_usage(m, n, 𝒯, data)

Extracts the capacity usage in each node.

# Arguments
- `m:`: the JuMP model or alternatively the directory where all csvs are saved
- `n`: the node
- `𝒯`: the time structure
- `data`: the loaded CSVs, if existing

# Returns
- `usage_op`: a matrix of the usage where dimension 1 corresponds to the strategic
period and 2 to the operational period
- `usage_sp`: an array of the usage where the indices correspond to the strategic periods

- `capacity_op`: a matrix of the capacity where dimension 1 corresponds to the strategic
period and 2 to the operational period
- `capacity_sp`: an array of the capacity where the indices correspond to the strategic periods
"""
function extract_node_usage(m, n::EMB.Node, 𝒯, data)

    # Extract the required subtypes
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    op_len = length(𝒯.operational[1])

    # Extract the usage and capacity values
    tmp_usage    = read_two_indeces(m, n, "cap_use", data.use)
    tmp_capacity = read_two_indeces(m, n, "cap_inst", data.inst)

    # Initialize the individual dictionary entries
    usage_op = Matrix{Float64}(undef, 0, op_len)
    usage_sp = Array{Float64}(undef, 0)
    capacity_op = Matrix{Float64}(undef, 0, op_len)
    capacity_sp = Array{Float64}(undef, 0)

    # Assign the values to the dictionaries 
    for t_inv ∈ 𝒯ᴵⁿᵛ
        iter = (t_inv.sp-1)*op_len+1 : t_inv.sp*op_len
        tmp_use = [if val < 1e-3; 0 else val end for val ∈ tmp_usage[iter]]
        tmp_cap = [if val < 1e-3; 0 else val end for val ∈ tmp_capacity[iter]]

        usage_op = cat(usage_op, tmp_use', dims=1)
        append!(usage_sp, sum(usage_op[t_inv.sp, :].*t_inv.operational.duration))
        
        capacity_op = cat(capacity_op, tmp_cap', dims=1)
        append!(capacity_sp, capacity_op[t_inv.sp, 1])
    end

    return usage_op, usage_sp, capacity_op, capacity_sp
end

function extract_node_usage(m, n::EMB.Storage, 𝒯, data)

    # Extract the required subtypes
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    op_len = length(𝒯.operational[1])

    # Extract the usage and capacity values
    tmp_rate_use = read_two_indeces(m, n, "stor_rate_use", data.rate_use)
    tmp_rate_inst = read_two_indeces(m, n, "stor_rate_inst", data.rate_inst)
    tmp_level = read_two_indeces(m, n, "stor_level", data.level)
    tmp_level_inst = read_two_indeces(m, n, "stor_cap_inst", data.cap_inst)

    # Initialize the individual dictionary entries
    usage_op = Dict{String,Matrix}(
                        "rate"=>Matrix{Float64}(undef, 0, op_len),
                        "level"=>Matrix{Float64}(undef, 0, op_len))
    usage_sp = Dict{String,Array}(
                        "rate"=>Array{Float64}(undef, 0),
                        "level"=>Array{Float64}(undef, 0))
    capacity_op = Dict{String,Matrix}(
                        "rate"=>Matrix{Float64}(undef, 0, op_len),
                        "level"=>Matrix{Float64}(undef, 0, op_len))
    capacity_sp = Dict{String,Array}(
                        "rate"=>Array{Float64}(undef, 0),
                        "level"=>Array{Float64}(undef, 0))

    # Assign the values to the dictionaries 
    for t_inv ∈ 𝒯ᴵⁿᵛ
        iter = (t_inv.sp-1)*op_len+1 : t_inv.sp*op_len
        tmp_use = [if val < 1e-3; 0 else val end for val ∈ tmp_rate_use[iter]]
        tmp_inst = [if val < 1e-3; 0 else val end for val ∈ tmp_rate_inst[iter]]
        tmp_lvl = [if val < 1e-3; 0 else val end for val ∈ tmp_level[iter]]
        tmp_cap = [if val < 1e-3; 0 else val end for val ∈ tmp_level_inst[iter]]

        usage_op["rate"] = cat(usage_op["rate"], tmp_use', dims=1)
        append!(usage_sp["rate"], sum(usage_op["rate"][t_inv.sp, :].*t_inv.operational.duration))
        
        usage_op["level"] = cat(usage_op["level"], tmp_lvl', dims=1)
        append!(usage_sp["level"], 0)

        capacity_op["rate"] = cat(capacity_op["rate"], tmp_inst', dims=1)
        append!(capacity_sp["rate"], capacity_op["rate"][t_inv.sp, 1])
        
        capacity_op["level"] = cat(capacity_op["level"], tmp_cap', dims=1)
        append!(capacity_sp["level"], capacity_op["level"][t_inv.sp, 1])
    end

    return usage_op, usage_sp, capacity_op, capacity_sp
end


"""
    extract_node_invest(m, n, 𝒯, data)

Extracts the capacity investment in each node.

# Arguments
- `m:`: the JuMP model or alternatively the directory where all csvs are saved
- `n`: the node
- `𝒯`: the time structure
- `data`: the loaded CSVs, if existing

# Returns
- `invest`: an array of the investments where the indices correspond to the strategic periods
- `capacity`: an array of the capacity where the indices correspond to the strategic periods
"""
function extract_node_invest(m, n::EMB.Node, 𝒯, data)
    
    if EMI.has_investment(n)
        invest   = read_two_indeces(m, n, "cap_add", data.add)
        capacity = read_two_indeces(m, n, "cap_current", data.current)
    else
        invest = zeros(Int64, 𝒯.len)
        capacity = zeros(Float64, 𝒯.len)
        for t_inv ∈ 𝒯ᴵⁿᵛ
            capacity[t_inv.sp] = read_two_indeces(m, n, "cap_inst", first_operational(t_inv), data.inst)
        end
    end

    return invest, capacity
end

function extract_node_invest(m, n::EMB.Storage, 𝒯, data)
    
    if EMI.has_investment(n)
        invest = Dict{String,Array}(
                "rate" => read_two_indeces(m, n, "stor_rate_add", data.rate_add),
                "level" => read_two_indeces(m, n, "stor_cap_add", data.cap_add),
                )
        capacity = Dict{String,Array}(
                "rate" => read_two_indeces(m, n, "stor_rate_current", data.rate_current),
                "level" => read_two_indeces(m, n, "stor_cap_current", data.cap_current),
                )
    else
        invest = Dict{String,Array}(
                    "rate" => zeros(Float64, 𝒯.len),
                    "level" => zeros(Float64, 𝒯.len))
        capacity = Dict{String,Array}(
                    "rate" => zeros(Float64, 𝒯.len),
                    "level" => zeros(Float64, 𝒯.len))
        for t_inv ∈ 𝒯ᴵⁿᵛ
            capacity["rate"][t_inv.sp] = read_two_indeces(m, n, "stor_rate_inst", first_operational(t_inv), data.rate_inst)
            capacity["level"][t_inv.sp] = read_two_indeces(m, n, "stor_cap_inst", first_operational(t_inv), data.cap_inst)
        end
    end

    return invest, capacity
end