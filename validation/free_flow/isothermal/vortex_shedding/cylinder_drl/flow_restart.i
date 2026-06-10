checkpoint_file_prefix = 'flow_out_cp'
checkpoint_step = 7000
checkpoint_file_base = '${checkpoint_file_prefix}/${checkpoint_step}'
run_steps = 7000

!include flow_params.i
!include mesh_file.i
!include problem_restart.i
!include flow_common.i
