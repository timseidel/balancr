library(testthat)
library(jsonlite)

# Helper function to reliably extract the inner BWD state from the wrapper's result
get_bwd_state <- function(res) {
  if (is.null(res$json_result)) return(NULL)

  # 1. Parse outer JSON
  outer <- jsonlite::fromJSON(res$json_result)

  # 2. Extract 'state' field
  # If checkpointing skipped saving, this is NULL
  if (is.null(outer$state)) return(NULL)

  if (is.character(outer$state)) {
    state_tree <- jsonlite::fromJSON(outer$state)
  } else {
    state_tree <- outer$state
  }

  # 3. Navigate through wrappers (Online -> BWD)
  if ("Online" %in% names(state_tree)) {
    return(state_tree$Online$state)
  } else if ("BWD" %in% names(state_tree)) {
    return(state_tree$BWD$state)
  } else {
    return(state_tree$state)
  }
}

test_that("formr_wrapper handles basic sequential assignment", {
  # 1. Setup
  bwd_settings <- list(N = 100, D = 2, intercept = TRUE)
  history <- list()

  # 2. First User (Time 1)
  x1 <- c(0.5, -0.5)
  res1 <- bwd_assign_next(
    current_covariates = x1,
    history = history,
    bwd_settings = bwd_settings,
    checkpoint_interval = 1 # <--- Force save so we can inspect state
  )

  expect_true(res1$assignment %in% c(0, 1))
  expect_true(!is.null(res1$json_result))

  # Verify internals
  state1 <- get_bwd_state(res1)
  expect_equal(state1$iterations, 1)

  # 3. Second User (Time 2)
  # Manually construct history entry
  entry1 <- list(
    assignment = res1$assignment,
    covariates = x1,
    timestamp = res1$timestamp,
    serialized_state = jsonlite::fromJSON(res1$json_result)$state
  )

  history <- list(entry1)
  x2 <- c(0.1, 0.2)

  res2 <- bwd_assign_next(
    current_covariates = x2,
    history = history,
    bwd_settings = bwd_settings,
    checkpoint_interval = 1 # <--- Force save again
  )

  state2 <- get_bwd_state(res2)
  expect_true(!is.null(state2), "State should not be NULL when checkpoint_interval=1")
  expect_equal(state2$iterations, 2)
})

test_that("formr_wrapper heals missing state via replay (The 'Fork' Fix)", {
  # 1. Setup
  bwd_settings <- list(N = 100, D = 2, intercept = FALSE)

  # 2. Generate Event A (Manually)
  x_a <- c(1, 1)
  event_a <- list(
    assignment = 1,
    covariates = x_a,
    timestamp = 1000,
    serialized_state = NA # <--- SIMULATING MISSING STATE
  )

  # 3. Run User B with "broken" history
  x_b <- c(2, 2)
  history_broken <- list(event_a)

  res_b <- bwd_assign_next(
    current_covariates = x_b,
    history = history_broken,
    bwd_settings = bwd_settings,
    checkpoint_interval = 1 # <--- Force save
  )

  # 4. Verification
  final_state <- get_bwd_state(res_b)
  expect_true(!is.null(final_state))
  expect_equal(final_state$iterations, 2)

  # Check Imbalance Vector w_i
  # Step A (Assign=1, x=1,1): w becomes c(1, 1)
  # Step B (Assign=res_b$assignment, x=2,2)
  val_b <- if (res_b$assignment == 1) 1 else -1
  expected_w <- c(1, 1) + val_b * x_b

  expect_equal(as.numeric(final_state$w_i), expected_w)
})

test_that("formr_wrapper sorts history by timestamp before replay", {
  bwd_settings <- list(N = 100, D = 2, intercept = FALSE)

  # Event 1 (Time 100)
  evt1 <- list(assignment=1, covariates=c(1,0), timestamp=100, serialized_state=NA)

  # Event 2 (Time 200)
  evt2 <- list(assignment=0, covariates=c(0,1), timestamp=200, serialized_state=NA)

  # Input history in WRONG order
  history_scrambled <- list(evt2, evt1)

  # Current User (Time 300)
  x_curr <- c(0,0)
  res <- bwd_assign_next(
    x_curr,
    history_scrambled,
    bwd_settings,
    checkpoint_interval = 1 # <--- Force save
  )

  state <- get_bwd_state(res)

  # If sorted correctly: w should be c(1, -1)
  expect_true(!is.null(state))
  expect_equal(state$iterations, 3)
  expect_equal(as.numeric(state$w_i), c(1, -1))
})
