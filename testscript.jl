# This script requires a current snapshot of the Clean Export packages to work
import Pkg;
Pkg.activate(@__DIR__)
Pkg.instantiate()

# Check that we can use and test one package:
using EnergyModelsRenewableProducers
Pkg.test("EnergyModelsRenewableProducers")