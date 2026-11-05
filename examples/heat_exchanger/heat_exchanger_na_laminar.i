##########################################################
# 7-tube hexagonal-lattice shell-and-tube heat exchanger,
# liquid sodium, laminar, conjugate heat transfer (CHT)
#
# Geometry is a 7-tube cut of the ABTR intermediate heat
# exchanger (IHX) tube bundle: 1 center tube + 6 in a hex
# ring on a triangular pitch, inside a cylindrical shell.
# Tube bore (secondary sodium), tube wall (9Cr-1Mo) and the
# shell-side region (primary sodium) are all resolved.
#
# Phase 1 of examples/heat_exchanger/PLAN-sodium-turbulent-hx.md:
# a laminar shakedown of solver, properties and mesh before the
# turbulent (k-epsilon) model. At Re_tube ~ 1500 the exchanger
# is thermally pinched (NTU ~ 50), so local quantities (wall
# heat flux, developed tube Nu) are the meaningful checks, not
# the duty. Pe_tube ~ 7.5, so fluid axial conduction matters;
# it is resolved here but not by 1D correlation tools.
#
# Gravity/buoyancy are excluded (no hydrostatic pressure); the
# reported pressure drops are irreversible + acceleration only.
#
# Primary (hot) sodium flows -z on the shell side, secondary
# (cold) sodium flows +z in the tubes (counter-current, as in
# the ABTR IHX).
##########################################################

# --- geometry ---
# Tube OD 15.9 mm, wall 0.889 mm, triangular pitch 22.3 mm
# [IHX-DDB-0001; SRC-chang2008-abtr-pcdr PDF p. 73]
tube_ir = 0.007061 # tube inner radius, (15.9 - 2*0.889)/2 mm
tube_or = 0.00795 # tube outer radius, 15.9/2 mm
pitch = 0.0223 # hex lattice pitch (center-to-center tube spacing)
# Shell inner radius from the hxdesign BundleGeometry sizing rule for
# n_tubes = 7: OTL + (P - D_o)/2 clearance -> ID 66.9 mm
# (ai-derived / hxdesign tool output). Peripheral bypass is 23.5 % of
# the shell flow area, versus 6.3 % in the full ABTR bundle.
shell_radius = 0.03345
length = 0.5 # axial length; shortened from the 3.85 m active length (laminar shakedown)
# Number of axial elements. 15 (33 mm cells) is within 0.4 % of 30 layers
# in duty and Nu, and within 0.5 K in the outlet temperatures, at half the
# cells and a third of the run time.
n_layers = 15

# Shell-side wall boundary layers: quad rings of this total width around each
# tube and inside the shell barrel, graded finest at the wall (each layer is
# bl_bias times thicker than the one nearer the wall). 0.7 mm in 3 layers
# gives 0.1 / 0.2 / 0.4 mm. The width must stay below half the minimum
# tube-to-shell and tube-to-tube gap, (P - D_o)/2 = 3.2 mm.
bl_width = 0.0007
bl_num = 3
bl_bias = 2.0

# In-plane resolution. For a mesh study, refine with e.g.
#   bl_num=6 bl_bias=1.414 bore_bl_num=6 bore_bl_bias=0.707 bore_core_num=6
#   wall_num=4 n_sectors=80 n_shell_sectors=288 core_area=3.75e-7
# which halves the cell size in every in-plane direction.
n_sectors = 40 # azimuthal intervals around each tube; multiple of 8 (even per square side)
n_shell_sectors = 144 # azimuthal intervals around the shell barrel
bore_core_num = 3 # radial intervals in the bore outside its boundary layer
bore_core_bias = 1.0 # radial growth factor of those intervals (> 1: coarser outward)
bore_square_r = 0.0035 # radius of the ring enclosing the square bore center
bore_bl_width = 0.0016 # tube-bore boundary layer width at tube_interface
bore_bl_num = 3
bore_bl_bias = 0.5 # < 1: finest at the wall (layer built outward)
wall_num = 2 # radial intervals across the tube wall
core_area = 1.5e-6 # max triangle area in the shell core, ~1.9 mm edge

# --- sodium properties, constant at the 694 K (421 C) exchanger mean ---
# hxdesign.properties, based on [SRC-fink1995-sodium-properties]
# (ai-derived / hxdesign tool output). Pr = mu*cp/k = 0.0050.
rho = 852.9
mu = 2.671e-4
k = 68.3
cp = 1278.0

# tube wall, 9Cr-1Mo [SRC-chang2008-abtr-pcdr p. 222]
k_s = 28.0

# --- operating conditions ---
# Tube-side velocity for Re = rho*U*D_i/mu = 1500 (laminar).
tube_vel = '${fparse 1500*mu/(rho*2*tube_ir)}' # ~0.0333 m/s, +z
# Shell-side velocity for equal capacity rates: U_s = U_t*A_t/A_s, with
# A_t = 1.096e-3 m^2 and A_s = 2.125e-3 m^2 (7 tubes, hxdesign geometry).
shell_vel = '${fparse tube_vel*1.096e-3/2.125e-3}' # ~0.0172 m/s, -z
tube_Tin = 606.15 # secondary inlet, 333 C [IHX-DDB-0001]
shell_Tin = 783.15 # primary inlet, 510 C [IHX-DDB-0001]
T_init = 694.0 # midway initial guess for fluid and solid
P_out = 1.0e5

# Robin-Robin CHT relaxation coefficients. Sodium conducts ~100x better
# than water, so these are raised from the water example's 50; the
# fluid-side optimum scales roughly like k/(wall-cell size).
# SIMPLEC (RhieChowMassFlux pressure_projection_method = consistent)
# relaxation factors. SIMPLEC runs without pressure under-relaxation
# (p_relax = 1.0), but 0.3 converged faster in every case tested (e.g. 126
# against 147 outer iterations with 5 CHT sweeps), so 0.3 is kept.
mom_relax = 0.8
p_relax = 0.3

h_f = 1.0e4
h_s = 1.0e4

# Momentum advection: an FVInterpolationMethods object name ('upwind' or
# 'vanLeer'). vanLeer changes the duty by < 0.01 % but stalls the momentum
# residual at ~5e-4, so upwind is kept.
advected_interp_method = 'upwind'
# Energy advection: LinearFVEnergyAdvection accepts 'upwind' or 'average'.
# Upwind adds an artificial axial diffusivity rho*cp*w*dz/2 ~ 4x the sodium
# conductivity at 30 layers, which matters here because physical axial
# conduction is part of the solution (Pe ~ 5-8). Central differencing
# ('average') cuts the 30 -> 60 layer duty change from 1.6 % to 0.35 %, and
# the temperature field stays monotone (no wiggles) even at 15 layers,
# where the axial cell Peclet number reaches 18.
energy_interp_method = 'average'

# Blocks (Exodus requires one element type per block):
#   tube_fluid       tube bore (square quad center + quad rings), incl. the
#                    tube_interface boundary layer
#   shell_fluid_bl   quad boundary-layer rings on shell_interface and shell_wall
#   shell_fluid      triangulated shell-side core between those rings
tube_blocks = 'tube_fluid'
shell_blocks = 'shell_fluid shell_fluid_bl'
fluid_blocks = 'tube_fluid shell_fluid shell_fluid_bl'

[Mesh]
  # One tube: bore, wall, and the shell-side quad boundary layer outside the
  # wall, all quads. The bore center is a square of quads blended into the
  # circular rings (quad_center_elements), which avoids the degenerate
  # triangle fan of a pure radial mesh at r = 0. The bore has a graded
  # boundary layer at the tube_interface wall, finest at the wall.
  # PolygonConcentricCircleMeshGenerator always adds a background region
  # between the last ring and the square; it is meshed with one interval and
  # deleted by tube_trim below.
  [tube_square]
    type = PolygonConcentricCircleMeshGenerator
    num_sides = 4
    num_sectors_per_side = '${fparse n_sectors/4} ${fparse n_sectors/4} ${fparse n_sectors/4} ${fparse n_sectors/4}'
    background_intervals = 1
    # The first ring (radius bore_square_r, one interval) holds the square
    # center; the generator sizes the square from the innermost ring node, so
    # this ring fixes the square size independently of the bore resolution.
    ring_radii = '${bore_square_r} ${tube_ir} ${tube_or} ${fparse tube_or+bl_width}'
    ring_intervals = '1 ${bore_core_num} ${wall_num} ${bl_num}'
    ring_radial_biases = '1 ${bore_core_bias} 1 ${bl_bias}'
    ring_outer_boundary_layer_widths = '0 ${bore_bl_width} 0 0'
    ring_outer_boundary_layer_intervals = '0 ${bore_bl_num} 0 0'
    ring_outer_boundary_layer_biases = '1 ${bore_bl_bias} 1 1'
    ring_block_ids = '1 1 2 5'
    ring_block_names = 'tube_fluid tube_fluid tube_wall shell_fluid_bl'
    background_block_ids = 99
    background_block_names = tube_trim_region
    # square apothem just outside the shell-side boundary layer
    polygon_size = '${fparse 1.1*(tube_or+bl_width)}'
    polygon_size_style = apothem
    quad_center_elements = true
    preserve_volumes = true
    create_outward_interface_boundaries = false
  []
  [tube]
    type = BlockDeletionGenerator
    input = tube_square
    block = tube_trim_region
    new_boundary = tube_outer
  []
  [t0]
    type = TransformGenerator
    input = tube
    transform = TRANSLATE
    vector_value = '0 0 0'
  []
  [t1]
    type = TransformGenerator
    input = tube
    transform = TRANSLATE
    vector_value = '${pitch} 0 0'
  []
  [t2]
    type = TransformGenerator
    input = tube
    transform = TRANSLATE
    vector_value = '${fparse pitch/2} ${fparse pitch*sqrt(3)/2} 0'
  []
  [t3]
    type = TransformGenerator
    input = tube
    transform = TRANSLATE
    vector_value = '${fparse -pitch/2} ${fparse pitch*sqrt(3)/2} 0'
  []
  [t4]
    type = TransformGenerator
    input = tube
    transform = TRANSLATE
    vector_value = '${fparse -pitch} 0 0'
  []
  [t5]
    type = TransformGenerator
    input = tube
    transform = TRANSLATE
    vector_value = '${fparse -pitch/2} ${fparse -pitch*sqrt(3)/2} 0'
  []
  [t6]
    type = TransformGenerator
    input = tube
    transform = TRANSLATE
    vector_value = '${fparse pitch/2} ${fparse -pitch*sqrt(3)/2} 0'
  []
  # Quad boundary-layer ring inside the shell barrel, finest at the wall.
  [shell_ring]
    type = AnnularMeshGenerator
    rmin = ${fparse shell_radius-bl_width}
    rmax = ${shell_radius}
    nr = ${bl_num}
    nt = ${n_shell_sectors}
    growth_r = ${fparse 1/bl_bias}
    quad_subdomain_id = 5
  []
  # Shell-side core: triangulated between the inner edge of the shell ring and
  # the outer edges of the 7 tube boundary-layer rings. A hexagonal-lattice/
  # peripheral-ring mesh cannot be used: the lattice corners reach
  # r = 34.06 mm > shell_radius.
  [shell_core]
    type = XYDelaunayGenerator
    boundary = shell_ring
    input_boundary_names = 'rmin'
    holes = 't0 t1 t2 t3 t4 t5 t6'
    stitch_holes = 'true true true true true true true'
    refine_holes = 'false false false false false false false'
    refine_boundary = false
    output_subdomain_id = 3
    output_subdomain_name = shell_fluid
    output_boundary = shell_core_outer
    desired_area = ${core_area}
  []
  [shell]
    type = StitchMeshGenerator
    inputs = 'shell_core shell_ring'
    stitch_boundaries_pairs = 'shell_core_outer rmin'
  []
  [names]
    # StitchMeshGenerator moves the unnamed shell ring (id 5 in shell_ring) to
    # a new id 6; merge it into the shell_fluid_bl block of the tube rings.
    type = RenameBlockGenerator
    input = shell
    old_block = '6'
    new_block = 'shell_fluid_bl'
  []
  [shell_wall]
    type = RenameBoundaryGenerator
    input = names
    old_boundary = 'rmax'
    new_boundary = 'shell_wall'
  []
  [remove_stale_boundaries]
    # The stitches leave the tube boundary-layer outer edge (tube_outer) and
    # the per-hole stitch sidesets (10003-10009) on internal faces; strip them
    # so no internal face carries a boundary.
    type = BoundaryDeletionGenerator
    input = shell_wall
    boundary_names = 'tube_outer 10003 10004 10005 10006 10007 10008 10009'
  []
  [tube_interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = remove_stale_boundaries
    primary_block = tube_fluid
    paired_block = tube_wall
    new_boundary = tube_interface
  []
  [shell_interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = tube_interface
    primary_block = shell_fluid_bl
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

  # split the extruded top/bottom caps per stream so tube-side and
  # shell-side flow can enter/exit at opposite ends (counter-current)
  [tube_inlet]
    type = SideSetsAroundSubdomainGenerator
    input = extrude
    block = ${tube_blocks}
    normal = '0 0 -1'
    new_boundary = tube_inlet
    replace = true
  []
  [tube_outlet]
    type = SideSetsAroundSubdomainGenerator
    input = tube_inlet
    block = ${tube_blocks}
    normal = '0 0 1'
    new_boundary = tube_outlet
    replace = true
  []
  [shell_inlet]
    type = SideSetsAroundSubdomainGenerator
    input = tube_outlet
    block = ${shell_blocks}
    normal = '0 0 1'
    new_boundary = shell_inlet
    replace = true
  []
  [shell_outlet]
    type = SideSetsAroundSubdomainGenerator
    input = shell_inlet
    block = ${shell_blocks}
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
    block = ${fluid_blocks}
    pressure_projection_method = consistent
  []
[]

[Variables]
  [vel_x]
    type = MooseLinearVariableFVReal
    solver_sys = u_system
    initial_condition = 0.0
    block = ${fluid_blocks}
  []
  [vel_y]
    type = MooseLinearVariableFVReal
    solver_sys = v_system
    initial_condition = 0.0
    block = ${fluid_blocks}
  []
  [vel_z]
    type = MooseLinearVariableFVReal
    solver_sys = w_system
    initial_condition = 0.0
    block = ${fluid_blocks}
  []
  [pressure]
    type = MooseLinearVariableFVReal
    solver_sys = pressure_system
    initial_condition = ${P_out}
    block = ${fluid_blocks}
  []
  [T_fluid]
    type = MooseLinearVariableFVReal
    solver_sys = energy_system
    initial_condition = ${T_init}
    block = ${fluid_blocks}
  []
  [T_solid]
    type = MooseLinearVariableFVReal
    solver_sys = solid_energy_system
    initial_condition = ${T_init}
    block = 'tube_wall'
  []
[]

[FVInterpolationMethods]
  [upwind]
    type = FVAdvectedUpwind
  []
  [vanLeer]
    type = FVAdvectedVanLeerWeightBased
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
    use_nonorthogonal_correction = true
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
    use_nonorthogonal_correction = true
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
    use_nonorthogonal_correction = true
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
    use_nonorthogonal_correction = true
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
    advected_interp_method = ${energy_interp_method}
    rhie_chow_user_object = 'rc'
  []
  [conduction]
    type = LinearFVDiffusion
    variable = T_fluid
    diffusion_coeff = ${k}
    use_nonorthogonal_correction = true
  []

  [solid-conduction]
    type = LinearFVDiffusion
    variable = T_solid
    diffusion_coeff = ${k_s}
    use_nonorthogonal_correction = true
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
  momentum_equation_relaxation = ${mom_relax}
  pressure_variable_relaxation = ${p_relax}
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
  # 5 CHT sweeps per outer iteration let the energy/CHT coupling keep pace
  # with the pressure-velocity loop. Tuned on an earlier mesh: 126 outer
  # iterations against 315 with 2 sweeps and 118 with 10, fastest wall time
  # of the three.
  max_cht_fpi = 5

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

  # conductive heat through the inlet/outlet planes, outward positive (W). At
  # Pe ~ 5-8 axial conduction is not negligible: heat conducts upstream out of
  # each inlet. The Dirichlet inlets carry this flux; the outflow BCs carry
  # none (zero normal gradient), which these postprocessors confirm.
  [tube_cond_in]
    type = BoundaryLinearFVFluxIntegral
    linearfvkernels = conduction
    boundary = tube_inlet
  []
  [tube_cond_out]
    type = BoundaryLinearFVFluxIntegral
    linearfvkernels = conduction
    boundary = tube_outlet
  []
  [shell_cond_in]
    type = BoundaryLinearFVFluxIntegral
    linearfvkernels = conduction
    boundary = shell_inlet
  []
  [shell_cond_out]
    type = BoundaryLinearFVFluxIntegral
    linearfvkernels = conduction
    boundary = shell_outlet
  []

  # heat duty on each side, as the net energy leaving the stream through its
  # inlet and outlet planes: advected enthalpy plus axial conduction.
  # VolumetricFlowRate and BoundaryLinearFVFluxIntegral both use the boundary's
  # outward normal, so an inflow integrates to a negative value. shell_duty
  # (positive) is the heat lost by the hot (shell, primary) stream; tube_duty
  # (positive) the heat gained by the cold (tube, secondary) stream.
  [tube_duty]
    type = ParsedPostprocessor
    pp_names = 'tube_H_in tube_H_out tube_cond_in tube_cond_out'
    expression = '(tube_H_in + tube_H_out + tube_cond_in + tube_cond_out)'
  []
  [shell_duty]
    type = ParsedPostprocessor
    pp_names = 'shell_H_in shell_H_out shell_cond_in shell_cond_out'
    expression = '-(shell_H_in + shell_H_out + shell_cond_in + shell_cond_out)'
  []
  # advective-only duties, H_out - H_in (the definition a 1D tool uses)
  [tube_duty_advective]
    type = ParsedPostprocessor
    pp_names = 'tube_H_in tube_H_out'
    expression = '(tube_H_in + tube_H_out)'
  []
  [shell_duty_advective]
    type = ParsedPostprocessor
    pp_names = 'shell_H_in shell_H_out'
    expression = '-(shell_H_in + shell_H_out)'
  []

  # overall energy balance: heat lost by the hot (shell) stream vs heat gained by
  # the cold (tube) stream; should match closely at convergence
  [energy_balance_error]
    type = ParsedPostprocessor
    pp_names = 'tube_duty shell_duty'
    expression = '(shell_duty - tube_duty) / shell_duty'
  []
  # each stream's duty vs the heat through its CHT interface
  [tube_interface_balance_error]
    type = ParsedPostprocessor
    pp_names = 'tube_duty Q_tube_interface_to_fluid'
    expression = '(tube_duty - Q_tube_interface_to_fluid) / Q_tube_interface_to_fluid'
  []
  [shell_interface_balance_error]
    type = ParsedPostprocessor
    pp_names = 'shell_duty Q_shell_interface_to_fluid'
    expression = '(shell_duty + Q_shell_interface_to_fluid) / shell_duty'
  []

  # relative mass imbalance on each side (incompressible: inflow + outflow = 0)
  [tube_mass_error]
    type = ParsedPostprocessor
    pp_names = 'tube_mdot_in tube_mdot_out'
    expression = '(tube_mdot_in + tube_mdot_out) / tube_mdot_in'
  []
  [shell_mass_error]
    type = ParsedPostprocessor
    pp_names = 'shell_mdot_in shell_mdot_out'
    expression = '(shell_mdot_in + shell_mdot_out) / shell_mdot_in'
  []

  # heat-exchanger effectiveness, Q / Q_max with Q_max = C_min*(T_hot,in - T_cold,in)
  [effectiveness]
    type = ParsedPostprocessor
    pp_names = 'shell_duty_advective tube_mdot_in shell_mdot_in'
    expression = 'shell_duty_advective / (min(-tube_mdot_in, -shell_mdot_in) * ${cp} * (${shell_Tin} - ${tube_Tin}))'
  []

  # integrated CHT interface heat rates (W) and interface areas (m^2). The
  # solid has insulated end caps, so at convergence the heat entering it on
  # shell_interface must leave it on tube_interface.
  [Q_tube_interface_to_fluid]
    type = SideIntegralFunctorPostprocessor
    functor = heat_flux_to_fluid_tube_interface
    boundary = tube_interface
  []
  [Q_tube_interface_to_solid]
    type = SideIntegralFunctorPostprocessor
    functor = heat_flux_to_solid_tube_interface
    boundary = tube_interface
  []
  [Q_shell_interface_to_fluid]
    type = SideIntegralFunctorPostprocessor
    functor = heat_flux_to_fluid_shell_interface
    boundary = shell_interface
  []
  [Q_shell_interface_to_solid]
    type = SideIntegralFunctorPostprocessor
    functor = heat_flux_to_solid_shell_interface
    boundary = shell_interface
  []
  [A_tube_interface]
    type = SideIntegralFunctorPostprocessor
    functor = 1
    boundary = tube_interface
  []
  [A_shell_interface]
    type = SideIntegralFunctorPostprocessor
    functor = 1
    boundary = shell_interface
  []
  [A_shell_wall]
    type = SideIntegralFunctorPostprocessor
    functor = 1
    boundary = shell_wall
  []

  # block volumes, for the mesh check against the analytic flow areas x length
  [vol_tube_fluid]
    type = VolumePostprocessor
    block = ${tube_blocks}
  []
  [vol_shell_fluid]
    type = VolumePostprocessor
    block = ${shell_blocks}
  []
  [vol_tube_wall]
    type = VolumePostprocessor
    block = tube_wall
  []
[]

[Outputs]
  exodus = true
  csv = true
  execute_on = 'initial timestep_end'
[]
