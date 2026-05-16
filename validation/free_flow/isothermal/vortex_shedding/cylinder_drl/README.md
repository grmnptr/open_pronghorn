# Cylinder DRL Baseline

This directory is a linearFV MOOSE starting point for reproducing the
`Cylinder2DFlowControlDRL` baseline flow around a cylinder before adding an RL
control loop.

The geometry and fluid properties follow the existing validation case and the
old DRL source scaling: cylinder radius `0.05`, channel length `2.2`, channel
height `0.41`, parabolic inlet with bulk velocity `1.0`, `rho = 1`, `mu = 1e-3`,
and Reynolds number `100` based on cylinder diameter.

The main run path is:

```bash
mpiexec -n 8 ../../../../../open_pronghorn-opt -i mesh_only.i --mesh-only cylinder_drl_mesh.e
mpiexec -n 8 ../../../../../open_pronghorn-opt -i flow.i
./check_coefficients.py flow_csv.csv
```

Use `flow.i` to run from the beginning. Use `flow_restart.i` to start from the
saved checkpoint:

```bash
mpiexec -n 8 ../../../../../open_pronghorn-opt -i flow_restart.i
```

Both wrappers default to `run_steps = 7000`. The restart wrapper defaults to
`flow_out_cp/7000`, then runs `run_steps` transient steps from that saved state.
Override either value on the command line:

```bash
mpiexec -n 8 ../../../../../open_pronghorn-opt -i flow_restart.i checkpoint_file_base=flow_out_cp/6999 run_steps=1000
```

Checkpoint restarts are partition-specific, so restart with the same MPI rank
count used to write the checkpoint.

The RL actuation hooks follow the paper/source setup: two cylinder-normal jets
centered at 90 and 270 degrees. The target paper width is 10 degrees; this
efficient 32-sector cylinder mesh resolves each jet as four cylinder faces,
which gives an effective width of 11.25 degrees. The mesh contains three
cylinder sidesets for this:

- `cylinder_jet_top`
- `cylinder_jet_bottom`
- `circle_solid`

The cylinder boundary is intentionally split into non-overlapping sidesets
because linearFV does not support multiple boundary IDs on the same face. Drag,
lift, and pressure extrapolation use the union of `circle_solid`,
`cylinder_jet_top`, and `cylinder_jet_bottom`. The no-slip velocity condition is
applied only to `circle_solid`; the two jet patches use parabolic-like radial
velocity profiles that default to zero mass flow. Set the jet controls from the
command line:

```bash
mpiexec -n 8 ../../../../../open_pronghorn-opt -i flow_restart.i \
  checkpoint_file_base=flow_out_cp/7000 run_steps=1000 \
  jet_mfr=1e-3
```

The public environment action is `jet_mfr`. The input applies
the controllable `Functions/jet_mfr_control/value` to the top jet and its
negative to the bottom jet, enforcing zero net synthetic-jet mass flow.

The DRL data hooks are included in `flow_common.i`:

- `jet_mfr_action`: the scalar action written to CSV
- `reward`: completed action-window reward from `CylinderDRLReward`,
  `reward_drag_baseline - mean(drag_coeff) - 0.2*abs(mean(lift_coeff))`
- `reward_instant`: diagnostic instantaneous `-drag_coeff - 0.2*abs(lift_coeff)`
- `observation_probes`: the reduced five pressure probes from the source/paper
  layout, sampled at `INITIAL` and every timestep and sorted by probe id for
  final CSV output
- `probe0_p` through `probe4_p`: scalar pressure probe postprocessors used as
  libtorch DRL observation components
- `drl_data`: an `AccumulateReporter` with scalar histories for
  stochastic-tools/MultiApp training workflows

The scalar CSV is written every timestep. The probe sampler executes every
timestep, but only the final probe values are written by the `probe_csv` output.
The accumulated reporter history is written at finalization as JSON.
For an RL loop, run one action interval, then collect the final observation and
a windowed reward:

```bash
mpiexec -n 8 ../../../../../open_pronghorn-opt -i flow_restart.i \
  checkpoint_file_base=flow_out_cp/7000 run_steps=25 \
  jet_mfr=1e-4 drl_file_base=action_0001 Outputs/file_base=action_0001_state
./collect_drl_data.py action_0001_csv.csv --summary-only
```

The collector computes the source-style action-window reward from the last 25
scalar samples by default. Override that with `--window-steps`:

```text
reward_windowed = -mean(drag_coeff) - 0.2*abs(mean(lift_coeff))
```

For a stochastic-tools trainer, use the accumulated scalar probe reporter fields
as observations. They follow the same `AccumulateReporter` name pattern as the
shipped DRL example:

```text
drl_data/reward:value
drl_data/jet_mfr_action:value
drl_data/probe0_p:value
...
drl_data/probe4_p:value
```

`flow_controlled.i` is the sub-app input for stochastic-tools training. It
restarts from `flow_out_cp/7000`, runs 2000 steps by default, and includes
`drl_control.i`, which adds the `LibtorchDRLControl`, log-probability
postprocessor, and `drl_policy_data` accumulator. The trainer driver is
`trainer.i`:

```bash
export OMP_NUM_THREADS=1
mpiexec -n 8 ../../../../../open_pronghorn-opt -i trainer.i
```

The application must be built with `STOCHASTIC_TOOLS := yes` for these inputs;
the trainer uses stochastic-tools libtorch DRL objects in both the main app and
the controlled sub-app. `trainer.i` suppresses sub-app CSV, probe CSV, reporter
JSON, and checkpoint output during rollouts because the trainer receives the
accumulated reporter data by transfer.

The DRL settings follow the cloned Python example while keeping only the reduced
5-pressure-probe observation vector. The probes are at `(0, 0.07)`,
`(0, -0.07)`, `(0.075, 0.1)`, `(0.075, 0)`, and `(0.075, -0.1)`. The original
example uses `dt = 5e-4`, 80 actions per episode, 50 solver steps per action,
`smooth_control = 0.1`, action bounds `[-1e-2, 1e-2]`, 20 episodes per PPO
update, 25 optimization passes, a 512x512 actor, and a 32x32 critic. This MOOSE
input uses `dt = 1e-3`, so the equivalent physical action interval is 25 solver
steps. The per-step relaxation is adjusted to `1 - (1 - 0.1)^2 = 0.19`, giving
the same physical relaxation over the longer timestep. During training, the
OpenPronghorn `CylinderDRLReward` postprocessor computes the completed
action-window reward, and the stochastic-tools trainer simply downsamples that
scalar at action boundaries.

The trainer transfers these policy reporters from the sub-app:

```text
drl_policy_data/probe0_p:value ... drl_policy_data/probe4_p:value
drl_policy_data/jet_mfr_policy_action:value
drl_policy_data/jet_mfr_log_probability:value
drl_policy_data/reward:value
drl_policy_data/reward_instant:value
drl_policy_data/drag_coeff:value
drl_policy_data/lift_coeff:value
```

`flow_generated_mesh.i` runs directly from the mesh generators. `flow.i` loads
`cylinder_drl_mesh.e` with `FileMeshGenerator`, which is the safer workflow for
iterating on the mesh once it has passed a `--mesh-only` check.

The expected developed-wake checks are:

- maximum drag coefficient in `[3.22, 3.24]`
- maximum absolute lift coefficient in `[0.99, 1.01]`

The mesh keeps the validation case's stitched central topology and coarsens the
downstream generated blocks. The near-cylinder resolution comes from the
validation case's concentric-circle mesh; post-stitch sideset refinement was
avoided because it can introduce fragile AMR/stitching behavior for this solve.
The timestep is `dt = 1e-3` with `scheme = 'bdf2'`. A `dt = 5e-4` run also
passes the same peak checks, but `dt = 1e-3` halves the rollout step count while
retaining the corrected validation targets for peak drag and lift. Console
output is disabled by default to avoid residual-log overhead during training.
