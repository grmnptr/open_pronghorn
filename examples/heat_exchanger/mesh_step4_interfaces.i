##########################################################
# Heat exchanger CHT mesh build-up, step 4: add explicit
# named CHT interfaces between tube_fluid/tube_wall and
# tube_wall/shell_fluid.
##########################################################

tube_ir = 0.008   # tube inner radius (bore)
tube_or = 0.010   # tube outer radius (wall)
pitch   = 0.025   # hex lattice pitch (center-to-center tube spacing)
shell_radius = 0.045 # shell barrel inner radius

[Mesh]
  [pin]
    type = PolygonConcentricCircleMeshGenerator
    num_sides = 6
    num_sectors_per_side = '4 4 4 4 4 4'
    background_intervals = 2
    ring_radii = '${tube_ir} ${tube_or}'
    ring_intervals = '2 1'
    ring_block_ids = '1 2'
    ring_block_names = 'tube_fluid tube_wall'
    background_block_ids = 3
    background_block_names = shell_fluid
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
    peripheral_layer_num = 4
    peripheral_ring_radius = ${shell_radius}
    peripheral_ring_block_id = 3
    peripheral_ring_block_name = shell_fluid
    external_boundary_id = 20000
    external_boundary_name = shell_wall
  []
  [tube_interface]
    type = SideSetsBetweenSubdomainsGenerator
    input = shell
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
[]

[Outputs]
  exodus = true
[]
