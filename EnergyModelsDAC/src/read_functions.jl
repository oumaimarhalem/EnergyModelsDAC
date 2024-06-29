"""
    read_two_indeces(m, var::String, p::Resource, data)

Return the values from either the JuMP model or a CSV file for a variable `var` that is 
indexed over two indeces.
"""
function read_two_indeces(m::Model, var::String, p::Resource, data)
    return Array(value.(m[Symbol(var)][:, p]))
end
function read_two_indeces(m::String, var::String, p::Resource, data)
    sub_data = subset(data, :x2 => x2 -> x2 .== repr(p))
    return sub_data[!, :y]
end

"""
    read_two_indeces(m, type, var::String, data)

Return the values from either the JuMP model or a CSV file for a variable `var` that is 
indexed over two indeces.
"""
function read_two_indeces(m::Model, type, var::String, data)
    return Array(value.(m[Symbol(var)][type, :]))
end
function read_two_indeces(m::String, type, var::String, data)
    sub_data = subset(data, :x1 => x1 -> x1 .== repr(type))
    return sub_data[!, :y]
end

"""
    read_two_indeces(m, type, var::String, tp, data)

Return the value from either the JuMP model or a CSV file for a variable `var` that is 
indexed over two indeces. If a `TimePeriod` `tp is specified, it returns a single value.
"""
function read_two_indeces(m::Model, type, var::String, tp, data)
    return value.(m[Symbol(var)][type, tp])
end
function read_two_indeces(m::String, type, var::String, tp::TS.OperationalPeriod, data)
    sub_data = subset(data, :x1 => x1 -> x1 .== repr(type), :x2 => x2 -> x2 .== "t$(tp.sp)_$(tp.op)")
    return sub_data[!, :y]
end
function read_two_indeces(m::String, type, var::String, tp::TS.StrategicPeriod, data)
    sub_data = subset(data, :x1 => x1 -> x1 .== repr(type), :x2 => x2 -> x2 .== "sp$(tp.sp)")
    return sub_data[!, :y]
end

"""
    read_three_indeces(m, type, var::String)

Return the value from either the JuMP model or a CSV file for a variable `var` that is 
indexed over three indeces.
"""
function read_three_indeces(m::Model, type, var::String, p, data)
    if isa(m[Symbol(var)], JuMP.Containers.SparseAxisArray)
        return collect(values(sort(value.(m[Symbol(var)][type, :, p]).data)))
    else
        return Array(value.(m[Symbol(var)][type, :, p]))
    end
end
function read_three_indeces(m::String, type, var::String, p, data)
    sub_data = subset(data, :x1 => x1 -> x1 .== repr(type), :x3 => x3 -> x3 .== repr(p))
    sort!(sub_data, [order(:x2, by=order_time_periods)])
    return sub_data[!, :y]
end

"""
    read_data(m, string::String)

Initialize the load of the CSV to avoid repetetive reads
"""
function read_base_data(m::Model, var::String)
    return nothing
end
function read_base_data(m::String, var::String)
    return CSV.read(joinpath(m, var*".csv"), DataFrame)
end
function read_data(m::Model, var::String)
    return nothing
end
function read_data(m::String, var::String)
    return CSV.read(joinpath(m, var*".csv"), DataFrame)
end
