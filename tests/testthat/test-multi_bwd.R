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
