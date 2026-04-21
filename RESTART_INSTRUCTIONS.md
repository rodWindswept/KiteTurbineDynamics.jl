# Morning Restart Instructions

The 14-hour full-length simulations have completed overnight in the background. The raw simulation output has been saved into the `scripts/results/` folder as `.csv` files. 

Because we decoupled the Julia simulation step from the Python reporting step, **your reports and charts have not yet been regenerated with the new data.**

To finish the process and build the reports based on the true canonical physics data, run the following commands sequentially:

1. **Regenerate Python Charts**
   ```bash
   python3 scripts/make_diagrams.py
   python3 scripts/plot_hub_excursion.py
   python3 scripts/plot_mppt_sweep.py
   python3 scripts/plot_mppt_individual.py
   ```

2. **Regenerate Word Reports**
   ```bash
   python3 scripts/produce_report.py
   python3 scripts/produce_free_beta_report.py
   python3 scripts/produce_kite_turbine_potential_report.py
   ```

3. **Verify and Commit**
   ```bash
   git status
   git add scripts/results/ TRPT_*.docx
   git commit -m "Update reports with full canonical data"
   git push origin master
   ```
