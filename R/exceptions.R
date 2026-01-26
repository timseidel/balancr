#' Sample Size Expended Error
#'
#' @description
#' A custom error condition thrown when the number of units assigned exceeds
#' the pre-allocated sample size N.
#'
#' @export
stop_sample_size_expended <- function() {
  cond <- structure(
    list(message = "Sample size has been exceeded"),
    class = c("SampleSizeExpendedError", "error", "condition")
  )
  stop(cond)
}
