# Stateless BWD Assignment with Automated History Parsing

Handles the full lifecycle of a BWD assignment in a stateless
environment (like formr). It parses raw history data, replays events to
synchronize state, assigns the next treatment, and formats the output
for efficient storage (checkpointing).

## Usage

``` r
bwd_assign_next(
  current_covariates,
  history = NULL,
  bwd_settings,
  history_covariate_cols = NULL,
  checkpoint_interval = 20
)
```

## Arguments

- current_covariates:

  Numeric vector. The covariates for the current participant.

- history:

  The history object. Can be:

  - A `data.frame` (result of `formr_api_results`).

  - A `list` of pre-parsed history entries.

- bwd_settings:

  List. Configuration for the balancer (e.g. `list(N=1000, D=5)`).

- history_covariate_cols:

  Character vector. Required if `history` is a data.frame. Specifies the
  column names in the dataframe that correspond to `current_covariates`,
  in the exact same order.

- checkpoint_interval:

  Integer. How often to save the full state (default 20). Interim
  entries will store NULL state to save bandwidth.

## Value

A list containing:

- `assignment`: Integer (0 or 1).

- `json_result`: String. The optimized JSON to save to the database.

- `timestamp`: Numeric.
