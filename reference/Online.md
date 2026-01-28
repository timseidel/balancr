# Online Balancer Wrapper

Wraps a balancer to automatically double the sample size N if the
original limit is exceeded.

## Public fields

- `balancer`:

  The underlying balancer object.

- `cls`:

  The class generator (e.g., BWD or MultiBWD).

- `cls_name`:

  The string name of the class (for serialization).

## Active bindings

- `definition`:

  Dictionary of definition parameters.

- `state`:

  Dictionary of current state.

## Methods

### Public methods

- [`Online$new()`](#method-Online-new)

- [`Online$assign_next()`](#method-Online-assign_next)

- [`Online$assign_all()`](#method-Online-assign_all)

- [`Online$update_state()`](#method-Online-update_state)

- [`Online$reset()`](#method-Online-reset)

- [`Online$process_x()`](#method-Online-process_x)

- [`Online$update_imbalance()`](#method-Online-update_imbalance)

- [`Online$update_path()`](#method-Online-update_path)

- [`Online$clone()`](#method-Online-clone)

------------------------------------------------------------------------

### Method `new()`

Initialize the Online wrapper.

#### Usage

    Online$new(cls, ...)

#### Arguments

- `cls`:

  The class generator (e.g., BWD) OR its character string name.

- `...`:

  Arguments passed to the balancer's initialize method.

------------------------------------------------------------------------

### Method `assign_next()`

Assign treatment to the next point, expanding N if necessary.

#### Usage

    Online$assign_next(x)

#### Arguments

- `x`:

  Covariate profile vector.

#### Returns

Treatment assignment.

------------------------------------------------------------------------

### Method `assign_all()`

Delegate assign_all to inner balancer.

#### Usage

    Online$assign_all(X)

#### Arguments

- `X`:

  Matrix of covariate profiles.

------------------------------------------------------------------------

### Method `update_state()`

Delegate update_state to inner balancer.

#### Usage

    Online$update_state(...)

#### Arguments

- `...`:

  State arguments.

------------------------------------------------------------------------

### Method `reset()`

Delegate reset to inner balancer.

#### Usage

    Online$reset()

------------------------------------------------------------------------

### Method `process_x()`

Delegate process_x to inner balancer.

#### Usage

    Online$process_x(x)

#### Arguments

- `x`:

  Covariate vector.

------------------------------------------------------------------------

### Method `update_imbalance()`

Delegate update_imbalance to inner balancer.

#### Usage

    Online$update_imbalance(x, a)

#### Arguments

- `x`:

  Processed covariate vector.

- `a`:

  Assignment.

------------------------------------------------------------------------

### Method `update_path()`

Delegate update_path to inner balancer.

#### Usage

    Online$update_path(x, a)

#### Arguments

- `x`:

  Covariate vector.

- `a`:

  Assignment.

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Online$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
