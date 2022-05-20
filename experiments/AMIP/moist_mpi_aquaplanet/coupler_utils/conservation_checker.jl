# generalise this into coupler-specific function

abstract type AbstractCheck end

struct ConservationCheck{A} <: AbstractCheck
    ρe_tot_atmos::A
    ρe_tot_slab::A
end

function check_conservation_callback(cs, atmos_sim, slab_sim)

    atmos_sim.domain.center_space.vertical_topology.mesh.domain
    Δz_1 =
        parent(ClimaCore.Fields.coordinate_field(atmos_sim.domain.face_space).z)[2] -
        parent(ClimaCore.Fields.coordinate_field(atmos_sim.domain.face_space).z)[1]

    atmos_field = atmos_sim.integrator.u.c.ρe  # J 
    slab_field = get_slab_energy(slab_sim, slab_sim.integrator.u.T_sfc) ./ Δz_1  # J  [NB: sum of the boundary field inherits the depth from the first atmospheric layer, which ≂̸ slab depth]

    ρe_tot_atmos = sum(atmos_field)
    ρe_tot_slab = sum(slab_field)

    push!(cs.ρe_tot_atmos, ρe_tot_atmos)
    push!(cs.ρe_tot_slab, ρe_tot_slab)
end

get_slab_energy(slab_sim, T_sfc) = slab_sim.params.ρ .* slab_sim.params.c .* T_sfc .* slab_sim.params.h #[NB: upon initialisation FT(275) was subtracted from T_0]

using ClimaCorePlots
function plot(CS::ConservationCheck)
    diff_ρe_tot_atmos = CS.ρe_tot_atmos .- CS.ρe_tot_atmos[3]
    diff_ρe_tot_slab = (CS.ρe_tot_slab .- CS.ρe_tot_slab[3])
    Plots.plot(diff_ρe_tot_atmos, label = "atmos")
    Plots.plot!(diff_ρe_tot_slab, label = "slab")
    tot = diff_ρe_tot_atmos .+ diff_ρe_tot_slab
    Plots.plot!(tot .- tot[1], label = "tot")
end

function conservation_plot(atmos_sim, slab_sim, solu_atm, solu_slab, figname = "tst_c.png")

    atmos_e = [sum(u.c.ρe) for u in solu_atm] # J 

    z = parent(ClimaCore.Fields.coordinate_field(atmos_sim.domain.face_space).z)
    Δz_1 = z[2] - z[1]
    slab_e = [sum(get_slab_energy(slab_sim, u)) for u in solu_slab]  # J  [NB: sum of the boundary field inherits the depth from the first atmospheric layer, which ≂̸ slab depth]

    diff_ρe_tot_atmos = atmos_e .- atmos_e[3]
    diff_ρe_tot_slab = (slab_e .- slab_e[3])
    Plots.plot(diff_ρe_tot_atmos, label = "atmos")
    Plots.plot!(diff_ρe_tot_slab, label = "slab")
    tot = diff_ρe_tot_atmos .+ diff_ρe_tot_slab
    Plots.plot!(tot .- tot[1], label = "tot", xlabel = "time [s]", ylabel = "energy(t) - energy(t=0) [s]")
    Plots.savefig(figname)

end