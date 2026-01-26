# Balancing Walk Design with Reversion to Bernoulli Randomization

A variant of BWD that reverts to simple Bernoulli randomization if the
imbalance exceeds the threshold.

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

- [`BWDRandom$new()`](#method-BWDRandom-new)

- [`BWDRandom$set_alpha()`](#method-BWDRandom-set_alpha)

- [`BWDRandom$assign_next()`](#method-BWDRandom-assign_next)

- [`BWDRandom$assign_all()`](#method-BWDRandom-assign_all)

- [`BWDRandom$update_state()`](#method-BWDRandom-update_state)

- [`BWDRandom$reset()`](#method-BWDRandom-reset)

- [`BWDRandom$clone()`](#method-BWDRandom-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize the BWDRandom balancer.

#### Usage

    BWDRandom$new(N, D, delta = 0.05, q = 0.5, intercept = TRUE, phi = 1)

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

    BWDRandom$set_alpha(N)

#### Arguments

- `N`:

  Number of units remaining.

------------------------------------------------------------------------

### Method `assign_next()`

Assign treatment to the next point.

#### Usage

    BWDRandom$assign_next(x)

#### Arguments

- `x`:

  Covariate profile vector.

#### Returns

Treatment assignment (0 or 1).

------------------------------------------------------------------------

### Method `assign_all()`

Assign all points in a matrix (offline setting).

#### Usage

    BWDRandom$assign_all(X)

#### Arguments

- `X`:

  Matrix of covariate profiles (N x D).

#### Returns

Vector of treatment assignments.

------------------------------------------------------------------------

### Method `update_state()`

Update the internal state of the balancer.

#### Usage

    BWDRandom$update_state(w_i, iterations, alpha = NULL)

#### Arguments

- `w_i`:

  Current imbalance vector.

- `iterations`:

  Current iteration count.

------------------------------------------------------------------------

### Method `reset()`

Reset the balancer to initial state.

#### Usage

    BWDRandom$reset()

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    BWDRandom$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
