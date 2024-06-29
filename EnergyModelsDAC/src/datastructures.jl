""" DAC deployment model """
struct DACDeploymentModel <: EMI.AbstractInvestmentModel
    CDR_target::TimeProfile
    Emission_limit::Dict{ResourceEmit, TimeProfile}
    Emission_price::Dict{ResourceEmit, TimeProfile}
    CO2_instance::ResourceEmit
    CO2_stor_rate::TimeProfile
    
    equal_DACM_min::TimeProfile
    equal_DAC_min::TimeProfile

    DACS_maj_DACM_min::TimeProfile
    DACS_maj_DACL_min::TimeProfile
    DACS_maj_DACS_min::TimeProfile

    DACL_maj_DACM_min::TimeProfile
    DACL_maj_DACL_min::TimeProfile
    DACL_maj_DACS_min::TimeProfile
    
    r::Real
end

""" Power grid as a subtype of Source node """
struct Grid <: EMB.Source
    id
    Cap::TimeProfile 
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Output::Dict{Resource, Real}
    Data::Array{Data}
    Emissions::Union{Nothing, Dict{ResourceEmit, TimeProfile}}
end
Grid(id, Cap, Opex_var, Opex_fixed, Output, Data) =
    Grid(id, Cap, Opex_var, Opex_fixed, Output, Data, nothing)

""" Small nuclear reactors as a subtype of Source node """
struct SMR <: EMB.Source
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Output::Dict{Resource, Real}
    Loss_factor::Real
    Data::Array{Data}
    Emissions::Union{Nothing, Dict{ResourceEmit, Real}}
end
SMR(id, Cap, Opex_var, Opex_fixed, Output, Loss_factor, Data) =
    SMR(id, Cap, Opex_var, Opex_fixed, Output, Loss_factor, Data, nothing)

""" Air-source heat pumps as a subtype of Network node """
struct HeatPump <: EMB.Network
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile 
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
    AirTemperature::TimeProfile
    HeatTemperature::Real
    Data::Array{Data}
end

""" Geothermal heat and power plant as a subtype of Source node """
struct GeothermalPowerPlant <: EMB.Source
    id
    Cap::TimeProfile
    Cap_factor::Real
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Output::Dict{Resource, Real}
    Electrical_flow_ratio::Real
    Data::Array{Data}
    Emissions::Dict{ResourceEmit, Real}
end


""" Nuclear power plant as a subtype of Source node """
struct NuclearPowerPlant <: EMB.Source
    id
    Cap::TimeProfile
    Cap_factor::Real
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Output::Dict{Resource, Real}
    Data::Array{Data}
    Emissions::Union{Nothing, Dict{ResourceEmit, Real}}
end
NuclearPowerPlant(id, Cap, Cap_factor, Opex_var, Opex_fixed, Output, Data) =
    NuclearPowerPlant(id, Cap, Cap_factor, Opex_var, Opex_fixed, Output, Data, nothing)

"""Solar thermal as a subtype of Source node """
struct SolarThermal <: EMB.Source
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Irradiance::TimeProfile
    Efficiency::TimeProfile
    Heat_capacity::Real
    Output::Dict{Resource, Real}
    Data::Array{Data}
    Emissions::Union{Nothing, Dict{ResourceEmit, Real}}
end
SolarThermal(id, Cap, Opex_var, Opex_fixed, Irradiance, Efficiency, Heat_capacity, Output, Data) =
    SolarThermal(id, Cap, Opex_var, Opex_fixed, Irradiance, Efficiency, Heat_capacity, Output, Data, nothing)

""" Heat storage as a subtype of Storage node """
struct HeatStorage <: EMB.Storage
    id
    Rate_cap::TimeProfile
    Stor_cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Stor_res::ResourceCarrier
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
    Stor_loss_coeff_1::Real
    Stor_loss_coeff_2::Real
    T_min::Real
    T_max::Real
    AirTemperature::TimeProfile
    Data::Array{Data}
end

""" DAC module as subtype of Network node """
abstract type DAC <: EMB.Network end

struct DACS <: DAC
    id
    Cap::TimeProfile
    Cap_factor::Real
    Cap_factor_min::Real
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Input::Dict{Resource, TimeProfile}
    Output::Dict{Resource, Real}
    Data::Array{Data}
    Emissions::Union{Nothing, Dict{ResourceEmit, Real}}
end
DACS(id, Cap, Cap_factor, Cap_factor_min, Opex_var, Opex_fixed, Input, Output, Data) =
    DACS(id, Cap, Cap_factor, Cap_factor_min, Opex_var, Opex_fixed, Input, Output, Data, nothing)

struct DACM <: DAC
    id
    Cap::TimeProfile
    Cap_factor::Real
    Cap_factor_min::Real
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Input::Dict{Resource, TimeProfile}
    Output::Dict{Resource, Real}
    Data::Array{Data}
    Emissions::Union{Nothing, Dict{ResourceEmit, Real}}
end
DACM(id, Cap, Cap_factor, Cap_factor_min, Opex_var, Opex_fixed, Input, Output, Data) =
    DACM(id, Cap, Cap_factor, Cap_factor_min, Opex_var, Opex_fixed, Input, Output, Data, nothing)

struct DACL <: DAC
    id
    Cap::TimeProfile
    Cap_factor::Real
    Cap_factor_min::Real
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Input::Dict{Resource, TimeProfile}
    Output::Dict{Resource, Real}
    Data::Array{Data}
    Emissions::Union{Nothing, Dict{ResourceEmit, Real}}
end
DACL(id, Cap, Cap_factor, Cap_factor_min, Opex_var, Opex_fixed, Input, Output, Data) =
    DACL(id, Cap, Cap_factor, Cap_factor_min, Opex_var, Opex_fixed, Input, Output, Data, nothing)

""" CO2 storage site as a subtype of RefStorageEmissions node """
struct CO2_storage <: EMB.Storage
    id
    Rate_cap::TimeProfile
    Stor_cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Stor_res::ResourceEmit
    Input::Dict{Resource, Real}
    Output::Dict{Resource, Real}
    Data::Array{Data}
    Emissions::Union{Nothing, Dict{ResourceEmit, Real}}
end
CO2_storage(id, Rate_cap, Stor_cap, Opex_var, Opex_fixed, Stor_res, Input, Output, Data) =
    CO2_storage(id, Rate_cap, Stor_cap, Opex_var, Opex_fixed, Stor_res, Input, Output, Data, nothing)

function area_sub(𝒜::Array{Area}, sub = RefArea)
    return 𝒜[findall(a -> isa(a, sub), 𝒜)]
end

function trans_mode_sub(ℳ::Array{TransmissionMode}, sub = RefDynamic)
    return ℳ[findall(tm -> isa(tm, sub), ℳ)]
end

struct Country <: EMG.Area
    id
    Name::String
    Lon::Real
    Lat::Real
    An::EMG.GeoAvailability
    CDR_target::Union{Nothing, TimeProfile}
end
Country(id, Name, Lon, Lat, An) =
    Country(id, Name, Lon, Lat, An, nothing)

""" Onshore storage sites as a subtype of Area """
struct Onshore <: EMG.Area
    id
    Name::String
    Country::String
    Lon::Real
    Lat::Real
    An::EMG.GeoAvailability
    Stor::EMB.Storage
end

""" Offshore storage sites as a subtype of Area """
struct Offshore <: EMG.Area
    id
    Name::String
    Country::String
    Lon::Real
    Lat::Real
    An::EMG.GeoAvailability
    Stor::EMB.Storage
end

""" Ports as a subtype of Area """
struct Port <: EMG.Area
    id
    Name::String
    Country::String
    Lon::Real
    Lat::Real
    An::EMG.GeoAvailability
end

function trans_mode_sub(ℳ::Array{TransmissionMode}, sub = PipeSimple)
    return ℳ[findall(tm -> isa(tm, sub), ℳ)]
end

""" CO2 shipping as a subtype of TransmissionMode  """
struct CO2_Ship <: EMG.TransmissionMode
    Name::String
    Resource::EMB.Resource
    Trans_cap::TimeProfile
    Trans_loss::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile 
    Directions::Int 
    Data::Array{Data}
end

""" CO2 pipeline transport as a subtype of TransmissionMode  """
struct CO2_Pipe <: EMG.TransmissionMode
    Name::String
    Resource::EMB.Resource
    Trans_cap::TimeProfile
    Trans_loss::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Directions::Int
    Data::Array{Data}
end