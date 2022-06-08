#' @title
#' Calculating long-run variance
#'
#' @param e (Tx1) vector or residuals.
#'
#' @return Long-run variance.
#'
#' @import MASS
lr.var <- function(e, l = NULL) {
    if (!is.matrix(e)) e <- as.matrix(e)

    N <- nrow(e)

    if (is.null(l))
        l <- trunc(4 * ((N / 100)^(1 / 4)))

    lrv <- drop(t(e) %*% e) / N
    for (i in 1:l) {
        w <- (1 - i / (l + 1))
        lrv <- lrv + 2 * drop(t(e[1:(N - i)]) %*% e[(1 + i):N]) * w / N
    }
    return(lrv)
}

#' @title
#' Calculating long-run variance
#'
#' @description
#' Procedure ALRVR to estimate the long-run variance
#' as in Andrews (1991) and Kurozumi (2002).
#'
#' @param e (Tx1) vector or residuals.
#'
#' @return Long-run variance.
#'
#' @import MASS
lr.var.AK <- function(e) {
    if (!is.matrix(e)) e <- as.matrix(e)

    N <- nrow(e)
    k <- 0.8
    a <- qr.solve(t(e[1:(N - 1)]) %*% e[1:(N - 1)]) %*%
        t(e[1:(N - 1)]) %*% e[2:N]
    l <- min(
        1.1447 * (4 * a^2 * N / ((1 + a)^2 * (1 - a)^2))^(1 / 3),
        1.1447 * (4 * k^2 * N / ((1 + k)^2 * (1 - k)^2))^(1 / 3)
    )
    l <- trunc(l)
    lrv <- drop(t(e) %*% e) / N
    for (i in 1:l) {
        w <- (1 - i / (l + 1))
        lrv <- lrv + 2 * drop(t(e[1:(N - i)]) %*% e[(1 + i):N]) * w / N
    }
    return(lrv)
}

#' @title
#' Calculating long-run variance
#'
#' @description
#' Procedure ALRVR to estimate the long-run variance as
#' in Sul, Phillips and Choi (2003).
#'
#' @details Used are Quadratic Spectral and Bartlett kernels.
#'
#' @param e (Tx1) vector or residuals.
#' @param max.lag Maximum number of lags.
#' The exact number is selected by information criterions.
#' @param kernel Kernel for calculating long-run variance
#' \describe{
#' \item{bartlett}{for Bartlett kernel.}
#' \item{quadratic}{for Quadratic Spectral kernel.}
#' \item{NULL}{for the Kurozumi's proposal, using Bartlett kernel.}
#' }
#' @param criterion The information crietreion: bic, aic or lwz.
#'
#' @return Long-run variance.
#'
#' @import MASS
lr.var.SPC <- function(e,
                       max.lag = 0,
                       kernel = "bartlett",
                       criterion = "bic") {
    if (!is.matrix(e)) e <- as.matrix(e)
    if (max.lag < 0) max.lag <- 0
    if (!kernel %in% c("bartlett", "quadratic")) {
        warning("WARNING! Unknown kernel, Barlett is used")
        kernel <- "bartlett"
    }
    if (!criterion %in% c("bic", "aic", "lwz")) {
        warning("WARNING! Unknown criterion, BIC is used")
        criterion <- "bic"
    }

    N <- nrow(e)

    info.crit.min <- log(drop(t(e) %*% e) / (N - max.lag))
    k <- 0
    rho <- 0
    res <- e

    for (i in 1:max.lag) {
        if (max.lag == 0) break

        temp <- e
        for (j in 1:i) temp <- cbind(temp, lagn(e, j))
        temp <- temp[(1 + i):nrow(temp), , drop = FALSE]

        x.temp <- temp[, 2:ncol(temp), drop = FALSE]

        rho.temp <- qr.solve(t(x.temp) %*% x.temp) %*%
            t(x.temp) %*% temp[, 1, drop = FALSE]

        res.temp <- temp[, 1, drop = FALSE] - x.temp %*% rho.temp

        info.crit <- info.criterion(res.temp, i, criterion)

        if (info.crit < info.crit.min) {
            info.crit.min <- info.crit
            k <- i
            rho <- rho.temp
            res <- res.temp
        }
    }

    if (k == 0) {
        lrv <- drop(t(res) %*% res) / N
    } else {
        temp <- cbind(res, lagn(res, 1))
        temp <- temp[2:nrow(res), , drop = FALSE]
        x.temp <- temp[, 2, drop = FALSE]
        a <- drop(
            qr.solve(t(x.temp) %*% x.temp) %*%
                t(x.temp) %*% temp[, 1, drop = FALSE]
        )

        if (kernel == "bartlett") {
            l <- 1.1447 * (4 * a^2 * N / ((1 + a)^2 * (1 - a)^2))^(1 / 3)
        } else if (kernel == "quadratic") {
            l <- 1.3221 * (4 * a^2 * N / ((1 + a)^2 * (1 - a)^2))^(1 / 5)
        }
        l <- trunc(l)

        lrv <- drop(t(res) %*% res) / N
        for (i in 1:l) {
            if (l == 0) break

            if (kernel == "bartlett") {
                ## Bartlett kernel
                w <- (1 - i / (l + 1))
            } else if (kernel == "quadratic") {
                ## Quadratic spectral kernel
                w <- 25 / (12 * pi^2 * (i / l)^2) *
                    (sin(6 * pi * i / (l * 5)) / (6 * pi * i / (l * 5)) -
                        cos(6 * pi * i / (l * 5)))
            }
            lrv <- lrv + 2 * drop(t(res[1:(nrow(res) - i), , drop = FALSE]) %*%
                res[(1 + i):nrow(res), , drop = FALSE]) *
                w / N
        }
    }

    lrv.recolored <- lrv / (1 - sum(rho))^2

    lrv <- min(lrv.recolored, N * 0.15 * lrv)

    return(lrv)
}