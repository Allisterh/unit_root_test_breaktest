#' @title
#' SADF test with wild bootstrap.
#'
#' @import doSNOW
#' @import foreach
#' @import parallel
#'
#' @export
SADF.bootstrap.test <- function(y,
                                r0 = 0.01 + 1.8 / sqrt(length(y)),
                                const = TRUE,
                                alpha = 0.05,
                                iter = 4 * 200,
                                seed = round(10^4 * sd(y))) {
    N <- length(y)

    # Find SADF.value.
    model <- SADF.test(y, r0, const)
    t.values <- model$t.values
    SADF.value <- model$SADF.value

    # Do parallel.
    cores <- detectCores()

    progress.bar <- txtProgressBar(max = iter, style = 3)
    progress <- function(n) setTxtProgressBar(progress.bar, n)

    cluster <- makeCluster(max(cores - 1, 1))
    clusterExport(cluster, c("SADF.test"))
    registerDoSNOW(cluster)

    SADF.bootstrap.values <- foreach(
        step = 1:iter,
        .combine = c,
        .options.snow = list(progress = progress)
    ) %dopar% {
        y.star <- cumsum(c(0, rnorm(N - 1) * diff(y)))
        model <- SADF.test(y.star, r0, const)
        model$SADF.value
    }

    stopCluster(cluster)

    # Find critical value.
    cr.value <- as.numeric(quantile(SADF.bootstrap.values, 1 - alpha))

    p.value <- round(sum(SADF.bootstrap.values > SADF.value) / iter, 4)

    is.explosive <- ifelse(SADF.value > cr.value, 1, 0)

    result <- list(
        y = y,
        r0 = r0,
        const = const,
        alpha = alpha,
        iter = iter,
        seed = seed,
        t.values = t.values,
        SADF.value = SADF.value,
        SADF.bootstrap.values = SADF.bootstrap.values,
        cr.value = cr.value,
        p.value = p.value,
        is.explosive = is.explosive
    )

    class(result) <- "sadf"

    return(result)
}