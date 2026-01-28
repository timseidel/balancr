library(testthat)

test_that("MultiBWD instantiation", {
  n <- 100
  d <- 5

  # Default q=0.5
  bal <- MultiBWD$new(N = n, D = d)
  expect_true(inherits(bal, "MultiBWD"))

  # Multiple treatments
  bal_multi <- MultiBWD$new(N = n, D = d, q = c(0.25, 0.25, 0.5))
  expect_equal(length(bal_multi$qs), 3)
})

test_that("MultiBWD assignment", {
  n <- 100
  d <- 5
  x <- rnorm(d)

  bal <- MultiBWD$new(N = n, D = d, q = c(1/3, 1/3, 1/3))
  assign <- bal$assign_next(x)
  expect_true(assign %in% c(0, 1, 2))
})

test_that("MultiBWD pairwise imbalance", {
  n_test <- 1500
  d_test <- 5
  n_runs <- 5
  q_probs <- c(1/3, 1/3, 1/3)

  # Helper to calc norm
  get_norm <- function(vec) sqrt(sum(vec^2))

  # Store results
  multi_res <- list("0-1" = c(), "0-2" = c(), "1-2" = c())
  rand_res  <- list("0-1" = c(), "0-2" = c(), "1-2" = c())

  for (seed in 1:n_runs) {
    set.seed(10000 + seed)
    X_test <- matrix(rnorm(n_test * d_test), nrow = n_test, ncol = d_test)

    # MultiBWD
    bal <- MultiBWD$new(N = n_test, D = d_test, q = q_probs)
    A_multi <- bal$assign_all(X_test)

    # Random
    A_rand <- sample(0:2, n_test, replace = TRUE, prob = q_probs)

    # Check pairs
    pairs <- list(c(0,1), c(0,2), c(1,2))
    names(pairs) <- c("0-1", "0-2", "1-2")

    for (p_name in names(pairs)) {
      g1 <- pairs[[p_name]][1]
      g2 <- pairs[[p_name]][2]

      # Calc Multi imbalance
      imb_m <- numeric(d_test)
      for (i in 1:n_test) {
        if (A_multi[i] == g1) imb_m <- imb_m + X_test[i,]
        if (A_multi[i] == g2) imb_m <- imb_m - X_test[i,]
      }
      multi_res[[p_name]] <- c(multi_res[[p_name]], get_norm(imb_m))

      # Calc Rand imbalance
      imb_r <- numeric(d_test)
      for (i in 1:n_test) {
        if (A_rand[i] == g1) imb_r <- imb_r + X_test[i,]
        if (A_rand[i] == g2) imb_r <- imb_r - X_test[i,]
      }
      rand_res[[p_name]] <- c(rand_res[[p_name]], get_norm(imb_r))
    }
  }

  expect_lt(mean(multi_res$`0-1`), mean(rand_res$`0-1`))
  expect_lt(mean(multi_res$`0-2`), mean(rand_res$`0-2`))
  expect_lt(mean(multi_res$`1-2`), mean(rand_res$`1-2`))
})

test_that("MultiBWD: Path finding, Replay, and State Management", {
  # 1. Setup
  # We use 3 groups to ensure a tree structure (Root -> Left, Right -> Leaf1, Leaf2)
  # q values: 0.5 for Group 0, 0.25 for Group 1, 0.25 for Group 2
  n <- 100
  d <- 2
  # This usually creates: Node 1 (Root) -> splits to Group 0 vs Node X
  # Node X -> splits to Group 1 vs Group 2
  mbwd <- MultiBWD$new(N = n, D = d, q = c(0.5, 0.25, 0.25))

  # -------------------------------------------------------------------------
  # Test: get_path_for_assignment
  # -------------------------------------------------------------------------
  # We need to find which leaf corresponds to which class to verify paths
  # Group 0 is likely on one side, Groups 1 & 2 on the other.

  # Check path for Group 0
  path0 <- mbwd$get_path_for_assignment(0)
  expect_true(is.list(path0))
  expect_true(length(path0) >= 1)
  expect_true(all(c("node", "decision") %in% names(path0[[1]])))

  # Check path for Group 1
  path1 <- mbwd$get_path_for_assignment(1)
  expect_true(length(path1) >= 1)

  # Check Invalid Class Error
  expect_error(mbwd$get_path_for_assignment(999), "Target class not found")

  # -------------------------------------------------------------------------
  # Test: replay_assignment & update_path
  # -------------------------------------------------------------------------
  # Simulate an assignment: User gets Group 1
  # This should update the Root node AND the internal node leading to Group 1
  x_vec <- c(1, -1)

  # Current state of root node (Node 1)
  root_node <- mbwd$nodes[[1]]
  initial_iter <- root_node$state$iterations

  # Replay assignment for Group 1
  mbwd$replay_assignment(x_vec, final_assignment = 1)

  # Verify Root Node updated
  expect_equal(root_node$state$iterations, initial_iter + 1)
  # Verify imbalance changed (should not be all zeros)
  expect_true(any(root_node$state$w_i != 0))

  # -------------------------------------------------------------------------
  # Test: state (active binding)
  # -------------------------------------------------------------------------
  st <- mbwd$state
  expect_type(st, "list")
  # Should contain keys for the BWD nodes (indices as strings)
  expect_true("1" %in% names(st))
  # Check structure of inner state
  expect_true("w_i" %in% names(st[["1"]]))

  # -------------------------------------------------------------------------
  # Test: update_state
  # -------------------------------------------------------------------------
  # Create a fresh balancer
  mbwd_new <- MultiBWD$new(N = n, D = d, q = c(0.5, 0.25, 0.25))

  # Transfer state from old to new
  # We use do.call to match how serialization.R calls it (passing list elements as args)
  do.call(mbwd_new$update_state, st)

  # Verify states match
  expect_equal(mbwd_new$nodes[[1]]$state$iterations, root_node$state$iterations)
  expect_equal(mbwd_new$nodes[[1]]$state$w_i, root_node$state$w_i)

  # -------------------------------------------------------------------------
  # Test: definition (active binding)
  # -------------------------------------------------------------------------
  def <- mbwd$definition
  expect_equal(def$N, n)
  expect_equal(def$D, d)
  expect_equal(length(def$q), 3)

  # -------------------------------------------------------------------------
  # Test: reset
  # -------------------------------------------------------------------------
  mbwd$reset()

  # Check Root Node is reset
  root_reset <- mbwd$nodes[[1]]
  expect_equal(root_reset$state$iterations, 0)
  expect_equal(sum(abs(root_reset$state$w_i)), 0)
})
