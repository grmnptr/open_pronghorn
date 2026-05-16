[Functions]
  [jet_mfr_control]
    type = ConstantFunction
    value = ${jet_mfr}
  []
  [inlet_function]
    type = ParsedFunction
    expression = '4*U*(y-ymin)*(ymax-y)/(ymax-ymin)/(ymax-ymin)'
    symbol_names = 'U ymax ymin'
    symbol_values = '${inlet_velocity} ${y_max} ${y_min}'
  []
  [jet_top_x]
    type = ParsedFunction
    expression = 'scale*Q*(1-(x/xj)^2)*x'
    symbol_names = 'Q scale xj'
    symbol_values = 'jet_mfr_control ${jet_profile_scale} ${jet_x_extent}'
  []
  [jet_top_y]
    type = ParsedFunction
    expression = 'scale*Q*(1-(x/xj)^2)*y'
    symbol_names = 'Q scale xj'
    symbol_values = 'jet_mfr_control ${jet_profile_scale} ${jet_x_extent}'
  []
  [jet_bottom_x]
    type = ParsedFunction
    expression = '-scale*Q*(1-(x/xj)^2)*x'
    symbol_names = 'Q scale xj'
    symbol_values = 'jet_mfr_control ${jet_profile_scale} ${jet_x_extent}'
  []
  [jet_bottom_y]
    type = ParsedFunction
    expression = '-scale*Q*(1-(x/xj)^2)*y'
    symbol_names = 'Q scale xj'
    symbol_values = 'jet_mfr_control ${jet_profile_scale} ${jet_x_extent}'
  []
[]

[UserObjects]
  [rc]
    type = RhieChowMassFlux
    u = vel_x
    v = vel_y
    pressure = pressure
    rho = ${rho}
    p_diffusion_kernel = p_diffusion
    pressure_projection_method = consistent
  []
[]

[Variables]
  [vel_x]
    type = MooseLinearVariableFVReal
    solver_sys = u_system
  []
  [vel_y]
    type = MooseLinearVariableFVReal
    solver_sys = v_system
  []
  [pressure]
    type = MooseLinearVariableFVReal
    solver_sys = pressure_system
  []
[]

[LinearFVKernels]
  [u_time]
    type = LinearFVTimeDerivative
    variable = vel_x
    factor = ${rho}
  []
  [u_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_x
    advected_interp_method = ${advected_interp_method}
    mu = ${mu}
    u = vel_x
    v = vel_y
    momentum_component = 'x'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = true
  []
  [u_pressure]
    type = LinearFVMomentumPressure
    variable = vel_x
    pressure = pressure
    momentum_component = 'x'
  []

  [v_time]
    type = LinearFVTimeDerivative
    variable = vel_y
    factor = ${rho}
  []
  [v_advection_stress]
    type = LinearWCNSFVMomentumFlux
    variable = vel_y
    advected_interp_method = ${advected_interp_method}
    mu = ${mu}
    u = vel_x
    v = vel_y
    momentum_component = 'y'
    rhie_chow_user_object = 'rc'
    use_nonorthogonal_correction = true
  []
  [v_pressure]
    type = LinearFVMomentumPressure
    variable = vel_y
    pressure = pressure
    momentum_component = 'y'
  []

  [p_diffusion]
    type = LinearFVAnisotropicDiffusion
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
[]

[LinearFVBCs]
  [inlet_x]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'left_boundary'
    functor = 'inlet_function'
  []
  [inlet_y]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'left_boundary'
    functor = 0
  []
  [circle_x]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'circle_solid'
    functor = 0
  []
  [circle_y]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'circle_solid'
    functor = 0
  []
  [jet_top_x]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'cylinder_jet_top'
    functor = 'jet_top_x'
  []
  [jet_top_y]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'cylinder_jet_top'
    functor = 'jet_top_y'
  []
  [jet_bottom_x]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'cylinder_jet_bottom'
    functor = 'jet_bottom_x'
  []
  [jet_bottom_y]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'cylinder_jet_bottom'
    functor = 'jet_bottom_y'
  []
  [walls_x]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_x
    boundary = 'top_boundary bottom_boundary'
    functor = 0
  []
  [walls_y]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    variable = vel_y
    boundary = 'top_boundary bottom_boundary'
    functor = 0
  []
  [outlet_p]
    type = LinearFVAdvectionDiffusionFunctorDirichletBC
    boundary = 'right_boundary'
    variable = pressure
    functor = 0
  []
  [pressure-extrapolation]
    type = LinearFVExtrapolatedPressureBC
    boundary = 'circle_solid cylinder_jet_top cylinder_jet_bottom top_boundary bottom_boundary'
    variable = pressure
    use_two_term_expansion = true
  []
  [outlet_u]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = vel_x
    use_two_term_expansion = false
    boundary = 'right_boundary'
  []
  [outlet_v]
    type = LinearFVAdvectionDiffusionOutflowBC
    variable = vel_y
    use_two_term_expansion = false
    boundary = 'right_boundary'
  []
[]

[Postprocessors]
  [drag_force]
    type = IntegralDirectedSurfaceForce
    vel_x = vel_x
    vel_y = vel_y
    mu = ${mu}
    pressure = pressure
    principal_direction = '1 0 0'
    boundary = 'circle_solid cylinder_jet_top cylinder_jet_bottom'
    outputs = none
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [drag_coeff]
    type = ParsedPostprocessor
    expression = '2*drag_force/rho/(avgvel*avgvel)/D'
    constant_names = 'rho avgvel D'
    constant_expressions = '${rho} ${fparse 2/3*inlet_velocity} ${fparse 2*circle_radius}'
    pp_names = 'drag_force'
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [lift_force]
    type = IntegralDirectedSurfaceForce
    vel_x = vel_x
    vel_y = vel_y
    mu = ${mu}
    pressure = pressure
    principal_direction = '0 1 0'
    boundary = 'circle_solid cylinder_jet_top cylinder_jet_bottom'
    outputs = none
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [lift_coeff]
    type = ParsedPostprocessor
    expression = '2*lift_force/rho/(avgvel*avgvel)/D'
    constant_names = 'rho avgvel D'
    constant_expressions = '${rho} ${fparse 2/3*inlet_velocity} ${fparse 2*circle_radius}'
    pp_names = 'lift_force'
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [jet_mfr_action]
    type = FunctionValuePostprocessor
    function = jet_mfr_control
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [reward_instant]
    type = ParsedPostprocessor
    expression = '-drag_coeff - lift_weight*abs(lift_coeff)'
    constant_names = 'lift_weight'
    constant_expressions = '${reward_lift_weight}'
    pp_names = 'drag_coeff lift_coeff'
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [reward]
    type = CylinderDRLReward
    drag = drag_coeff
    lift = lift_coeff
    timestep_window = ${drl_control_period_steps}
    drag_baseline = ${reward_drag_baseline}
    lift_weight = ${reward_lift_weight}
    execute_on = 'INITIAL TIMESTEP_END'
  []
[]

!include drl_probes.i

[Reporters]
  [drl_data]
    type = AccumulateReporter
    reporters = 'drag_coeff/value lift_coeff/value reward/value reward_instant/value jet_mfr_action/value
                 probe0_p/value probe1_p/value probe2_p/value probe3_p/value probe4_p/value'
  []
[]

[Executioner]
  type = PIMPLE
  momentum_l_abs_tol = 1e-7
  pressure_l_abs_tol = 1e-7
  momentum_l_tol = 1e-7
  pressure_l_tol = 1e-7
  rhie_chow_user_object = 'rc'
  momentum_systems = 'u_system v_system'
  pressure_system = 'pressure_system'
  momentum_equation_relaxation = 0.9
  pressure_variable_relaxation = 1.0
  num_iterations = 100
  pressure_absolute_tolerance = 5e-6
  momentum_absolute_tolerance = 5e-6
  momentum_petsc_options_iname = '-pc_type -pc_hypre_type'
  momentum_petsc_options_value = 'hypre boomeramg'
  pressure_petsc_options_iname = '-pc_type -pc_hypre_type'
  pressure_petsc_options_value = 'hypre boomeramg'
  print_fields = false
  continue_on_max_its = true
  # BDF2 resolves the lift/drag peaks well enough here at the validation timestep.
  # A dt = 5e-4 run also passes, but dt = 1e-3 halves the training rollout cost.
  scheme = 'bdf2'
  dt = 0.001
  num_steps = ${run_steps}
[]

[Outputs]
  console = false
  [csv]
    type = CSV
    file_base = '${drl_file_base}_csv'
    execute_on = 'TIMESTEP_END FINAL'
    execute_vector_postprocessors_on = none
    show = 'drag_coeff jet_mfr_action lift_coeff reward reward_instant
            probe0_p probe1_p probe2_p probe3_p probe4_p'
  []
  [probe_csv]
    type = CSV
    file_base = '${drl_file_base}_probes'
    execute_on = FINAL
    execute_postprocessors_on = none
    execute_vector_postprocessors_on = FINAL
    show = 'observation_probes'
    create_final_symlink = true
  []
  [reporter_json]
    type = JSON
    file_base = '${drl_file_base}_reporters'
    execute_on = FINAL
  []
  # exodus = true
  checkpoint = true
[]
