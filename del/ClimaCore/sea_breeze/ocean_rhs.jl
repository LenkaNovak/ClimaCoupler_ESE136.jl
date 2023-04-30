# # Ocean Model

#=
## Slab Ocean ODE
For our ocean component, we solve a simple slab ocean ODE just as we did for the land:

$$\rho_o c_o H_o \partial_t T_{ocn} = - F_{integ} / \Delta t_{coupler}$$
- where $\rho_o = 1025$ kg m $^{-3}$, $c_o=3850$ J K $^{-1}$ kg $^{-1}$, $H_o = 100$ m are the density, specific heat and depth of the ocean,
- and $F_{integ}$ is the integrated surface fluxes in time.
=#

# ## Model Code
function ocn_rhs!(du, u, (parameters, F_accumulated), t)
    """
    Slab layer equation
        d(T_sfc)/dt = - (F_accumulated) / (h_ocn * ρ_ocn * c_ocn)
        where 
            F_accumulated = F_integrated / Δt_coupler
    """
    @unpack ocn_h, ocn_ρ, ocn_c = parameters
    @unpack T_sfc = du

    @. T_sfc = (-F_accumulated) / (ocn_h * ocn_ρ * ocn_c)
end

## set up domain
function hspace_1D(xlim = (-π, π), npoly = 0, helem = 10)
    FT = Float64

    domain = Domains.IntervalDomain(Geometry.XPoint{FT}(xlim[1]) .. Geometry.XPoint{FT}(xlim[2]), periodic = true)
    mesh = Meshes.IntervalMesh(domain; nelems = helem)
    topology = Topologies.IntervalTopology(mesh)

    ## Finite Volume Approximation: Gauss-Lobatto with 1pt per element
    quad = Spaces.Quadratures.GL{npoly + 1}()
    space = Spaces.SpectralElementSpace1D(topology, quad)

    return space
end

## init simulation
function ocn_init(; xmin = -1000, xmax = 1000, helem = 20, npoly = 0)

    ## construct domain spaces - get only surface layer (NB: z should be zero, not z = first central height)
    space = hspace_1D((xmin, xmax), npoly, helem)
    coords = Fields.coordinate_field(space)
    domain = space

    ## initial condition
    T_sfc = map(coords) do coord
        T_sfc = 267.0
    end

    ## prognostic variable
    Y = Fields.FieldVector(T_sfc = T_sfc)

    return Y, domain
end

# ## Coupled Ocean Wrappers
## Ocean Simulation - Later to live in Oceananigans
struct OceanSimulation <: ClimaCoupler.AbstractOceanSimulation
    integrator::Any
end

function OceanSimulation(Y_init, t_start, dt, t_end, timestepper, p, saveat, callbacks = CallbackSet())
    ocn_prob = ODEProblem(ocn_rhs!, Y_init, (t_start, t_end), p)
    ocn_integ = init(ocn_prob, timestepper, dt = dt, saveat = saveat, callback = callbacks)
    return OceanSimulation(ocn_integ)
end

function ClimaCoupler.coupler_push!(coupler::ClimaCoupler.CouplerState, ocean::OceanSimulation)
    coupler_put!(coupler, :T_sfc_ocean, ocean.integrator.u.T_sfc, ocean)
end

function ClimaCoupler.coupler_pull!(ocean::OceanSimulation, coupler::ClimaCoupler.CouplerState)
    coupler_get!(ocean.integrator.p.F_sfc, coupler, :F_sfc, ocean)
    ocean.integrator.p.F_sfc ./= coupler.Δt_coupled
end
