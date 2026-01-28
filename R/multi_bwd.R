#' Multi-treatment Balancing Walk Design
#'
#' @description
#' Extends BWD to multiple treatments by constructing a binary tree where
#' each node balances between the treatment groups on the left and right.
#'
#' @importFrom R6 R6Class
#' @export
MultiBWD <- R6::R6Class("MultiBWD",
                        public = list(
                          #' @field N Total number of points.
                          N = NULL,
                          #' @field D Dimension of the data.
                          D = NULL,
                          #' @field delta Probability of failure.
                          delta = NULL,
                          #' @field intercept Whether to add an intercept term.
                          intercept = NULL,
                          #' @field phi Robustness parameter.
                          phi = NULL,
                          #' @field qs Target marginal probabilities for each treatment.
                          qs = NULL,
                          #' @field classes Vector of class labels.
                          classes = NULL,
                          #' @field K Number of treatment groups minus 1.
                          K = NULL,
                          #' @field nodes List to store BWD objects or integers (leaves).
                          nodes = NULL,
                          #' @field weights List to store weights for tree construction.
                          weights = NULL,

                          #' @description
                          #' Initialize the MultiBWD balancer.
                          #' @param N Total number of points.
                          #' @param D Dimension of the data.
                          #' @param delta Probability of failure (default 0.05).
                          #' @param q Target marginal probabilities. Can be a scalar (0.5 implied for 2 groups) or vector.
                          #' @param intercept Whether to add an intercept term (default TRUE).
                          #' @param phi Robustness parameter (default 1).
                          initialize = function(N, D, delta = 0.05, q = 0.5, intercept = TRUE, phi = 1.0) {
                            self$N <- N
                            self$D <- D
                            self$delta <- delta
                            self$intercept <- intercept
                            self$phi <- phi

                            if (length(q) == 1) {
                              q_val <- if (q < 0.5) q else 1 - q
                              self$qs <- c(1 - q_val, q_val)
                              self$classes <- c(0, 1)
                            } else {
                              self$qs <- q / sum(q)
                              self$classes <- 0:(length(self$qs) - 1)
                            }

                            self$build_tree()
                          },

                          #' @description
                          #' Internal helper to build the tree structure.
                          build_tree = function() {
                            num_groups <- length(self$qs)
                            self$K <- num_groups - 1

                            num_levels <- ceiling(log2(num_groups))
                            num_leaves <- 2^num_levels
                            extra_leaves <- num_leaves - num_groups
                            num_nodes <- 2^(num_levels + 1) - 1

                            self$nodes <- vector("list", num_nodes)
                            self$weights <- vector("list", num_nodes)

                            # Calculate leaf assignments
                            trt_by_leaf <- integer()
                            num_leaves_by_trt <- integer()
                            current_extra <- extra_leaves

                            for (trt in 0:(num_groups - 1)) {
                              if ((length(trt_by_leaf) %% 2 == 0) && (current_extra > 0)) {
                                num_trt <- 2 * (floor((current_extra - 1) / 2) + 1)
                                current_extra <- current_extra - (num_trt - 1)
                              } else {
                                num_trt <- 1
                              }
                              trt_by_leaf <- c(trt_by_leaf, rep(trt, num_trt))
                              num_leaves_by_trt <- c(num_leaves_by_trt, num_trt)
                            }

                            # Initialize leaf nodes
                            start_leaf_idx <- num_nodes - num_leaves + 1
                            for (i in seq_along(trt_by_leaf)) {
                              node_idx <- start_leaf_idx + i - 1
                              trt <- trt_by_leaf[i]
                              self$nodes[[node_idx]] <- trt
                              self$weights[[node_idx]] <- 1 / self$qs[trt + 1] / num_leaves_by_trt[trt + 1]
                            }

                            # Build internal nodes
                            for (cur_node in seq(num_nodes, 2)) {
                              parent <- floor(cur_node / 2)
                              left <- 2 * parent
                              right <- 2 * parent + 1

                              if (is.null(self$nodes[[left]]) || is.null(self$nodes[[right]])) next
                              if (!is.null(self$nodes[[parent]])) next

                              if (is.numeric(self$nodes[[left]]) && is.numeric(self$nodes[[right]]) &&
                                  self$nodes[[left]] == self$nodes[[right]]) {
                                self$nodes[[parent]] <- self$nodes[[left]]
                                self$weights[[parent]] <- self$weights[[left]] + self$weights[[right]]
                              } else {
                                left_weight <- self$weights[[left]]
                                right_weight <- self$weights[[right]]
                                pr_right <- right_weight / (left_weight + right_weight)

                                self$nodes[[parent]] <- BWD$new(
                                  N = self$N, D = self$D, intercept = self$intercept,
                                  delta = self$delta, q = pr_right, phi = self$phi
                                )
                                self$weights[[parent]] <- left_weight + right_weight
                              }
                            }
                          },

                          #' @description
                          #' Assign treatment to the next point.
                          #' @param x Covariate profile vector.
                          #' @return Treatment assignment (integer index).
                          assign_next = function(x) {
                            cur_idx <- 1
                            while (inherits(self$nodes[[cur_idx]], "BWD")) {
                              assign <- self$nodes[[cur_idx]]$assign_next(x)
                              if (assign > 0.5) {
                                cur_idx <- 2 * cur_idx + 1
                              } else {
                                cur_idx <- 2 * cur_idx
                              }
                            }
                            return(self$nodes[[cur_idx]])
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
                          #' @param ... Named arguments mapping node indices to state lists.
                          update_state = function(...) {
                            args <- list(...)
                            for (node_idx in names(args)) {
                              idx <- as.integer(node_idx)
                              if (inherits(self$nodes[[idx]], "BWD")) {
                                state <- args[[node_idx]]
                                do.call(self$nodes[[idx]]$update_state, state)
                              }
                            }
                          },

                          #' @description
                          #' Helper to manually update path for replay logic.
                          #' @param x Covariate vector.
                          #' @param final_assignment The assigned class integer.
                          update_path = function(x, final_assignment) {
                            path <- self$get_path_for_assignment(final_assignment)
                            for (step in path) {
                              node_idx <- step$node
                              decision <- step$decision
                              x_proc <- self$nodes[[node_idx]]$process_x(x)
                              self$nodes[[node_idx]]$update_imbalance(x_proc, decision)
                            }
                          },

                          #' @description
                          #' Replay assignment through the tree.
                          #' @param x Covariate profile vector.
                          #' @param final_assignment The treatment assignment (integer).
                          replay_assignment = function(x, final_assignment) {
                            path <- self$get_path_for_assignment(final_assignment)
                            for (step in path) {
                              node_idx <- step$node
                              decision <- step$decision
                              # Delegate to the BWD node's replay method
                              self$nodes[[node_idx]]$replay_assignment(x, decision)
                            }
                          },

                          #' @description
                          #' BFS to find the path to a specific leaf class.
                          #' @param target_class Integer class label.
                          get_path_for_assignment = function(target_class) {
                            # Queue contains: list(idx, path_so_far)
                            queue <- list(list(idx = 1, path = list()))

                            while(length(queue) > 0) {
                              curr <- queue[[1]]
                              queue <- queue[-1]
                              idx <- curr$idx

                              node <- self$nodes[[idx]]

                              if (inherits(node, "BWD")) {
                                # Left child (Decision 0)
                                queue[[length(queue)+1]] <- list(
                                  idx = 2 * idx,
                                  path = c(curr$path, list(list(node = idx, decision = 0)))
                                )
                                # Right child (Decision 1)
                                queue[[length(queue)+1]] <- list(
                                  idx = 2 * idx + 1,
                                  path = c(curr$path, list(list(node = idx, decision = 1)))
                                )
                              } else if (is.numeric(node) && node == target_class) {
                                return(curr$path)
                              }
                            }
                            stop("Target class not found in tree")
                          },

                          #' @description
                          #' Reset the balancer to initial state.
                          reset = function() {
                            for (node in self$nodes) {
                              if (inherits(node, "BWD")) {
                                node$reset()
                              }
                            }
                          }
                        ),

                        active = list(
                          #' @field definition Dictionary of definition parameters.
                          definition = function() {
                            list(
                              N = self$N,
                              D = self$D,
                              delta = self$delta,
                              q = self$qs,
                              intercept = self$intercept,
                              phi = self$phi
                            )
                          },
                          #' @field state Dictionary of current state.
                          state = function() {
                            st <- list()
                            for (i in seq_along(self$nodes)) {
                              if (inherits(self$nodes[[i]], "BWD")) {
                                st[[as.character(i)]] <- self$nodes[[i]]$state
                              }
                            }
                            st
                          }
                        )
)
