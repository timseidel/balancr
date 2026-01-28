# Multi-treatment Balancing Walk Design

Extends BWD to multiple treatments by constructing a binary tree where
each node balances between the treatment groups on the left and right.

## Public fields

- `N`:

  Total number of points.

- `D`:

  Dimension of the data.

- `delta`:

  Probability of failure.

- `intercept`:

  Whether to add an intercept term.

- `phi`:

  Robustness parameter.

- `qs`:

  Target marginal probabilities for each treatment.

- `classes`:

  Vector of class labels.

- `K`:

  Number of treatment groups minus 1.

- `nodes`:

  List to store BWD objects or integers (leaves).

- `weights`:

  List to store weights for tree construction.

## Active bindings

- `definition`:

  Dictionary of definition parameters.

- `state`:

  Dictionary of current state.

## Methods

### Public methods

- [`MultiBWD$new()`](#method-MultiBWD-new)

- [`MultiBWD$build_tree()`](#method-MultiBWD-build_tree)

- [`MultiBWD$assign_next()`](#method-MultiBWD-assign_next)

- [`MultiBWD$assign_all()`](#method-MultiBWD-assign_all)

- [`MultiBWD$update_state()`](#method-MultiBWD-update_state)

- [`MultiBWD$update_path()`](#method-MultiBWD-update_path)

- [`MultiBWD$replay_assignment()`](#method-MultiBWD-replay_assignment)

- [`MultiBWD$get_path_for_assignment()`](#method-MultiBWD-get_path_for_assignment)

- [`MultiBWD$reset()`](#method-MultiBWD-reset)

- [`MultiBWD$clone()`](#method-MultiBWD-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize the MultiBWD balancer.

#### Usage

    MultiBWD$new(N, D, delta = 0.05, q = 0.5, intercept = TRUE, phi = 1)

#### Arguments

- `N`:

  Total number of points.

- `D`:

  Dimension of the data.

- `delta`:

  Probability of failure (default 0.05).

- `q`:

  Target marginal probabilities. Can be a scalar (0.5 implied for 2
  groups) or vector.

- `intercept`:

  Whether to add an intercept term (default TRUE).

- `phi`:

  Robustness parameter (default 1).

------------------------------------------------------------------------

### Method `build_tree()`

Internal helper to build the tree structure.

#### Usage

    MultiBWD$build_tree()

------------------------------------------------------------------------

### Method `assign_next()`

Assign treatment to the next point.

#### Usage

    MultiBWD$assign_next(x)

#### Arguments

- `x`:

  Covariate profile vector.

#### Returns

Treatment assignment (integer index).

------------------------------------------------------------------------

### Method `assign_all()`

Assign all points in a matrix (offline setting).

#### Usage

    MultiBWD$assign_all(X)

#### Arguments

- `X`:

  Matrix of covariate profiles (N x D).

#### Returns

Vector of treatment assignments.

------------------------------------------------------------------------

### Method `update_state()`

Update the internal state of the balancer.

#### Usage

    MultiBWD$update_state(...)

#### Arguments

- `...`:

  Named arguments mapping node indices to state lists.

------------------------------------------------------------------------

### Method `update_path()`

Helper to manually update path for replay logic.

#### Usage

    MultiBWD$update_path(x, final_assignment)

#### Arguments

- `x`:

  Covariate vector.

- `final_assignment`:

  The assigned class integer.

------------------------------------------------------------------------

### Method `replay_assignment()`

Replay assignment through the tree.

#### Usage

    MultiBWD$replay_assignment(x, final_assignment)

#### Arguments

- `x`:

  Covariate profile vector.

- `final_assignment`:

  The treatment assignment (integer).

------------------------------------------------------------------------

### Method `get_path_for_assignment()`

BFS to find the path to a specific leaf class.

#### Usage

    MultiBWD$get_path_for_assignment(target_class)

#### Arguments

- `target_class`:

  Integer class label.

------------------------------------------------------------------------

### Method `reset()`

Reset the balancer to initial state.

#### Usage

    MultiBWD$reset()

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    MultiBWD$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
