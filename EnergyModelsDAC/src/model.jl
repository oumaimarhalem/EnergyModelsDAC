function EMB.variables_emission(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
    𝒩ⁿᵒᵗ = EMB.node_not_av(𝒩)    
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, emissions_node[𝒩ⁿᵒᵗ, 𝒯, 𝒫ᵉᵐ] >= 0) 
    @variable(m, emissions_total[𝒯, 𝒫ᵉᵐ] >= 0) 
    @variable(m, emissions_strategic[t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ] <= modeltype.Emission_limit[p][t_inv]) 

    # Variables for setting the CDR target
    @variable(m, CO2_captured[𝒯ᴵⁿᵛ] >= 0) 
    @variable(m, CO2_stored[𝒯ᴵⁿᵛ] >= 0) 

    @variable(m, CO2_captured_DACS[𝒯ᴵⁿᵛ] >= 0) 
    @variable(m, CO2_captured_DACL[𝒯ᴵⁿᵛ] >= 0) 
    @variable(m, CO2_captured_DACM[𝒯ᴵⁿᵛ] >= 0)
end

function EMB.variables_node(m, 𝒩ˢᵘᵇ::Vector{<:CO2_storage}, 𝒯, modeltype::EnergyModel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @variable(m, CO2_rate_cap[𝒯ᴵⁿᵛ] >= 0) 
    @variable(m, stor_level_strat[𝒩ˢᵘᵇ, 𝒯ᴵⁿᵛ] >= 0) 
    @variable(m, CO2_trans_cap[𝒯ᴵⁿᵛ] >= 0) 
end

function EMG.variables_area(m, 𝒜, 𝒯, ℒᵗʳᵃⁿˢ, modeltype::EnergyModel)
    @variable(m, area_exchange[a ∈ 𝒜, 𝒯, p ∈ EMG.exchange_resources(ℒᵗʳᵃⁿˢ, a)])

    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    𝒜_countries = area_sub(𝒜, Country)

    @variable(m, CO2_captured_area[a ∈ 𝒜_countries, 𝒯ᴵⁿᵛ] >= 0)
end

function EMB.create_node(m, n::CO2_storage, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    p_stor = n.Stor_res
    𝒫ᵉᵐ    = EMB.res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ   = strategic_periods(𝒯)

    if hasfield(typeof(n), :Emissions) && !isnothing(n.Emissions)
        @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
            m[:emissions_node][n, t, p_em] == m[:stor_rate_use][n, t] * n.Emissions[p_em]
        )
    else
        @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
            m[:emissions_node][n, t, p_em] == 0
        )
    end

    # Defining a variable for the storage level at the end of each strategic period
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ), t ∈ t_inv
        if isnothing(t_inv_prev)
            @constraint(m,  
                m[:stor_level_strat][n, t_inv] == sum(m[:flow_in][n, t, p_stor] for t ∈ t_inv) * 
                                                    duration(t) * 
                                                    duration(t_inv)
                )
        else
            @constraint(m,  
                m[:stor_level_strat][n, t_inv] == m[:stor_level_strat][n, t_inv_prev] +
                                                    sum(m[:flow_in][n, t, p_stor] for t ∈ t_inv) * 
                                                        duration(t) *
                                                        duration(t_inv)
                )
        end 
    end 

    # Mass/energy balance constraints for stored energy carrier.
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ), (t_prev, t) ∈ withprev(t_inv)
        if isnothing(t_prev) && isnothing(t_inv_prev)
            @constraint(m,
                m[:stor_level][n, t] ==  (m[:flow_in][n, t , p_stor] -
                                            m[:emissions_node][n, t, p_stor]) * 
                                            duration(t)
                )
        elseif isnothing(t_prev) && !isnothing(t_inv_prev)
            @constraint(m,
                m[:stor_level][n, t] ==  m[:stor_level_strat][n, t_inv_prev] + 
                                            (m[:flow_in][n, t , p_stor] -
                                            m[:emissions_node][n, t, p_stor]) * 
                                            duration(t)
                )
        else 
            @constraint(m,
                m[:stor_level][n, t] ==  m[:stor_level][n, t_prev] + 
                                            (m[:flow_in][n, t , p_stor] -
                                            m[:emissions_node][n, t, p_stor]) * 
                                            duration(t)
                )
        end
    end
    
    # Constraint for the other emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ EMB.res_not(𝒫ᵉᵐ, p_stor)],
        m[:emissions_node][n, t, p_em] == 0)

    # Call of the function for the inlet flow to the `Storage` node
    EMB.constraints_flow_in(m, n, 𝒯, modeltype)
    constraints_flow_out(m, n::CO2_storage, 𝒯, modeltype)
    
    # Call of the function for limiting the capacity to the maximum installed capacity
    EMB.constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    EMB.constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    EMB.constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

""" Function for computing the storage level of heat storage tanks """
function EMB.create_node(m, n::HeatStorage, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    p_stor = n.Stor_res
    𝒫ᵉᵐ    = EMB.res_sub(𝒫, ResourceEmit)
    CO2 = modeltype.CO2_instance
    𝒯ᴵⁿᵛ   = strategic_periods(𝒯)

    # Mass/energy balance constraints for stored energy carrier.
    for t_inv ∈ 𝒯ᴵⁿᵛ, (t_prev, t) ∈ withprev(t_inv)
        if isnothing(t_prev)
            @constraint(m,
                m[:stor_level][n, t] ==  (m[:stor_level][n, last(t_inv)] * (1 - n.Stor_loss_coeff_1)) + 
                                            (m[:flow_in][n, t , p_stor] -
                                            m[:flow_out][n, t , p_stor] -
                                            (n.Stor_loss_coeff_2 * m[:stor_cap_inst][n, t] * ((n.T_min - n.AirTemperature[t])/(n.T_max - n.T_min)))) * 
                                            duration(t)
            )
        else
            @constraint(m,
                m[:stor_level][n, t] ==  (m[:stor_level][n, t_prev] * (1 - n.Stor_loss_coeff_1)) + 
                                            (m[:flow_in][n, t , p_stor] -
                                            m[:flow_out][n, t , p_stor] -
                                            (n.Stor_loss_coeff_2 * m[:stor_cap_inst][n, t] * ((n.T_min - n.AirTemperature[t])/(n.T_max - n.T_min)))) * 
                                            duration(t)
            )
        end
    end
    
    # Constraint for the emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == 0)

    # Call of the function for the inlet flow to the `Storage` node
    EMB.constraints_flow_in(m, n, 𝒯, modeltype)
    
    # Call of the function for limiting the capacity to the maximum installed capacity
    EMB.constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    EMB.constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    EMB.constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

""" Function for setting all constraints for Grid node """
function EMB.create_node(m, n::Grid, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    
    if hasfield(typeof(n), :Emissions) && !isnothing(n.Emissions)
        # Constraint for the emissions to avoid problems with unconstrained variables.
        @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
            m[:emissions_node][n, t, p_em] == m[:cap_use][n, t] * n.Emissions[p_em][t])
    else
        # Constraint for the emissions associated to using the source.
        @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
            m[:emissions_node][n, t, p_em] == 0)
    end

    # Call of the function for the outlet flow from the `Source` node
    EMB.constraints_flow_out(m, n, 𝒯, modeltype)

    # Call of the function for limiting the capacity to the maximum installed capacity
    EMB.constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    EMB.constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    EMB.constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

function EMB.create_node(m, n::DAC, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets.
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)
    CO2 = modeltype.CO2_instance
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    if hasfield(typeof(n), :Emissions) && !isnothing(n.Emissions)
        # Constraint for the emissions to avoid problems with unconstrained variables.
        @constraint(m, [t ∈ 𝒯],
            m[:emissions_node][n, t, CO2] == m[:cap_use][n, t] * n.Emissions[CO2])
    else
        # Constraint for the emissions associated to using the source.
        @constraint(m, [t ∈ 𝒯],
            m[:emissions_node][n, t, CO2] == 0)
    end
    
    # Constraint for the other emissions to avoid problems with unconstrained variables.
    @constraint(m, [t ∈ 𝒯, p_em ∈ EMB.res_not(𝒫ᵉᵐ, CO2)],
        m[:emissions_node][n, t, p_em] == 0)

    # Call of the function for the inlet flow to and outlet flow from the `Network` node
    EMB.constraints_flow_in(m, n, 𝒯, modeltype)
    EMB.constraints_flow_out(m, n, 𝒯, modeltype)
            
    # Call of the function for limiting the capacity to the maximum installed capacity
    EMB.constraints_capacity(m, n, 𝒯, modeltype)

    # Call of the functions for both fixed and variable OPEX constraints introduction
    EMB.constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    EMB.constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end