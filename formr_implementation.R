# --- 1. CONFIGURATION ---
# Define the matching columns:
# "covariates" is what we have NOW.
# "history_cols" is where we find them in the PAST data.
covariates   <- c(intake$age_std, ifelse(intake$gender == 'f', 1, 0))
history_cols <- c("intake_age_std", "intake_gender")
settings     <- list(N = 2000, D = 2)

# --- 2. GET DATA ---
# We grab the bwd_result and the specific history columns we defined above
past_data <- suppressMessages(
  formr_api_results(
    run_name = "my_run",
    items = c("bwd_result", history_cols)
  )
)

# --- 3. RUN BWD ---
# The wrapper now handles all parsing, replaying, and optimization internally
result <- bwd::bwd_assign_next(
  current_covariates = covariates,
  history = past_data,
  history_covariate_cols = history_cols,
  bwd_settings = settings
)

# --- 4. SAVE ---
bwd_assignment <- result$assignment
bwd_result     <- result$json_result
