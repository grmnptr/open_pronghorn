[StochasticTools]
[]

rollout_steps = 2000
checkpoint_file_prefix = 'flow_out_cp'
training_iterations = 2000
parallel_rollouts = 10

drl_control_period_steps = 25
drl_action_smoother = 0.19
drl_action_scale = 1.0
drl_min_action = -1e-2
drl_max_action = 1e-2
reward_lift_weight = 0.2
reward_drag_baseline = 3.205

[Samplers]
  [rollouts]
    type = CartesianProduct
    # checkpoint_step = 5250, 5500, ..., 7500
    linear_space_items = '5250 250 ${parallel_rollouts}'
    execute_on = 'INITIAL PRE_MULTIAPP_SETUP'
  []
[]

[MultiApps]
  [runner]
    type = SamplerFullSolveMultiApp
    sampler = rollouts
    input_files = 'flow_controlled.i'
    mode = batch-reset
    cli_args = 'run_steps=${rollout_steps};checkpoint_file_prefix=${checkpoint_file_prefix};drl_control_period_steps=${drl_control_period_steps};drl_action_smoother=${drl_action_smoother};drl_action_scale=${drl_action_scale};drl_min_action=${drl_min_action};drl_max_action=${drl_max_action};reward_lift_weight=${reward_lift_weight};reward_drag_baseline=${reward_drag_baseline};Outputs/checkpoint/enable=false;Outputs/csv/execute_on=none;Outputs/probe_csv/execute_on=none;Outputs/reporter_json/execute_on=none'
  []
[]

[Controls]
  [checkpoint_step]
    type = MultiAppSamplerControl
    multi_app = runner
    sampler = rollouts
    param_names = 'checkpoint_step'
  []
[]

[Transfers]
  [nn_transfer]
    type = SamplerDRLControlTransfer
    to_multi_app = runner
    trainer_name = nn_trainer
    control_name = src_control
    sampler = rollouts
  []
  [r_transfer]
    type = SamplerReporterTransfer
    from_multi_app = runner
    sampler = rollouts
    stochastic_reporter = storage
    from_reporter = 'drl_policy_data/probe0_p:value
                     drl_policy_data/probe1_p:value
                     drl_policy_data/probe2_p:value
                     drl_policy_data/probe3_p:value
                     drl_policy_data/probe4_p:value
                     drl_policy_data/jet_mfr_action:value
                     drl_policy_data/jet_mfr_policy_action:value
                     drl_policy_data/jet_mfr_log_probability:value
                     drl_policy_data/reward:value
                     drl_policy_data/reward_instant:value
                     drl_policy_data/drag_coeff:value
                     drl_policy_data/lift_coeff:value'
  []
[]

[Trainers]
  [nn_trainer]
    type = LibtorchDRLControlTrainer
    observation = 'storage/r_transfer:drl_policy_data:probe0_p:value
                   storage/r_transfer:drl_policy_data:probe1_p:value
                   storage/r_transfer:drl_policy_data:probe2_p:value
                   storage/r_transfer:drl_policy_data:probe3_p:value
                   storage/r_transfer:drl_policy_data:probe4_p:value'
    control = 'storage/r_transfer:drl_policy_data:jet_mfr_policy_action:value'
    log_probability = 'storage/r_transfer:drl_policy_data:jet_mfr_log_probability:value'
    reward = 'storage/r_transfer:drl_policy_data:reward:value'

    input_timesteps = 1
    observation_shift_factors = '0 0 0 0 0'
    observation_scaling_factors = '1 1 1 1 1'
    action_scaling_factors = ${drl_action_scale}
    min_control_value = ${drl_min_action}
    max_control_value = ${drl_max_action}

    num_epochs = 5
    update_frequency = 2

    decay_factor = 0.99
    lambda_factor = 0.97
    clip_parameter = 0.2
    timestep_window = ${drl_control_period_steps}
    average_reward_over_timestep_window = false

    critic_learning_rate = 0.001
    num_critic_neurons_per_layer = '32 32'
    critic_activation_functions = 'relu relu'

    control_learning_rate = 0.001
    num_control_neurons_per_layer = '512 512'
    control_activation_functions = 'relu relu'

    standardize_advantage = false
    batch_size = 320
    entropy_coeff = 0.01
    filename_base = 'cylinder_drl'
    read_from_file = false
  []
[]

[Reporters]
  [storage]
    type = StochasticReporter
    parallel_type = ROOT
    outputs = none
  []
  [reward]
    type = DRLRewardReporter
    drl_trainer_name = nn_trainer
  []
[]

[Executioner]
  type = Transient
  num_steps = ${training_iterations}
[]

[Outputs]
  checkpoint = false
  [json]
    type = JSON
    file_base = 'train_out'
    time_step_interval = 1
    execute_on = TIMESTEP_END
  []
[]
