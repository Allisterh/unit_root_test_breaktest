#' @title
#' SADF test based on NW estimation and reindexing.
#'
#' @importFrom zeallot %<-%
#'
#' @export
STADF.test <- function(y,
                       r0 = 0.01 + 1.8 / sqrt(length(y)),
                       const = FALSE,
                       omega.est = TRUE,
                       h = "auto_CV",
                       truncated = TRUE,
                       is.reindex = TRUE,
                       ksi.input = "auto",
                       hc = 1,
                       pc = 1,
                       add.p.value = TRUE) {

    N <- length(y)

    # Part 4.1. NW estimation.
    # Estimate kernel regression either on the basis of CV or for a fixed h.
    y.0 <- y - y[1]
    my <- diff(y.0)
    mx <- y.0[1:(N - 1)]
    nw.model.cv <- NW.loocv(my, mx)
    nw.model <- NW.estimation(my, mx, h = nw.model.cv$h)

    h.est <- hc * nw.model.cv$h
    u.hat <- nw.model$u.hat

    # Truncating the residuals.
    if (truncated == TRUE) {
        if (ksi.input == "auto") {
            # Calculate sigma.
            sigma <- 0
            bd <- round(0.1 * (N - 1))
            for (s in bd:(N - 1)) {
                sigma1 <- sd(u.hat[(s - bd + 1):s])
                if (sigma1 > sigma) {
                    sigma <- sigma1
                }
            }
            ksi <- pc * sigma * (N - 1) ^ (1 / 7)
        } else {
            ksi <- ksi.input
        }
        u.hat.truncated <- ifelse(abs(u.hat) < ksi, u.hat, 0)
        u.hat.star <- u.hat.truncated
    } else {
        u.hat.star <- u.hat
    }

    # w.sq - the average of squares residues.
    if (omega.est == TRUE) {
        w.sq <- mean(u.hat.star^2)
    } else {
        w.sq <- 1
    }

    # Part 4.2. Reindex.
    if (is.reindex == TRUE) {
        c(., ., eta.hat, ., new.index) %<-% reindex(u.hat.star)
    } else {
        new.index <- c(0:(N - 1))
    }
    y.tt <- y[new.index + 1]

    # Part 4.3. STADF test.
    t.values <- c()
    m <- 1

    for (j in (floor(r0 * N)):N) {
        # If we consider a model with a constant, we subtract the moving average.
        if (const) {
            y.tt.norm <- y.tt - mean(y.tt[1:j])
        } else {
            y.tt.norm <- y.tt - y.tt[1]
        }

        t.values[m] <- (y.tt.norm[j]^2 - y.tt.norm[1]^2 - w.sq * (j - 1)) /
        (w.sq^0.5 * 2 * sum(y.tt.norm[1:(j - 1)]^2)^0.5)
        m <- m + 1
    }

    # Take the maximum of the calculated t-statistics.
    stadf.value <- max(t.values)

    # Critical value.
    if (const == TRUE) {
        cr.value <- 2.2 # modify
    } else {
        cr.value <- 3.36 # modify
    }

    if (add.p.value) {
        if (const == TRUE) {
            cr.values <- .cval_SADF_with_const
        } else {
            cr.values <- .cval_SADF_without_const
        }
        p.value <- round(sum(cr.values > stadf.value) / length(cr.values), 4)
    }

    # If stadf_value > cr_value, we reject the null hypothesis.
    is.explosive <- ifelse(stadf.value > cr.value, 1, 0)

    result <- c(
        list(
            y = y,
            N = N,
            r0 = r0,
            const = const,
            omega.est = omega.est,
            h = h,
            truncated = truncated,
            is.reindex = is.reindex,
            new.index = new.index,
            ksi.input = ksi.input,
            hc = hc,
            h.est = h.est,
            u.hat = u.hat,
            pc = pc,
            w.sq = w.sq,
            t.values = t.values,
            stadf.value = stadf.value,
            is.explosive = is.explosive
        ),
        if (truncated) {
            list(u.hat.truncated = u.hat.truncated)
        } else NULL,
        if (ksi.input == "auto") {
            list(ksi = ksi, sigma = sigma)
        } else NULL,
        if (is.reindex) {
            list(eta.hat = eta.hat)
        } else NULL,
        if (add.p.value) {
            list(p.value = p.value)
        } else NULL
    )

    class(result) <- "sadf"
    
    return(result)
}