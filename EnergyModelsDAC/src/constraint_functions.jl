function EMB.constraints_emissions(m, 𝒩, 𝒯, 𝒫, modeltype::EnergyModel)
    
    # Emission constraints
    𝒩ⁿᵒᵗ = EMB.node_not_av(𝒩)
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵉᵐ],
        m[:emissions_total][t, p] == sum(m[:emissions_node][n, t, p] for n ∈ 𝒩ⁿᵒᵗ)
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, p ∈ 𝒫ᵉᵐ],
        m[:emissions_strategic][t_inv, p] == sum(m[:emissions_total][t, p] * duration(t) for t ∈ t_inv)
    )

    # Constraints to set the collective CDR target
    CO2 = modeltype.CO2_instance
    CDR_target = modeltype.CDR_target

    𝒩ˢᵘᵇ = EMB.node_sub(𝒩, DAC)
    𝒩ˢᵗᵒʳ = EMB.node_sub(𝒩, CO2_storage)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:CO2_captured][t_inv] == sum(m[:flow_out][n, t, CO2] * duration(t) for t ∈ t_inv, n ∈ 𝒩ˢᵘᵇ)
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:CO2_stored][t_inv] == sum(m[:flow_in][n, t, CO2] * duration(t) for t ∈ t_inv, n ∈ 𝒩ˢᵗᵒʳ)
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:CO2_stored][t_inv] >= CDR_target[t_inv]
    )

    ## Constraints to set predefined shares for each DAC technology
    𝒩_S = EMB.node_sub(𝒩ˢᵘᵇ, DACS)
    𝒩_L = EMB.node_sub(𝒩ˢᵘᵇ, DACL)
    𝒩_M = EMB.node_sub(𝒩ˢᵘᵇ, DACM)

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:CO2_captured_DACS][t_inv] == sum(m[:flow_out][n, t, CO2] * duration(t) for t ∈ t_inv, n ∈ 𝒩_S)
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:CO2_captured_DACL][t_inv] == sum(m[:flow_out][n, t, CO2] * duration(t) for t ∈ t_inv, n ∈ 𝒩_L)
    )
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:CO2_captured_DACM][t_inv] == sum(m[:flow_out][n, t, CO2] * duration(t) for t ∈ t_inv, n ∈ 𝒩_M)
    )
    
    ## Constraint to set the minimum share of DAC-S in Europe similar to the assumed global share
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
        m[:CO2_captured_DACS][t_inv] >= 0.40 * m[:CO2_captured][t_inv]
    )

    # # Scenario with equal shares of the three technologies
    # equal_DACM_min = modeltype.equal_DACM_min
    # equal_DAC_min = modeltype.equal_DAC_min

    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     equal_DAC_min[t_inv] * CDR_target[t_inv] <= m[:CO2_captured_DACS][t_inv] 
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     equal_DAC_min[t_inv] * CDR_target[t_inv] <= m[:CO2_captured_DACL][t_inv])

    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     equal_DACM_min[t_inv] * CDR_target[t_inv] <= m[:CO2_captured_DACM][t_inv]
    # )

    # # Scenario with equal shares of DAC-S and DAC-L and without DAC-M
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     0.50 * CDR_target[t_inv] <= m[:CO2_captured_DACS][t_inv]
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     0.50 * CDR_target[t_inv] <= m[:CO2_captured_DACL][t_inv]
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     m[:CO2_captured_DACM][t_inv] == 0.0
    # )

    # # Scenario with DAC-S majority
    # DACS_maj_DACM_min = modeltype.DACS_maj_DACM_min
    # DACS_maj_DACL_min = modeltype.DACS_maj_DACL_min
    # DACS_maj_DACS_min = modeltype.DACS_maj_DACS_min

    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     DACS_maj_DACS_min[t_inv] * CDR_target[t_inv] <= m[:CO2_captured_DACS][t_inv] 
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     DACS_maj_DACL_min[t_inv] * CDR_target[t_inv] <= m[:CO2_captured_DACL][t_inv] 
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     DACS_maj_DACM_min[t_inv] * CDR_target[t_inv] <= m[:CO2_captured_DACM][t_inv]
    # )

    # # Scenario with DAC-L majority
    # DACL_maj_DACM_min = modeltype.DACL_maj_DACM_min
    # DACL_maj_DACL_min = modeltype.DACL_maj_DACL_min
    # DACL_maj_DACS_min = modeltype.DACL_maj_DACS_min

    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     DACL_maj_DACS_min[t_inv] * CDR_target[t_inv] <= m[:CO2_captured_DACS][t_inv] 
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     DACL_maj_DACL_min[t_inv] * CDR_target[t_inv] <= m[:CO2_captured_DACL][t_inv] 
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ], 
    #     DACL_maj_DACM_min[t_inv] * CDR_target[t_inv] <= m[:CO2_captured_DACM][t_inv]
    # )

    ## Scenario with 100% shares for each of the DAC technologies
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     m[:CO2_captured][t_inv] == m[:CO2_captured_DACS][t_inv]
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     m[:CO2_captured_DACL][t_inv] == 0.0
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     m[:CO2_captured_DACM][t_inv] == 0.0
    # )
    
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     m[:CO2_captured][t_inv] == m[:CO2_captured_DACL][t_inv]
    # )
    #     @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     m[:CO2_captured_DACS][t_inv] == 0.0
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     m[:CO2_captured_DACM][t_inv] == 0.0
    # )

    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     m[:CO2_captured][t_inv] == m[:CO2_captured_DACM][t_inv]
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     m[:CO2_captured_DACL][t_inv] == 0.0
    # )
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     m[:CO2_captured_DACS][t_inv] == 0.0
    # )

    # Constraint to specify the operations of CO2 storage reservoirs
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ, n ∈ 𝒩ˢᵗᵒʳ],
        m[:stor_level_strat][n, t_inv] <= m[:stor_cap_current][n, t_inv]
    )
end

""" Function for setting the country-based CDR targets"""
# function EMG.create_area(m, a::Country, 𝒯, ℒᵗʳᵃⁿˢ, modeltype)
    
#     CO2 = modeltype.CO2_instance
#     𝒯ᴵⁿᵛ = strategic_periods(𝒯)
#     CDR_target = a.CDR_target

#     @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
#         m[:CO2_captured_area][a, t_inv] == sum(m[:flow_in][a.An, t, CO2] * duration(t) for t ∈ t_inv)
#     )
#     @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
#         CDR_target[t_inv] <= m[:CO2_captured_area][a, t_inv]
#     )
# end

""" Function for creating the constraint on the input flows of DAC nodes """
function EMB.constraints_flow_in(m, n::DAC, 𝒯::TimeStructure, modeltype::EnergyModel)
    𝒫ⁱⁿ  = keys(n.Input)

    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ], 
        m[:flow_in][n, t, p] == m[:cap_use][n, t] * n.Input[p][t]
    )
end

function EMB.constraints_capacity(m, n::DAC, 𝒯::TimeStructure, modeltype::EnergyModel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t]/8760
    )

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:cap_use][n, t] * duration(t) for t ∈ t_inv) <= 
                sum(m[:cap_inst][n, t]/8760 * duration(t) for t ∈ t_inv) * n.Cap_factor
    )

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:cap_use][n, t] * duration(t) for t ∈ t_inv) >= 
                sum(m[:cap_inst][n, t]/8760 * duration(t) for t ∈ t_inv) * n.Cap_factor_min
    )

    EMB.constraints_capacity_installed(m, n::DAC, 𝒯, modeltype)
end

""" Function for creating the constraint on the output flows of CO2 storage nodes """
function constraints_flow_out(m, n::CO2_storage, 𝒯::TimeStructure, modeltype::EnergyModel)
    𝒫ᵒᵘᵗ = keys(n.Output)

    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:flow_out][n, t, p] == 0
    )
end

""" Functions for creating the constraint on the heat output flow from a heat pump node """
function cop_hp(T1, T2)
    Lorentz_efficiency = 0.5
    T_inlet = T1 + 273 # K
    T_outlet = T2 + 273 # K

    COP_HP = (T_outlet / (T_outlet - T_inlet)) * 1.07 * Lorentz_efficiency

    return COP_HP
end

function EMB.constraints_flow_in(m, n::HeatPump, 𝒯::TimeStructure, modeltype::EnergyModel)
    𝒫ⁱⁿ  = keys(n.Input)

    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ⁱⁿ], 
        m[:flow_in][n, t, p] == m[:cap_use][n, t] / cop_hp(n.AirTemperature[t], n.HeatTemperature)
    )
end

""" Functions for creating the constraint on the heat output flow from a GeothermalPowerPlant node """
function EMB.constraints_flow_out(m, n::GeothermalPowerPlant, 𝒯::TimeStructure, modeltype::EnergyModel)
    𝒫ᵒᵘᵗ = keys(n.Output)

    p_th = collect(𝒫ᵒᵘᵗ)[1]

    c_water = 4.186 # kJ/(kg deg C)
    ΔT_DAC_geo = 30 # Drop in T when providing heat for DAC 

    @constraint(m, [t ∈ 𝒯],
        m[:flow_out][n, t, p_th] == 
            (m[:cap_use][n, t] * 1e3 / n.Electrical_flow_ratio) * c_water * ΔT_DAC_geo / 1e6 # GWth
    )
end

function EMB.constraints_capacity(m, n::GeothermalPowerPlant, 𝒯::TimeStructure, modeltype::EnergyModel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t]
    )

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:cap_use][n, t] * duration(t) for t ∈ t_inv) == 
            sum(m[:cap_inst][n, t] * duration(t) for t ∈ t_inv) * n.Cap_factor
    )

    EMB.constraints_capacity_installed(m, n, 𝒯, modeltype)
end

function EMB.constraints_capacity(m, n::NuclearPowerPlant, 𝒯::TimeStructure, modeltype::EnergyModel)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t]
    )

    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        sum(m[:cap_use][n, t] * duration(t) for t ∈ t_inv) == 
            sum(m[:cap_inst][n, t] * duration(t) for t ∈ t_inv) * n.Cap_factor
    )

    EMB.constraints_capacity_installed(m, n, 𝒯, modeltype)
end

""" Functions for creating the constraint on the heat output flow from a SolarThermal node """
 function EMB.constraints_capacity(m, n::SolarThermal, 𝒯::TimeStructure, modeltype::EnergyModel)
    
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= m[:cap_inst][n, t]
    )

     @constraint(m, [t ∈ 𝒯],
         m[:cap_use][n, t] ==
            n.Efficiency[t] * (n.Irradiance[t]/1e3) * (m[:cap_inst][n, t]/n.Heat_capacity) # GWth
    )

     EMB.constraints_capacity_installed(m, n, 𝒯, modeltype)
 end

""" Function for creating the constraint on the heat and power output flows from a SMR node """
function EMB.constraints_flow_out(m, n::SMR, 𝒯::TimeStructure, modeltype::EnergyModel)
    𝒫ᵒᵘᵗ = keys(n.Output)

    p_th = collect(𝒫ᵒᵘᵗ)[1]
    p_el = collect(𝒫ᵒᵘᵗ)[2]

    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:flow_out][n, t, p] <= n.Output[p] * m[:cap_use][n, t]
    )

    @constraint(m, [t ∈ 𝒯],
        m[:flow_out][n, t, p_el]  ==  n.Output[p_el] * m[:cap_use][n, t] - n.Loss_factor * m[:flow_out][n, t, p_th]
    )
end

