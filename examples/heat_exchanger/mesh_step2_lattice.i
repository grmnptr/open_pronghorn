##########################################################
# Heat exchanger CHT mesh build-up, step 2: tile the
# single pin into a 7-tube hexagonal lattice (1 center +
# 6 surrounding), zig-zag outer boundary (no hex duct).
##########################################################

tube_ir = 0.008   # tube inner radius (bore)
tube_or = 0.010   # tube outer radius (wall)
pitch   = 0.025   # hex lattice pitch (center-to-center tube spacing)

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
  []
  [lattice]
    type = PatternedHexMeshGenerator
    inputs = 'pin'
    pattern = '0 0;
              0 0 0;
               0 0'
    pattern_boundary = none
  []
[]

[Outputs]
  exodus = true
[]
