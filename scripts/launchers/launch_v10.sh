rm ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.ji ~/.julia/compiled/v1.12/KiteTurbineDynamics/*.so
julia --project=. scripts/run_v10_campaign.jl --power 50 2>&1 | tee scripts/results/v10_campaign_50kw/campaign.log
