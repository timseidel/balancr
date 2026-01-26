test_that("stop_sample_size_expended throws the correct custom error", {
  # 1. Verify the error is thrown with the correct class and message
  expect_error(
    stop_sample_size_expended(),
    class = "SampleSizeExpendedError",
    regexp = "Sample size has been exceeded"
  )

  # 2. Advanced: Capture the error object to inspect its structure
  err <- expect_error(stop_sample_size_expended())

  expect_s3_class(err, "SampleSizeExpendedError")
  expect_s3_class(err, "error")
  expect_equal(err$message, "Sample size has been exceeded")
})
