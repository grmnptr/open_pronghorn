# -----------------------------------------------------------------------------
# Libtorch DRL control hook for stochastic-tools training
# -----------------------------------------------------------------------------
drl_action_smoother = 0.19
drl_action_scale = 1.0
drl_min_action = -1e-2
drl_max_action = 1e-2

[Postprocessors]
  [jet_mfr_policy_action]
    type = LibtorchControlValuePostprocessor
    control_name = src_control
    execute_on = 'INITIAL TIMESTEP_END'
  []
[]

[Controls]
  [src_control]
    type = LibtorchDRLControl
    parameters = 'Functions/jet_mfr_control/value'
    observations = 'probe0_p probe1_p probe2_p probe3_p probe4_p'

    input_timesteps = 1
    observation_shift_factors = '0 0 0 0 0'
    observation_scaling_factors = '1 1 1 1 1'
    action_scaling_factors = ${drl_action_scale}
    min_control_value = ${drl_min_action}
    max_control_value = ${drl_max_action}

    num_steps_in_period = ${drl_control_period_steps}
    smoother = ${drl_action_smoother}
    stochastic = false

    num_neurons_per_layer = '512 512'
    activation_function = 'relu relu'

    filename = cylinder_drl_control.net

    execute_on = 'TIMESTEP_BEGIN'
  []
[]