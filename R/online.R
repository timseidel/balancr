#' Online Balancer Wrapper
#'
#' @description
#' Wraps a balancer to automatically double the sample size N if the original
#' limit is exceeded.
#'
#' @importFrom R6 R6Class
#' @export
Online <- R6::R6Class("Online",
                      public = list(
                        #' @field balancer The underlying balancer object.
                        balancer = NULL,
                        #' @field cls The class generator (e.g., BWD or MultiBWD).
                        cls = NULL,
                        #' @field cls_name The string name of the class (for serialization).
                        cls_name = NULL,

                        #' @description
                        #' Initialize the Online wrapper.
                        #' @param cls The class generator (e.g., BWD) OR its character string name.
                        #' @param ... Arguments passed to the balancer's initialize method.
                        initialize = function(cls, ...) {
                          args <- list(...)
                          if (is.null(args$N)) args$N <- 100 # Safe default

                          # Handle 'cls' being passed as a string (from JSON) or an object
                          if (is.character(cls)) {
                            self$cls_name <- cls
                            self$cls <- get(cls) # Resolve string to object
                          } else {
                            self$cls <- cls
                            self$cls_name <- cls$classname
                          }

                          self$balancer <- do.call(self$cls$new, args)
                        },

                        #' @description
                        #' Assign treatment to the next point, expanding N if necessary.
                        #' @param x Covariate profile vector.
                        #' @return Treatment assignment.
                        assign_next = function(x) {
                          tryCatch({
                            self$balancer$assign_next(x)
                          }, SampleSizeExpendedError = function(e) {
                            # 1. Expand N
                            bal_def <- self$balancer$definition
                            bal_def$N <- bal_def$N * 2

                            # 2. Capture old state
                            bal_state <- self$balancer$state

                            # 3. Re-initialize with new N
                            self$balancer <- do.call(self$cls$new, bal_def)

                            # 4. Restore state
                            if (inherits(self$balancer, "MultiBWD")) {
                              do.call(self$balancer$update_state, bal_state)
                            } else {
                              self$balancer$update_state(bal_state$w_i, bal_state$iterations)
                            }

                            # 5. Retry assignment
                            self$balancer$assign_next(x)
                          })
                        },

                        # Delegate these methods to the inner balancer
                        assign_all = function(X) self$balancer$assign_all(X),
                        update_state = function(...) self$balancer$update_state(...),
                        reset = function() self$balancer$reset(),

                        # Required for manual replay logic in formr_wrapper
                        process_x = function(x) self$balancer$process_x(x),
                        update_imbalance = function(x, a) self$balancer$update_imbalance(x, a),
                        update_path = function(x, a) self$balancer$update_path(x, a)
                      ),

                      active = list(
                        #' @field definition Dictionary of definition parameters.
                        definition = function() {
                          # CRITICAL CHANGE: We save 'cls' as a string name, not the object
                          c(list(cls = self$cls_name), self$balancer$definition)
                        },
                        #' @field state Dictionary of current state.
                        state = function() {
                          self$balancer$state
                        }
                      )
)
