"""
    ClimaCoupler

Module for atmos-ocean-land coupled simulations.
"""
module ClimaCoupler

include("../test/TestHelper.jl")
include("Utilities.jl")
include("TimeManager.jl")
include("Regridder.jl")
include("ConservationChecker.jl")
include("BCReader.jl")
include("Diagnostics.jl")
include("PostProcessor.jl")

end
