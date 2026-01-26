library(testthat)

test_that("BWDRandom works", {
  n <- 100
  d <- 5
  balancer <- BWDRandom$new(N = n, D = d)
  expect_true(inherits(balancer, "BWDRandom"))

  test_x <- rnorm(d)

  # Test assignment
  expect_no_error(balancer$assign_next(test_x))

  # Test serialization
  dump <- serialize_bwd(balancer)
  bal_restored <- deserialize_bwd(dump)
  expect_true(inherits(bal_restored, "BWDRandom"))
})

test_that("BWDRandom reduces imbalance on average", {
  n_test <- 1000
  d_test <- 5
  n_runs <- 5

  bwd_norms <- numeric(n_runs)
  rand_norms <- numeric(n_runs)

  for (i in 1:n_runs) {
    set.seed(10000 + i)
    X_test <- matrix(rnorm(n_test * d_test), nrow = n_test, ncol = d_test)

    balancer <- BWDRandom$new(N = n_test, D = d_test)
    imbalance_bwd <- numeric(d_test)

    for (j in 1:n_test) {
      x <- X_test[j, ]
      a <- balancer$assign_next(x)
      val <- if (a == 1) 1 else -1
      imbalance_bwd <- imbalance_bwd + val * x
    }

    # Pure Random
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

  expect_lt(mean(bwd_norms), mean(rand_norms))
})
