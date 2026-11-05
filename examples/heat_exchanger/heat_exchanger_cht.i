##########################################################
# 7-tube hexagonal-lattice shell-and-tube heat exchanger
# Conjugate heat transfer (CHT), laminar, counter-current
#
# Geometry: 7 tubes (1 center + 6 in a hexagonal ring)
# inside a cylindrical shell barrel. Tube bore (tube-side
# fluid), tube wall (solid), and the region surrounding
# the tubes inside the shell (shell-side fluid) are all
# resolved with CFD.
#
# A single shared velocity/pressure field is solved over
# both fluid regions (tube-side + shell-side); separate
# temperature fields are solved for the fluid and the
# solid, coupled through a Robin-type CHT boundary
# condition at each fluid/solid interface.
#
# Tube-side fluid flows in +z; shell-side fluid flows in
# -z (counter-current).
##########################################################

tube_ir = 0.008   # tube inner radius (bore)
tube_or = 0.010   # tube outer radius (wall)
pitch   = 0.025   # hex lattice pitch (center-to-center tube spacing)
shell_radius = 0.045 # shell barrel inner radius
length = 0.5 # heat exchanger axial length
n_layers = 30 # number of axial elements

# fluid properties (water-like, both sides share the same fluid here)
rho = 998.0
mu = 1.0e-3
k = 0.6
cp = 4180.0

# solid (tube wall) properties (steel-like)
k_s = 16.0

# operating conditions
tube_vel = 0.05    # tube-side inlet velocity (m/s), +z
shell_vel = 0.02   # shell-side inlet velocity (m/s), -z
tube_Tin = 350.0   # tube-side inlet temperature (K), hot fluid
shell_Tin = 300.0  # shell-side inlet temperature (K), cold fluid
P_out = 1.0e5

h_f = 50.0 # virtual CHT relaxation coefficient (fluid side)
h_s = 50.0 # virtual CHT relaxation coefficient (solid side)

advected_interp_method = 'upwind'

[Mesh]
  [pin]
    type = PolygonConcentricCircleMeshGenerator
    num_sides = 6
    num_sectors_per_side = '6 6 6 6 6 6'
    background_intervals = 3
    ring_radii = '${tube_ir} ${tube_or}'
    ring_intervals = '2 3'
    # Graded boundary layer on the tube-bore (tube-side fluid) side of the
    # tube_interface wall, finest right at the wall (bias < 1).
    ring_outer_boundary_layer_widths = '0.0016 0'
    ring_outer_boundary_layer_intervals = '3 0'
    ring_outer_boundary_layer_biases = '0.5 1'
    ring_block_ids = '1 2'
    ring_block_names = 'tube_fluid tube_wall'
    background_block_ids = 3
    background_block_names = shell_fluid
    # Graded boundary layer on the shell-side fluid (background) side of the
    # shell_interface wall, finest right at the wall (bias > 1).
    background_inner_boundary_layer_width = 0.0007
    background_inner_boundary_layer_intervals = 3
    background_inner_boundary_layer_bias = 2.0
    polygon_size = '${fparse pitch/2}'
    polygon_size_style = apothem
    quad_center_elements = true
    preserve_volumes = true
    create_outward_interface_boundaries = false
  []
  [lattice]
    type = PatternedHexMeshGenerator
    inputs = 'pin'
    pattern = '0 0;
              0 0 0;
               0 0'
    pattern_boundary = none
  []
  [shell]
    type = PeripheralRingMeshGenerator
    input = lattice
    input_mesh_external_boundary = 10000
    peripheral_layer_num = 5
    peripheral_ring_radius = ${shell_radius}
    peripheral_ring_block_id = 3
    peripheral_ring_block_name = shell_fluid
    # Graded boundary layer on the shell-side fluid at the outer shell wall,
    # finest right at the wall (bias < 1, since the layer is built outward).
    peripheral_outer_boundary_layer_width = 0.0007
    peripheral_outer_boundary_layer_intervals = 3
    peripheral_outer_boundary_layer_bias = 0.5
    external_boundary_id = 20000
    external_boundary_name = shell_wall
  []
  [remove_stale_boundary]
    # PeripheralRingMeshGenerator leaves the old "10000" id on the
    # same faces as the new "shell_wall" id; strip it so each face
    # carries only one boundary.
    type = BoundaryDeletionGenerator
    input = shell
    boundary_names = '10000'
  []
  [tube_interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = remove_stale_boundary
    primary_block = tube_fluid
    paired_block = tube_wall
    new_boundary = tube_interface
  []
  [shell_interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = tube_interface
    primary_block = shell_fluid
    paired_block = tube_wall
    new_boundary = shell_interface
  []
  [extrude]
    type = AdvancedExtruderGenerator
    input = shell_interface
    direction = '0 0 1'
    heights = '${length}'
    num_layers = '${n_layers}'
    bottom_boundary = 'bottom_cap'
    top_boundary = 'top_cap'
  []

  # split the extruded top/bottom caps per block so tube-side and
  # shell-side flow can enter/exit at opposite ends (counter-current)
  [tube_inlet]
    type = SideSetsAroundSubdomainGenerator
    input = extrude
    block = tube_fluid
    normal = '0 0 -1'
    new_boundary = tube_inlet
    replace = true
  []
  [tube_outlet]
    type = SideSetsAroundSubdomainGenerator
    input = tube_inlet
    block = tube_fluid
    normal = '0 0 1'
    new_boundary = tube_outlet
    replace = true
  []
  [shell_inlet]
    type = SideSetsAroundSubdomainGenerator
    input = tube_outlet
    block = shell_fluid
    normal = '0 0 1'
    new_boundary = shell_inlet
    replace = true
  []
  [shell_outlet]
    type = SideSetsAroundSubdomainGenerator
    input = shell_inlet
    block = shell_fluid
    normal = '0 0 -1'
    new_boundary = shell_outlet
    replace = true
  []
[]

[Problem]
  linear_sys_names = 'u_system v_system w_system pressure_system energy_system solid_energy_system'
  previous_nl_solution_required = true
[]

[UserObjects]
  [rc]
    type = RhieChowMassFlux
    u = vel_x
    v = vel_y
    w = vel_z
    pressure = pressure
    rho = ${rho}
    p_diffusion_kernel = p_diffusion
    block = 'tube_fluid shell_fluid'
    pressure_projection_method = consistent
  []
[]

[Variables]
  [vel_x]
    type = MooseLinearVariableFVReal
    solver_sys = u_system
    initial_condition = 0.0
    block = 'tube_fluid shell_fluid'
  []
  [vel_y]
    type = MooseLinearVariableFVReal
    solver_sys = v_system
    initial_condition = 0.0
    block = 'tube_fluid shell_fluid'
  []
  [vel_z]
    type = MooseLinearVariableFVReal
    solver_sys = w_system
    initial_condition = 0.0
    block = 'tube_fluid shell_fluid'
  []
  [pressure]
    type = MooseLinearVariableFVReal
    solver_sys = pressure_system
    initial_condition = ${P_out}
    block = 'tube_fluid shell_fluid'
  []
  [T_fluid]
    type = MooseLinearVariableFVReal
    solver_sys = energy_system
    initial_condition = ${shell_Tin}
    block = 'tube_fluid shell_fluid'
  []
  [T_solid]
    type = MooseLinearVariableFVReal
    solver_sys = solid_energy_system
    initial_condition = ${tube_Tin}
    block = 'tube_wall'
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
    mu = ${mu}
    u = vel_x
    v = vel_y
    w = vel_z
    momentum_component = 'x'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = false
  []
  [v_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_y
    advected_interp_method_name = ${advected_interp_method}
    mu = ${mu}
    u = vel_x
    v = vel_y
    w = vel_z
    momentum_component = 'y'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = false
  []
  [w_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_z
    advected_interp_method_name = ${advected_interp_method}
    mu = ${mu}
    u = vel_x
    v = vel_y
    w = vel_z
    momentum_component = 'z'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = false
  []
  [u_pressure]
    type = LinearFVMomentumPressure
    variable = vel_x
    pressure = pressure
    momentum_component = 'x'
  []
  [v_pressure]
    type = LinearFVMomentumPressure
    variable = vel_y
    pressure = pressure
    momentum_component = 'y'
  []
  [w_pressure]
    type = LinearFVMomentumPressure
    variable = vel_z
    pressure = pressure
    momentum_component = 'z'
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

  [h_advection]
    type = LinearFVEnergyAdvection
    variable = T_fluid
    advected_quantity = temperature
    cp = ${cp}
    advected_interp_method = ${advected_interp_method}
    rhie_chow_user_object = 'rc'
  []
  [conduction]
    type = LinearFVDiffusion
    variable = T_fluid
    diffusion_coeff = ${k}
    use_nonorthogonal_correction = false
  []

  [solid-conduction]
    type = LinearFVDiffusion
    variable = T_solid
    diffusion_coeff = ${k_s}
    use_nonorthogonal_correction = false
  []
[]

[LinearFVBCs]
  # tube-side inlet/outlet (flow in +z)
  [tube_inlet_w]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'tube_inlet'
    variable = vel_z
    functor = ${tube_vel}
  []
  [tube_inlet_u]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'tube_inlet'
    variable = vel_x
    functor = 0.0
  []
  [tube_inlet_v]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'tube_inlet'
    variable = vel_y
    functor = 0.0
  []
  [tube_outlet_p]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'tube_outlet'
    variable = pressure
    functor = ${P_out}
  []
  [tube_outlet_u]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'tube_outlet'
    variable = vel_x
    use_two_term_expansion = false
  []
  [tube_outlet_v]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'tube_outlet'
    variable = vel_y
    use_two_term_expansion = false
  []
  [tube_outlet_w]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'tube_outlet'
    variable = vel_z
    use_two_term_expansion = false
  []

  # shell-side inlet/outlet (flow in -z, counter-current)
  [shell_inlet_w]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'shell_inlet'
    variable = vel_z
    functor = '${fparse -shell_vel}'
  []
  [shell_inlet_u]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'shell_inlet'
    variable = vel_x
    functor = 0.0
  []
  [shell_inlet_v]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'shell_inlet'
    variable = vel_y
    functor = 0.0
  []
  [shell_outlet_p]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'shell_outlet'
    variable = pressure
    functor = ${P_out}
  []
  [shell_outlet_u]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'shell_outlet'
    variable = vel_x
    use_two_term_expansion = false
  []
  [shell_outlet_v]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'shell_outlet'
    variable = vel_y
    use_two_term_expansion = false
  []
  [shell_outlet_w]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'shell_outlet'
    variable = vel_z
    use_two_term_expansion = false
  []

  # no-slip at fluid/solid interfaces and the outer shell wall
  [walls_u]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'tube_interface shell_interface shell_wall'
    variable = vel_x
    functor = 0.0
  []
  [walls_v]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'tube_interface shell_interface shell_wall'
    variable = vel_y
    functor = 0.0
  []
  [walls_w]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'tube_interface shell_interface shell_wall'
    variable = vel_z
    functor = 0.0
  []

  # temperature boundary conditions
  [tube_inlet_T]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T_fluid
    functor = ${tube_Tin}
    boundary = 'tube_inlet'
  []
  [tube_outlet_T]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = T_fluid
    use_two_term_expansion = false
    boundary = 'tube_outlet'
  []
  [shell_inlet_T]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = T_fluid
    functor = ${shell_Tin}
    boundary = 'shell_inlet'
  []
  [shell_outlet_T]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = T_fluid
    use_two_term_expansion = false
    boundary = 'shell_outlet'
  []
  [insulated_shell_wall]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_fluid
    functor = 0.0
    boundary = 'shell_wall'
  []
  [insulated_solid_caps]
    type = LinearFVAdvectionDiffusionFunctorNeumannBC
    variable = T_solid
    functor = 0.0
    boundary = 'bottom_cap top_cap'
  []

  # CHT coupling between the tube bore (fluid) and the tube wall (solid)
  [tube_fluid_solid]
    type = LinearFVRobinCHTBC
    variable = T_fluid
    boundary = tube_interface
    h = ${h_f}
    incoming_flux = heat_flux_to_fluid_tube_interface
    surface_temperature = interface_temperature_to_fluid_tube_interface
    thermal_conductivity = ${k}
  []
  [tube_solid_fluid]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = tube_interface
    h = ${h_s}
    incoming_flux = heat_flux_to_solid_tube_interface
    surface_temperature = interface_temperature_to_solid_tube_interface
    thermal_conductivity = ${k_s}
  []

  # CHT coupling between the tube wall (solid) and the shell-side fluid
  [shell_fluid_solid]
    type = LinearFVRobinCHTBC
    variable = T_fluid
    boundary = shell_interface
    h = ${h_f}
    incoming_flux = heat_flux_to_fluid_shell_interface
    surface_temperature = interface_temperature_to_fluid_shell_interface
    thermal_conductivity = ${k}
  []
  [shell_solid_fluid]
    type = LinearFVRobinCHTBC
    variable = T_solid
    boundary = shell_interface
    h = ${h_s}
    incoming_flux = heat_flux_to_solid_shell_interface
    surface_temperature = interface_temperature_to_solid_shell_interface
    thermal_conductivity = ${k_s}
  []
[]

[Executioner]
  type = SIMPLE

  momentum_systems = 'u_system v_system w_system'
  pressure_system = 'pressure_system'
  rhie_chow_user_object = 'rc'
  momentum_l_abs_tol = 1e-12
  pressure_l_abs_tol = 1e-12
  momentum_l_tol = 0
  pressure_l_tol = 0
  momentum_equation_relaxation = 0.8
  pressure_variable_relaxation = 0.3
  momentum_absolute_tolerance = 1e-6
  pressure_absolute_tolerance = 1e-6
  momentum_petsc_options_iname = '-pc_type -pc_hypre_type'
  momentum_petsc_options_value = 'hypre boomeramg'
  pressure_petsc_options_iname = '-pc_type -pc_hypre_type'
  pressure_petsc_options_value = 'hypre boomeramg'

  energy_system = 'energy_system'
  solid_energy_system = 'solid_energy_system'
  energy_l_abs_tol = 1e-12
  solid_energy_l_abs_tol = 1e-12
  energy_l_tol = 0
  solid_energy_l_tol = 0
  energy_equation_relaxation = 1.0
  energy_absolute_tolerance = 1e-6
  solid_energy_absolute_tolerance = 1e-6
  energy_petsc_options_iname = '-pc_type -pc_hypre_type'
  energy_petsc_options_value = 'hypre boomeramg'
  solid_energy_petsc_options_iname = '-pc_type -pc_hypre_type'
  solid_energy_petsc_options_value = 'hypre boomeramg'

  cht_interfaces = 'tube_interface shell_interface'
  cht_solid_flux_relaxation = '1.0 1.0'
  cht_fluid_flux_relaxation = '1.0 1.0'
  cht_solid_temperature_relaxation = '1.0 1.0'
  cht_fluid_temperature_relaxation = '1.0 1.0'
  max_cht_fpi = 2

  num_iterations = 1000
  print_fields = false
  continue_on_max_its = true
[]

[FunctorMaterials]
  [rhocpT]
    type = ParsedFunctorMaterial
    property_name = 'rhocpT'
    functor_names = 'T_fluid'
    expression = '${rho}*${cp}*T_fluid'
  []
[]

[Postprocessors]
  [tube_p_in]
    type = SideAverageValue
    variable = pressure
    boundary = tube_inlet
  []
  [tube_p_out]
    type = SideAverageValue
    variable = pressure
    boundary = tube_outlet
  []
  [shell_p_in]
    type = SideAverageValue
    variable = pressure
    boundary = shell_inlet
  []
  [shell_p_out]
    type = SideAverageValue
    variable = pressure
    boundary = shell_outlet
  []

  # mass flow rates (should match on each side's inlet/outlet; incompressible flow)
  [tube_mdot_in]
    type = VolumetricFlowRate
    boundary = tube_inlet
    vel_x = vel_x
    vel_y = vel_y
    vel_z = vel_z
    rhie_chow_user_object = rc
    advected_quantity = ${rho}
  []
  [tube_mdot_out]
    type = VolumetricFlowRate
    boundary = tube_outlet
    vel_x = vel_x
    vel_y = vel_y
    vel_z = vel_z
    rhie_chow_user_object = rc
    advected_quantity = ${rho}
    advected_interp_method = upwind
  []
  [shell_mdot_in]
    type = VolumetricFlowRate
    boundary = shell_inlet
    vel_x = vel_x
    vel_y = vel_y
    vel_z = vel_z
    rhie_chow_user_object = rc
    advected_quantity = ${rho}
  []
  [shell_mdot_out]
    type = VolumetricFlowRate
    boundary = shell_outlet
    vel_x = vel_x
    vel_y = vel_y
    vel_z = vel_z
    rhie_chow_user_object = rc
    advected_quantity = ${rho}
    advected_interp_method = upwind
  []

  # enthalpy flow rates (rho*cp*T advected through each boundary)
  [tube_H_in]
    type = VolumetricFlowRate
    boundary = tube_inlet
    vel_x = vel_x
    vel_y = vel_y
    vel_z = vel_z
    rhie_chow_user_object = rc
    advected_quantity = 'rhocpT'
  []
  [tube_H_out]
    type = VolumetricFlowRate
    boundary = tube_outlet
    vel_x = vel_x
    vel_y = vel_y
    vel_z = vel_z
    rhie_chow_user_object = rc
    advected_quantity = 'rhocpT'
    advected_interp_method = upwind
  []
  [shell_H_in]
    type = VolumetricFlowRate
    boundary = shell_inlet
    vel_x = vel_x
    vel_y = vel_y
    vel_z = vel_z
    rhie_chow_user_object = rc
    advected_quantity = 'rhocpT'
  []
  [shell_H_out]
    type = VolumetricFlowRate
    boundary = shell_outlet
    vel_x = vel_x
    vel_y = vel_y
    vel_z = vel_z
    rhie_chow_user_object = rc
    advected_quantity = 'rhocpT'
    advected_interp_method = upwind
  []

  # flow-weighted (bulk) outlet temperatures: T_bulk = H_dot / (mdot * cp)
  [tube_Tin_bulk]
    type = ParsedPostprocessor
    pp_names = 'tube_H_in tube_mdot_in'
    expression = 'tube_H_in / (tube_mdot_in * ${cp})'
  []
  [tube_Tout_bulk]
    type = ParsedPostprocessor
    pp_names = 'tube_H_out tube_mdot_out'
    expression = 'tube_H_out / (tube_mdot_out * ${cp})'
  []
  [shell_Tin_bulk]
    type = ParsedPostprocessor
    pp_names = 'shell_H_in shell_mdot_in'
    expression = 'shell_H_in / (shell_mdot_in * ${cp})'
  []
  [shell_Tout_bulk]
    type = ParsedPostprocessor
    pp_names = 'shell_H_out shell_mdot_out'
    expression = 'shell_H_out / (shell_mdot_out * ${cp})'
  []

  # simple area-averaged outlet temperatures, for comparison with the bulk values above
  [tube_Tout_avg]
    type = SideAverageValue
    variable = T_fluid
    boundary = tube_outlet
  []
  [shell_Tout_avg]
    type = SideAverageValue
    variable = T_fluid
    boundary = shell_outlet
  []

  # heat duty on each side. VolumetricFlowRate uses the boundary's outward normal,
  # so an inflow boundary integrates to a negative value and an outflow boundary to
  # a positive one; duty_lost = -(H_in + H_out) is therefore the positive heat lost
  # by the hot (tube) stream, and duty_gained = (H_in + H_out) the positive heat
  # gained by the cold (shell) stream.
  [tube_duty]
    type = ParsedPostprocessor
    pp_names = 'tube_H_in tube_H_out'
    expression = '-(tube_H_in + tube_H_out)'
  []
  [shell_duty]
    type = ParsedPostprocessor
    pp_names = 'shell_H_in shell_H_out'
    expression = '(shell_H_in + shell_H_out)'
  []

  # overall energy balance: heat lost by the hot (tube) stream vs heat gained by
  # the cold (shell) stream; should match closely at convergence
  [energy_balance_error]
    type = ParsedPostprocessor
    pp_names = 'tube_duty shell_duty'
    expression = '(tube_duty - shell_duty) / tube_duty'
  []
[]

[Outputs]
  exodus = true
  csv = true
  execute_on = 'initial timestep_end'
[]
