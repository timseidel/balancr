#' Balancing Walk Design with Restarts
#'
#' @description
#' The Balancing Walk Design with Restarts. At each step, it adjusts randomization
#' probabilities to ensure that imbalance tends towards zero.
#'
#' @importFrom R6 R6Class
#' @export
BWD <- R6::R6Class("BWD",
                   public = list(
                     #' @field q Target marginal probability of treatment.
                     q = NULL,
                     #' @field intercept Whether to add an intercept term.
                     intercept = NULL,
                     #' @field delta Probability of failure.
                     delta = NULL,
                     #' @field N Total number of points.
                     N = NULL,
                     #' @field D Dimension of the data.
                     D = NULL,
                     #' @field value_plus Value added to imbalance when treatment is 1.
                     value_plus = NULL,
                     #' @field value_minus Value added to imbalance when treatment is 0.
                     value_minus = NULL,
                     #' @field phi Robustness parameter.
                     phi = NULL,
                     #' @field alpha Normalizing constant (threshold).
                     alpha = NULL,
                     #' @field w_i Current imbalance vector.
                     w_i = NULL,
                     #' @field iterations Current iteration count.
                     iterations = NULL,

                     #' @description
                     #' Initialize the BWD balancer.
                     #' @param N Total number of points.
                     #' @param D Dimension of the data.
                     #' @param delta Probability of failure (default 0.05).
                     #' @param q Target marginal probability of treatment (default 0.5).
                     #' @param intercept Whether to add an intercept term (default TRUE).
                     #' @param phi Robustness parameter (default 1).
                     initialize = function(N, D, delta = 0.05, q = 0.5, intercept = TRUE, phi = 1) {
                       self$q <- q
                       self$intercept <- intercept
                       self$delta <- delta
                       self$N <- N
                       self$D <- D + if (self$intercept) 1 else 0
                       self$value_plus <- 2 * (1 - self$q)
                       self$value_minus <- -2 * self$q
                       self$phi <- phi
                       self$reset()
                     },

                     #' @description
                     #' Set normalizing constant for remaining N units.
                     #' @param N Number of units remaining.
                     set_alpha = function(N) {
                       if (N < 0) {
                         stop_sample_size_expended()
                       }
                       self$alpha <- log(2 * N / self$delta) * min(1 / self$q, 9.32)
                     },

                     #' @description
                     #' Internal helper to process the input vector x.
                     #' Returns the vector with intercept if applicable.
                     #' @param x Covariate profile vector.
                     process_x = function(x) {
                       if (self$intercept) c(1, x) else x
                     },

                     #' @description
                     #' Manually update internal state based on an assignment.
                     #' Used during Replay/Event Sourcing.
                     #' @param x_proc Processed covariate vector (with intercept).
                     #' @param assignment The treatment assignment (0 or 1).
                     update_imbalance = function(x_proc, assignment) {
                       val <- if (assignment == 1) self$value_plus else self$value_minus
                       self$w_i <- self$w_i + val * x_proc
                       self$iterations <- self$iterations + 1
                     },

                     #' @description
                     #' Assign treatment to the next point.
                     #' @param x Covariate profile vector.
                     #' @return Treatment assignment (0 or 1).
                     assign_next = function(x) {
                       x_proc <- self$process_x(x)
                       dot_prod <- sum(x_proc * self$w_i)

                       # Restart logic if imbalance exceeds alpha
                       if (abs(dot_prod) > self$alpha) {
                         self$w_i <- numeric(self$D)
                         self$set_alpha(self$N - self$iterations)
                         dot_prod <- 0 # Effectively zero after reset
                       }

                       p_i <- self$q * (1 - self$phi * dot_prod / self$alpha)
                       p_i <- max(0, min(1, p_i)) # Safety clamp

                       if (runif(1) < p_i) {
                         assignment <- 1
                       } else {
                         assignment <- 0
                       }

                       self$update_imbalance(x_proc, assignment)
                       return(assignment)
                     },

                     #' @description
                     #' Replay a historical assignment, respecting Restart logic.
                     replay_assignment = function(x, assignment) {
                       x_proc <- self$process_x(x)
                       dot_prod <- sum(x_proc * self$w_i)

                       # Check for Restart
                       if (abs(dot_prod) > self$alpha) {
                         self$w_i <- numeric(self$D)
                         self$set_alpha(self$N - self$iterations)
                       }

                       self$update_imbalance(x_proc, assignment)
                     },

                     #' @description
                     #' Assign all points in a matrix (offline setting).
                     #' @param X Matrix of covariate profiles (N x D).
                     #' @return Vector of treatment assignments.
                     assign_all = function(X) {
                       n_rows <- nrow(X)
                       assignments <- integer(n_rows)
                       for (i in 1:n_rows) {
                         assignments[i] <- self$assign_next(X[i, ])
                       }
                       return(assignments)
                     },

                     #' @description
                     #' Update the internal state of the balancer.
                     #' @param w_i Current imbalance vector.
                     #' @param iterations Current iteration count.
                     update_state = function(w_i, iterations, alpha = NULL) {
                       self$w_i <- as.numeric(w_i)
                       self$iterations <- iterations
                       if (!is.null(alpha)) self$alpha <- alpha
                     },

                     #' @description
                     #' Reset the balancer to initial state.
                     reset = function() {
                       self$w_i <- numeric(self$D)
                       self$set_alpha(self$N)
                       self$iterations <- 0
                     }
                   ),

                   active = list(
                     #' @field definition Dictionary of definition parameters.
                     definition = function() {
                       list(
                         N = self$N,
                         D = if (self$intercept) self$D - 1 else self$D,
                         delta = self$delta,
                         q = self$q,
                         intercept = self$intercept,
                         phi = self$phi
                       )
                     },
                     #' @field state Dictionary of current state.
                     state = function() {
                       list(
                         w_i = self$w_i,
                         iterations = self$iterations,
                         alpha = self$alpha
                       )
                     }
                   )
)
