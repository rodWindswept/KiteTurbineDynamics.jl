### A Pluto.jl notebook ###
# v1.0.3

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ c9092282-7b74-11f1-973b-e9815e6ced55
begin
	import Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
	using KiteTurbineDynamics
	using PlutoUI
	using MeshCat
	using MeshCat.GeometryBasics
	using LinearAlgebra
	using Colors
	using CoordinateTransformations
	using Rotations
	using Printf
	using JSON3
	include(joinpath(@__DIR__, "..", "scripts", "builders_util.jl"))
	html"🚀 Environment initialized successfully!"
end

# ╔═╡ 00000000-0000-0000-0000-000000000003
begin
	# Instantiate the visualizer. Returning render(vis) embeds the 3D iframe inside the cell.
	vis = Visualizer()
	render(vis)
end

# ╔═╡ 00000000-0000-0000-0000-000000000004
md"""
### Preset Configuration
Select a base design configuration to load:
"""

# ╔═╡ 00000000-0000-0000-0000-000000000005
@bind preset Select([
	"10 kW Prototype" => "10kw",
	"50 kW Scaled Target" => "50kw",
	"50 kW V6 Campaign" => "v6_50kw",
	"10 kW V5 Safe" => "v5_safe",
	"V10 Tight (viable 50kW candidate)" => "v10_tight",
	"V10 Reinforced (viable 50kW)" => "v10_reinforced",
	"λ=0.69 (stable lead candidate)" => "0.69",
	"λ=0.69 Reinforced (stable 50kW)" => "0.69_reinforced"
], default="10kw")

# ╔═╡ 00000000-0000-0000-0000-000000000006
md"""
### Design Parameter Overrides
Adjust the design parameters to tweak the physical structure:
"""

# ╔═╡ 00000000-0000-0000-0000-000000000007
begin
	# Load base preset
	sys_preset, u0_preset, p_preset = if preset == "v10_tight"
		sys, u0, p, _ = build_v10_tight_no_lowest(blade_scale=1.0, tether_diameter=0.003, r_bottom_scale=1.0)
		sys, u0, p
	elseif preset == "v10_reinforced"
		sys, u0, p, _ = build_v10_tight_no_lowest(blade_scale=1.0, tether_diameter=0.004, r_bottom_scale=1.3)
		sys, u0, p
	elseif preset == "0.69"
		sys, u0, p, _ = build_v10_tight_no_lowest(blade_scale=0.69, tether_diameter=0.003, r_bottom_scale=1.0)
		sys, u0, p
	elseif preset == "0.69_reinforced"
		sys, u0, p, _ = build_v10_tight_no_lowest(blade_scale=0.69, tether_diameter=0.004, r_bottom_scale=1.3)
		sys, u0, p
	elseif preset == "10kw"
		p = params_10kw()
		sys, u0 = build_kite_turbine_system(p)
		sys, u0, p
	elseif preset == "50kw"
		p = params_50kw()
		sys, u0 = build_kite_turbine_system(p)
		sys, u0, p
	elseif preset == "v6_50kw"
		p = params_v6_50kw()
		sys, u0 = build_kite_turbine_system(p)
		sys, u0, p
	else
		p = params_v5_safe_10kw()
		sys, u0 = build_kite_turbine_system(p)
		sys, u0, p
	end

	# Display geometry sliders
	HTML("""
	<div style="background:#12161d; border:1px solid #222a35; border-radius:8px; padding:12px; font-family:sans-serif; color:#e8eef6; margin-bottom:12px">
		<table style="width:100%; font-size:12px; border-collapse:collapse">
			<tr style="border-bottom:1px solid #1b212b">
				<td style="padding:6px"><b>Number of Rings</b></td>
				<td style="padding:6px">$(@bind n_rings Slider(5:25, default=p_preset.n_rings, show_value=true))</td>
			</tr>
			<tr style="border-bottom:1px solid #1b212b">
				<td style="padding:6px"><b>Number of Lines</b></td>
				<td style="padding:6px">$(@bind n_lines Slider(3:8, default=p_preset.n_lines, show_value=true))</td>
			</tr>
			<tr style="border-bottom:1px solid #1b212b">
				<td style="padding:6px"><b>Hub (Rotor) Radius (m)</b></td>
				<td style="padding:6px">$(@bind rotor_radius Slider(1.0:0.1:15.0, default=p_preset.rotor_radius, show_value=true))</td>
			</tr>
			<tr style="border-bottom:1px solid #1b212b">
				<td style="padding:6px"><b>TRPT Hub Ring Radius (m)</b></td>
				<td style="padding:6px">$(@bind trpt_hub_radius Slider(0.5:0.1:10.0, default=p_preset.trpt_hub_radius, show_value=true))</td>
			</tr>
			<tr style="border-bottom:1px solid #1b212b">
				<td style="padding:6px"><b>r/L Geometry Ratio</b></td>
				<td style="padding:6px">$(@bind trpt_rL_ratio Slider(0.2:0.01:1.2, default=p_preset.trpt_rL_ratio, show_value=true))</td>
			</tr>
			<tr style="border-bottom:1px solid #1b212b">
				<td style="padding:6px"><b>Tether Length (m)</b></td>
				<td style="padding:6px">$(@bind tether_length Slider(10.0:1.0:200.0, default=p_preset.tether_length, show_value=true))</td>
			</tr>
			<tr style="border-bottom:1px solid #1b212b">
				<td style="padding:6px"><b>Elevation Angle (deg)</b></td>
				<td style="padding:6px">$(@bind elevation_deg Slider(15:1:75, default=Int(round(rad2deg(p_preset.elevation_angle))), show_value=true))</td>
			</tr>
			<tr style="border-bottom:1px solid #1b212b">
				<td style="padding:6px"><b>Tether Diameter (mm)</b></td>
				<td style="padding:6px">$(@bind tether_diam_mm Slider(1.0:0.1:15.0, default=p_preset.tether_diameter * 1000.0, show_value=true))</td>
			</tr>
			<tr style="border-bottom:1px solid #1b212b">
				<td style="padding:6px"><b>Spacer Ring Mass (kg)</b></td>
				<td style="padding:6px">$(@bind m_ring Slider(0.1:0.05:10.0, default=p_preset.m_ring, show_value=true))</td>
			</tr>
			<tr>
				<td style="padding:6px"><b>Hub Blade Mass (kg)</b></td>
				<td style="padding:6px">$(@bind m_blade Slider(0.5:0.1:20.0, default=p_preset.m_blade, show_value=true))</td>
			</tr>
		</table>
	</div>
	""")
end

# ╔═╡ 00000000-0000-0000-0000-000000000008
md"""
### Operating Wind & Drivetrain Controls
Adjust the wind speed and drivetrain parameters:
"""

# ╔═╡ 00000000-0000-0000-0000-000000000009
HTML("""
<div style="background:#12161d; border:1px solid #222a35; border-radius:8px; padding:12px; font-family:sans-serif; color:#e8eef6; margin-bottom:12px">
	<table style="width:100%; font-size:12px; border-collapse:collapse">
		<tr style="border-bottom:1px solid #1b212b">
			<td style="padding:6px"><b>Wind Speed (m/s)</b></td>
			<td style="padding:6px">$(@bind wind_speed Slider(1.0:0.5:25.0, default=p_preset.v_wind_ref, show_value=true))</td>
		</tr>
		<tr style="border-bottom:1px solid #1b212b">
			<td style="padding:6px"><b>k_mppt gain</b></td>
			<td style="padding:6px">$(@bind k_mppt Slider(1.0:0.5:100.0, default=p_preset.k_mppt, show_value=true))</td>
		</tr>
		<tr>
			<td style="padding:6px"><b>Lifter Elevation (deg)</b></td>
			<td style="padding:6px">$(@bind lifter_elevation_deg Slider(30:1:90, default=Int(round(rad2deg(p_preset.lifter_elevation))), show_value=true))</td>
		</tr>
	</table>
</div>
""")

# ╔═╡ 00000000-0000-0000-0000-000000000010
solve_result = begin
	# Reconstruct SystemParams from custom slider values
	p_custom = override_params(p_preset;
		n_rings = n_rings,
		n_lines = n_lines,
		n_blades = n_lines,
		rotor_radius = rotor_radius,
		trpt_hub_radius = trpt_hub_radius,
		trpt_rL_ratio = trpt_rL_ratio,
		tether_length = tether_length,
		elevation_angle = deg2rad(elevation_deg),
		tether_diameter = tether_diam_mm / 1000.0,
		m_ring = m_ring,
		m_blade = m_blade,
		v_wind_ref = wind_speed,
		k_mppt = k_mppt,
		lifter_elevation = deg2rad(lifter_elevation_deg)
	)

	# Build the system, preserving preset expansion rotors if present
	sys_custom, u0_custom = build_kite_turbine_system(p_custom;
		expansion_rotors = sys_preset.expansion_rotors
	)

	# Setup wind profile and lifter device
	wind_fn_custom = (pos, t) -> begin
		z = max(pos[3], 1.0)
		sh = (z / p_custom.h_ref)^(1.0/7.0)
		[wind_speed * sh, 0.0, 0.0]
	end
	lift_dev = rotary_lifter_default()
	ω_rated = cbrt(p_custom.p_rated_w / p_custom.k_mppt)

	# Solve static equilibrium at operational state (without spokes in settle to avoid objective errors)
	try
		u_start = settle_to_operational_state(sys_custom, u0_custom, p_custom, ω_rated;
											  lift_device = lift_dev,
											  wind_fn = wind_fn_custom)
		(status=:ok, u=u_start, err="")
	catch e
		(status=:error, u=copy(u0_custom), err=string(e))
	end
end

# ╔═╡ 00000000-0000-0000-0000-000000000011
let
	# Trigger redraw in MeshCat whenever solve_result is recalculated
	solve_result
	
	if solve_result.status == :ok
		u_vis = solve_result.u
		N = sys_custom.n_total
		Nr = sys_custom.n_ring
		swl = KiteTurbineDynamics.TETHER_SWL
		
		# Delete old parts
		delete!(vis["tethers"])
		delete!(vis["rings"])
		delete!(vis["blades"])
		delete!(vis["bearing"])
		delete!(vis["lifter"])
		delete!(vis["wind"])
		
		# Render tethers
		for s in 1:(Nr - 1)
			for j in 1:p_custom.n_lines
				xs, ys, zs = KiteTurbineDynamics._rope_line_pts(u_vis, sys_custom, p_custom, s, j)
				points_seg = [ [xs[k], ys[k], zs[k]] for k in 1:5 ]
				T_seg = get_segment_tension(u_vis, sys_custom, p_custom, s, j)
				color_rgb = KiteTurbineDynamics._tension_color(T_seg, swl)
				mc_color = RGB(color_rgb.r, color_rgb.g, color_rgb.b)
				
				seg_points = Point3f[]
				for i in 1:4
					push!(seg_points, Point3f(points_seg[i]...))
					push!(seg_points, Point3f(points_seg[i+1]...))
				end
				width = T_seg < 5.0 ? 1.0 : 2.5
				setobject!(vis["tethers"]["seg_$(s)"]["line_$(j)"], 
						   LineSegments(seg_points, LineBasicMaterial(color=mc_color, linewidth=width)))
			end
		end
		
		# Render rings
		pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u_vis, sys_custom, sys_custom.rotor.node_id, (sys_custom.nodes[sys_custom.rotor.node_id]::RingNode).ring_idx)
		for s in 1:Nr
			gid = sys_custom.ring_ids[s]
			node = sys_custom.nodes[gid]::RingNode
			radius = node.radius
			ctr = u_vis[3*(gid-1)+1 : 3*gid]
			α = u_vis[6N + node.ring_idx]
			
			ring_color = s == Nr ? RGB(0.7, 0.1, 0.1) : RGB(0.2, 0.5, 0.8)
			ring_points = Point3f[]
			for j in 1:p_custom.n_lines
				pt1 = attachment_point(ctr, radius, α, j, p_custom.n_lines, pp1, pp2)
				pt2 = attachment_point(ctr, radius, α, mod1(j+1, p_custom.n_lines), p_custom.n_lines, pp1, pp2)
				push!(ring_points, Point3f(pt1...))
				push!(ring_points, Point3f(pt2...))
			end
			width = s == Nr ? 4.0 : 2.0
			setobject!(vis["rings"]["ring_$(s)"], LineSegments(ring_points, LineBasicMaterial(color=ring_color, linewidth=width)))
		end
		
		# Render hub blades
		hub_gid = sys_custom.rotor.node_id
		hub_pos = u_vis[3*(hub_gid-1)+1 : 3*hub_gid]
		α_hub = u_vis[6N + (sys_custom.nodes[hub_gid]::RingNode).ring_idx]
		blade_points = Point3f[]
		for j in 1:p_custom.n_lines
			pt_root = attachment_point(hub_pos, trpt_hub_radius, α_hub, j, p_custom.n_lines, pp1, pp2)
			pt_tip = attachment_point(hub_pos, rotor_radius, α_hub, j, p_custom.n_lines, pp1, pp2)
			push!(blade_points, Point3f(pt_root...))
			push!(blade_points, Point3f(pt_tip...))
		end
		setobject!(vis["blades"], LineSegments(blade_points, LineBasicMaterial(color=RGB(0.27, 0.5, 0.7), linewidth=3.0)))
		
		# Render bearing node
		bgid = sys_custom.bearing_id
		bearing_pos = u_vis[3*(bgid-1)+1 : 3*bgid]
		setobject!(vis["bearing"], HyperSphere(Point3f(bearing_pos...), 0.15f0), MeshLambertMaterial(color=RGB(1.0, 0.84, 0.0)))
		
		# Render lifter line
		sky_gid = sys_custom.sky_anchor_id
		sky_pos = u_vis[3*(sky_gid-1)+1 : 3*sky_gid]
		lifter_line = [Point3f(bearing_pos...), Point3f(sky_pos...)]
		setobject!(vis["lifter"], LineSegments(lifter_line, LineBasicMaterial(color=RGB(1.0, 0.84, 0.0), linewidth=2.0)))
		
		# Render wind arrow
		arrow_start = hub_pos .- [wind_speed, 0.0, 0.0]
		arrow_points = [Point3f(arrow_start...), Point3f(hub_pos...)]
		setobject!(vis["wind"], LineSegments(arrow_points, LineBasicMaterial(color=RGB(1.0, 0.55, 0.0), linewidth=3.0)))
		
		html"<span style='color:green; font-weight:600'>✔ Static operational state rendered successfully in 3D Viewport.</span>"
	else
		html"<span style='color:red; font-weight:600'>✗ Settle failed: $(solve_result.err)</span>"
	end
end

# ╔═╡ 00000000-0000-0000-0000-000000000012
let
	# Display dashboard telemetry HUD
	if solve_result.status == :ok
		u_vis = solve_result.u
		N = sys_custom.n_total
		Nr = sys_custom.n_ring
		T_max, n_slack = get_max_rope_tension(u_vis, sys_custom, p_custom)
		swl = KiteTurbineDynamics.TETHER_SWL
		fos_tether = swl / T_max
		
		ω_hub = u_vis[6N + Nr + Nr]
		P_out_kw = (p_custom.k_mppt * ω_hub^3) / 1000.0
		
		sf = ring_safety_frame(u_vis, u0_custom, sys_custom, p_custom)
		min_ring_fos = minimum(f.fos for f in sf; init=Inf)
		
		HTML("""
		<div style="background:#12161d; border:1px solid #222a35; border-radius:10px; padding:16px; font-family:-apple-system,BlinkMacSystemFont,sans-serif; color:#e8eef6; width:100%; max-width:600px; margin-top:12px">
			<h3 style="margin-top:0; color:#39d0d8; border-bottom:1px solid #222a35; padding-bottom:8px; font-weight:500; font-size:14px; text-transform:uppercase; letter-spacing:0.8px">Settle Equilibrium Metrics</h3>
			<div style="display:grid; grid-template-columns:1fr 1fr; gap:14px">
				<div>
					<span style="font-size:10px; color:#647284; text-transform:uppercase; letter-spacing:0.5px">OUTPUT POWER</span><br/>
					<span style="font-size:24px; font-weight:bold; font-family:monospace; color:#34d399">$(@sprintf("%.2f", P_out_kw)) kW</span>
				</div>
				<div>
					<span style="font-size:10px; color:#647284; text-transform:uppercase; letter-spacing:0.5px">ROTATIONAL SPEED</span><br/>
					<span style="font-size:24px; font-weight:bold; font-family:monospace">$(@sprintf("%.1f", ω_hub * 30/π)) rpm</span>
				</div>
				<div>
					<span style="font-size:10px; color:#647284; text-transform:uppercase; letter-spacing:0.5px">MAX TETHER TENSION</span><br/>
					<span style="font-size:18px; font-weight:bold; font-family:monospace">$(@sprintf("%.0f", T_max)) N</span><br/>
					<span style="font-size:11px; color:$(fos_tether < 1.5 ? "#ff4d4f" : "#34d399")">FoS: $(@sprintf("%.2f", fos_tether))</span>
				</div>
				<div>
					<span style="font-size:10px; color:#647284; text-transform:uppercase; letter-spacing:0.5px">SLACK TETHERS</span><br/>
					<span style="font-size:18px; font-weight:bold; font-family:monospace; color:$(n_slack > 0 ? "#f5b73d" : "#34d399")">$n_slack / $(p_custom.n_lines)</span>
				</div>
				<div>
					<span style="font-size:10px; color:#647284; text-transform:uppercase; letter-spacing:0.5px">MIN RING BUCKLING FoS</span><br/>
					<span style="font-size:18px; font-weight:bold; font-family:monospace; color:$(min_ring_fos < 1.5 ? "#ff4d4f" : "#34d399")">$(@sprintf("%.2f", min_ring_fos))</span>
				</div>
				<div>
					<span style="font-size:10px; color:#647284; text-transform:uppercase; letter-spacing:0.5px">PRESET USED</span><br/>
					<span style="font-size:16px; font-weight:bold; font-family:monospace">$preset</span>
				</div>
			</div>
		</div>
		""")
	else
		HTML("<div style='color:#ff4d4f; font-weight:bold'>✗ Settle failed. No metrics to display.</div>")
	end
end

# ╔═╡ 00000000-0000-0000-0000-000000000013
md"""
### Time-Domain Dynamics Simulation
Check the box below to run a 2.0-second dynamic ODE simulation of this geometry under wind load (with active damping and full non-linear mechanics).
*To maintain fast UI responsiveness when dragging geometry sliders, leave this unchecked while adjusting values.*
"""

# ╔═╡ 00000000-0000-0000-0000-000000000014
@bind run_dynamic CheckBox(default=false)

# ╔═╡ 00000000-0000-0000-0000-000000000015
sim_run_result = let
	is_run = try run_dynamic catch; false end
	if is_run && solve_result.status == :ok
		u_s = solve_result.u
		
		# Simulation setups
		dt_sim = 4e-5
		save_every = 500
		t_total = 2.0
		n_steps = round(Int, t_total / dt_sim)
		
		u_curr = copy(u_s)
		N = sys_custom.n_total
		Nr = sys_custom.n_ring
		du = zeros(Float64, length(u_curr))
		
		sim_frames = [copy(u_curr)]
		t = 0.0
		
		# Set up ODE params
		ode_params = lift_dev === nothing ? (sys_custom, p_custom, wind_fn_custom) : (sys_custom, p_custom, wind_fn_custom, lift_dev)
		bgid = sys_custom.bearing_id
		hub_gid = sys_custom.rotor.node_id
		b_iv = 3N + 3*(bgid-1) + 1
		sd0 = [cos(p_custom.elevation_angle), 0.0, sin(p_custom.elevation_angle)]
		
		# Step-by-step ODE solve
		for step in 1:n_steps
			fill!(du, 0.0)
			multibody_ode!(du, u_curr, ode_params, t)
			t += dt_sim
			
			@views u_curr[(3N + 1):6N] .+= dt_sim .* du[(3N + 1):6N]
			@views u_curr[1:3N] .+= dt_sim .* u_curr[(3N + 1):6N]
			@views u_curr[(6N + Nr + 1):(6N + 2Nr)] .+= dt_sim .* du[(6N + Nr + 1):(6N + 2Nr)]
			@views u_curr[(6N + 1):(6N + Nr)] .+= dt_sim .* u_curr[(6N + Nr + 1):(6N + 2Nr)]
			
			orbital_damp_rope_velocities!(u_curr, sys_custom, p_custom, 0.05)
			@views u_curr[(6N + Nr + 1):(6N + 2Nr)] .*= 1.0
			
			# Bearing transverse damping
			hp = @view u_curr[(3 * (hub_gid - 1) + 1):(3 * hub_gid)]
			hp_m = norm(hp)
			sd = hp_m > 0.1 ? hp ./ hp_m : sd0
			vbx, vby, vbz = u_curr[b_iv], u_curr[b_iv + 1], u_curr[b_iv + 2]
			v_ax_s = vbx*sd[1] + vby*sd[2] + vbz*sd[3]
			u_curr[b_iv] = v_ax_s*sd[1] + 0.99994*(vbx - v_ax_s*sd[1])
			u_curr[b_iv + 1] = v_ax_s*sd[2] + 0.99994*(vby - v_ax_s*sd[2])
			u_curr[b_iv + 2] = v_ax_s*sd[3] + 0.99994*(vbz - v_ax_s*sd[3])
			
			u_curr[1:3] .= 0.0
			u_curr[(3N + 1):(3N + 3)] .= 0.0
			
			if step % save_every == 0
				push!(sim_frames, copy(u_curr))
			end
		end
		
		(status=:ok, frames=sim_frames)
	else
		(status=:error, frames=[])
	end
end

# ╔═╡ 00000000-0000-0000-0000-000000000016
md"""
### Simulation Playback
Scrub through the simulation output below to animate the 3D scene:
"""

# ╔═╡ 00000000-0000-0000-0000-000000000017
@bind frame_idx Slider(1:max(1, length(sim_run_result.frames)), default=1, show_value=true)

# ╔═╡ 00000000-0000-0000-0000-000000000018
let
	# Trigger redraw whenever frame_idx changes
	sim_run_result
	frame_idx
	
	if sim_run_result.status == :ok && !isempty(sim_run_result.frames) && frame_idx <= length(sim_run_result.frames)
		u_frame = sim_run_result.frames[frame_idx]
		
		N = sys_custom.n_total
		Nr = sys_custom.n_ring
		swl = KiteTurbineDynamics.TETHER_SWL
		
		delete!(vis["tethers"])
		delete!(vis["rings"])
		delete!(vis["blades"])
		delete!(vis["bearing"])
		delete!(vis["lifter"])
		delete!(vis["wind"])
		
		# Draw tethers
		for s in 1:(Nr - 1)
			for j in 1:p_custom.n_lines
				xs, ys, zs = KiteTurbineDynamics._rope_line_pts(u_frame, sys_custom, p_custom, s, j)
				points_seg = [ [xs[k], ys[k], zs[k]] for k in 1:5 ]
				T_seg = get_segment_tension(u_frame, sys_custom, p_custom, s, j)
				color_rgb = KiteTurbineDynamics._tension_color(T_seg, swl)
				mc_color = RGB(color_rgb.r, color_rgb.g, color_rgb.b)
				
				seg_points = Point3f[]
				for i in 1:4
					push!(seg_points, Point3f(points_seg[i]...))
					push!(seg_points, Point3f(points_seg[i+1]...))
				end
				width = T_seg < 5.0 ? 1.0 : 2.5
				setobject!(vis["tethers"]["seg_$(s)"]["line_$(j)"], 
						   LineSegments(seg_points, LineBasicMaterial(color=mc_color, linewidth=width)))
			end
		end
		
		# Draw rings
		pp1, pp2 = KiteTurbineDynamics._tilted_ring_basis(u_frame, sys_custom, sys_custom.rotor.node_id, (sys_custom.nodes[sys_custom.rotor.node_id]::RingNode).ring_idx)
		for s in 1:Nr
			gid = sys_custom.ring_ids[s]
			node = sys_custom.nodes[gid]::RingNode
			radius = node.radius
			ctr = u_frame[3*(gid-1)+1 : 3*gid]
			α = u_frame[6N + node.ring_idx]
			
			ring_color = s == Nr ? RGB(0.7, 0.1, 0.1) : RGB(0.2, 0.5, 0.8)
			ring_points = Point3f[]
			for j in 1:p_custom.n_lines
				pt1 = attachment_point(ctr, radius, α, j, p_custom.n_lines, pp1, pp2)
				pt2 = attachment_point(ctr, radius, α, mod1(j+1, p_custom.n_lines), p_custom.n_lines, pp1, pp2)
				push!(ring_points, Point3f(pt1...))
				push!(ring_points, Point3f(pt2...))
			end
			width = s == Nr ? 4.0 : 2.0
			setobject!(vis["rings"]["ring_$(s)"], LineSegments(ring_points, LineBasicMaterial(color=ring_color, linewidth=width)))
		end
		
		# Draw Hub Blades
		hub_gid = sys_custom.rotor.node_id
		hub_pos = u_frame[3*(hub_gid-1)+1 : 3*hub_gid]
		α_hub = u_frame[6N + (sys_custom.nodes[hub_gid]::RingNode).ring_idx]
		blade_points = Point3f[]
		for j in 1:p_custom.n_lines
			pt_root = attachment_point(hub_pos, trpt_hub_radius, α_hub, j, p_custom.n_lines, pp1, pp2)
			pt_tip = attachment_point(hub_pos, rotor_radius, α_hub, j, p_custom.n_lines, pp1, pp2)
			push!(blade_points, Point3f(pt_root...))
			push!(blade_points, Point3f(pt_tip...))
		end
		setobject!(vis["blades"], LineSegments(blade_points, LineBasicMaterial(color=RGB(0.27, 0.5, 0.7), linewidth=3.0)))
		
		# Draw bearing node
		bgid = sys_custom.bearing_id
		bearing_pos = u_frame[3*(bgid-1)+1 : 3*bgid]
		setobject!(vis["bearing"], HyperSphere(Point3f(bearing_pos...), 0.15f0), MeshLambertMaterial(color=RGB(1.0, 0.84, 0.0)))
		
		# Draw lifter line
		sky_gid = sys_custom.sky_anchor_id
		sky_pos = u_frame[3*(sky_gid-1)+1 : 3*sky_gid]
		lifter_line = [Point3f(bearing_pos...), Point3f(sky_pos...)]
		setobject!(vis["lifter"], LineSegments(lifter_line, LineBasicMaterial(color=RGB(1.0, 0.84, 0.0), linewidth=2.0)))
		
		# Draw wind arrow
		arrow_start = hub_pos .- [wind_speed, 0.0, 0.0]
		arrow_points = [Point3f(arrow_start...), Point3f(hub_pos...)]
		setobject!(vis["wind"], LineSegments(arrow_points, LineBasicMaterial(color=RGB(1.0, 0.55, 0.0), linewidth=3.0)))
		
		# Compute frame-specific metrics
		T_max, n_slack = get_max_rope_tension(u_frame, sys_custom, p_custom)
		ω_hub = u_frame[6N + Nr + Nr]
		P_out_kw = (p_custom.k_mppt * ω_hub^3) / 1000.0
		sf = ring_safety_frame(u_frame, u0_custom, sys_custom, p_custom)
		min_ring_fos = minimum(f.fos for f in sf; init=Inf)
		
		HTML("""
		<div style="background:#17191c; border:1px solid #2a2e33; border-radius:8px; padding:12px; font-family:-apple-system,BlinkMacSystemFont,sans-serif; color:#e6e8ea; width:100%; max-width:600px; margin-top:6px">
			<span style="font-size:12px; font-weight:bold; color:#ef9f27">Dynamic Frame: $frame_idx / $(length(sim_run_result.frames))</span><br/>
			<span style="font-size:11px; color:#8a9099">Power: <b>$(@sprintf("%.2f", P_out_kw)) kW</b> | Speed: <b>$(@sprintf("%.1f", ω_hub * 30/π)) rpm</b> | Max Tension: <b>$(@sprintf("%.0f", T_max)) N</b> | Buckle FoS: <b>$(@sprintf("%.2f", min_ring_fos))</b></span>
		</div>
		""")
	else
		HTML("<div style='color:#647284; font-family:sans-serif; font-size:11px'>No active dynamic simulation. Check 'Run dynamic simulation' above.</div>")
	end
end

# ╔═╡ Cell order:
# ╠═00000000-0000-0000-0000-000000000003
# ╠═00000000-0000-0000-0000-000000000004
# ╠═00000000-0000-0000-0000-000000000005
# ╠═00000000-0000-0000-0000-000000000006
# ╠═00000000-0000-0000-0000-000000000007
# ╠═00000000-0000-0000-0000-000000000008
# ╠═00000000-0000-0000-0000-000000000009
# ╠═00000000-0000-0000-0000-000000000010
# ╠═00000000-0000-0000-0000-000000000011
# ╠═00000000-0000-0000-0000-000000000012
# ╠═00000000-0000-0000-0000-000000000013
# ╠═00000000-0000-0000-0000-000000000014
# ╠═00000000-0000-0000-0000-000000000015
# ╠═00000000-0000-0000-0000-000000000016
# ╠═00000000-0000-0000-0000-000000000017
# ╠═00000000-0000-0000-0000-000000000018
# ╠═c9092282-7b74-11f1-973b-e9815e6ced55
