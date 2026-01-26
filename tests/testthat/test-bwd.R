library(testthat)

test_that("BWD instantiation works", {
  n <- 100
  d <- 5
  balancer <- BWD$new(N = n, D = d)
  expect_true(inherits(balancer, "BWD"))
  expect_equal(balancer$definition$N, n)
})

test_that("BWD serialization works", {
  n <- 100
  d <- 5
  balancer <- BWD$new(N = n, D = d)

  # Serialize
  dump <- serialize_bwd(balancer)
  expect_type(dump, "character")

  # Deserialize
  bal_restored <- deserialize_bwd(dump)
  expect_true(inherits(bal_restored, "BWD"))

  # Check functionality after restore
  test_x <- rnorm(d)
  assign <- bal_restored$assign_next(test_x)
  expect_true(assign %in% c(0, 1))
})

test_that("BWD assignment works", {
  n <- 100
  d <- 5
  balancer <- BWD$new(N = n, D = d)
  test_x <- rnorm(d)

  # Assign one
  a <- balancer$assign_next(test_x)
  expect_true(a %in% c(0, 1))

  # Assign all
  X <- matrix(rnorm(n * d), nrow = n, ncol = d)
  A <- balancer$assign_all(X)
  expect_length(A, n)
})

test_that("BWD reduces imbalance compared to random", {
  n_test <- 1000
  d_test <- 5
  n_runs <- 5

  bwd_norms <- numeric(n_runs)
  rand_norms <- numeric(n_runs)

  for (i in 1:n_runs) {
    set.seed(10000 + i)
    X_test <- matrix(rnorm(n_test * d_test), nrow = n_test, ncol = d_test)

    # BWD
    balancer <- BWD$new(N = n_test, D = d_test)
    imbalance_bwd <- numeric(d_test)

    # Use intercept logic manually for imbalance check to match Python test logic
    # The Python test calculates imbalance on the raw X (no intercept added in calculation)

    for (j in 1:n_test) {
      x <- X_test[j, ]
      a <- balancer$assign_next(x)
      # Map 0/1 to -1/1
      val <- if (a == 1) 1 else -1
      imbalance_bwd <- imbalance_bwd + val * x
    }

    # Random
    A_rand <- rbinom(n_test, 1, 0.5)
    imbalance_rand <- numeric(d_test)
    for (j in 1:n_test) {
      x <- X_test[j, ]
      val <- if (A_rand[j] == 1) 1 else -1
      imbalance_rand <- imbalance_rand + val * x
    }

    bwd_norms[i] <- sqrt(sum(imbalance_bwd^2))
    rand_norms[i] <- sqrt(sum(imbalance_rand^2))
  }

  avg_bwd <- mean(bwd_norms)
  avg_rand <- mean(rand_norms)

  expect_lt(avg_bwd, avg_rand)
})
