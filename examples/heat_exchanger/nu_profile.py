#!/usr/bin/env python3
"""Tube-side Nusselt number profile Nu(z) from heat_exchanger_na_laminar_out.e.

For every tube and every axial mesh layer this script evaluates

    Nu = q'' * D_i / (k * (T_w - T_b))

with
  q''  wall heat flux into the bore, from the radial temperature gradient
       between the two outermost bore cell rings, scaled from the mid-ring
       radius to the wall radius (radial flux * r is constant in a thin ring),
  T_w  wall temperature, extrapolated from the wall-adjacent cell ring to the
       wall: T_adj + q'' * d_f / k, with d_f the cell-centroid-to-wall distance,
  T_b  velocity-weighted bulk temperature of the bore, sum(w T A) / sum(w A).

A second flux estimate, q''_energy = (rho cp sum(w A)) dT_b/dz / (pi D_i), is
printed as a cross-check; it neglects axial conduction (Pe_tube ~ 7.5).

LinearFVRobinCHTBC approximates the interface face temperature by the adjacent
cell value, so the fluid- and solid-side wall cells converge to the same
temperature and the CHT interface functors are face-only (not in Exodus); the
wall state is therefore reconstructed from the bore cells here.

--wall solid (for heat_exchanger_na_turbulent.i, Dirichlet-Neumann CHT and a
single wall-function cell layer in the bore) takes instead
  q''  the energy-balance flux q''_energy above (axial conduction is
       negligible at Pe_tube ~ 320),
  T_w  from the innermost tube-wall (solid) cell ring, extrapolated to the
       bore radius with the conduction resistance of the cylinder:
       T_w = T_s1 - q'' R_i ln(r_s1/R_i) / k_s.
The fluid-side ring gradient is not usable there: k_eff varies across the
wall-adjacent cell and the bore has one coarse wall layer.

Usage: python nu_profile.py [exodus_file] [--csv out.csv] [--wall fluid|solid]
Reads the Exodus (netCDF classic) file with scipy, no SEACAS needed.
"""

import argparse
import math

import numpy as np
from scipy.io import netcdf_file

# geometry and properties; keep in sync with heat_exchanger_na_laminar.i
TUBE_IR = 0.007061
PITCH = 0.0223
K_FLUID = 68.3
K_SOLID = 28.0
RHO = 852.9
CP = 1278.0

TUBE_CENTERS = [(0.0, 0.0)] + [
    (PITCH * math.cos(math.radians(60 * i)), PITCH * math.sin(math.radians(60 * i)))
    for i in range(6)
]


def names(var):
    return [b"".join(row).decode().strip("\x00 ") for row in var[:]]


def read(path):
    nc = netcdf_file(path, "r", mmap=False)
    v = nc.variables
    xyz = np.stack([v["coordx"][:], v["coordy"][:], v["coordz"][:]], axis=1)
    blocks = names(v["eb_names"])
    elem_vars = names(v["name_elem_var"])
    last = v["time_whole"].shape[0] - 1

    cells = {}
    for ib, bname in enumerate(blocks, start=1):
        conn = v[f"connect{ib}"][:] - 1
        nodes = xyz[conn]
        n_bottom = conn.shape[1] // 2  # HEX8 -> 4, WEDGE6 -> 3
        centroid = nodes.mean(axis=1)
        # extruded cells: cross-section area from the bottom polygon (shoelace)
        px, py = nodes[:, :n_bottom, 0], nodes[:, :n_bottom, 1]
        area = 0.5 * np.abs(
            np.sum(px * np.roll(py, -1, axis=1) - np.roll(px, -1, axis=1) * py, axis=1)
        )
        data = {"centroid": centroid, "area": area}
        for iv, vname in enumerate(elem_vars, start=1):
            key = f"vals_elem_var{iv}eb{ib}"
            if key in v:
                data[vname] = v[key][last].copy()
        cells[bname] = data
    nc.close()
    return cells


def tube_index(c):
    d = [np.hypot(c[:, 0] - x, c[:, 1] - y) for x, y in TUBE_CENTERS]
    d = np.stack(d, axis=1)
    return np.argmin(d, axis=1), np.min(d, axis=1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("exodus", nargs="?", default="heat_exchanger_na_laminar_out.e")
    ap.add_argument("--csv", default=None)
    ap.add_argument("--wall", choices=("fluid", "solid"), default="fluid")
    args = ap.parse_args()

    cells = read(args.exodus)
    # the bore is one block (square quad center); older meshes also had a
    # separate triangular center block
    bore_blocks = [b for b in ("tube_fluid", "tube_fluid_core") if b in cells]
    bore = {
        k: np.concatenate([cells[b][k] for b in bore_blocks])
        for k in ("centroid", "area", "T_fluid", "vel_z")
    }
    wall = cells["tube_wall"]

    z_layers = np.unique(np.round(bore["centroid"][:, 2], 9))
    bi, br = tube_index(bore["centroid"])
    wi, wr = tube_index(wall["centroid"])
    bz = np.round(bore["centroid"][:, 2], 9)
    wz = np.round(wall["centroid"][:, 2], 9)

    # Group bore cells into radial layers. Centroid radii within one layer
    # scatter (polygon-based rings with preserve_volumes are not exact
    # circles; ~0.03 mm on 24 sectors), so a new layer starts where
    # consecutive sorted radii jump by more than RING_GAP. The thinnest wall
    # layer is ~0.2 mm, so 0.1 mm separates layers without splitting one.
    RING_GAP = 1e-4
    rs = np.sort(np.unique(np.round(br, 9)))
    starts = np.concatenate([[0], np.nonzero(np.diff(rs) > RING_GAP)[0] + 1])
    layer_lo = rs[starts]
    layer_of = np.searchsorted(layer_lo, np.round(br, 9), side="right") - 1
    ring1 = layer_of == len(layer_lo) - 1  # wall-adjacent layer
    ring2 = layer_of == len(layer_lo) - 2  # next layer inward
    r1, r2 = br[ring1].mean(), br[ring2].mean()
    d_f = TUBE_IR - r1
    # innermost solid cell ring of the tube wall
    ws = np.sort(np.unique(np.round(wr, 9)))
    wstarts = np.concatenate([[0], np.nonzero(np.diff(ws) > RING_GAP)[0] + 1])
    w_lo = ws[wstarts]
    wring1 = (np.searchsorted(w_lo, np.round(wr, 9), side="right") - 1) == 0
    r_s1 = wr[wring1].mean()

    rows = []
    for z in z_layers:
        nu_t, tb_t, tw_t, q_t, mcp_t, T_s1 = [], [], [], [], [], []
        for t in range(len(TUBE_CENTERS)):
            m = (bi == t) & (bz == z)
            w, T, A = bore["vel_z"][m], bore["T_fluid"][m], bore["area"][m]
            T_b = np.sum(w * T * A) / np.sum(w * A)
            T1 = bore["T_fluid"][m & ring1].mean()
            T2 = bore["T_fluid"][m & ring2].mean()
            q = K_FLUID * (T1 - T2) / (r1 - r2) * (0.5 * (r1 + r2) / TUBE_IR)
            T_w = T1 + q * d_f / K_FLUID
            nu_t.append(q * 2 * TUBE_IR / (K_FLUID * (T_w - T_b)))
            T_s1.append(wall["T_solid"][(wi == t) & (wz == z) & wring1].mean())
            tb_t.append(T_b)
            tw_t.append(T_w)
            q_t.append(q)
            mcp_t.append(RHO * CP * np.sum(w * A))
        rows.append([z, np.mean(tb_t), np.mean(tw_t), np.mean(q_t), np.nan, nu_t[0], np.mean(nu_t[1:])])
        rows[-1].append((tb_t, T_s1, mcp_t))
    # energy-balance flux from central differences of the bulk temperature
    zs = np.array([r[0] for r in rows])
    tb = np.array([r[1] for r in rows])
    dTdz = np.gradient(tb, zs)
    # per-tube bulk temperatures, for per-tube energy-balance fluxes
    tbs = np.array([r[-1][0] for r in rows])
    dTdz_t = np.gradient(tbs, zs, axis=0)
    for r, g, gt in zip(rows, dTdz, dTdz_t):
        tb_t, T_s1, mcp_t = r.pop()
        r[4] = np.mean(mcp_t) * g / (math.pi * 2 * TUBE_IR)
        if args.wall == "solid":
            q_t = np.array(mcp_t) * gt / (math.pi * 2 * TUBE_IR)
            T_w = np.array(T_s1) - q_t * TUBE_IR * math.log(r_s1 / TUBE_IR) / K_SOLID
            nu_t = q_t * 2 * TUBE_IR / (K_FLUID * (T_w - np.array(tb_t)))
            r[2], r[3], r[5], r[6] = np.mean(T_w), np.mean(q_t), nu_t[0], np.mean(nu_t[1:])

    hdr = "z_m,T_bulk_K,T_wall_K,q_wall_W_m2,q_energy_W_m2,Nu_center_tube,Nu_ring_tubes"
    print(hdr)
    for r in rows:
        print(",".join(f"{x:.6g}" for x in r))
    if args.csv:
        np.savetxt(args.csv, np.array(rows), delimiter=",", header=hdr, comments="")


if __name__ == "__main__":
    main()
