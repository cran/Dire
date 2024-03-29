% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/de.R
\name{mml}
\alias{mml}
\title{Marginal Maximum Likelihood Estimation of Linear Models}
\usage{
mml(
  formula,
  stuItems,
  stuDat,
  idVar,
  dichotParamTab = NULL,
  polyParamTab = NULL,
  testScale = NULL,
  Q = 30,
  minNode = -4,
  maxNode = 4,
  polyModel = c("GPCM", "GRM"),
  weightVar = NULL,
  multiCore = FALSE,
  bobyqaControl = NULL,
  composite = TRUE,
  strataVar = NULL,
  PSUVar = NULL,
  fast = TRUE,
  calcCor = TRUE,
  verbose = 0
)
}
\arguments{
\item{formula}{a \ifelse{latex}{\code{formula}}{\code{\link[stats]{formula}}}
object in the style of \ifelse{latex}{\code{lm}}{\code{\link[stats]{lm}}}}

\item{stuItems}{a \code{data.frame} where each row represents a single student's response to one item.
The columns must include the \code{idVar} column, a \code{key} column, and a
\code{score} column. Values in the \code{score} column are checked against expectations
(based on \code{dichotParamTab} and \code{polyParamTab}) and when
\code{verbose} is >= 1 a table of expected and actual levels is printed.}

\item{stuDat}{a \code{data.frame} with a single row per student. Predictors in
the \code{formula} must be in \code{stuDat}.}

\item{idVar}{a variable name on \code{stuDat} that is the identifier. Every 
ID from \code{stuDat} must appear on \code{stuItems} and vice versa.}

\item{dichotParamTab}{a \code{data.frame} of dichotomous item information, see Details}

\item{polyParamTab}{a \code{data.frame} of polytomous item information, see Details}

\item{testScale}{a \code{data.frame} of scaling information, see Details}

\item{Q}{an integer; the number of integration points}

\item{minNode}{a numeric; the smallest integration point for the latent variable}

\item{maxNode}{a numeric; the largest integration point for the latent variable}

\item{polyModel}{polytomous response model;
one of \code{GPCM} for the Graded Partial Credit Model
or \code{GRM} for the Graded Response Model}

\item{weightVar}{a variable name on \code{stuDat} that is the full sample weight}

\item{multiCore}{allows the \code{foreach} package to be used. You should
                 have already setup the 
\ifelse{latex}{the \code{registerDoParallel} function in the \code{doParallel} package}{\code{\link[doParallel]{registerDoParallel}}}.}

\item{bobyqaControl}{deprecated. A list that gets passed to the \code{bobyqa} optimizer in \code{minqa}}

\item{composite}{a logical indicating if an overall test should be treated as
a composite score; a composite is a weighted average of the
subscales in it.}

\item{strataVar}{character naming a variable on \code{stuDat}, the variable indicating the
stratum for each row. Used in post-hoc robust variance estimation.}

\item{PSUVar}{character naming a variable on \code{stuDat}; the primary sampling unit
(PSU) variable. Used in post-hoc robust variance estimation. The values
do not need to be unique across strata.}

\item{fast}{a logical indicating if cpp code should be used in \code{mml} processes. This should 
yield speed-ups to runs.}

\item{calcCor}{set to \code{TRUE} to calculate covariances. Needed to estimate variances and form plausible values}

\item{verbose}{integer, negative or zero for no details, increasingly verbose messages at one and two}
}
\value{
When called for a single subscale or overall score, returns object of class \code{mmlMeans}. 
This is a list with elements: 
\itemize{
\item{\code{call} the call used to generate this \code{mml.means} object}
\item{\code{coefficients} the unscaled marginal maximum likelihood regression coefficients}
\item{\code{LogLik} the log-likelihood of the fit model}
\item{\code{X} the design matrix of the marginal maximum likelihood regression}
\item{\code{Convergence} a convergence note from the optimizer}
\item{\code{location} used for scaling the estimates}
\item{\code{scale} used for scaling the estimates}
\item{\code{lnlf} the log-likelihood function of the unscaled parameters} 
\item{\code{rr1} the density function of each individual, conditional only on item responses in \code{stuItems}}
\item{\code{stuDat} the \code{stuDat} argument}
\item{\code{weightVar} the name of the weight variable on \code{stuDat}}
\item{\code{nodes} the nodes the likelihood was evaluated on}
\item{\code{iterations} the number of iterations required to reach convergence}
\item{\code{obs} the number of observations used}
\item{\code{weightedObs} the weighted N for the observations}
\item{\code{strataVar} the column name of the stratum variable on stuDat; potentially used for variance estimation}
\item{\code{PSUVar} the column name of the PSU variable on stuDat; potentially used for variance estimation}
\item{\code{itemScorePoints} a data frame that shows item IDs, the number of score points, expected scores (both from the paramTab arguments), as well as the occupied score points}
\item{\code{stuItems} the data frame passed to \code{mml} reformatted for use in mml}
\item{\code{formula} the formula passed to \code{mml}}
\item{\code{contrasts} the contrasts used in forming the design matrix}
\item{\code{xlevels} the levels of the covariates used in forming the design matrix}
\item{\code{polyModel} the value of the argument of the same name passed to \code{mml}}
\item{\code{paramTab} a data frame that condenses \code{dichotParamTab} and \code{polyParamTab}}
\item{\code{fast} the value of the argument of the same name passed to \code{mml}}
\item{\code{idVar} the value of the argument of the same name passed to \code{mml}}
\item{\code{posteriorEsts} the posterior estimates for the people in \code{stuDat} included in the model}
}

When a composite score is computed there are several subscales run and the return is a \code{mmlCompositeMeans}. Many elements are themselves list with one element per construct.
this is a list with elements:
\itemize{
\item{\code{call} the call used to generate this \code{mml.means} object}
\item{\code{coefficients} matrix of the unscaled marginal maximum likelihood regression coefficients, each row represents a subscale, each column represents a coefficient}
\item{\code{X} the design matrix of the marginal maximum likelihood regression}
\item{\code{rr1} a list of elements, each the rr1 object for a subscale (see \code{mmlMeans} output)}
\item{\code{ids} The ID variable used for each row of \code{stuDat}}
\item{\code{Convergence} a vector of convergence notes from the optimizer}
\item{\code{lnlfl} a list of log-likelihood functions of the unscaled parameters, by construct}
\item{\code{stuDat} a list of \code{stuDat} data frames, as used when fitting each construct, filtered to just relevant student records}
\item{\code{weightVar} the name of the weight variable on \code{stuDat}}
\item{\code{nodes} the nodes the likelihood was evaluated on}
\item{\code{iterations} a vector of the number of iterations required to reach convergence on each construct}
\item{\code{obs} a vector of the the number of observations used on each construct}
\item{\code{testScale} the \code{testScale} used to scale the data}
\item{\code{weightedObs} a vector of the weighted N for the observations}
\item{\code{SubscaleVC} the covariance matrix of subscales. The residuals are assumed to be multivariate normal with this covairiance matrix}
\item{\code{idVar} the name of the identifier used on \code{stuDat} and \code{stuItems} data}
\item{\code{resl} list of mmlMeans objects, one per construct}
\item{\code{strataVar} the column name of the stratum variable on \code{stuDat}; potentially used for variance estimation}
\item{\code{PSUVar} the column name of the PSU variable on \code{stuDat}; potentially used for variance estimation}
\item{\code{stuItems} the data frame passed to \code{mml} reformatted for use in mml}
\item{\code{formula} the formula passed to \code{mml}}
\item{\code{contrasts} the contrasts used in forming the design matrix}
\item{\code{xlevels} the levels of the covariates used in forming the design matrix}
\item{\code{polyModel} the value of the argument of the same name passed to \code{mml}}
\item{\code{posteriorEsts} the list of posterior estimates for the people in \code{stuDat} included in the model}
\item{\code{SubscaleVC} the matrix of latent correlations across constructs}
}

\code{LogLik} is not returned because there is no likelihood for a composite model.
}
\description{
Implements a survey-weighted marginal maximum estimation, a type of
regression where the outcome is a latent trait (such as student ability).
Instead of using an estimate, the likelihood function marginalizes student
ability. Includes a variety of variance estimation strategies.
}
\details{
The \code{mml} function models a latent outcome conditioning on
item response data, covariate data, item parameter information,
and scaling information.
These four parts are broken up into at least one argument each.
Student item response data go into \code{stuItems}; whereas student
covariates, weights, and sampling information go into \code{stuDat}.
The \code{dichotParamTab} and \code{polyParamTab}
contain item parameter information for dichotomous and polytomous items,
respectively---the item parameter data is the result of an existing
item parameter scaling. In the case of 
the National Assessment of Educational Progress (NAEP),
they can be found online, for example, at
\href{https://nces.ed.gov/nationsreportcard/tdw/analysis/scaling_irt.aspx}{NAEP technical documentation}.
Finally, information about scaling and subscale weights for composites are put in \code{testScale}.

The model for dichotomous responses data is, by default, three Parameter Logit
(3PL), unless the item parameter information provided by users suggests
otherwise. For example, if the scaling used a two Parameter Logit (2PL) model,
then the guessing parameter can simply be set to zero. For polytomous
responses data, the model is dictated by the \code{polyModel} argument.

The \code{dichotParamTab} argument is a \code{data.frame} with a column named
\code{ItemID} that identifies the items and agrees with
the \code{key} column in the \code{stuItems} argument,
and, for  a 3PL item, columns \code{slope},
\code{difficulty}, and \code{guessing} for the \dQuote{a}, \dQuote{d}, and
\dQuote{g} parameters, respectively; see the vignette for details of
the 3PL model. Users can also use the column names directly from the
vignette notation (\dQuote{a}, \dQuote{d}, and \dQuote{g}) if they prefer.
Items that are missing (\code{NA}) are not used in the likelihood function. 
Users wishing to apply a special behavior for a subset of items can use
set those items to an invalid score and put that in the \code{dichotParamTab}
column \code{missingCode}. They are then scored as if they are \code{missingValue}
proportion correct. To use the guessing parameter for the proportion correct
set \code{missingValue} to \dQuote{c}.

The \code{polyParamTab} has columns \code{ItemID} that must match with the
\code{key} from \code{stuItems}, as well as \code{slope}
(which can also be called \code{a}) that corresponds to the \code{a}
parameter in the vignette.
Users must also specify the location of the cut points (\eqn{d_{cj}} in the vignette)
which are named \code{d1}, \code{d2}, ..., up to \code{dn} where \code{n} is
one less than the number of score points. Some people prefer to also apply a 
shift to all of these and this shift is applied when there is a column named
\code{itemLocation} by simply adding that to every \code{d*} column. Items
are not included in the likelihood for an individual when their value on \code{stuItems}
is \code{NA}, but no provision is made for guessing, nor special provision for 
missing codes in polytomous items.

For both \code{dichotParamTab} and \code{polyParamTab} users wishing
to use a \code{D} paramter of 1.7 (or any other value) may specify that, per item,
in a column named \code{D}. 

When there are multiple constructs, subscales, or the user wants a composite
score, additional, optional, columns \code{test} and \code{subtest} can be used. 
these columns can be numeric or text, they must agree with the same 
columns in \code{testScale} to scale the results. 

Student data are broken up into two parts. The item response data goes
into \code{stuItems}, and the student covariates for the formula go into
\code{stuDat}. Information about items, such as item difficulties, is in 
\code{paramTab}. All dichotomous items are assumed to be 
3PL, though by setting the guessing parameter to zero, the user
can use a 2PL or the one Parameter Logit (1PL) or Rasch models.
The model for polytomous responses data is dictated by the \code{polyModel}
argument.

The marginal maximum likelihood then integrates the product of the student
ability from the assessment data, and the estimate from the linear model
estimates each student's ability based on the \code{formula} provided
and a residual standard error term. This integration happens from the
minimum node to the maximum node in the \code{control} argument (described
later in this section) with \code{Q} quadrature points. 

The \code{stuItems} argument has the scored student data. It is a list where
each element is named with student ID and contains
a \code{data.frame} with at least two columns.
The first required column is named
\code{key} and shows the item name as it appears in \code{paramTab};
the second column in named
\code{score} and shows the score for that item. For dichotomous
items, the \code{score} is 0 or 1. For \code{GPCM} items, the scores
start at zero as well. For \code{GRM}, the scores start at 1.

For a \code{GPCM} model, \code{P0} is the \dQuote{a} parameter, and the other 
columns are the \dQuote{d} parameters; see the vignette for details
of the GPCM model.

The quadrature points then are a range from \code{minNode} to \code{maxNode}
with a total of \code{Q} nodes.
}
\examples{
\dontrun{
require(EdSurvey)

# 1) make param tab for dichotomous items
dichotParamTab <- data.frame(ItemID = c("m109801", "m020001", "m111001",
                                        "m046301", "m046501", "m051501",
                                        "m111601", "m111301", "m111201",
                                        "m110801", "m110101"),
                             test = rep("composite",11),
                             subtest = c(rep("num",6),rep("alg",5)),
                             slope = c(0.96, 0.69, 0.83,
                                       0.99, 1.03, 0.97,
                                       1.45, 0.59, 0.34,
                                       0.18, 1.20),
                             difficulty = c(-0.37, -0.55,  0.85,
                                            -0.97, -0.14,  1.21,
                                             0.53, -1.84, -0.46,
                                             2.43,  0.70),
                             guessing = c(0.16, 0.00, 0.17,
                                          0.31, 0.37, 0.18,
                                          0.28, 0.15, 0.09,
                                          0.05, 0.18),
                             D = rep(1.7, 11),
                             MODEL = rep("3pl", 11))

# param tab for GPCM items
polyParamTab <- data.frame(ItemID = factor(c("m0757cl", "m066501")),
                           test = rep("composite",2),
                           subtest = rep("alg",2),
                           slope = c(0.43, 0.52), # could also be called "a"
                           itemLocation = c(-1.21, -0.96), # added to d1 ... dn
                           d1 = c(2.38, -0.56), 
                           d2 = c(-0.57, 0.56),
                           d3 = c(-1.18, NA),
                           D = c(1.7, 1.7),
                           scorePoints = c(4L, 3L)) # number of score points, read d1 to d(n-1)
# read-in NAEP Primer data 
sdf <- readNAEP(system.file("extdata/data", "M36NT2PM.dat", package = "NAEPprimer"))
# read in these items
items <- c(as.character(dichotParamTab$ItemID), as.character(polyParamTab$ItemID))
# dsex, student sex
# origwt, full sample weights
# repgrp1, stratum indicator
# jkunit, PSU indicator
edf <- getData(data=sdf, varnames=c(items, "dsex", "origwt", "repgrp1", "jkunit", "sdracem"),
               omittedLevels = FALSE, returnJKreplicates=FALSE)
# make up a student ID
edf$sid <- paste0("S",1:nrow(edf))
# apply simplified scoring
for(i in 1:length(items)) {
  coli <- items[i]
  # save the original
  rawcol <- paste0(coli,"raw")
  edf[,rawcol] <- edf[,coli]
  if( coli \%in\% dichotParamTab$ItemID) {
    edf[,coli] <- ifelse(grepl("[ABCDE]", edf[,rawcol]), 0, NA)
    edf[,coli] <- ifelse(grepl("*", edf[,rawcol]), 1, edf[,coli])
  } else {
    # scale for m066501
    edf[,coli] <- ifelse(grepl("Incorrect", edf[,rawcol]), 0, NA)
    edf[,coli] <- ifelse(grepl("Partial", edf[,rawcol]), 1, edf[,coli])
    edf[,coli] <- ifelse(grepl("Correct", edf[,rawcol]), 2, edf[,coli])
    # scale for m0757cl
    edf[,coli] <- ifelse(grepl("None correct", edf[,rawcol]), 0, edf[,coli])
    edf[,coli] <- ifelse(grepl("One correct", edf[,rawcol]), 1, edf[,coli])
    edf[,coli] <- ifelse(grepl("Two correct", edf[,rawcol]), 2, edf[,coli])
    edf[,coli] <- ifelse(grepl("Three correct", edf[,rawcol]), 3, edf[,coli])
  }
  edf[,rawcol] <- NULL # delete original
}

# stuItems has one row per student/item combination
stuItems <- edf[,c("sid", items)]
stuItems <- reshape(data=stuItems, varying=c(items), idvar=c("sid"),
                    direction="long", v.names="score", times=items, timevar="key")
# stuDat is one row per student an contains student-level information
stuDat <- edf[,c("sid", "origwt", "repgrp1", "jkunit", "dsex", "sdracem")]

# testDat shows scaling and weights for subtests, an overall score can be treated as a subtest
testDat <- data.frame(test=c("composite", "composite") ,
                      subtest=c("num", "alg"),
                      location=c(277.1563, 280.2948),
                      scale=c(37.7297, 36.3887),
                      subtestWeight=c(0.3,0.7))

# estimate a regression for Algebra subscale
mmlA <- mml(alg ~ dsex,
            stuItems=stuItems, stuDat=stuDat,
            dichotParamTab=dichotParamTab, polyParamTab=polyParamTab,
            testScale=testDat,
            idVar="sid", weightVar="origwt", # these are column names on stuDat
            strataVar="repgrp1", PSUVar="jkunit")
# summary, with Taylor standard errors
mmlAs <- summary.mmlMeans(mmlA, varType="Taylor")


# estimate a regression for Numeracy subscale
mmlN <- mml(num ~ dsex,
            stuItems=stuItems, stuDat=stuDat,
            dichotParamTab=dichotParamTab, polyParamTab=polyParamTab,
            testScale=testDat,
            idVar="sid", weightVar="origwt", # these are column names on stuDat
            strataVar="repgrp1", PSUVar="jkunit")
# summary, with Taylor standard errors
mmlNs <- summary.mmlMeans(mmlN, varType="Taylor")
mmlNs

# draw plausible values for mmlA
head(pvd <- drawPVs.mmlMeans(mmlA))
# alternative specification
head(pvs <- drawPVs.mmlMeans(summary.mmlMeans(mmlA, varType="Taylor"), stochasticBeta=TRUE))

# composite regression 
mmlC <- mml(composite ~ dsex ,
            stuItems=stuItems, stuDat=stuDat,
            dichotParamTab=dichotParamTab, polyParamTab=polyParamTab,
            testScale=testDat,
            idVar="sid", weightVar="origwt", # these are column names on stuDat
            strataVar="repgrp1", PSUVar="jkunit")
# summary, with Taylor standard errors
summary(mmlC, varType="Taylor")

# draw plausible values for mmlC
head(pvd <- drawPVs.mmlCompositeMeans(mmlC))
# alternative specification 
mmlCsum <- summary.mmlCompositeMeans(mmlC, varType="Taylor")
head(pvs <- drawPVs.mmlCompositeMeans(mmlCsum, stochasticBeta=TRUE))

}
}
\author{
Harold Doran, Paul Bailey, Claire Kelley, Sun-joo Lee, and Eric Buehler
}
