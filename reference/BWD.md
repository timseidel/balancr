# Balancing Walk Design with Restarts

The Balancing Walk Design with Restarts. At each step, it adjusts
randomization probabilities to ensure that imbalance tends towards zero.

## Public fields

- `q`:

  Target marginal probability of treatment.

- `intercept`:

  Whether to add an intercept term.

- `delta`:

  Probability of failure.

- `N`:

  Total number of points.

- `D`:

  Dimension of the data.

- `value_plus`:

  Value added to imbalance when treatment is 1.

- `value_minus`:

  Value added to imbalance when treatment is 0.

- `phi`:

  Robustness parameter.

- `alpha`:

  Normalizing constant (threshold).

- `w_i`:

  Current imbalance vector.

- `iterations`:

  Current iteration count.

## Active bindings

- `definition`:

  Dictionary of definition parameters.

- `state`:

  Dictionary of current state.

## Methods

### Public methods

- [`BWD$new()`](#method-BWD-new)

- [`BWD$set_alpha()`](#method-BWD-set_alpha)

- [`BWD$process_x()`](#method-BWD-process_x)

- [`BWD$update_imbalance()`](#method-BWD-update_imbalance)

- [`BWD$assign_next()`](#method-BWD-assign_next)

- [`BWD$replay_assignment()`](#method-BWD-replay_assignment)

- [`BWD$assign_all()`](#method-BWD-assign_all)

- [`BWD$update_state()`](#method-BWD-update_state)

- [`BWD$reset()`](#method-BWD-reset)

- [`BWD$clone()`](#method-BWD-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize the BWD balancer.

#### Usage

    BWD$new(N, D, delta = 0.05, q = 0.5, intercept = TRUE, phi = 1)

#### Arguments

- `N`:

  Total number of points.

- `D`:

  Dimension of the data.

- `delta`:

  Probability of failure (default 0.05).

- `q`:

  Target marginal probability of treatment (default 0.5).

- `intercept`:

  Whether to add an intercept term (default TRUE).

- `phi`:

  Robustness parameter (default 1).

------------------------------------------------------------------------

### Method `set_alpha()`

Set normalizing constant for remaining N units.

#### Usage

    BWD$set_alpha(N)

#### Arguments

- `N`:

  Number of units remaining.

------------------------------------------------------------------------

### Method `process_x()`

Internal helper to process the input vector x. Returns the vector with
intercept if applicable.

#### Usage

    BWD$process_x(x)

#### Arguments

- `x`:

  Covariate profile vector.

------------------------------------------------------------------------

### Method `update_imbalance()`

Manually update internal state based on an assignment. Used during
Replay/Event Sourcing.

#### Usage

    BWD$update_imbalance(x_proc, assignment)

#### Arguments

- `x_proc`:

  Processed covariate vector (with intercept).

- `assignment`:

  The treatment assignment (0 or 1).

------------------------------------------------------------------------

### Method `assign_next()`

Assign treatment to the next point.

#### Usage

    BWD$assign_next(x)

#### Arguments

- `x`:

  Covariate profile vector.

#### Returns

Treatment assignment (0 or 1).

------------------------------------------------------------------------

### Method `replay_assignment()`

Replay a historical assignment, respecting Restart logic.

#### Usage

    BWD$replay_assignment(x, assignment)

------------------------------------------------------------------------

### Method `assign_all()`

Assign all points in a matrix (offline setting).

#### Usage

    BWD$assign_all(X)

#### Arguments

- `X`:

  Matrix of covariate profiles (N x D).

#### Returns

Vector of treatment assignments.

------------------------------------------------------------------------

### Method `update_state()`

Update the internal state of the balancer.

#### Usage

    BWD$update_state(w_i, iterations, alpha = NULL)

#### Arguments

- `w_i`:

  Current imbalance vector.

- `iterations`:

  Current iteration count.

------------------------------------------------------------------------

### Method `reset()`

Reset the balancer to initial state.

#### Usage

    BWD$reset()

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BWD$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
