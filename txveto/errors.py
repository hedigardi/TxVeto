"""TxVeto exceptions."""


class TxVetoError(Exception):
    """Base exception for all TxVeto safety failures."""


class BudgetExceededError(TxVetoError):
    """Raised when an agent attempts to exceed its budget."""


class LoopDetectedError(TxVetoError):
    """Raised when a repeated loop or runaway pattern is detected."""


class PolicyViolationError(TxVetoError):
    """Raised when a policy rule blocks an action."""
