# Turbulent conjugate heat transfer regression test: a 2D plane channel
# between two solid slabs, k-epsilon with wall functions on both internal
# fluid/solid interfaces, Dirichlet-Neumann CHT, and k_eff = k + cp*mu_t/Pr_t.
# Plan: PLAN-turbulent-cht-test.md.
#
#     y ^   solid_top      (T = T_top on solid_top_outer)
#       |  ---------------  interface_top     (fluid below the solid)
#       |   fluid  ->
#       |  ---------------  interface_bottom  (fluid above the solid)
#       |   solid_bottom   (T = T_bot on solid_bottom_outer)
#       +-------------------> x
#
# The top half of the mesh is the bottom half mirrored about y = 0, so the
# two interfaces are geometrically identical apart from orientation.
# Element numbering is set by [renumber]:
#   fluid listed first -> fluid elements have the lower IDs -> fluid is the
#   FaceInfo ELEM side on both interfaces (the default here);
#   fluid listed last  -> fluid is the NEIGHBOR side on both interfaces.

# ---------------------------------------------------------------------------
# Flow: ERCOFTAC channel of the MOOSE linear-segregated k-epsilon tests
# (modules/navier_stokes/test/tests/finite_volume/ins/turbulence/channel/
# linear-segregated/header_and_mesh.i), Re = 13700 on 2H.
H = 1 # fluid half-height
L = 100 # channel length
b = 0.25 # solid slab thickness, 0.25 H

Re = 13700
rho = 1
bulk_u = 1
mu = '${fparse rho * bulk_u * 2 * H / Re}'

# k-epsilon closure (standard constants, as in the ERCOFTAC test)
sigma_k = 1.0
sigma_eps = 1.3
C1_eps = 1.44
C2_eps = 1.92
C_mu = 0.09

# inlet turbulence, as in the ERCOFTAC test
intensity = '${fparse 0.16*Re^(-1./8.)}'
k_init = '${fparse 1.5*(intensity * bulk_u)^2}'
eps_init = '${fparse C_mu^0.75 * k_init^1.5 / (2*H)}'

bulk_wall_treatment = false
walls = 'interface_bottom interface_top'
wall_treatment = 'eq_newton'

# ---------------------------------------------------------------------------
# Mesh. Re_tau ~ 0.09 Re^0.88 ~ 390, so u_tau ~ 390 nu/H and y+ ~ 390 y/H.
# Six uniform cells per half-channel put the wall-cell centroid at y = H/12,
# y+ ~ 33, inside the log layer the wall function assumes.
nx = 20
ny_f = 6 # fluid cells per half-channel
ny_s = 4 # cells across each solid slab
fluid_first_blocks = 'fluid solid_bottom solid_top'
fluid_is_elem = 1 # 0 when fluid_first_blocks lists the fluid last

# ---------------------------------------------------------------------------
# Energy. cp = 1 with rho = U = 1. Pr sets the fluid conductivity: the
# default is water-like (Pr = 1); Pr = 0.005 is sodium-like.
cp = 1
Pr = 1
k = '${fparse mu*cp/Pr}'
Pr_t = 0.9 # constant turbulent Prandtl number (plan D3 (a))
# Turbulent Prandtl number model of k_eff:
#   0 - constant Pr_t (above)
#   1 - Kays (1994), Pr_t = 0.85 + 0.7/Pe_t with Pe_t = (mu_t/mu)*Pr, for
#       liquid metals. Written as k_t = cp*mu_t*Pe_t/(0.85*Pe_t + 0.7),
#       which is finite as mu_t -> 0. Applies to k_eff only; k_eff_wf and
#       the thermal wall function keep the constant Pr_t.
Pr_t_kays = 0
# Fluid conductivity used by the energy equation and the CHT coupling:
#   k_eff    - k + cp*mu_t/Pr_t (Pr_t from Pr_t_kays) from a functor
#              material; on the interfaces
#              it uses the momentum wall-function mu_t (no thermal wall
#              function)
#   k_eff_wf - the same in the bulk, but on the interfaces the value comes
#              from the Jayatilleke thermal wall function
#              (LinearFVTemperatureWallFunctionBC)
k_eff_name = 'k_eff'
# Solid conductivity: of the same order as the near-wall fluid k_eff for
# water-like Pr, so that neither side of the interface controls the
# resistance by itself.
k_s = 1e-3

T_in = 300
T_bot = 350
T_top = 350 # symmetric case; T_top = 250 gives the asymmetric case

# CHT coupling: Dirichlet-Neumann. The fluid side is Dirichlet on the
# temperature passed from the solid, so the fluid flux is
# k_wall*(T_surface - T_cell)/d and k_eff (or the thermal wall-function
# k_eff_wf) sets the fluid near-wall resistance. The solid side receives the
# fluid heat flux through a Robin BC. Robin-Robin is not used: the fluid-side
# LinearFVRobinCHTBC takes the wall-cell value as the face value, so the
# fluid conductivity at the interface would not enter the converged flux.

# Robin coefficient of the solid-side BC. It affects only the convergence
# rate of the CHT fixed-point iteration, not the converged solution.
h_s = 1.0

advected_interp_method = 'upwind'

[Mesh]
  # bottom half: fluid on [-H, 0] and solid_bottom on [-H-b, -H]
  [fluid_b]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0
    xmax = ${L}
    ymin = '${fparse -H}'
    ymax = 0
    nx = ${nx}
    ny = ${ny_f}
    subdomain_ids = 0
    subdomain_name = 'fluid'
    boundary_name_prefix = 'fb'
  []
  [solid_b]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0
    xmax = ${L}
    ymin = '${fparse -H-b}'
    ymax = '${fparse -H}'
    nx = ${nx}
    ny = ${ny_s}
    subdomain_ids = 1
    subdomain_name = 'solid_bottom'
    boundary_name_prefix = 'sb'
    boundary_id_offset = 10
  []
  [half_b]
    type = StitchMeshGenerator
    inputs = 'fluid_b solid_b'
    stitch_boundaries_pairs = 'fb_bottom sb_top'
    clear_stitched_boundary_ids = true
  []

  # top half: built as a second copy of the bottom half and mirrored
  [fluid_t]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0
    xmax = ${L}
    ymin = '${fparse -H}'
    ymax = 0
    nx = ${nx}
    ny = ${ny_f}
    subdomain_ids = 0
    subdomain_name = 'fluid'
    boundary_name_prefix = 'ft'
    boundary_id_offset = 20
  []
  [solid_t]
    type = GeneratedMeshGenerator
    dim = 2
    xmin = 0
    xmax = ${L}
    ymin = '${fparse -H-b}'
    ymax = '${fparse -H}'
    nx = ${nx}
    ny = ${ny_s}
    subdomain_ids = 2
    subdomain_name = 'solid_top'
    boundary_name_prefix = 'st'
    boundary_id_offset = 30
  []
  [half_t]
    type = StitchMeshGenerator
    inputs = 'fluid_t solid_t'
    stitch_boundaries_pairs = 'ft_bottom st_top'
    clear_stitched_boundary_ids = true
  []
  [mirror_t]
    type = SymmetryTransformGenerator
    input = half_t
    mirror_point = '0 0 0'
    mirror_normal_vector = '0 1 0'
  []

  [channel]
    type = StitchMeshGenerator
    inputs = 'half_b mirror_t'
    stitch_boundaries_pairs = 'fb_top ft_top'
    clear_stitched_boundary_ids = true
  []

  # boundaries used by the physics, built from the blocks so that the
  # generated names above do not matter
  [interface_bottom]
    type = SideSetsBetweenSubdomainsGenerator
    input = channel
    primary_block = 'fluid'
    paired_block = 'solid_bottom'
    new_boundary = 'interface_bottom'
  []
  [interface_top]
    type = SideSetsBetweenSubdomainsGenerator
    input = interface_bottom
    primary_block = 'fluid'
    paired_block = 'solid_top'
    new_boundary = 'interface_top'
  []
  [inlet]
    type = SideSetsAroundSubdomainGenerator
    input = interface_top
    block = 'fluid'
    normal = '-1 0 0'
    new_boundary = 'inlet'
  []
  [outlet]
    type = SideSetsAroundSubdomainGenerator
    input = inlet
    block = 'fluid'
    normal = '1 0 0'
    new_boundary = 'outlet'
  []
  [solid_bottom_outer]
    type = SideSetsAroundSubdomainGenerator
    input = outlet
    block = 'solid_bottom'
    normal = '0 -1 0'
    new_boundary = 'solid_bottom_outer'
  []
  [solid_top_outer]
    type = SideSetsAroundSubdomainGenerator
    input = solid_bottom_outer
    block = 'solid_top'
    normal = '0 1 0'
    new_boundary = 'solid_top_outer'
  []
  [solid_ends_left]
    type = SideSetsAroundSubdomainGenerator
    input = solid_top_outer
    block = 'solid_bottom solid_top'
    normal = '-1 0 0'
    new_boundary = 'solid_ends'
  []
  [solid_ends_right]
    type = SideSetsAroundSubdomainGenerator
    input = solid_ends_left
    block = 'solid_bottom solid_top'
    normal = '1 0 0'
    new_boundary = 'solid_ends'
  []

  # drop the generator sidesets, which overlap the ones built above
  [keep_named]
    type = BoundaryDeletionGenerator
    input = solid_ends_right
    operation = keep
    boundary_names = 'interface_bottom interface_top inlet outlet solid_bottom_outer '
                     'solid_top_outer solid_ends'
  []

  # element numbering decides which side of each interface face is the
  # FaceInfo ELEM: the block listed first gets the lowest IDs
  [renumber]
    type = RenumberBySubdomainGenerator
    input = keep_named
    blocks_to_renumber = ${fluid_first_blocks}
  []

  # keep the ordering above through the solve
  allow_renumbering = false
[]

[Problem]
  linear_sys_names = 'u_system v_system pressure_system TKE_system TKED_system energy_system '
                     'solid_energy_system'
  previous_nl_solution_required = true
  # the functor materials (mu_eff, k_eff, rhocpT) exist only in the fluid;
  # the solid conductivity is a constant passed directly to its kernel
  material_coverage_check = false
[]

[GlobalParams]
  rhie_chow_user_object = 'rc'
[]

[UserObjects]
  [rc]
    type = RhieChowMassFlux
    u = vel_x
    v = vel_y
    pressure = pressure
    rho = ${rho}
    p_diffusion_kernel = p_diffusion
    block = 'fluid'
  []
[]

[Variables]
  [vel_x]
    type = MooseLinearVariableFVReal
    initial_condition = ${bulk_u}
    solver_sys = u_system
    block = 'fluid'
  []
  [vel_y]
    type = MooseLinearVariableFVReal
    initial_condition = 0
    solver_sys = v_system
    block = 'fluid'
  []
  [pressure]
    type = MooseLinearVariableFVReal
    initial_condition = 1e-8
    solver_sys = pressure_system
    block = 'fluid'
  []
  [TKE]
    type = MooseLinearVariableFVReal
    solver_sys = TKE_system
    initial_condition = ${k_init}
    block = 'fluid'
  []
  [TKED]
    type = MooseLinearVariableFVReal
    solver_sys = TKED_system
    initial_condition = ${eps_init}
    block = 'fluid'
  []
  [T_fluid]
    type = MooseLinearVariableFVReal
    solver_sys = energy_system
    initial_condition = ${T_in}
    block = 'fluid'
  []
  [T_solid]
    type = MooseLinearVariableFVReal
    solver_sys = solid_energy_system
    initial_condition = ${T_in}
    block = 'solid_bottom solid_top'
  []
[]

[FVInterpolationMethods]
  [upwind]
    type = FVAdvectedUpwind
  []
[]

[LinearFVKernels]
  [u_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_x
    advected_interp_method_name = ${advected_interp_method}
    mu = 'mu_eff'
    u = vel_x
    v = vel_y
    momentum_component = 'x'
    use_nonorthogonal_correction = false
    use_deviatoric_terms = yes
  []
  [u_pressure]
    type = LinearFVMomentumPressure
    variable = vel_x
    pressure = pressure
    momentum_component = 'x'
  []
  [v_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_y
    advected_interp_method_name = ${advected_interp_method}
    mu = 'mu_eff'
    u = vel_x
    v = vel_y
    momentum_component = 'y'
    use_nonorthogonal_correction = false
    use_deviatoric_terms = yes
  []
  [v_pressure]
    type = LinearFVMomentumPressure
    variable = vel_y
    pressure = pressure
    momentum_component = 'y'
  []

  [p_diffusion]
    type = LinearFVPressureCorrectionDiffusion
    variable = pressure
    diffusion_tensor = Ainv
    use_nonorthogonal_correction = false
  []
  [HbyA_divergence]
    type = LinearFVDivergence
    variable = pressure
    face_flux = HbyA
    force_boundary_execution = true
  []

  [TKE_advection]
    type = LinearFVTurbulentAdvection
    variable = TKE
    advected_interp_method_name = ${advected_interp_method}
  []
  [TKE_diffusion]
    type = LinearFVTurbulentDiffusion
    variable = TKE
    diffusion_coeff = ${mu}
    use_nonorthogonal_correction = false
  []
  [TKE_turb_diffusion]
    type = LinearFVTurbulentDiffusion
    variable = TKE
    diffusion_coeff = 'mu_t'
    scaling_coeff = ${sigma_k}
    use_nonorthogonal_correction = false
  []
  [TKE_source_sink]
    type = LinearFVTKESourceSink
    variable = TKE
    u = vel_x
    v = vel_y
    epsilon = TKED
    rho = ${rho}
    mu = ${mu}
    mu_t = 'mu_t'
    walls = ${walls}
    wall_treatment = ${wall_treatment}
    C_pl = 1e10
  []

  [TKED_advection]
    type = LinearFVTurbulentAdvection
    variable = TKED
    advected_interp_method_name = ${advected_interp_method}
    walls = ${walls}
  []
  [TKED_diffusion]
    type = LinearFVTurbulentDiffusion
    variable = TKED
    diffusion_coeff = ${mu}
    use_nonorthogonal_correction = false
    walls = ${walls}
  []
  [TKED_turb_diffusion]
    type = LinearFVTurbulentDiffusion
    variable = TKED
    diffusion_coeff = 'mu_t'
    scaling_coeff = ${sigma_eps}
    use_nonorthogonal_correction = false
    walls = ${walls}
  []
  [TKED_source_sink]
    type = LinearFVTKEDSourceSink
    variable = TKED
    u = vel_x
    v = vel_y
    tke = TKE
    rho = ${rho}
    mu = ${mu}
    mu_t = 'mu_t'
    C1_eps = ${C1_eps}
    C2_eps = ${C2_eps}
    walls = ${walls}
    wall_treatment = ${wall_treatment}
    C_pl = 1e10
  []

  [fluid_advection]
    type = LinearFVEnergyAdvection
    variable = T_fluid
    advected_quantity = temperature
    cp = ${cp}
    advected_interp_method = ${advected_interp_method}
  []
  # CHTHandler requires exactly one LinearFVDiffusion per side, so molecular
  # and turbulent conduction go through one kernel with k_eff
  [fluid_conduction]
    type = LinearFVDiffusion
    variable = T_fluid
    diffusion_coeff = ${k_eff_name}
    use_nonorthogonal_correction = false
  []
  [solid_conduction]
    type = LinearFVDiffusion
    variable = T_solid
    diffusion_coeff = ${k_s}
    use_nonorthogonal_correction = false
  []
[]

[LinearFVBCs]
  [inlet_u]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'inlet'
    variable = vel_x
    functor = ${bulk_u}
  []
  [inlet_v]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'inlet'
    variable = vel_y
    functor = 0
  []
  [walls_u]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = ${walls}
    variable = vel_x
    functor = 0
  []
  [walls_v]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = ${walls}
    variable = vel_y
    functor = 0
  []
  [outlet_u]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'outlet'
    variable = vel_x
    use_two_term_expansion = false
  []
  [outlet_v]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'outlet'
    variable = vel_y
    use_two_term_expansion = false
  []
  [outlet_p]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'outlet'
    variable = pressure
    functor = 0
  []

  [inlet_TKE]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'inlet'
    variable = TKE
    functor = ${k_init}
  []
  [outlet_TKE]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'outlet'
    variable = TKE
    use_two_term_expansion = false
  []
  [inlet_TKED]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'inlet'
    variable = TKED
    functor = ${eps_init}
  []
  [outlet_TKED]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'outlet'
    variable = TKED
    use_two_term_expansion = false
  []
  [walls_mu_t]
    type = LinearFVTurbulentViscosityWallFunctionBC
    boundary = ${walls}
    variable = 'mu_t'
    u = vel_x
    v = vel_y
    rho = ${rho}
    mu = ${mu}
    tke = TKE
    wall_treatment = ${wall_treatment}
  []

  # face values of k_eff_wf on the interfaces from the thermal wall
  # function; unused unless k_eff_name = k_eff_wf
  [walls_k_eff_wf]
    type = LinearFVTemperatureWallFunctionBC
    boundary = ${walls}
    variable = 'k_eff_wf'
    u = vel_x
    v = vel_y
    rho = ${rho}
    mu = ${mu}
    cp = ${cp}
    k = ${k}
    Pr_t = ${Pr_t}
    tke = TKE
    wall_treatment = ${wall_treatment}
  []

  [inlet_T]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'inlet'
    variable = T_fluid
    functor = ${T_in}
  []
  [outlet_T]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'outlet'
    variable = T_fluid
    use_two_term_expansion = false
  []
  [solid_bottom_T]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'solid_bottom_outer'
    variable = T_solid
    functor = ${T_bot}
  []
  [solid_top_T]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'solid_top_outer'
    variable = T_solid
    functor = ${T_top}
  []
  [solid_ends_insulated]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    boundary = 'solid_ends'
    variable = T_solid
    functor = 0
  []

  [fluid_solid_bottom]
    type = LinearFVDirichletCHTBC
    variable = T_fluid
    boundary = interface_bottom
    functor = interface_temperature_to_fluid_interface_bottom
  []
  [solid_fluid_bottom]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = interface_bottom
    h = ${h_s}
    incoming_flux = heat_flux_to_solid_interface_bottom
    surface_temperature = interface_temperature_to_solid_interface_bottom
    thermal_conductivity = ${k_s}
  []
  [fluid_solid_top]
    type = LinearFVDirichletCHTBC
    variable = T_fluid
    boundary = interface_top
    functor = interface_temperature_to_fluid_interface_top
  []
  [solid_fluid_top]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = interface_top
    h = ${h_s}
    incoming_flux = heat_flux_to_solid_interface_top
    surface_temperature = interface_temperature_to_solid_interface_top
    thermal_conductivity = ${k_s}
  []
[]

[AuxVariables]
  [mu_t]
    type = MooseLinearVariableFVReal
    initial_condition = '${fparse rho * C_mu * k_init^2 / eps_init}'
    block = 'fluid'
  []
  [yplus]
    type = MooseLinearVariableFVReal
    block = 'fluid'
  []
  [k_eff_wf]
    type = MooseLinearVariableFVReal
    initial_condition = ${k}
    block = 'fluid'
  []
  # element IDs, for the interface-ownership check (ownership_ok)
  [elem_id]
    type = MooseLinearVariableFVReal
  []
[]

[AuxKernels]
  [compute_mu_t]
    type = kEpsilonViscosityAux
    variable = mu_t
    C_mu = ${C_mu}
    tke = TKE
    epsilon = TKED
    mu = ${mu}
    rho = ${rho}
    u = vel_x
    v = vel_y
    bulk_wall_treatment = ${bulk_wall_treatment}
    walls = ${walls}
    wall_treatment = ${wall_treatment}
    execute_on = 'NONLINEAR'
    mu_t_ratio_max = 1e20
  []
  [compute_yplus]
    type = RANSYPlusAux
    variable = yplus
    tke = TKE
    mu = ${mu}
    rho = ${rho}
    u = vel_x
    v = vel_y
    walls = ${walls}
    wall_treatment = ${wall_treatment}
    execute_on = 'NONLINEAR'
  []
  [compute_k_eff_wf]
    type = EffectiveTurbulentThermalConductivityAux
    variable = k_eff_wf
    cp = ${cp}
    k = ${k}
    mu_t = 'mu_t'
    Pr_t = ${Pr_t}
    execute_on = 'INITIAL NONLINEAR'
  []
  [compute_elem_id]
    type = ElementIDAux
    variable = elem_id
    execute_on = 'INITIAL'
  []
[]

[FunctorMaterials]
  [mu_eff]
    type = FunctorEffectiveDynamicViscosity
    property_name = mu_eff
    mu = ${mu}
    mu_t = mu_t
    mu_t_inverse_factor = 1
    block = 'fluid'
    execute_on = 'ALWAYS'
  []
  [k_eff]
    type = ParsedFunctorMaterial
    property_name = 'k_eff'
    functor_names = 'mu_t'
    # Kays: Pe_t = mu_t*Pr/mu, k_t = cp*mu_t*Pe_t/(0.85*Pe_t + 0.7)
    expression = '${k} + if(${Pr_t_kays} > 0, '
                 '${cp} * mu_t * (mu_t * ${Pr} / ${mu}) / (0.85 * mu_t * ${Pr} / ${mu} + 0.7), '
                 '${cp} * mu_t / ${Pr_t})'
    block = 'fluid'
  []
  [rhocpT]
    type = ParsedFunctorMaterial
    property_name = 'rhocpT'
    functor_names = 'T_fluid'
    expression = '${rho} * ${cp} * T_fluid'
    block = 'fluid'
  []
[]

[Executioner]
  type = SIMPLE

  momentum_systems = 'u_system v_system'
  pressure_system = 'pressure_system'
  turbulence_systems = 'TKE_system TKED_system'
  energy_system = 'energy_system'
  solid_energy_system = 'solid_energy_system'

  momentum_l_abs_tol = 1e-14
  pressure_l_abs_tol = 1e-14
  turbulence_l_abs_tol = 1e-14
  energy_l_abs_tol = 1e-14
  solid_energy_l_abs_tol = 1e-14
  momentum_l_tol = 1e-14
  pressure_l_tol = 1e-14
  turbulence_l_tol = 1e-14
  energy_l_tol = 1e-14
  solid_energy_l_tol = 1e-14

  # relaxation as in the ERCOFTAC channel test
  momentum_equation_relaxation = 0.7
  pressure_variable_relaxation = 0.3
  turbulence_equation_relaxation = '0.2 0.2'
  turbulence_field_relaxation = '0.2 0.2'
  energy_equation_relaxation = 1.0

  # Dirichlet-Neumann CHT converges slower than the flow alone: 1500-1700
  # iterations for the turbulent cases and about 2300 for the laminar limit
  num_iterations = 3000
  momentum_absolute_tolerance = 1e-10
  pressure_absolute_tolerance = 1e-10
  turbulence_absolute_tolerance = '1e-10 1e-10'
  energy_absolute_tolerance = 1e-10
  solid_energy_absolute_tolerance = 1e-10

  momentum_petsc_options_iname = '-pc_type -pc_hypre_type'
  momentum_petsc_options_value = 'hypre boomeramg'
  pressure_petsc_options_iname = '-pc_type -pc_hypre_type'
  pressure_petsc_options_value = 'hypre boomeramg'
  turbulence_petsc_options_iname = '-pc_type -pc_hypre_type'
  turbulence_petsc_options_value = 'hypre boomeramg'
  energy_petsc_options_iname = '-pc_type -pc_hypre_type'
  energy_petsc_options_value = 'hypre boomeramg'
  solid_energy_petsc_options_iname = '-pc_type -pc_hypre_type'
  solid_energy_petsc_options_value = 'hypre boomeramg'

  cht_interfaces = 'interface_bottom interface_top'
  cht_solid_flux_relaxation = '1.0 1.0'
  cht_fluid_flux_relaxation = '1.0 1.0'
  cht_solid_temperature_relaxation = '1.0 1.0'
  cht_fluid_temperature_relaxation = '1.0 1.0'
  max_cht_fpi = 2

  print_fields = false
  continue_on_max_its = false
[]

[Postprocessors]
  # wall-function values on the interfaces (C1, C4)
  [mu_t_bottom]
    type = SideAverageFunctorPostprocessor
    functor = mu_t
    boundary = interface_bottom
  []
  [mu_t_top]
    type = SideAverageFunctorPostprocessor
    functor = mu_t
    boundary = interface_top
  []
  [k_eff_bottom]
    type = SideAverageFunctorPostprocessor
    functor = ${k_eff_name}
    boundary = interface_bottom
  []
  [k_eff_top]
    type = SideAverageFunctorPostprocessor
    functor = ${k_eff_name}
    boundary = interface_top
  []
  [T_fluid_bottom]
    type = SideAverageFunctorPostprocessor
    functor = T_fluid
    boundary = interface_bottom
  []
  [T_fluid_top]
    type = SideAverageFunctorPostprocessor
    functor = T_fluid
    boundary = interface_top
  []
  # the interface sidesets sit on the fluid elements, so the solid-side
  # surface temperature comes from the CHT coupling field the fluid receives
  [T_solid_bottom]
    type = SideAverageFunctorPostprocessor
    functor = interface_temperature_to_fluid_interface_bottom
    boundary = interface_bottom
  []
  [T_solid_top]
    type = SideAverageFunctorPostprocessor
    functor = interface_temperature_to_fluid_interface_top
    boundary = interface_top
  []

  # interface heat rates per unit depth (C3, C5)
  [Q_bottom_to_fluid]
    type = SideIntegralFunctorPostprocessor
    functor = heat_flux_to_fluid_interface_bottom
    boundary = interface_bottom
  []
  [Q_bottom_to_solid]
    type = SideIntegralFunctorPostprocessor
    functor = heat_flux_to_solid_interface_bottom
    boundary = interface_bottom
  []
  [Q_top_to_fluid]
    type = SideIntegralFunctorPostprocessor
    functor = heat_flux_to_fluid_interface_top
    boundary = interface_top
  []
  [Q_top_to_solid]
    type = SideIntegralFunctorPostprocessor
    functor = heat_flux_to_solid_interface_top
    boundary = interface_top
  []

  # fluid energy balance (C6): advected enthalpy through inlet and outlet
  # (outward-positive) plus conduction through them
  [H_in]
    type = VolumetricFlowRate
    boundary = 'inlet'
    vel_x = vel_x
    vel_y = vel_y
    advected_quantity = 'rhocpT'
    advected_interp_method = upwind
    subtract_mesh_velocity = false
  []
  [H_out]
    type = VolumetricFlowRate
    boundary = 'outlet'
    vel_x = vel_x
    vel_y = vel_y
    advected_quantity = 'rhocpT'
    advected_interp_method = upwind
    subtract_mesh_velocity = false
  []
  [cond_in]
    type = BoundaryLinearFVFluxIntegral
    boundary = 'inlet'
    linearfvkernels = 'fluid_conduction'
  []
  [cond_out]
    type = BoundaryLinearFVFluxIntegral
    boundary = 'outlet'
    linearfvkernels = 'fluid_conduction'
  []
  # solid outer-face heat, outward-positive (C6)
  [Q_solid_bottom_outer]
    type = BoundaryLinearFVFluxIntegral
    boundary = 'solid_bottom_outer'
    linearfvkernels = 'solid_conduction'
  []
  [Q_solid_top_outer]
    type = BoundaryLinearFVFluxIntegral
    boundary = 'solid_top_outer'
    linearfvkernels = 'solid_conduction'
  []
[]

# Which side owns the interface faces. FaceInfo puts the lower element ID on
# the ELEM side, and [renumber] makes every fluid ID lower (or higher) than
# every solid ID. fluid_is_elem = 1 if fluid is ELEM on every interface face,
# 0 if it is NEIGHBOR on every face, -1 otherwise. ownership_ok compares it
# with the intended ordering, so both orderings can share one gold file.
[Postprocessors]
  [fluid_id_min]
    type = ElementExtremeFunctorValue
    functor = elem_id
    value_type = min
    block = 'fluid'
    execute_on = 'INITIAL TIMESTEP_END'
    outputs = 'none' # differ between orderings by design
  []
  [fluid_id_max]
    type = ElementExtremeFunctorValue
    functor = elem_id
    value_type = max
    block = 'fluid'
    execute_on = 'INITIAL TIMESTEP_END'
    outputs = 'none' # differ between orderings by design
  []
  [solid_id_min]
    type = ElementExtremeFunctorValue
    functor = elem_id
    value_type = min
    block = 'solid_bottom solid_top'
    execute_on = 'INITIAL TIMESTEP_END'
    outputs = 'none' # differ between orderings by design
  []
  [solid_id_max]
    type = ElementExtremeFunctorValue
    functor = elem_id
    value_type = max
    block = 'solid_bottom solid_top'
    execute_on = 'INITIAL TIMESTEP_END'
    outputs = 'none' # differ between orderings by design
  []
  [ownership_ok]
    type = ParsedPostprocessor
    pp_names = 'fluid_id_min fluid_id_max solid_id_min solid_id_max'
    expression = 'if(fluid_id_max < solid_id_min, 1, if(fluid_id_min > solid_id_max, 0, -1)) = ${fluid_is_elem}'
    execute_on = 'INITIAL TIMESTEP_END'
    outputs = 'csv'
  []
[]

[VectorPostprocessors]
  # profiles across the full fluid height, mirrored about y = 0 (C1, C2, C4).
  # 2*ny_f points, one per cell centroid row.
  [fluid_profile]
    type = LineValueSampler
    variable = 'vel_x TKE TKED mu_t yplus T_fluid'
    start_point = '${fparse 0.8*L} ${fparse -H + H/ny_f/2} 0'
    end_point = '${fparse 0.8*L} ${fparse H - H/ny_f/2} 0'
    num_points = '${fparse 2*ny_f}'
    sort_by = y
    warn_discontinuous_face_values = false
  []
  [solid_bottom_profile]
    type = LineValueSampler
    variable = 'T_solid'
    start_point = '${fparse 0.8*L} ${fparse -H-b + b/ny_s/2} 0'
    end_point = '${fparse 0.8*L} ${fparse -H - b/ny_s/2} 0'
    num_points = ${ny_s}
    sort_by = y
    warn_discontinuous_face_values = false
  []
  [solid_top_profile]
    type = LineValueSampler
    variable = 'T_solid'
    start_point = '${fparse 0.8*L} ${fparse H + b/ny_s/2} 0'
    end_point = '${fparse 0.8*L} ${fparse H+b - b/ny_s/2} 0'
    num_points = ${ny_s}
    sort_by = y
    warn_discontinuous_face_values = false
  []
  # wall-adjacent fluid cell rows, for the independent log-law check of the
  # interface mu_t (C4)
  [wall_row_bottom]
    type = LineValueSampler
    variable = 'vel_x vel_y'
    start_point = '${fparse L/nx/2} ${fparse -H + H/ny_f/2} 0'
    end_point = '${fparse L - L/nx/2} ${fparse -H + H/ny_f/2} 0'
    num_points = ${nx}
    sort_by = x
    warn_discontinuous_face_values = false
  []
  [wall_row_top]
    type = LineValueSampler
    variable = 'vel_x vel_y'
    start_point = '${fparse L/nx/2} ${fparse H - H/ny_f/2} 0'
    end_point = '${fparse L - L/nx/2} ${fparse H - H/ny_f/2} 0'
    num_points = ${nx}
    sort_by = x
    warn_discontinuous_face_values = false
  []
[]

[Outputs]
  csv = true
  exodus = true
  execute_on = 'timestep_end'
[]
