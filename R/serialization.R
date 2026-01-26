#' Serialization Utilities
#'
#' @description
#' Utilities to serialize and deserialize BWD objects to/from JSON.
#'
#' @param obj The BWD balancer object to serialize.
#' @param json_str A JSON string representing a serialized BWD object.
#'
#' @name serialization
#' @import jsonlite
NULL

#' @rdname serialization
#' @export
serialize_bwd <- function(obj) {
  # Get class name
  cls_name <- class(obj)[1]

  data <- list()
  data[[cls_name]] <- list(
    definition = obj$definition,
    state = obj$state
  )

  return(jsonlite::toJSON(data, auto_unbox = TRUE, digits = NA))
}

#' @rdname serialization
#' @export
#' @rdname serialization
#' @export
deserialize_bwd <- function(json_str) {
  defs <- jsonlite::fromJSON(json_str)
  cls_name <- names(defs)[1]
  content <- defs[[cls_name]]

  # Select class constructor
  cls_ctor <- get(cls_name)

  # Create object
  bal_obj <- do.call(cls_ctor$new, content$definition)

  # Restore state
  if (cls_name == "MultiBWD") {
    do.call(bal_obj$update_state, content$state)
  } else {
    do.call(bal_obj$update_state, content$state)
  }

  return(bal_obj)
}
