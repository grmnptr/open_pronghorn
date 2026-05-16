[Postprocessors]
  [probe0_p]
    type = PointValue
    point = '0 0.07 0'
    variable = pressure
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe1_p]
    type = PointValue
    point = '0 -0.07 0'
    variable = pressure
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe2_p]
    type = PointValue
    point = '0.075 0.1 0'
    variable = pressure
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe3_p]
    type = PointValue
    point = '0.075 0 0'
    variable = pressure
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [probe4_p]
    type = PointValue
    point = '0.075 -0.1 0'
    variable = pressure
    execute_on = 'INITIAL TIMESTEP_END'
  []
[]

[VectorPostprocessors]
  [observation_probes]
    type = PointValueSampler
    variable = 'pressure'
    points = '0 0.07 0
              0 -0.07 0
              0.075 0.1 0
              0.075 0 0
              0.075 -0.1 0'
    sort_by = id
    execute_on = 'INITIAL TIMESTEP_END'
  []
[]
