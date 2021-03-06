#' Marginal Maximum Likelihood Estimation of Linear Models
#' @description
#' Implements a survey-weighted marginal maximum estimation, a type of
#' regression where the outcome is a latent trait (such as student ability).
#' Instead of using an estimate, the likelihood function marginalizes student
#' ability. Includes a variety of variance estimation strategies.
#' 
#' @param formula  a \ifelse{latex}{\code{formula}}{\code{\link[stats]{formula}}}
#'                 object in the style of \ifelse{latex}{\code{lm}}{\code{\link[stats]{lm}}}
#' @param stuItems a list where each element is named a student ID and contains
#'                 a \code{data.frame}; see Details for the format
#' @param stuDat   a \code{data.frame} with a single row per student. Predictors in
#'                 the \code{formula} must be in \code{stuDat}.
#' @param dichotParamTab a \code{data.frame} of dichotimous item information, see Details
#' @param polyParamTab a \code{data.frame} of polytimous item information, see Details
#' @param testScale a \code{data.frame} of scaling information, see Details
#' @param Q        an integer; the number of integration points
#' @param minNode a numeric; the smallest integration point for the latent variable
#' @param maxNode a numeric; the largest integration point for the latent variable
#' @param polyModel polytomous response model;
#'                  one of \code{GPCM} for the Graded Partial Credit Model
#'                  or \code{GRM} for the Graded Response Model
#' @param weightVar a variable name on \code{stuDat} that is the full sample weight
#' @param idVar a variable name on \code{stuDat} that is the identifier. Every 
#'              ID from \code{stuDat} must appear on \code{stuItems} and vice versa.
#' @param multiCore allows the \code{foreach} package to be used. You should
#'                  have already setup the 
#' \ifelse{latex}{the \code{registerDoParallel} function in the \code{doParallel} package}{\code{\link[doParallel]{registerDoParallel}}}.
#' @param bobyqaControl a list that gets passed to \ifelse{latex}{the \code{bobyqa} optimizer in \code{minqa}}{\code{\link[minqa]{bobyqa}}}
#' @param composite a logical indicating if an overall test should be treated as
#'                  a composite score; a composite is a weighted average of the
#'                  subscales in it.
#' @param strataVar character naming a variable on \code{stuDat}, the variable indicating the
#'                  stratum for each row. Used in post-hoc robust variance estimation.
#' @param PSUVar character naming a variable on \code{stuDat}; the primary sampling unit
#'               (PSU) variable. Used in post-hoc robust variance estimation. The values
#'               do not need to be unique across strata.
#' @param fast a logical indicating if cpp code should be used in \code{mml} processes. This should 
#'             yield speed-ups to runs. 
#'
#' @details
#' 
#' The \code{mml} function models a latent outcome conditioning on
#' item response data, covariate data, item parameter information,
#' and scaling information.
#' These four parts are broken up into at least one argument each.
#' Student item response data go into \code{stuItems}; whereas student
#' covariates, weights, and sampling information go into \code{stuDat}.
#' The \code{dichotParamTab} and \code{polyParamTab}
#' contains item parameter information for dichotimous and polytimous items,
#' respectively---the item parameter data is the result of an existing
#' item parameter scaling. In the case of 
#' the National Assessment of Educational Progress (NAEP),
#' they can be found online, for example, at
#' \href{https://nces.ed.gov/nationsreportcard/tdw/analysis/scaling_irt.aspx}{https://nces.ed.gov/nationsreportcard/tdw/analysis/scaling_irt.aspx}.
#' Finally, information about scaling and subscale weights for composites are put in \code{testScale}.
#' 
#' The model for dichotomous responses data is, by default, three Parameter Logit
#' (3PL), unless the item parameter information provided by users suggests
#' otherwise. For example, if the scaling used a two Parameter Logit (2PL) model,
#' then the guessing parameter can simply be set to zero. For polytomous
#' responses data, the model is dictated by the \code{polyModel} argument.
#'
#' The \code{dichotParamTab} argument is a \code{data.frame} with a column named
#' \code{ItemID} that identifies the items and agrees with
#' the \code{key} column in the \code{stuItems} argument,
#' and, for  a 3PL item, columns \code{slope},
#' \code{difficulty}, and \code{guessing} for the \dQuote{a}, \dQuote{d}, and
#' \dQuote{g} parameters, respectively; see the vignette for details of
#' the 3PL model. Users can also use the column names directly from the
#' vignette notation (\dQuote{a}, \dQuote{d}, and \dQuote{g}) if they prefer.
#' Items that are missing (\code{NA}) are not used in the likelihood function 
#' Users wishing to apply a special behavior for a subset of items can use
#' set those items to an invalid score and put that in the \code{dichotParamTab}
#' column \code{missingCode}. They are then scored as if they are \code{missingValue}
#' proportion correct. To use the guessing parameter for the proportion correct
#' set \code{missingValue} to \dQuote{c}.
#' 
#' The \code{polyParamTab} has columns \code{ItemID} that must match with the
#' \code{key} from \code{stuItems}, as well as \code{slope}
#' (which can also be called \code{a}) that corresponds to the \code{a}
#' parameter in the vignette.
#' Users must also specify the location of the cut points (d-sub-cj in the vignette)
#' which are named \code{d1}, \code{d2}, ..., up to \code{dn} where \code{n} is
#' one less than the number of score points. Some people prefer to also apply a 
#' shift to all of these and this shift is applied when there is a column named
#' \code{itemLocation} by simply adding that to every \code{d*} column. Items
#' are not included in the likelihood for an individual when there value on \code{stuItems}
#' is \code{NA}, but no provision is made for guessing, nor special provision for 
#' missing codes in polytimious items.
#' 
#' For both \code{dichotParamTab} and \code{polyParamTab} users wishing
#' to use a \code{D} paramter of 1.7 (or any other value) may specify that, per item,
#' in a column named \code{D}. 
#'
#' When there are multiple constructs, subscales, or the user wants a composite
#' score, additional, optional, columns \code{test} and \code{subtest} can be used. 
#' these columns can be numeric or text, they must agree with the same 
#' columns in \code{testScale} to scale the results. 
#' 
#' Student data are broken up into two parts. The item response data goes
#' into \code{stuItems}, and the student covariates for the formula go into
#' \code{stuDat}. Information about items, such as item difficulties, is in 
#' \code{paramTab}. All dichotomous items are assumed to be 
#' 3PL, though by setting the guessing parameter to zero, the user
#' can use a 2PL or the one Parameter Logit (1PL) or Rasch models.
#' The model for polytomous responses data is dictated by the \code{polyModel}
#' argument.
#' 
#' The marginal maximum likelihood then integrates the product of the student
#' ability from the assessment data, and the estimate from the linear model
#' estimates each student's ability based on the \code{formula} provided
#' and a residual standard error term. This integration happens from the
#' minimum node to the maximum node in the \code{control} argument (described
#' later in this section) with \code{Q} quadrature points. 
#' 
#' The \code{stuItems} argument has the scored student data. It is a list where
#' each element is named with student ID and contains
#' a \code{data.frame} with at least two columns.
#' The first required column is named
#' \code{key} and shows the item name as it appears in \code{paramTab};
#' the second column in named
#' \code{score} and shows the score for that item. For binomial
#' items, the \code{score} is 0 or 1. For \code{GPCM} items, the scores
#' start at zero as well. For \code{GRM}, the scores start at 1.
#' 
#' For a \code{GPCM} model, \code{P0} is the \dQuote{a} parameter, and the other 
#' columns are the \dQuote{d} parameters; see the vignette for details
#' of the GPCM model.
#' 
#' The quadrature points then are a range from \code{minNode} to \code{maxNode}
#' with a total of \code{Q} nodes. 
#' 
#' @return when called for a single subscale or overall score, returns object of class \code{mmlMeans}. 
#' This is a list with elements: 
#' \itemize{
#' \item{\code{call} the call used to generate this \code{mml.means} object}
#' \item{\code{coefficients} the unscaled marginal maximum likelihood regression coefficients}
#' \item{\code{LogLik} the log-likelihood of the fit model}
#' \item{\code{X} the design matrix of the marginal maximum likelihood regression}
#' \item{\code{Convergence} a convergence note from the \code{bobyqa} optimizer}
#' \item{\code{location} used for scaling the estimates}
#' \item{\code{scale} used for scaling the estimates}
#' \item{\code{lnlf} the log-likelihood function of the unscaled parameters} 
#' \item{\code{rr1} the density function of each individual, conditional only on item responses in \code{stuItems}}
#' \item{\code{stuDat} the \code{stuDat} argument}
#' \item{\code{weightVar} the name of the weight variable on \code{stuDat}}
#' \item{\code{nodes} the nodes the likelihood was evaluated on}
#' \item{\code{iterations} the number of iterations required to reach convergence}
#' \item{\code{obs} the number of observations used}
#' \item{\code{weightedObs} the weighted N for the observations}
#' \item{\code{strataVar} the column name of the stratum variable on stuDat; potentially used for variance estimation}
#' \item{\code{PSUVar} the column name of the stratum variable on stuDat; potentially used for variance estimation}
#' }
#' 
#' When a composite score is computed there are several subscales run and the return is a \code{mmlCompositeMeans}. Many elements are themselves list with one element per construct.
#' this is a list with elements:
#' \itemize{
#' \item{\code{call} the call used to generate this \code{mml.means} object}
#' \item{\code{coefficients} matrix of the unscaled marginal maximum likelihood regression coefficients, each row represents a subscale, each column represents a coefficient}
#' \item{\code{X} the design matrix of the marginal maximum likelihood regression}
#' \item{\code{rr1} a list of elements, each the rr1 object for a subscale (see \code{mmlMeans} output)}
#' \item{\code{ids} The ID variable used for each row of \code{stuDat}}
#' \item{\code{Convergence} a vector of convergence notes from the \code{bobyqa} optimizer}
#' \item{\code{lnlfl} a list of log-likelihood functions of the unscaled parameters, by construct}
#' \item{\code{stuDat} a list of \code{stuDat} data frames, as used when fitting each construct, filtered to just relevant student records}
#' \item{\code{weightVar} the name of the weight variable on \code{stuDat}}
#' \item{\code{nodes} the nodes the likelihood was evaluated on}
#' \item{\code{iterations} a vector of the number of iterations required to reach convergence on each construct}
#' \item{\code{obs} a vector of the the number of observations used on each construct}
#' \item{\code{testScale} the \code{testScale} used to scale the data}
#' \item{\code{weightedObs} a vector of the weighted N for the observations}
#' \item{\code{SubscaleVC} the covariance matrix of subscales. The residuals are assumed to be multivariate normal with this covairiance matrix}
#' \item{\code{idVar} the name of the identifier used on \code{stuDat} and \code{stuItems} data}
#' \item{\code{resl} list of mmlMeans objects, one per construct}
#' \item{\code{strataVar} the column name of the stratum variable on \code{stuDat}; potentially used for variance estimation}
#' \item{\code{PSUVar} the column name of the stratum variable on \code{stuDat}; potentially used for variance estimation}
#' }
#'
#' \code{LogLik} is not returned because there is no likelihood for a composite model.
#' 
#' @example man/examples/de.R
#' @author Harold Doran, Paul Bailey, Claire Kelley, Sun-joo Lee, and Eric Buehler 
#' @export
#' @importFrom methods as 
#' @importFrom minqa bobyqa 
#' @importFrom stats as.formula model.matrix coef dbinom sd terms reformulate complete.cases
#' @importFrom utils head
#' @import Rcpp
#' @import haven 
#' @useDynLib Dire, .registration = TRUE
mml <- function(formula,
                stuItems,
                stuDat,
                idVar,
                dichotParamTab = NULL,
                polyParamTab = NULL,
                testScale = NULL,
                Q = 30,
                minNode = -4,
                maxNode = 4,
                polyModel = c('GPCM', 'GRM'),
                weightVar = NULL,
                multiCore = FALSE,
                bobyqaControl = list(maxfun=1e5),
                composite = TRUE,
                strataVar = NULL,
                PSUVar = NULL,
                fast = TRUE) { # missing code from NAEP
  call <- match.call()
  polyModel <- match.arg(polyModel)
  polyModel <- tolower(polyModel)
  if(!idVar %in% names(stuDat)) {
    stop(paste0(dQuote("idVar"), ", ", dQuote(idVar), ", must be a variable on stuDat."))
  }
  if(!inherits(stuDat, "data.frame")) {
    stop(paste0("Argument ", dQuote("stuDat"), " must be a data frame."))
  } else {
    if(length(class(stuDat))>1) {
      # not all data.frames are the same, recast
      stuDat <- as.data.frame(stuDat)
    }
  }
  if(missing(polyParamTab) & missing(dichotParamTab)) {
    stop(paste0("At least one of the arguments ", dQuote("polyParamTab"), " or ", dQuote("dichotParamTab"), " must be defined."))
  }
  dichotParamTab <- cleanDichotParamTab(dichotParamTab) 
  # clean polyParamTab, get the list of d variables on it
  pptd <- cleanPolyParamTab(polyParamTab)
  paramTab <- condenseParamTab(dichotParamTab, pptd$polyParamTab, pptd$dvars)
  
  # make sure every stuItems student has a stuDat student, and the other way around
  if(!is.data.frame(stuItems)) {
    stuItems <- do.call(rbind, stuItems)
  }
  if(length(class(stuItems))>1) {
    # not all data.frames are the same, recast
    stuItems <- as.data.frame(stuItems)
  }
  if(any(!stuItems[[idVar]] %in% stuDat[[idVar]])) {
    missing <- (stuItems[[idVar]])[!(stuItems[[idVar]]) %in% stuDat[[idVar]]]
    stop(paste0("The ", dQuote("stuItems"), " argument must be a list with names that correspond to every " , dQuote("idVar"), " in ", dQuote("stuDat"), ". some missing IDs ", pasteItems(dQuote(head(missing,5))), "."))
  }
  if(any(!stuDat[[idVar]] %in% stuItems[[idVar]])) {
    missing <- stuDat[[idVar]][!stuDat[[idVar]] %in% stuItems[[idVar]]]
    stop(paste0("The ", dQuote("stuDat"), " argument must be a data frame with a column ", dQuote("idVar"), " that correspond to every name of ", dQuote("stuItems"), ". some missing IDs ", pasteItems(dQuote(head(missing,5))), "." ))
  }
  # make sure stuItems and stuDat are in the same order
  stuItems[[idVar]] <- as.character(stuItems[[idVar]])
  stuItems$key <- as.character(stuItems$key)
  stuDat[[idVar]] <- as.character(stuDat[[idVar]])
  stuItems <- stuItems[order(stuItems[[idVar]]), ]
  stuDat <- stuDat[order(stuDat[[idVar]]), ]
  # overall: boolean for if this is a test (multiple subtest)
  # assume not, check if TRUE later
  overall <- FALSE 
  # formula may be missing, then define a null model
  if(missing(formula)) {
    formula <- ~ 1
  } # end if(missing(formula))
  testScale2 <- testScale # potentially update testScale
  if(length(formula) > 2) {
    outcome <- as(formula[[2]], "character")
    if(outcome %in% c(paramTab$test)) {
      testScale2 <- testScale[testScale$test %in% outcome, ]
      if("subtest" %in% colnames(testScale)) {
        testScale2 <- testScale2[is.na(testScale2$subtest), ]
      }
      paramTab <- paramTab[paramTab$test %in% outcome, ]
      overall <- TRUE
    } else {
      if( "subtest" %in% colnames(paramTab) & outcome %in% paramTab$subtest) {
        paramTab <- paramTab[paramTab$subtest %in% outcome,]
        testScale2 <- testScale[testScale$subtest %in% outcome,]
      } else {
        stop(paste0("Outcome variable ", dQuote(outcome)," not found in any of  ", pasteItems(dQuote(c("dichotParamTab$test", "dichotParamTab$subtest", "polyParamTab$test", "polyParamTab$subtest")), "nor"), "."))
      }
    }
  } else { # else for     if(length(formula) > 2) 
    # the user did not specify a test or subtest
    if(length(unique(paramTab$test)) > 1) {
      stop("when there are multiple tests defined the test must be specified as the outcome in the formula.")
    }
    if(!"subtest" %in% colnames(paramTab)) {
      paramTab$subtest <- "default subtest"
      composite <- FALSE
      overall <- FALSE
    }
    if(length(unique(paramTab$subtest)) > 1) {
      overall <- TRUE
    }
  } # end else for if(length(formula) > 2)

  # in this situation, it is not composite/overall
  if(length(unique(paramTab$subtest)) == 1) {
    overall <- FALSE
    composite <- FALSE
  }
  # subset testScale if not composite
  if(!composite) {
    testScale <- testScale2
  }

  # break down to subtests and optimize those
  if(composite) {
    subtests <- sort(unique(paramTab$subtest))
    testScale <- testScale[order(testScale$subtest), ]
    testScale <- testScale[testScale$subtest %in% subtests, ]
    coef <- c()
    lnlfl <- list()
    rr1l <- list()
    stuDatl <- list()
    Xl <- list()
    iter <- c()
    obs <- c()
    wobs <- c()
    Convergence <- c()
    subt <- c()
    resl <- list()
    s <- c()
    for(sti in 1:length(subtests)) {
      subt <- c(subt, subtests[sti])
      termLabels <- attr(terms(formula), "term.labels")
      if(length(termLabels) == 0) {
        termLabels <- "1"
      }
      formulai <- reformulate(termLabels, response = subtests[sti])
      calli <- call
      calli$formula <- formulai
      # this resolves any lazy unresolved calls in variables
      calli$stuItems <- stuItems
      calli$testScale <- testScale
      calli$strataVar <- strataVar
      calli$PSUVar <- PSUVar
      # this subtest will not itself be a composite
      calli$composite <- FALSE
      resi <- eval(calli)
      # the call is stored very inefficiently and is removed
      calliName <- call
      calliName$composite <- FALSE
      calliName$formula <- formulai
      resi$call <- calliName
      resl <- c(resl, list(resi))
      co <- resi$coefficients
      # remove standard deviation
      Xbi <- as.vector(resi$X %*% co[-length(co)])
      Xbdf <- data.frame(id=rownames(resi$X), xb=Xbi, stringsAsFactors=FALSE)
      colnames(Xbdf)[2] <- paste0("Xb",sti)
      if(sti > 1) {
        Xb <- merge(Xb, Xbdf, by="id", all=TRUE)
      } else {
        Xb <- Xbdf
      }
      # standard deviation is the last element
      s <- c(s, co[length(co)])
      coef <- c(coef, resi$coefficients)
      lnlfl <- c(lnlfl, list(resi$lnlf))
      stuDatl <- c(stuDatl, list(resi$stuDat))
      Convergence <- c(Convergence, resi$Convergence)
      rr1l <- c(rr1l, list(resi$rr1))
      Xl <- c(Xl, list(resi$X))
      iter <- c(iter, resi$iterations)
      obs <- c(obs, resi$obs)
      wobs <- c(wobs, resi$weightedObs)
      k <- length(resi$coefficients)
      # nodes are the same for every run
      nodes <- resi$nodes
    }
    vc <- matrix(0, nrow=length(subtests), ncol=length(subtests))
    diag(vc) <- s^2
    if(is.null(weightVar)) {
      stuDat$one <- 1
      weightVar <- "one"
    }
    wgt <- stuDat[ , c(idVar, weightVar)]
    colnames(wgt)[2] <- "w"
    if(multiCore) {
      corm <- data.frame(i= rep(1:length(subtests), each=length(subtests)),
                        j= rep(1:length(subtests), length(subtests)))
      corm <- corm[corm$i > corm$j, ]
      corms <- split(corm, 1:nrow(corm))
      itc <- iter(corms)
      cori <- foreach(dopari = itc, .packages="Dire", .export = c("optimize")) %dopar% {
        i <- dopari$i
        j <- dopari$j
        xbi <- Xb[,paste0("Xb",i)]
        xbj <- Xb[,paste0("Xb",j)]
        # just cases in both
        ijss <- !is.na(xbi) & !is.na(xbj)
        xbi <- xbi[ijss]
        xbj <- xbj[ijss]
        # subset rr1 
        rr1i <- rr1l[[i]]
        rr1j <- rr1l[[j]]
        rr1i <- rr1i[ , colnames(rr1i) %in% Xb$id[ijss]]
        rr1j <- rr1j[ , colnames(rr1j) %in% Xb$id[ijss]]
        if( all.equal(colnames(rr1i), Xb$id[ijss])[1] != TRUE) {
          stop("rr1i names do not agree with Xb names.")
        }
        if( all.equal(colnames(rr1j), Xb$id[ijss])[1] != TRUE) {
          stop("rr1j names do not agree with Xb names.")
        }
        w <- wgt[wgt[,idVar] %in% Xb$id[ijss],]
        if( all.equal(w[,idVar], Xb$id[ijss])[1] != TRUE) {
          stop("weigth names do not agree with Xb names.")
        }
        vcij <- mmlCor(Xb1=xbi,
                       Xb2=xbj,
                       s1=s[i],
                       s2=s[j],
                       rr1=rr1i,
                       rr2=rr1j,
                       weights=w$w,
                       nodes=resi$nodes)
        return(list(i=i,j=j,vc=vcij))
      }
      # make a long data frame with columns i, j, and cor
      vclong <- as.data.frame(do.call(rbind,lapply(cori, unlist)))
      colnames(vclong)[3] <- "cor"
      for(i in 1:length(subtests)) {
        for(j in 1:length(subtests)) {
          if(i > j) {
            vc[i,j] <- vclong[vclong$i == i & vclong$j == j, "cor"] 
            vc[j,i] <- vc[i,j]
          }
        }
      }

    } else {
      for(i in 1:length(subtests)) {
        for(j in 1:length(subtests)) {
          if(i > j) {
            # subset Xb
            xbi <- Xb[,paste0("Xb",i)]
            xbj <- Xb[,paste0("Xb",j)]
            # just cases in both
            ijss <- !is.na(xbi) & !is.na(xbj)
            xbi <- xbi[ijss]
            xbj <- xbj[ijss]
            # subset rr1 
            rr1i <- rr1l[[i]]
            rr1j <- rr1l[[j]]
            rr1i <- rr1i[ , colnames(rr1i) %in% Xb$id[ijss]]
            rr1j <- rr1j[ , colnames(rr1j) %in% Xb$id[ijss]]
            if( all.equal(colnames(rr1i), Xb$id[ijss])[1] != TRUE) {
              stop("rr1i names do not agree with Xb names.")
            }
            if( all.equal(colnames(rr1j), Xb$id[ijss])[1] != TRUE) {
              stop("rr1j names do not agree with Xb names.")
            }
            w <- wgt[wgt[,idVar] %in% Xb$id[ijss],]
            if( all.equal(w[,idVar], Xb$id[ijss])[1] != TRUE) {
              stop("weigth names do not agree with Xb names.")
            }
            vc[i,j] <- mmlCor(Xb1=xbi,
                              Xb2=xbj,
                              s1=s[i],
                              s2=s[j],
                              rr1=rr1i,
                              rr2=rr1j,
                              weights=w$w,
                              nodes=resi$nodes)
            vc[j,i] <- vc[i,j]
          }
        }
      }
    }
    # add names to everything
    colnames(vc) <- rownames(vc) <- subtests
    names(stuDatl) <- names(lnlfl) <- names(rr1l) <- names(Xl) <- names(resl) <- subtests
    names(iter) <- names(obs) <- names(wobs) <- subtests
    coefM <- matrix(coef, nrow=length(subtests), byrow=TRUE)
    rownames(coefM) <- subtests
    colnames(coefM) <- names(coef)[1:ncol(coefM)]
    res <- structure(list("call" = call,
                          "coefficients" = coefM,
                          "X" = Xl,
                          "rr1" = rr1l,
                          "ids" = stuDat[[idVar]],
                          'Convergence' = Convergence,
                          "lnlfl" = lnlfl,
                          "stuDat" = stuDatl,
                          "weightVar" = weightVar,
                          "nodes" = resi$nodes,
                          iterations = iter,
                          "obs" = obs,
                          "testScale" = testScale,
                          "weightedObs" = wobs,
                          "SubscaleVC" = vc,
                          idVar = idVar,
                          resl = resl,
                          strataVar = strataVar,
                          PSUVar = PSUVar),
                     class = "mmlCompositeMeans")
     return(res)
  } # end if(composite) {

  # done with the left hand side of the formula, if it exists, drop it
  if(length(formula) > 2) {
    formula[[2]] <- NULL
  }
  # subset stuDat to valid data
  cc <- complete.cases(stuDat[,c(all.vars(formula), weightVar, strataVar, PSUVar)])
  stuDat <- stuDat[cc,]
  stuItems <- stuItems[stuItems[[idVar]] %in% stuDat[[idVar]],]
  if(nrow(stuDat) == 0) {
    stop(paste0("no complete cases in ", dQuote("stuDat"), "."))
  }
  if(nrow(stuItems) == 0) {
    stop(paste0("no complete cases in ", dQuote("stuItems"), "."))
  }

  # make sure stuItems (now stu) has only data.frames in each element
  # sort by key/ItemID
  if(any(!c(idVar, "key", "score") %in% colnames(stuItems))) {
    stop(paste0("Argument ", dQuote("stuItems"), " must have variables ", pasteItems(c(idVar, "key", "score")), "."))
  }
  # these are the only columns we need
  stuItems <- stuItems[,c(idVar, "key", "score")]
  # drop rows with no test data on them, they get dropped from the likelihood function anyways
  stuItems <- stuItems[!is.na(stuItems$score),]
  # only keep items in the paramTab
  stuItems <- stuItems[stuItems$key %in% paramTab$ItemID,]
  stu <- stuItems[order(stuItems$key), ]
  stu <- split(stu, stu[[idVar]])
  paramTab <- paramTab[order(paramTab$ItemID),]

  # subset to students who have at least one valid score
  stuDat <- stuDat[stuDat[[idVar]] %in% names(stu),]

  # now form X
  X <- model.matrix(formula, stuDat)
  rownames(X) <- stuDat[[idVar]]
  K <- ncol(X) # number of fixed parameters to estimate   
  nms <- c(colnames(X), 'Population SD') 
  startVal <- c(rep(0, K), 1)
  if(nrow(X) != nrow(stuDat)) {
    stop("Missing values not allowed in independent variables.")
  }
  ### These are the exported functions passed to the dopar function
  nodes <- seq(from = minNode, to = maxNode, length.out = Q)

  ### This portion of the code computes all the likelihood evaluations
  ### and does so outside of the function that is maximized
  ### This saves a lot of overhead by using fixed quadrature points
  if(multiCore) {
    # use multiple cores to calculate rr1
    rr1 <- calcRR1_dopar(stu, Q, polyModel, paramTab, nodes, fast)
  } else {
    # calculate rr1 on a single core
    rr1 <- calcRR1(stu, Q, polyModel, paramTab, nodes, fast)
  }
  # add names to rr1
  colnames(rr1) <- names(stu)
  if(!all.equal(colnames(rr1), stuDat[[idVar]])) {
    stop("Sorting error in mml.")
  }
  #colnames(rr1) <- stuDat[[idVar]]
  fn2 <- fn.regression(X_=X, i=NULL, wv=weightVar, rr1=rr1, nodes=nodes, stuDat=stuDat)
  opt <- bobyqa(startVal, fn2, control=bobyqaControl)
  opt$par[length(opt$par)] <- abs(opt$par[length(opt$par)])
  iter <- opt$feval
  convergence <- opt$msg
  names(opt$par) <- c(colnames(X), "s")
  # default location and scale
  location <- 0
  scale <- 1
  if(!is.null(testScale)) {
    location <- testScale$location[1]
    scale <- testScale$scale[1]
  }
  if(is.null(weightVar)) {
    obs <- sum(apply(rr1,2,sum)>0)
    weightedObs <- obs
  } else {
    obs <- sum(stuDat[,weightVar]>0 & apply(rr1,2,sum)>0) # number with positive weight, at least one response
    weightedObs <- sum(stuDat[apply(rr1,2,sum)>0,weightVar]) # sum of weights for those with positive weight, at least one response
  }
  coefficients <- opt$par
  names(coefficients) <-nms
  structure(list("call" = call,
                 "coefficients" = coefficients,
                 "LogLik" = -1/2*opt$fval,
                 "X" = X,
                 'Convergence' = convergence,
                 "location" = location,
                 "scale" = scale,
                 "lnlf"= fn2,
                 "rr1"= rr1,
                 "stuDat" = stuDat,
                 "weightVar" = weightVar,
                 "nodes" = nodes,
                 iterations = iter,
                 "obs" = obs,
                 "weightedObs" = weightedObs,
                 strataVar = strataVar,
                 PSUVar = PSUVar),
            class = "mmlMeans")
}

#' @importFrom stats optimize
mmlCor <- function(Xb1,
                   Xb2,
                   s1,
                   s2,
                   rr1,
                   rr2,
                   nodes,
                   weights=NULL) { 
  # fn2 uses the Fisher-Z transformation
  # fine rebins rr1 for large correlations where numerical integration becomes difficult
  fn2f <- fnCor(Xb1=Xb1, Xb2=Xb2, s1=s1, s2=s2, w=weights, rr1=rr1, rr2=rr2, nodes=nodes, fine=TRUE, fast = TRUE)
  ## optimize in Fisher-Z space
  # assumes no local minima
  # -5/5 are close enough to cor=-1/1 to use
  opt <- optimize(fn2f, c(-5, 5))
  
  # transform back to original space and return result
  return(tanh(opt$minimum) * s1 * s2)
}

# unused
Newton <- function(fn, start, min, max){ 
  opt <- optimize(fn, c(-10, 10), tol=0.1)
  here <- opt$minimum
  fnhere <- fn(here)
  grHere <- getGrad(fn, here)
  Hhere <- as.numeric(getHessian(fn, here))
  hereProposal <- here - grHere / Hhere
  fnhereP <- fn(hereProposal)
  if(fnhereP < opt$objective) {
    return(hereProposal)
  }
  return(opt$minimum)
}


cleanDichotParamTab <- function(dpt) {
  if(!is.null(dpt)) {
    if(!inherits(dpt, "data.frame")) {
      stop(paste0("Argument ", dQuote("dichotParamTab"), " must be a data frame."))
    } else {
      if(length(class(dpt))>1) {
        # not all data.frames are the same, recast
        dpt <- as.data.frame(dpt)
      }
    }
    if(!"ItemID" %in% colnames(dpt)) {
      stop(paste0("Argument ", dQuote("dichotParamTab"), " must have column ", dQuote("ItemID"), "."))
    }
    if(length(unique(dpt$ItemID)) < nrow(dpt)) {
      stop(paste0("The ", dQuote("ItemID"), " column on the ", dQuote("dichotParamTab"), " argument must be unique."))
    }
    colnames(dpt)[colnames(dpt)=="a"] <- "slope"
    colnames(dpt)[colnames(dpt) %in% c("asymptote", "g") ] <- "guessing"
    colnames(dpt)[colnames(dpt)=="d"] <- "difficulty"
    reqVar <- c("ItemID", "test", "slope", "difficulty", "guessing")
    if(any(!reqVar %in% colnames(dpt))) {
      stop(paste0("dichotParamTab must have all of the columns ", pasteItems(reqVar), "."))
    }
    if("subtest" %in% colnames(dpt)) {
      dpt$subtest <- as.character(dpt$subtest)
    }
    if("test" %in% colnames(dpt)) {
      dpt$test <- as.character(dpt$test)
    }
  }
  return(dpt)
}

cleanPolyParamTab <- function(ppt) {
  dvars <- c()
  if(!is.null(ppt)) {
    if(!inherits(ppt, "data.frame")) {
      stop(paste0("Argument ", dQuote("polyParamTab"), " must be a data frame."))
    } else {
      if(length(class(ppt))>1) {
        # not all data.frames are the same, recast
        ppt <- as.data.frame(ppt)
      }
    }
    if(length(unique(ppt$ItemID)) < nrow(ppt)) {
      stop(paste0("The ", dQuote("ItemID"), " column on the ", dQuote("polyParamTab"), " argument must be unique."))
    }
    colnames(ppt)[colnames(ppt)=="a"] <- "slope"
    colnames(ppt)[colnames(ppt)=="d"] <- "itemLocation"
    if(!"itemLocation" %in% colnames(ppt)) {
      ppt$itemLocation <- NA
    } 
    i <- 1
    while(paste0("d",i) %in% colnames(ppt)) {
      var <- paste0("d",i)
      ppt[,var] <- ifelse(is.na(ppt$itemLocation), ppt[,var], ppt$itemLocation - ppt[,var])
      dvars <- c(dvars, var)
      i <- i + 1
    }
    # prevent this from being applied twice for composite
    ppt$itemLocation <- NULL 
    ppt[,"d0"] <- 0
    i <- i - 1
    if(any(!is.na(ppt[,paste0("d",i)]))) {
      ppt[,paste0("d",i+1)] <- NA
    }
    reqVar <- c("ItemID", "test", "slope", "scorePoints")
    if(any(!reqVar %in% colnames(ppt))) {
      stop(paste0("polyParamTab must have all of the columns ", pasteItems(reqVar), "."))
    }
  }
  return(list(polyParamTab=ppt, dvars=dvars))
}

condenseParamTab <- function(dpt, ppt, dvars) {
  # build paramTab with info from both
  if(!is.null(dpt)) {
    paramTab <- dpt
    paramTab$scorePoints <- 1L
    if(!is.null(ppt)) {
      for(dvi in c("d0",dvars)) {
        paramTab[,dvi] <- NA
      }
      # make sure col names agree
      for(ci in colnames(paramTab)) {
        if(!ci %in% colnames(ppt)) {
          ppt[,ci] <- NA
        }
      }
      if("D" %in% colnames(ppt)) {
        if(!"D" %in% colnames(dpt)) {
          if(sd(ppt$D) < sqrt(.Machine$double.eps)) {
            paramTab$D <- ppt$D
          } else {
            paramTab$D <- 1
          }
        }
      }
      for(ci in colnames(ppt)) {
        if(!ci %in% colnames(paramTab)) {
          paramTab[,ci] <- NA
        }
      }
      paramTab <- rbind(paramTab, ppt)
    }
  } else {
    paramTab <- ppt
    paramTab$guessing <- NA
    paramTab$difficulty <- NA
  }
  paramTab$ItemID <- as.character(paramTab$ItemID)
  return(paramTab)
}