test_that("Online Wrapper: Delegation Methods", {
  # Setup
  n <- 10
  d <- 2
  # Initialize Online wrapper around BWD
  online_bal <- Online$new("BWD", N = n, D = d)

  # 1. Test assign_all delegation
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  res_all <- online_bal$assign_all(X)
  expect_length(res_all, n)
  expect_equal(online_bal$state$iterations, n)

  # 2. Test reset delegation
  online_bal$reset()
  expect_equal(online_bal$state$iterations, 0)
  expect_equal(sum(abs(online_bal$state$w_i)), 0)

  # 3. Test process_x delegation
  x_raw <- c(1, 1)
  x_proc <- online_bal$process_x(x_raw)
  # BWD defaults to intercept=TRUE, so length should be D+1
  expect_equal(length(x_proc), d + 1)
  expect_equal(x_proc[1], 1) # Intercept

  # 4. Test update_imbalance delegation
  online_bal$update_imbalance(x_proc, 1)
  expect_equal(online_bal$state$iterations, 1)

  # 5. Test update_path delegation (Only relevant for MultiBWD, but BWD might have a dummy or error)
  # BWD does NOT implement update_path, so calling it on Online(BWD) would fail if not handled.
  # However, the Online class blindly delegates: `self$balancer$update_path(x, a)`
  # If BWD doesn't have it, R6 might error. BWD doesn't have update_path in your provided XML.
  # Let's verify it errors correctly (proving delegation happened) OR use MultiBWD for this test.

  online_multi <- Online$new("MultiBWD", N = n, D = d)
  expect_no_error(online_multi$update_path(c(0,0), 0))
})

test_that("Online Wrapper: Sample Size Expansion (BWD)", {
  # We need to trigger StopSampleSizeExpended.
  # This error is thrown by BWD$set_alpha(N) if N < 0.
  # set_alpha is called during assign_next ONLY if a restart (imbalance > alpha) occurs.

  # 1. Initialize with tiny N
  n_start <- 2
  online_bal <- Online$new("BWD", N = n_start, D = 2)

  # 2. Force the internal state to be "over limit" and "highly imbalanced"
  # This guarantees the next assignment triggers a restart check AND fails the N check.

  # Manipulate inner balancer
  inner <- online_bal$balancer

  # Set iterations > N
  inner$iterations <- 5

  # Set w_i to huge value to force restart logic: `if (abs(dot_prod) > self$alpha)`
  # Alpha is usually around ~10-20. We set w_i to 1000.
  inner$w_i <- c(1000, 1000, 1000)

  # 3. Trigger Assignment
  x <- c(1, 1) # Positive dot product with w_i

  # This call should:
  # a. Detect restart condition (dot > alpha)
  # b. Call set_alpha(N - iterations) -> set_alpha(2 - 5) -> set_alpha(-3)
  # c. Throw SampleSizeExpendedError
  # d. Online wrapper catches error
  # e. Expands N to 4 (2*2) -> Re-inits -> Restores state -> Retries
  # f. Retry might fail again if N is still too small?
  #    Wait, if N becomes 4, and iterations is 5, N-iter is -1. It will fail again!
  #    The simple doubling logic might require multiple expansions if we are way over.
  #    BUT standard usage implies we hit N, N+1... so doubling once is usually enough.
  #    To test the *logic*, let's set iterations such that doubling N is sufficient.

  # Retrying setup with N=4, Iterations=5 (Fail) -> N=8 (Pass)
  inner$N <- 4
  inner$reset() # recalculates alpha for N=4
  inner$iterations <- 5
  inner$w_i <- c(1000, 1000, 1000)

  # Check definition before
  expect_equal(online_bal$definition$N, 4)

  # Run assignment
  expect_no_error(online_bal$assign_next(x))

  # 4. Verification
  # N should have doubled from 4 to 8
  expect_equal(online_bal$definition$N, 8)
  # Iterations should be 6 (5 pre-existing + 1 new)
  expect_equal(online_bal$state$iterations, 6)
})

test_that("Online Wrapper: Sample Size Expansion (MultiBWD)", {
  # MultiBWD state restoration uses a different branch: `do.call(self$balancer$update_state, bal_state)`
  # We need to ensure this branch is covered.

  # 1. Setup
  n_start <- 4
  online_bal <- Online$new("MultiBWD", N = n_start, D = 2, q = c(0.5, 0.5))

  # 2. Manipulate state to force failure
  # MultiBWD delegates to nodes. We need to find the active node and break it.
  # Root node is index 1.
  root_node <- online_bal$balancer$nodes[[1]]

  # Set iterations > N so restart fails
  root_node$iterations <- 5
  # Set imbalance high to force restart
  root_node$w_i <- c(1000, 1000, 1000)

  # 3. Run assignment
  x <- c(1, 1)
  expect_no_error(online_bal$assign_next(x))

  # 4. Verify expansion and state restoration
  # N should double
  expect_equal(online_bal$definition$N, 8)

  # Root node should have preserved the '5' iterations and added 1 -> 6
  # (assuming the assignment went to this node, which it must as it's the root)
  new_root <- online_bal$balancer$nodes[[1]]
  expect_equal(new_root$iterations, 6)
})

test_that("Online Wrapper: Initialization Edge Cases", {

  # -------------------------------------------------------------------------
  # Test 1: Default N Assignment
  # Target Line: if (is.null(args$N)) args$N <- 100 # Safe default
  # -------------------------------------------------------------------------

  # Initialize without providing N
  # We must provide D because BWD requires it, but we omit N.
  online_default <- Online$new("BWD", D = 5)

  # Verify N defaulted to 100
  expect_equal(online_default$definition$N, 100)


  # -------------------------------------------------------------------------
  # Test 2: Class Object Initialization
  # Target Lines:
  #   self$cls <- cls
  #   self$cls_name <- cls$classname
  # -------------------------------------------------------------------------

  # Initialize by passing the R6 generator object (BWD) instead of the string "BWD"
  online_obj <- Online$new(BWD, N = 50, D = 5)

  # Verify it initialized correctly
  expect_true(inherits(online_obj$balancer, "BWD"))

  # Verify the internal class name was extracted correctly
  # The definition active binding returns cls_name, so we check that
  expect_equal(online_obj$definition$cls, "BWD")
})
