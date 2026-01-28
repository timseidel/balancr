# Integration with formr (Stateless Deployment)

In web-based survey frameworks like **formr**, the R session does not
persist between users. Every time a new participant arrives, the R
script runs from scratch (“stateless”).

To perform sequential covariate balancing in this environment, we must:

1.  **Fetch** the history of previous participants from the database.
2.  **Reconstruct** the state of the balancer.
3.  **Assign** the current user.
4.  **Save** the new state back to the database.

The `bwd-balancer` package provides a dedicated wrapper,
[`bwd_assign_next()`](https://timseidel.github.io/balancr/reference/bwd_assign_next.md),
to handle this complexity automatically.

## Prerequisites

Ensure your survey item (e.g., in the `formr` spreadsheet) has a single
calculate item to store the result:

1.  **`bwd_result`**: A calculate item capable of storing long strings
    (JSON).

## Implementation Example

Below is the standard snippet to use inside a `formr` R calculate block.

### 1. Configuration

Define your study parameters and prepare the current user’s data.

``` r
library("balancr")

# A. BWD Settings
settings <- list(N = 2000, D = 2, intercept = TRUE)

# B. Prepare Current Data
# Assume 'intake' is the survey of the current user's responses
current_age_std <- intake$age_std 
current_gender  <- ifelse(intake$gender == 'f', 1, 0)

covariates <- c(current_age_std, current_gender)

# C. Column Mapping
# These names must match the column names in your formr results table
history_cols <- c("intake_age_std", "intake_gender")
```

#### 🔍 Data Snapshot: The Current User

At this stage, your `covariates` vector represents the new participant
waiting for assignment:

| index | value | description      |
|:------|:------|:-----------------|
| 1     | `0.5` | Standardized Age |
| 2     | `1`   | Gender (Female)  |

### 2. Fetch History

Retrieve the data of all previous participants. We fetch the JSON result
column (primary source) AND the covariates (backup source for
replaying).

``` r
past_data <- suppressMessages(
  formr_api_results(
    run_name = "my_run", 
    items = c("bwd_result", history_cols)
  )
)
```

#### 🔍 Data Snapshot: The History Table (`past_data`)

This is what the wrapper receives. Notice that `bwd_result` contains the
saved state strings.

| bwd_result (JSON)                 | intake_age_std | intake_gender |
|:----------------------------------|:---------------|:--------------|
| `{"assignment":1, "state":"..."}` | `-1.2`         | `0`           |
| `{"assignment":0, "state":"..."}` | `0.8`          | `1`           |
| `NA` *(User missed a checkpoint)* | `0.1`          | `0`           |

*Note: The 3rd row has a missing state. The wrapper will automatically
use the values in `intake_age_std` and `intake_gender` to “replay” this
user and restore the correct state.*

### 3. Run the Stateless Wrapper

Pass the data to `bwd_assign_next`. This function will parse the JSON
history, replay the state if necessary, and calculate the new
assignment.

``` r
 result <- balancr::bwd_assign_next(
  current_covariates = covariates,
  history = past_data,
  history_covariate_cols = history_cols,
  bwd_settings = settings
)
```

### 4. Save & Use Results

You only need to save the `json_result` string to the database. It
contains everything (Assignment + State + Timestamp).

``` r
# 1. Save this string to your formr item
# (This ensures the NEXT user can read the history)
bwd_result <- result$json_result
```

#### 🔍 Data Snapshot: The Output String (`bwd_result`)

This is the actual string that gets saved to your database. It contains
the assignment for the current user and the fully serialized
mathematical state required for the next user.

Notice that the `state` field is a **stringified JSON** containing the
imbalance vector (`w_i`), iteration count, and the current threshold
(`alpha`).

``` json
{
  "assignment": 1,
  "timestamp": 1715694205,
  "state": "{\"BWD\":{\"definition\":{\"N\":2000,\"D\":2,\"delta\":0.05,\"q\":0.5,
  \"intercept\":true,\"phi\":1},\"state\":{\"w_i\":[0.5,-0.2],
  \"iterations\":4,\"alpha\":20.59}}}"
}
```

### 5. Using the Assignment

You can use the assignment immediately in your R script for logic (e.g.,
skip logic, text piping).

``` r
if (bwd_result$assignment == 1) {
  treatment_text <- "You are in the Treatment Group"
} else {
  treatment_text <- "You are in the Control Group"
}
```

## Retrieving Data (Post-Hoc Analysis)

When you download your data from `formr` later, you will have a column
`bwd_result` containing JSON strings. Here is how to extract the
assignments in R:

``` r
library(jsonlite)
library(dplyr)

# Assume 'results' is your downloaded dataframe
results <- results %>%
  rowwise() %>%
  mutate(
    # Extract assignment from the JSON string
    assigned_group = fromJSON(bwd_result)$assignment
  )
```

#### 🔍 Data Snapshot: Post-Hoc Analysis

After running the code above, your analysis dataframe will look like
this:

| session | bwd_result              | assigned_group |
|:--------|:------------------------|:---------------|
| User 1  | `{"assignment":1, ...}` | **1**          |
| User 2  | `{"assignment":0, ...}` | **0**          |
| User 3  | `{"assignment":1, ...}` | **1**          |

## Performance Notes

- **Checkpointing:** The wrapper automatically creates full-state
  checkpoints (default: every 20 users).
- **Cold Starts:** The wrapper automatically handles the first user
  (empty history).
