#' Stateless BWD Assignment with Automated History Parsing
#'
#' @description
#' Handles the full lifecycle of a BWD assignment in a stateless environment (like formr).
#' It parses raw history data, replays events to synchronize state, assigns the next treatment,
#' and formats the output for efficient storage (checkpointing).
#'
#' @param current_covariates Numeric vector. The covariates for the current participant.
#' @param history The history object. Can be:
#'   \itemize{
#'     \item A \code{data.frame} (result of \code{formr_api_results}).
#'     \item A \code{list} of pre-parsed history entries.
#'   }
#' @param bwd_settings List. Configuration for the balancer (e.g. \code{list(N=1000, D=5)}).
#' @param history_covariate_cols Character vector. Required if \code{history} is a data.frame.
#'   Specifies the column names in the dataframe that correspond to \code{current_covariates},
#'   in the exact same order.
#' @param checkpoint_interval Integer. How often to save the full state (default 20).
#'   Interim entries will store NULL state to save bandwidth.
#'
#' @return A list containing:
#'   \itemize{
#'     \item \code{assignment}: Integer (0 or 1).
#'     \item \code{json_result}: String. The optimized JSON to save to the database.
#'     \item \code{timestamp}: Numeric.
#'   }
#' @export
bwd_assign_next <- function(current_covariates,
                            history = NULL,
                            bwd_settings,
                            history_covariate_cols = NULL,
                            checkpoint_interval = 20) {

  # ============================================================================
  # 1. PARSE HISTORY (Dataframe -> List)
  # ============================================================================
  history_log <- list()

  if (is.data.frame(history)) {
    # Validation
    if (is.null(history_covariate_cols)) {
      stop("When passing a dataframe as history, 'history_covariate_cols' must be provided.")
    }
    if (!"bwd_result" %in% names(history)) {
      # Handle first run case gracefully (column might not exist yet)
      history_log <- list()
    } else {
      # Extract valid rows
      valid_rows <- which(!is.na(history$bwd_result))

      if (length(valid_rows) > 0) {
        history_log <- lapply(valid_rows, function(i) {
          row <- history[i, ]

          # Safe JSON Parse
          stored <- tryCatch(
            jsonlite::fromJSON(row$bwd_result),
            error = function(e) NULL
          )
          if (is.null(stored)) return(NULL)

          # Extract Covariates from DF columns
          # We iterate through the provided column names
          hist_covs <- tryCatch({
            as.numeric(sapply(history_covariate_cols, function(col) row[[col]]))
          }, error = function(e) rep(NA, length(history_covariate_cols)))

          list(
            assignment = as.integer(stored$assignment),
            covariates = hist_covs,
            timestamp = as.numeric(stored$timestamp),
            serialized_state = stored$state # Might be NULL (checkpointing)
          )
        })
        # Clean NULLs
        history_log <- history_log[!sapply(history_log, is.null)]
      }
    }
  } else if (is.list(history)) {
    history_log <- history
  }

  # ============================================================================
  # 2. REPLAY LOGIC (Restore State)
  # ============================================================================
  # Sort by timestamp
  if (length(history_log) > 0) {
    timestamps <- sapply(history_log, function(x) x$timestamp)
    history_log <- history_log[order(timestamps)]
  }

  # Find Checkpoint
  checkpoint_idx <- 0
  balancer <- NULL

  for (i in rev(seq_along(history_log))) {
    entry <- history_log[[i]]
    st <- entry$serialized_state
    if (is.character(st) && length(st) == 1 && !is.na(st) && st != "") {
      tryCatch({
        balancer <- deserialize_bwd(st)
        checkpoint_idx <- i
        break
      }, error = function(e) {})
    }
  }

  # Initialize Online Wrapper if needed
  if (is.null(balancer)) {
    inner_cls_name <- if (!is.null(bwd_settings$q) && length(bwd_settings$q) > 1) "MultiBWD" else "BWD"
    init_args <- c(list(cls = inner_cls_name), bwd_settings)
    balancer <- do.call(Online$new, init_args)
    checkpoint_idx <- 0
  }

  # Replay events since checkpoint
  if (checkpoint_idx < length(history_log)) {
    pending <- history_log[(checkpoint_idx + 1):length(history_log)]
    for (evt in pending) {
      if (any(is.na(evt$covariates)) || is.na(evt$assignment)) next

      # Delegate replay to the inner balancer (BWD or MultiBWD)
      # Note: If using the Online wrapper, ensure it passes this call through,
      # OR access the inner balancer directly:
      if (inherits(balancer, "Online")) {
        balancer$balancer$replay_assignment(evt$covariates, evt$assignment)
      } else {
        balancer$replay_assignment(evt$covariates, evt$assignment)
      }
    }
  }

  # ============================================================================
  # 3. ASSIGN NEXT
  # ============================================================================
  new_assignment <- balancer$assign_next(current_covariates)
  new_state_full <- serialize_bwd(balancer)
  curr_timestamp <- as.numeric(Sys.time())

  # ============================================================================
  # 4. OPTIMIZED PACKING (Checkpointing)
  # ============================================================================
  # Extract iteration count to decide if we save state
  current_iter <- tryCatch({
    st <- jsonlite::fromJSON(new_state_full)
    # Parse based on structure
    if ("BWD" %in% names(st)) st$BWD$state$iterations
    else if ("MultiBWD" %in% names(st)) st$MultiBWD$state$iterations
    else st$Online$state$iterations
  }, error = function(e) 0)

  # Logic: Save if iter 1, or divisible by interval
  should_save <- (is.null(current_iter) || current_iter <= 1 || (current_iter %% checkpoint_interval == 0))

  output_data <- list(
    assignment = new_assignment,
    timestamp = curr_timestamp,
    state = if (should_save) as.character(new_state_full) else NULL
  )

  # Serialize to JSON
  json_str <- jsonlite::toJSON(output_data, auto_unbox = TRUE, digits = NA)

  return(list(
    assignment = new_assignment,
    json_result = as.character(json_str),
    timestamp = curr_timestamp
  ))
}
