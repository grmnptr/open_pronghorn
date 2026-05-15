[Postprocessors]
  [probe0_vel_x]
    type = PointValue
    point = '0.15 -0.1 0'
    variable = vel_x
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe0_vel_y]
    type = PointValue
    point = '0.15 -0.1 0'
    variable = vel_y
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe1_vel_x]
    type = PointValue
    point = '0.15 -0.05 0'
    variable = vel_x
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe1_vel_y]
    type = PointValue
    point = '0.15 -0.05 0'
    variable = vel_y
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe2_vel_x]
    type = PointValue
    point = '0.15 0 0'
    variable = vel_x
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe2_vel_y]
    type = PointValue
    point = '0.15 0 0'
    variable = vel_y
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe3_vel_x]
    type = PointValue
    point = '0.15 0.05 0'
    variable = vel_x
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe3_vel_y]
    type = PointValue
    point = '0.15 0.05 0'
    variable = vel_y
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe4_vel_x]
    type = PointValue
    point = '0.15 0.1 0'
    variable = vel_x
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe4_vel_y]
    type = PointValue
    point = '0.15 0.1 0'
    variable = vel_y
    execute_on = 'INITIAL TIMESTEP_END'
  []
[]

[VectorPostprocessors]
  [observation_probes]
    type = PointValueSampler
    variable = 'vel_x vel_y'
    points = '0.15 -0.1 0
              0.15 -0.05 0
              0.15 0 0
              0.15 0.05 0
              0.15 0.1 0'
    sort_by = id
    execute_on = 'INITIAL TIMESTEP_END'
  []
[]
