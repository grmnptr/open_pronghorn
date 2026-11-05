##########################################################
# 7-tube hexagonal-lattice shell-and-tube heat exchanger,
# liquid sodium, TURBULENT (standard k-epsilon with wall
# functions), conjugate heat transfer (CHT)
#
# Geometry is a 7-tube cut of the ABTR intermediate heat
# exchanger (IHX) tube bundle: 1 center tube + 6 in a hex
# ring on a triangular pitch, inside a cylindrical shell.
# Tube bore (secondary sodium), tube wall (9Cr-1Mo) and the
# shell-side region (primary sodium) are all resolved.
#
# Phase 2 of examples/heat_exchanger/PLAN-sodium-turbulent-hx.md,
# derived from the Phase 1 laminar input heat_exchanger_na_laminar.i.
# Operating point: ABTR IHX mid-length velocities (Re_tube ~ 6.4e4,
# Pe_tube ~ 320). Turbulence model and CHT coupling as in the
# regression test turbulent_cht_channel.i:
#   - k-epsilon, log-law wall functions on tube_interface,
#     shell_interface and shell_wall (no thermal wall function: at
#     Pr = 0.005 the conductive sublayer, y+ ~ 2300, spans the whole
#     flow, so it would return k)
#   - one LinearFVDiffusion with k_eff = k + k_t (CHTHandler needs one)
#   - Dirichlet-Neumann CHT: Dirichlet on the fluid side, Robin on the
#     solid side
#   - k_t from the Kays (1994) liquid-metal turbulent Prandtl number
#     by default (Pr_t_kays = 1), or a constant Pr_t
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
length = 3.85 # active length [IHX-DDB-0001; SRC-chang2008-abtr-pcdr PDF p. 73]
# Number of axial elements (~48 mm cells at the full length)
n_layers = 80

# Wall-function mesh (plan Step 2.2): the wall-adjacent cell centroid must
# sit in the log layer, 30 < y+ < 100-150. Estimates from Blasius friction
# (ai-derived): u_tau ~ 0.071 m/s (tube), ~ 0.046 m/s (shell), so
# nu/u_tau ~ 4.4 um (tube) and ~ 6.8 um (shell).
# Shell-side wall boundary layers: quad rings of this total width around each
# tube and inside the shell barrel (each layer is bl_bias times thicker than
# the one nearer the wall). One 0.8 mm layer puts the centroid at 0.4 mm,
# y+ ~ 60. The width must stay below half the minimum tube-to-shell and
# tube-to-tube gap, (P - D_o)/2 = 3.2 mm.
bl_width = 0.0008
bl_num = 1
bl_bias = 1.0

# In-plane resolution. Coarse mesh: 206k cells at 3.85 m / 80 layers. On
# the 0.5 m / 10-layer test (MUSCL) it was within 0.3 % in duty and ~2 % in
# tube Nu of the Phase 1 in-plane mesh (n_sectors = 40, n_shell_sectors =
# 144, core_area = 1.5e-6; 48k cells at 0.5 m), with an unchanged pressure
# drop, and converged in ~950 instead of > 1500 outer iterations. The middle
# mesh, 32 / 112 / 2.5e-6, lay in between. The wall layers do not change.
n_sectors = 24 # azimuthal intervals around each tube; multiple of 8 (even per square side)
n_shell_sectors = 96 # azimuthal intervals around the shell barrel
bore_core_num = 3 # radial intervals in the bore outside its boundary layer
bore_core_bias = 1.0 # radial growth factor of those intervals (> 1: coarser outward)
bore_square_r = 0.0035 # radius of the ring enclosing the square bore center
# One 0.5 mm wall layer in the bore: centroid at 0.25 mm, y+ ~ 55.
bore_bl_width = 0.0005 # tube-bore boundary layer width at tube_interface
bore_bl_num = 1
bore_bl_bias = 1.0 # < 1: finest at the wall (layer built outward)
wall_num = 2 # radial intervals across the tube wall
core_area = 3e-6 # max triangle area in the shell core, ~2.6 mm edge

# --- sodium properties, constant at the 694 K (421 C) exchanger mean ---
# hxdesign.properties, based on [SRC-fink1995-sodium-properties]
# (ai-derived / hxdesign tool output). Pr = mu*cp/k = 0.0050.
rho = 852.9
mu = 2.671e-4
k = 68.3
cp = 1278.0

Pr = '${fparse mu*cp/k}'

# tube wall, 9Cr-1Mo [SRC-chang2008-abtr-pcdr p. 222]
k_s = 28.0

# --- turbulence ---
# standard k-epsilon constants, as in the MOOSE ERCOFTAC channel test
sigma_k = 1.0
sigma_eps = 1.3
C1_eps = 1.44
C2_eps = 1.92
C_mu = 0.09
walls = 'tube_interface shell_interface shell_wall'
wall_treatment = 'eq_newton'
bulk_wall_treatment = false
# Limiter on mu_t/mu. Next to the shell inlet the plug inflow has no shear
# in the subchannel centres, epsilon decays faster than k and mu_t/mu ran
# away to ~7e4 (fully developed values are ~50-300).
mu_t_ratio_max = 1e3

# Turbulent heat conduction, k_eff = k + k_t (plan D3):
#   Pr_t_kays = 1: Kays (1994) liquid-metal model, Pr_t = 0.85 + 0.7/Pe_t
#                  with Pe_t = (mu_t/mu)*Pr; written as
#                  k_t = cp*mu_t*Pe_t/(0.85*Pe_t + 0.7)
#   Pr_t_kays = 0: constant Pr_t
# At Pr = 0.005 Kays gives Pr_t ~ 2 in the core and k_t -> 0 at the wall,
# about half the k_t of Pr_t = 0.9.
Pr_t_kays = 1
Pr_t = 0.9

# --- operating conditions ---
# ABTR IHX mid-length velocities from the hxdesign flow areas at 421 C
# (ai-derived / hxdesign tool output, plan section 0): Re_tube ~ 6.4e4.
tube_vel = 1.424 # +z
shell_vel = 0.901 # -z
D_tube = '${fparse 2*tube_ir}'
D_shell = 0.01518 # whole-bundle shell hydraulic diameter (hxdesign BundleGeometry)
# Inlet turbulence as in the ERCOFTAC channel test (a modelling choice):
# I = 0.16 Re^(-1/8), k = 1.5 (I U)^2, eps = C_mu^0.75 k^1.5 / D_h
tube_Re = '${fparse rho*tube_vel*D_tube/mu}'
shell_Re = '${fparse rho*shell_vel*D_shell/mu}'
tube_k_in = '${fparse 1.5*(0.16*tube_Re^(-1/8)*tube_vel)^2}'
shell_k_in = '${fparse 1.5*(0.16*shell_Re^(-1/8)*shell_vel)^2}'
tube_eps_in = '${fparse C_mu^0.75*tube_k_in^1.5/D_tube}'
shell_eps_in = '${fparse C_mu^0.75*shell_k_in^1.5/D_shell}'
tube_Tin = 606.15 # secondary inlet, 333 C [IHX-DDB-0001]
shell_Tin = 783.15 # primary inlet, 510 C [IHX-DDB-0001]
T_init = 694.0 # midway initial guess for fluid and solid
P_out = 1.0e5

# SIMPLEC (RhieChowMassFlux pressure_projection_method = consistent)
# relaxation factors. SIMPLEC runs without pressure under-relaxation
# (p_relax = 1.0), but 0.3 converged faster in every case tested (e.g. 126
# against 147 outer iterations with 5 CHT sweeps), so 0.3 is kept.
mom_relax = 0.7
p_relax = 0.3
turb_relax = 0.2

# Dirichlet-Neumann CHT (as in turbulent_cht_channel.i): the fluid side is
# Dirichlet on the wall temperature from the solid, the solid side a Robin
# BC on the fluid heat flux. h_s affects only the convergence rate of the
# CHT fixed point, not the converged solution. 5e5 is of the order of the
# wall-cell conductances (fluid k/y_c ~ 2-3e5, solid k_s/(dx/2) ~ 1.3e5
# W/m2K); it has not been tuned.
h_s = 5.0e5

# Momentum advection: an FVInterpolationMethods object name ('upwind' or
# 'vanLeer'). vanLeer changes the duty by < 0.01 % but stalls the momentum
# residual at ~5e-4, so upwind is kept.
advected_interp_method = 'upwind'
# Energy advection: an FVInterpolationMethods object name ('upwind',
# 'vanLeer' or 'average_energy'). At the turbulent velocities the axial cell
# Peclet number is ~1e3 (plan R9). Central differencing ('average_energy')
# decouples alternate axial layers: the tube bulk temperature came out as a
# staircase (632.0, 631.7, 653.9, 653.0, ... K on 50 mm layers). Upwind is
# monotone but adds an axial numerical diffusivity rho*cp*w*dz/2 (~600 k on
# 48 mm cells). Bounded second-order options:
#   'vanLeer' - limited blending weights in the matrix; the limiter makes the
#               matrix depend on T, and the energy residual stalled at ~2e-3
#               with energy_relax = 1
#   'minmod'  - as vanLeer but with the most diffusive TVD limiter
#   'muscl'   - MUSCL reconstruction with a Venkatakrishnan-limited gradient
#               as a deferred correction: upwind matrix, high-order part on
#               the right hand side
energy_interp_method = 'muscl'
# deferred-correction strength of 'muscl' (0 = upwind, 1 = full MUSCL)
muscl_factor = 1.0
# energy equation relaxation (the limited schemes need < 1)
energy_relax = 0.8
# Linear (two-term) extrapolation of the outlet temperature from the cell
# centre. The second-order schemes need it: with the cell-centre value the
# last cell sits ~half an axial step above the profile (outlet kink). On the
# 0.5 m / 10-layer test it removed the outlet Nu spike (23 -> 11.3) and moved
# the duty 0.6 % toward the 20-layer result.
outlet_two_term = true

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
  linear_sys_names = 'u_system v_system w_system pressure_system TKE_system TKED_system '
                     'energy_system solid_energy_system'
  previous_nl_solution_required = true
  # mu_eff and k_eff exist only in the fluid; the solid conductivity is a
  # constant passed directly to its kernel
  material_coverage_check = false
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
  [TKE]
    type = MooseLinearVariableFVReal
    solver_sys = TKE_system
    initial_condition = ${tube_k_in}
    block = ${fluid_blocks}
  []
  [TKED]
    type = MooseLinearVariableFVReal
    solver_sys = TKED_system
    initial_condition = ${tube_eps_in}
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

# start from plug flow in each stream
[ICs]
  [tube_w]
    type = ConstantIC
    variable = vel_z
    value = ${tube_vel}
    block = ${tube_blocks}
  []
  [shell_w]
    type = ConstantIC
    variable = vel_z
    value = '${fparse -shell_vel}'
    block = ${shell_blocks}
  []
[]

[FVInterpolationMethods]
  [upwind]
    type = FVAdvectedUpwind
  []
  [vanLeer]
    type = FVAdvectedVanLeerWeightBased
  []
  [average_energy]
    type = FVGeometricAverage
  []
  [minmod]
    type = FVAdvectedMinmodWeightBased
  []
  [muscl]
    type = FVAdvectedMUSCLDeferredCorrection
    deferred_correction_factor = ${muscl_factor}
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
    w = vel_z
    momentum_component = 'x'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = true
    use_deviatoric_terms = yes
  []
  [v_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_y
    advected_interp_method_name = ${advected_interp_method}
    mu = 'mu_eff'
    u = vel_x
    v = vel_y
    w = vel_z
    momentum_component = 'y'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = true
    use_deviatoric_terms = yes
  []
  [w_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_z
    advected_interp_method_name = ${advected_interp_method}
    mu = 'mu_eff'
    u = vel_x
    v = vel_y
    w = vel_z
    momentum_component = 'z'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = true
    use_deviatoric_terms = yes
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

  [TKE_advection]
    type = LinearFVTurbulentAdvection
    variable = TKE
    advected_interp_method_name = ${advected_interp_method}
    rhie_chow_user_object = 'rc'
  []
  [TKE_diffusion]
    type = LinearFVTurbulentDiffusion
    variable = TKE
    diffusion_coeff = ${mu}
    use_nonorthogonal_correction = true
  []
  [TKE_turb_diffusion]
    type = LinearFVTurbulentDiffusion
    variable = TKE
    diffusion_coeff = 'mu_t'
    scaling_coeff = ${sigma_k}
    use_nonorthogonal_correction = true
  []
  [TKE_source_sink]
    type = LinearFVTKESourceSink
    variable = TKE
    u = vel_x
    v = vel_y
    w = vel_z
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
    rhie_chow_user_object = 'rc'
  []
  [TKED_diffusion]
    type = LinearFVTurbulentDiffusion
    variable = TKED
    diffusion_coeff = ${mu}
    use_nonorthogonal_correction = true
    walls = ${walls}
  []
  [TKED_turb_diffusion]
    type = LinearFVTurbulentDiffusion
    variable = TKED
    diffusion_coeff = 'mu_t'
    scaling_coeff = ${sigma_eps}
    use_nonorthogonal_correction = true
    walls = ${walls}
  []
  [TKED_source_sink]
    type = LinearFVTKEDSourceSink
    variable = TKED
    u = vel_x
    v = vel_y
    w = vel_z
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

  [h_advection]
    type = LinearFVEnergyAdvection
    variable = T_fluid
    advected_quantity = temperature
    cp = ${cp}
    advected_interp_method_name = ${energy_interp_method}
    rhie_chow_user_object = 'rc'
  []
  # CHTHandler requires exactly one LinearFVDiffusion per side, so molecular
  # and turbulent conduction go through one kernel with k_eff
  [conduction]
    type = LinearFVDiffusion
    variable = T_fluid
    diffusion_coeff = 'k_eff'
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

  # turbulence inlet/outlet and wall-function mu_t
  [tube_inlet_TKE]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'tube_inlet'
    variable = TKE
    functor = ${tube_k_in}
  []
  [shell_inlet_TKE]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'shell_inlet'
    variable = TKE
    functor = ${shell_k_in}
  []
  [outlet_TKE]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'tube_outlet shell_outlet'
    variable = TKE
    use_two_term_expansion = false
  []
  [tube_inlet_TKED]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'tube_inlet'
    variable = TKED
    functor = ${tube_eps_in}
  []
  [shell_inlet_TKED]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'shell_inlet'
    variable = TKED
    functor = ${shell_eps_in}
  []
  [outlet_TKED]
    type = LinearFVAdvectionDiffusionOutflowBC
    boundary = 'tube_outlet shell_outlet'
    variable = TKED
    use_two_term_expansion = false
  []
  [walls_mu_t]
    type = LinearFVTurbulentViscosityWallFunctionBC
    boundary = ${walls}
    variable = 'mu_t'
    u = vel_x
    v = vel_y
    w = vel_z
    rho = ${rho}
    mu = ${mu}
    tke = TKE
    wall_treatment = ${wall_treatment}
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
    use_two_term_expansion = ${outlet_two_term}
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
    use_two_term_expansion = ${outlet_two_term}
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

  # Dirichlet-Neumann CHT coupling between the tube bore (fluid) and the tube wall (solid)
  [tube_fluid_solid]
    type = LinearFVDirichletCHTBC
    variable = T_fluid
    boundary = tube_interface
    functor = interface_temperature_to_fluid_tube_interface
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
    type = LinearFVDirichletCHTBC
    variable = T_fluid
    boundary = shell_interface
    functor = interface_temperature_to_fluid_shell_interface
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

  turbulence_systems = 'TKE_system TKED_system'
  turbulence_l_abs_tol = 1e-12
  turbulence_l_tol = 0
  turbulence_equation_relaxation = '${turb_relax} ${turb_relax}'
  turbulence_field_relaxation = '${turb_relax} ${turb_relax}'
  turbulence_absolute_tolerance = '1e-6 1e-6'
  turbulence_petsc_options_iname = '-pc_type -pc_hypre_type'
  turbulence_petsc_options_value = 'hypre boomeramg'

  energy_system = 'energy_system'
  solid_energy_system = 'solid_energy_system'
  energy_l_abs_tol = 1e-12
  solid_energy_l_abs_tol = 1e-12
  energy_l_tol = 0
  solid_energy_l_tol = 0
  energy_equation_relaxation = ${energy_relax}
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
  # CHT sweeps per outer iteration (5 was fastest in the laminar Phase 1)
  max_cht_fpi = 5

  num_iterations = 3000
  print_fields = false
  continue_on_max_its = true
[]

[AuxVariables]
  [mu_t]
    type = MooseLinearVariableFVReal
    initial_condition = '${fparse rho*C_mu*tube_k_in^2/tube_eps_in}'
    block = ${fluid_blocks}
  []
  [yplus]
    type = MooseLinearVariableFVReal
    block = ${fluid_blocks}
  []
  [mu_t_ratio]
    type = MooseLinearVariableFVReal
    block = ${fluid_blocks}
  []
  [k_eff_ratio]
    type = MooseLinearVariableFVReal
    block = ${fluid_blocks}
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
    w = vel_z
    bulk_wall_treatment = ${bulk_wall_treatment}
    walls = ${walls}
    wall_treatment = ${wall_treatment}
    execute_on = 'NONLINEAR'
    mu_t_ratio_max = ${mu_t_ratio_max}
  []
  [compute_yplus]
    type = RANSYPlusAux
    variable = yplus
    tke = TKE
    mu = ${mu}
    rho = ${rho}
    u = vel_x
    v = vel_y
    w = vel_z
    walls = ${walls}
    wall_treatment = ${wall_treatment}
    execute_on = 'TIMESTEP_END'
  []
  [compute_mu_t_ratio]
    type = ParsedAux
    variable = mu_t_ratio
    coupled_variables = 'mu_t'
    expression = 'mu_t / ${mu}'
    execute_on = 'TIMESTEP_END'
  []
  [compute_k_eff_ratio]
    type = FunctorAux
    variable = k_eff_ratio
    functor = 'k_eff'
    factor = '${fparse 1/k}'
    execute_on = 'TIMESTEP_END'
  []
[]

[FunctorMaterials]
  [mu_eff]
    type = FunctorEffectiveDynamicViscosity
    property_name = mu_eff
    mu = ${mu}
    mu_t = mu_t
    mu_t_inverse_factor = 1
    block = ${fluid_blocks}
    execute_on = 'ALWAYS'
  []
  # k_eff = k + k_t; Kays: Pe_t = mu_t*Pr/mu, k_t = cp*mu_t*Pe_t/(0.85*Pe_t + 0.7)
  [k_eff]
    type = ParsedFunctorMaterial
    property_name = 'k_eff'
    functor_names = 'mu_t'
    expression = '${k} + if(${Pr_t_kays} > 0, '
                 '${cp} * mu_t * (mu_t * ${Pr} / ${mu}) / (0.85 * mu_t * ${Pr} / ${mu} + 0.7), '
                 '${cp} * mu_t / ${Pr_t})'
    block = ${fluid_blocks}
  []
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

  # wall-adjacent y+ (RANSYPlusAux is nonzero only in wall-bounded cells)
  [yplus_max]
    type = ElementExtremeValue
    variable = yplus
    value_type = max
    block = ${fluid_blocks}
  []
  [yplus_tube_wall_avg]
    type = SideAverageValue
    variable = yplus
    boundary = tube_interface
  []
  [yplus_shell_interface_avg]
    type = SideAverageValue
    variable = yplus
    boundary = shell_interface
  []
  [yplus_shell_wall_avg]
    type = SideAverageValue
    variable = yplus
    boundary = shell_wall
  []
  [mu_t_ratio_max]
    type = ElementExtremeValue
    variable = mu_t_ratio
    value_type = max
    block = ${fluid_blocks}
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
