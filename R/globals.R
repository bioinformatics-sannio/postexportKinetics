# The frozen ODE right-hand side rna_kinetics() (R/ode.R) evaluates the state
# and parameter names inside with(); declare them so that R CMD check does not
# report them as undefined globals. This does not change the ported code.
utils::globalVariables(c(
    "R", "N", "N_s", "C", "C_s",
    "tau", "tau_s", "sigma_c", "sigma_n", "alpha", "alpha_s"
))
