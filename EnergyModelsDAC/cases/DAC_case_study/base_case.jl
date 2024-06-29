function run_base_case(
        input_nodes,
        input_transmission, 
        input_regions, 
        input_DAC, 
        input_storage,
        input_geo,
        input_nuclear;
        optimizer=Gurobi.Optimizer,
        directory="./EnergyModelsDAC/cases/DAC_case_study/results"
    )
    start= Dates.now()

    input           = YAML.load_file(input_nodes)
    input_trans     = YAML.load_file(input_transmission)
    input_regions   = YAML.load_file(input_regions)
    input_DAC       = YAML.load_file(input_DAC)
    input_storage   = YAML.load_file(input_storage)
    input_geo       = YAML.load_file(input_geo)
    input_nuclear   = YAML.load_file(input_nuclear)


    @info "Reading the input data:"
    @time case, modeltype = read_data(input, input_trans, input_regions, input_DAC, input_geo, input_nuclear, input_storage);

    @info "Building the model:"
    m = EMG.create_model(case, modeltype)

    @info "Optimizing the model:"
    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        set_attribute(m, "MIPFocus", 3)
        set_attribute(m, "MIPGAP", 0.01)
        set_attribute(m, "NumericFocus", 1)
        #set_attribute(m, "NodefileStart", 0.5)
        #set_attribute(m, "PreSparsify", 1)
        optimize!(m)
    else
        @warn "No optimizer given"  
    end

    # @info "Writing the model to external files:"
    # write_to_file(m, "base_case.lp")
    # write_to_file(m, "base_case.mps")

    dir_var = joinpath(directory, "csv_files")
    if !ispath(directory)
        mkpath(directory)
        mkdir(dir_var)
    end

    #cp(input, joinpath(directory, "input_nodes.yml"))
    #cp(input_regions, joinpath(directory, "input_regions.yml"))
    #cp(input_trans, joinpath(directory, "input_transmission.yml"))
    #cp(input_DAC, joinpath(directory, "input_DAC.yml"))
    #cp(input_storage, joinpath(directory, "input_storage.yml"))
    #cp(input_geo, joinpath(directory, "input_geo.yml"))
    
    @info "Saving the case and model:"
    save_case_modeltype(case, modeltype, directory=directory)

    @info "Saving the results:"
    save_results(m, directory=dir_var)

    endtime = Dates.now()-start
    println("Total time solving the system: $(round(endtime, Dates.Minute(1)))")

    return m, case, modeltype
end


