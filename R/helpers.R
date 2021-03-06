#' @method print mmlMeans
#' @export
print.mmlMeans <- function(x, ...){
  co <- coef(x)
  print(co, ...)
}

#' @method print mmlCompositeMeans
#' @export
print.mmlCompositeMeans <- function(x, ...){
  co <- coef(x)
  print(co, ...)
}

mml.remap.coef <- function(coefficients, location, scale, noloc=FALSE) {
  coefficients <- coefficients * scale
  if(!noloc) {
    coefficients[names(coefficients) == "(Intercept)"] <- coefficients[names(coefficients) == "(Intercept)"] + location
  }
  return(coefficients)
}

#' @importFrom stats cov2cor
#' @method summary mmlCompositeMeans
#' @export
summary.mmlCompositeMeans <- function(object, gradientHessian=FALSE,
                                      varType=c("consistent", "robust", "replicate", "Taylor"),
                                      clusterVar=NULL, jkSumMultiplier=1, # cluster
                                      repWeight=NULL, # replicate
                                      strataVar=NULL, PSUVar=NULL, singletonFix=c("drop", "use mean"),# Taylor
                                      ...){
  sumCall <- match.call()
  # get varType and singletonFix cleaned up
  varType <- match.arg(varType)
  singletonFix <- match.arg(singletonFix)
  # 
  if(missing(strataVar)) {
    if(is.null(object$strataVar) & varType %in% c("Taylor")) {
      stop(paste0("argument ", dQuote("strataVar"), " must be included in the ", dQuote("mml"), " or ", dQuote("summary"), " call."))
    }
    strataVar <- object$strataVar
  }
  if(missing(PSUVar)) {
    if(is.null(object$PSUVar) & varType %in% c("Taylor")) {
      stop(paste0("argument ", dQuote("PSUVar"), " must be included in the ", dQuote("mml"), " or ", dQuote("summary"), " call."))
    }
    PSUVar <- object$PSUVar
  }
  # first
  M <- nrow(object$coefficients)
  k <- ncol(object$coefficients)
  rawCoef <- object$coefficients
  # the H_B_prime0 and (later) VCfull are block diagonal matrixes
  # "block" is a list where each element is every index for that block
  block <- list()
  for(i in 1:M) {
    block <- c(block, list(1:k + k*(i-1)))
  }

  # build H_B_prime
  H_B_prime0 <- matrix(0, nrow=k*M, ncol=k*M)
  for(i in 1:nrow(rawCoef)) {
    obji <- list(lnlf=object$lnlfl[[i]],
                 coefficients=rawCoef[i,],
                 X=object$X[[i]],
                 stuDat=object$stuDat[[i]],
                 rr1=object$rr1[[i]],
                 nodes=object$nodes,
                 weightVar=object$weightVar)
    ih <- getIHessian.mmlMeans(obji, gradientHessian=gradientHessian)
    H_B_prime0[block[[i]], block[[i]]] <- ih
  }
  # get weighted obs, if relevant
  if(is.null(object$weightVar)) {
    wo <- NA
  } else {
    wo <- object$weightedObs
  }


  if(varType=="consistent") {
    V0 <- -1 * H_B_prime0
  }
  if(varType=="robust") {
    varsL <- list()
    V0 <- 0 * H_B_prime0
    for(i in 1:M) {
      obj <- list(X = object$X[[i]],
                  stuDat = object$stuDat[[i]],
                  coefficients = rawCoef[i, ],
                  rr1 = object$rr1[[i]],
                  nodes = object$nodes)
      Vi <- getVarRobust(obj, H_B_prime0[block[[i]], block[[i]]])
      V0[block[[i]], block[[i]]] <- Vi
    }
  }
  if(varType=="replicate") {
    repCoef <- matrix(0, nrow=length(repWeight), ncol=ncol(object$coef), dimnames=list(repWeight, colnames(object$coef)))
    for(i in 1:M) {
      obj <- list(X = object$X[[i]],
                  stuDat = object$stuDat[[i]],
                  coefficients = rawCoef[i, ],
                  rr1 = object$rr1[[i]],
                  nodes = object$nodes)
      repi <- getVarReplicate(object = obj,
                              H_B_prime = H_B_prime0[block[[i]], block[[i]]],
                              repWeight=repWeight,
                              jkSumMultiplier=jkSumMultiplier,
                              returnVecs=TRUE)
      repC <- lapply(repi, function(b) {
          names(b) <- colnames(object$coef)
          return(mml.remap.coef(b, object$testScale$location[i], object$testScale$scale[i]))
        })
      repC <- do.call(rbind, repC)
      repCoef <- repCoef + object$testScale$subtestWeight[i] * repC
    }
    # already subtracted from mean
    B0 <- coef(object)
    jkB0 <- apply(repCoef, 2, mean)
    # subtract off mean estimate
    repDiff <- lapply(1:nrow(repCoef), function(i){
      (repCoef[i,]-B0) %*% t(repCoef[i,]-B0)
    })
    varR <- jkSumMultiplier * Reduce("+", repDiff)
    se <- sqrt(diag(varR))

    tval <- as.vector(B0/se)
    TAB <- cbind(Estimate = B0,
                 StdErr = se,
                 t.value = tval)
    return(structure(list("call" = object$call,
                          "summaryCall" = sumCall,
                          "coefficients" = TAB,
                          "converged" = object$Convergence,
                          "convergence" = object$convergence,
                          "iterations" = object$iterations,
                          "VC" = varR,
                          "iHessian" = -1*H_B_prime0,
                          "stuDat" = object$stuDat,
                          "X" = object$X,
                          "obs" = object$obs,
                          "weightedObs" = wo),
                     class="summary.mmlCompositeMeans"))
  }
  if(varType=="Taylor") {
    V0 <- 0 * H_B_prime0
    for(i in 1:M) {
      obj <- list(X = object$X[[i]],
                  stuDat = object$stuDat[[i]],
                  coefficients = rawCoef[i, ],
                  rr1 = object$rr1[[i]],
                  nodes = object$nodes,
                  weightVar = object$weightVar)
      Vi <- getVarTaylor(object=obj, H_B_prime = H_B_prime0[block[[i]], block[[i]]],
                         strataVar = strataVar, PSUVar = PSUVar,
                         singletonFix = singletonFix,
                         returnVecs=FALSE)
      V0[block[[i]], block[[i]]] <- Vi
    }
  }
  td <- object$testScale
  # make a containder for scaled weights
  scaledCoef <- rawCoef

  # scale them
  for(i in 1:M) {
    scaledCoef[i, ] <- mml.remap.coef(rawCoef[i, ], td$location[i], td$scale[i])
  }
  # remap to weighted levels
  compositeCoef <- coef(object)
  names(compositeCoef) <- colnames(object$coefficients)
  VCsmall <- matrix(0, nrow=k, ncol=k)
  VCfull <- V0
  sVC <- object$SubscaleVC
  # add covariance here,
  # update VCfull along diag below so we don't muddle the update of the covariances
  for(i in 1:M) {
    for(j in 1:M) {
      if(i > j) {
        # block i, j
        VCfull[block[[i]], block[[j]]] <- td$scale[i] * td$scale[j] * cov2cor(sVC)[i,j] *
                                          sign(VCfull[block[[i]], block[[i]]] * VCfull[block[[j]], block[[j]]]) *
                                          sqrt(abs(VCfull[block[[i]], block[[i]]] * VCfull[block[[j]], block[[j]]]))
        # symetric matrix, so also set block j, i
        VCfull[ block[[j]],block[[i]]] <- t(VCfull[block[[i]], block[[j]]])
      }      
    }
  }
  # now scale within moddle covariances
  for(i in 1:M) {
    VCfull[block[[i]], block[[i]]] <- td$scale[i]^2 * VCfull[block[[i]], block[[i]]]
  }

  for(i in 1:k) {
    vi <- rep(0, k*M)
    vi[i+((1:M)-1)*k] <- td$subtestWeight
    for(j in 1:k) {
      vj <- rep(0, k*M)
      vj[j+((1:M)-1)*k] <- td$subtestWeight
      VCsmall[i,j] <- t(vj) %*% VCfull %*% vi
    }
  }
  # this is the composite VC
  VC <- VCsmall
  se <- sqrt(diag(VC))
 
  # this cannot be estimated
  se[names(compositeCoef) == "Population SD"] <- NA
  tval <- as.vector(compositeCoef/se)
  TAB <- cbind(Estimate = compositeCoef,
               StdErr = se,
               t.value = tval)
  row.names(TAB) <- names(compositeCoef) 
  return(structure(list("call" = object$call,
                        "summaryCall" = sumCall,
                        "coefficients" = TAB,
                        "converged" = object$Convergence,
                        "convergence" = object$convergence,
                        "iterations" = object$iterations,
                        "VC" = VC,
                        "iHessian" = -1*H_B_prime0,
                        "stuDat" = object$stuDat,
                        "X" = object$X,
                        "obs" = object$obs,
                        "weightedObs" = wo),
                   class="summary.mmlCompositeMeans"))
}

#' @method summary mmlMeans
#' @export
summary.mmlMeans <- function(object, gradientHessian=FALSE,
                             varType=c("consistent", "robust", "cluster", "replicate", "Taylor"),
                             clusterVar=NULL, jkSumMultiplier=1, # cluster
                             repWeight=NULL, # replicate
                             strataVar=NULL, PSUVar=NULL, singletonFix=c("drop", "use mean"),# Taylor
                             ...){
  sumCall <- match.call()
  if(missing(strataVar)) {
    strataVar <- object$strataVar
  }
  if(missing(PSUVar)) {
    PSUVar <- object$PSUVar
  }
  H_B_prime <- getIHessian.mmlMeans(object, gradientHessian)
  # check/fix varType argument
  varType <- match.arg(varType)
  singletonFix <- match.arg(singletonFix)
  if(varType=="consistent") {
    VC <- getVarConsistent(object, H_B_prime)
  }
  if(varType=="robust") {
    VC <- getVarRobust(object, H_B_prime)
  }
  if(varType=="cluster") {
    stuDat <- object$stuDat
    if(is.null(clusterVar)) {
      stop("You must define a valid clusterVar to use cluster variance estimation.")
    }
    if(length(clusterVar) != 1) {
      if("ClusterVar__" %in% colnames(stuDat)) {
        stop("Please rename the variable ", dQuote("ClusterVar__"), " on the ", dQuote("stuDat"), " argument.")
      }
      # paste together variables with colons
      # first, remove colons from existing variables, if necessary
      for(i in 1:length(clusterVar)) {
        if(inherits(stuDat[clusterVar], "character") && sd(nchar(stuDat[clusterVar])) > 0) {
          stuDat[clusterVar] <- gsub(":", "-", stuDat[clusterVar], fixed=TRUE)
        }
        if(inherits(stuDat[clusterVar], "factor")) {
          stuDat[clusterVar] <- gsub(":", "-", as.character(stuDat[clusterVar]), fixed=TRUE)
        }
      }
      stuDat$ClusterVar__ <- apply(stuDat[clusterVar], 1, function(x) { paste(x, collapse=":") } )
      clusterVar <- "ClusterVar__"
    }
    if(!clusterVar %in% colnames(stuDat)) {
      stop(paste0("Could not find clusterVar column named ", dQuote(clusterVar), " on ", dQuote("stuDat"), " data"))
    }
    if(length(unique(stuDat[,clusterVar])) <= 1) {
      stop("There must be more than one cluster for cluster variance estimation.")
    }
    VC <- getVarCluster(object, H_B_prime, clusterVar)
  }
  if(varType=="replicate") {
    stuDat <- object$stuDat
    if(is.null(repWeight)) {
      stop(paste0("the argument ", dQuote("repWeight"), " must be defined for varType ", dQuote("replicate"), "."))
    }
    if( any(! repWeight %in% colnames(stuDat))) {
      rep_not <- repWeight[! repWeight %in% colnames(stuDat)]
      stop(paste0("Could not find repWeight column named ", pasteItems(dQuote(rep_not)), " on ", dQuote("stuDat"), " data."))
    }
    VC <- getVarReplicate(object, H_B_prime, repWeight, jkSumMultiplier)
  }
  if(varType=="Taylor") {
    stuDat <- object$stuDat
    if(is.null(strataVar) | is.null(PSUVar)) {
      stop(paste0("the arguments ", dQuote("strataVar"), " and ", dQuote("PSUVar")," must be defined for varType ", dQuote("Taylor"), "."))
    }
    if(!strataVar %in% colnames(stuDat)) {
      stop(paste0("Could not find strataVar column named ", dQuote(strataVar), " on ", dQuote("stuDat"), " data."))
    }
    if(!PSUVar %in% colnames(stuDat)) {
      stop(paste0("Could not find strataVar column named ", dQuote(PSUVar), " on ", dQuote("stuDat"), " data."))
    }
    VC <- getVarTaylor(object, H_B_prime, strataVar, PSUVar, singletonFix)
  }
  if(inherits(object, "mmlCompositeMeans" )) {
    return(structure(list("VC" = VC,
                          "iHessian" = H_B_prime),
                     class="summary.mmlMeans"))
  }
  se <- sqrt(diag(VC))
  se <- as.vector(mml.remap.coef(se, object$location, object$scale, noloc=TRUE))
  tval <- as.vector(coef(object)/se)
  TAB <- cbind(Estimate = coef(object),
               StdErr = se,
               t.value = tval)
  row.names(TAB) <- names(object$coefficients) 
  # get weighted obs, if relevant
  if(is.null(object$weightVar)) {
    wo <- NA
  } else {
    wo <- object$weightedObs
  }
  return(structure(list("call" = object$call,
                        "summaryCall" = sumCall,
                        "coefficients" = TAB,
                        "converged" = object$Convergence,
                        "LL" = object$LogLik,
                        "iterations" = object$iterations,
                        "VC" = VC,
                        "iHessian" = H_B_prime,
                        "stuDat" = object$stuDat,
                        "X" = object$X,
                        "obs" = object$obs,
                        "weightedObs" = wo,
                        "location" = object$location,
                        "scale" = object$scale),
                   class="summary.mmlMeans"))
}

#' @importFrom stats printCoefmat
#' @method print summary.mmlMeans
#' @export
print.summary.mmlMeans <- function(x, ...){
  cat(paste0("Call:\n"))
  print(x$call)
  cat(paste0("Summary Call:\n"))
  print(x$summaryCall)
  cat("\n")
  cat("Summary:\n")
  cof <- x$coefficients
  cof1 <- cof[1:(nrow(cof)-1),,drop=FALSE]
  cof2 <- cof[nrow(cof),1:2,drop=FALSE]
  printCoefmat(cof1)
  cat("\n")
  cat("Residual Variance Estimate:\n")
  print(cof2)
  cat("\n")
  cat(paste0("Convergence = ", x$converged, "\n"))
  cat(paste0("Iterations = ", x$iterations, "\n"))
  cat(paste0("LogLike = ", round(x$LL,2), "\n"))
  cat(paste0("Observations = ", x$obs, "\n"))
  if(!is.na(x$weightedObs)) {
    cat(paste0("Weighted observations = ", round(x$weightedObs,2), "\n"))
  }
} 

#' @method print summary.mmlCompositeMeans
#' @export
print.summary.mmlCompositeMeans <- function(x, ...){
  cat(paste0("Call:\n"))
  print(x$call)
  cat(paste0("Summary Call:\n"))
  print(x$summaryCall)
  cat("\n")
  cat("Summary:\n")
  cof <- x$coefficients
  cof1 <- cof[1:(nrow(cof)-1),,drop=FALSE]
  cof2 <- cof[nrow(cof),1:2,drop=FALSE]
  printCoefmat(cof1)
  cat("\n")
  cat("Residual Variance Estimate:\n")
  print(cof2)
  cat("\n")
  cat(paste0("Convergence = ", pasteItems(unique(x$converged)), "\n"))
  cat(paste0("Iterations = ", sum(x$iterations), "\n"))
  cat(paste0("observations = ", pasteItems(x$obs), "\n"))
  if(!all(is.na(x$weightedObs))) {
    cat(paste0("Weighted observations = ", pasteItems(round(x$weightedObs,2)), "\n"))
  }
} 

getIHessian.comp <- function(object) {
  k <- length(object$X)
  Xl <- object$X
  co <- object$coefficients
  p <- length(co)/k
  Wsum <- rep(NA, k)
  for(ki in 1:k) {
    coki <- object$coefficients[1:p + p*(ki-1)]
    X <- Xl[[ki]]
    x_ind <- split(X, as.factor(1:nrow(X)), drop=FALSE)
    # dl/dBeta * dl/dBeta ' evaluated for each individual 
    stuDat <- object$stuDat[[ki]]
    stuDat$one <- 1
    weightVar <- object$weightVar
    if(is.null(object$weightVar)) {
      weightVar <- "one"
    }
    vars <- lapply(1:nrow(X), FUN=function(i) {
      stuDat[i,weightVar] * gradInd(location=coki,
                                    ii=i,
                                    X_subset=matrix(x_ind[[i]], nrow=1),
                                    weightVar="one",
                                    rr1=object$rr1[[ki]],
                                    stuDat=stuDat,
                                    nodes=object$nodes)
    })
    varsMat <- data.frame(id=stuDat[,object$idVar], do.call(rbind, vars))
    colnames(varsMat) <- c("id", paste0(ki,":",1:(ncol(varsMat)-1)))
    if(ki == 1) {
      varsMatOverall <- varsMat
    } else {
      varsMatOverall <- merge(varsMatOverall, varsMat, by="id", all=TRUE)
    }
    Wsum[ki] <- sum(stuDat[,weightVar])
  }
  varsMatOverall[is.na(varsMatOverall)] <- 0
  varsMatList <- split(varsMatOverall[,-1], varsMatOverall$id)
  varsMatOuterList <- lapply(varsMatList, FUN=function(gri) {
    gri <- as.numeric(gri)
    gri %*% t(gri)
  })
  Wsum <- mean(Wsum)
  H_B_prime <- -1 * Wsum/(Wsum-1) * solve(Reduce("+", varsMatOuterList))
  return(H_B_prime)
}

getIHessian.mmlMeans <- function(object, gradientHessian=FALSE, returnVars=FALSE) {
  if(gradientHessian) {
    X <- object$X
    x_ind <- split(X, as.factor(1:nrow(X)), drop=FALSE)
    # dl/dBeta * dl/dBeta ' evaluated for each individual 
    stuDat <- object$stuDat
    stuDat$one <- 1
    weightVar <- object$weightVar
    if(is.null(object$weightVar)) {
      weightVar <- "one"
    }
    vars <- lapply(1:nrow(X), FUN=function(i) {
      stuDat[i,weightVar] * gradgradT(location=object$coefficients,
                                      ii=i,
                                      X_subset=matrix(x_ind[[i]], nrow=1),
                                      weightVar="one",
                                      rr1=object$rr1,
                                      stuDat=stuDat,
                                      nodes=object$nodes)
    })
    Wsum <- sum(stuDat[,weightVar])
    H_B_prime <- -1 * Wsum/(Wsum-1) * solve(Reduce("+", vars))
  } else {
    # lnlf is actually the deviance function, so -1/2 maps it back to lnl
    H_B_prime <- solve(-1/2*getHessian(object$lnlf, object$coefficients))
  }
  return(H_B_prime)
}

# estimate covariance matrix (Standard error)
# -1/2 turns a deviance into a likelihood
getVarConsistent <- function(object, H_B_prime) {
  #consistent  estimate
  return(-1 * H_B_prime )
}

getVarRobust <- function(object, H_B_prime) {
  X <- object$X
  x_ind <- split(X, as.factor(1:nrow(X)), drop=FALSE)
  # dl/dBeta * dl/dBeta ' evaluated for each individual 
  object$stuDat$one <- 1
  vars <- lapply(1:nrow(X), FUN=function(i){gradgradT(location=object$coefficients,
                                                      ii=i,
                                                      X_subset=matrix(x_ind[[i]], nrow=1),
                                                      weightVar="one",
                                                      rr1=object$rr1,
                                                      stuDat=object$stuDat,
                                                      nodes=object$nodes)})
  V <- Reduce("+", vars)
  return(H_B_prime %*% V %*% H_B_prime)
}

getVarCluster <- function(object, H_B_prime, clusterVar) {
  stuDat <- object$stuDat
  X <- object$X
  # dl/dBeta * dl/dBeta ' evaluated for each group  before being multipled and then summed
  # first get list of each group index 
  #this is important to ensure group_index and x_group+s are in the same order
  stuDat[[clusterVar]] <- factor(stuDat[[clusterVar]], levels=unique(stuDat[[clusterVar]])) 
  group_index <- lapply(levels(stuDat[[clusterVar]]), FUN=function(x) {
    which(stuDat[[clusterVar]]==x)
  })
  x_groups <- lapply(split(X, stuDat[[clusterVar]]), matrix, ncol=ncol(X))
  vars <- lapply(c(1:length(group_index)), FUN=function(group){
    gradgradT(location=object$coefficients,
              ii=group_index[[group]],
              X_subset = x_groups[[group]],
              weightVar=object$weightVar,
              rr1=object$rr1,
              stuDat=object$stuDat,
              nodes=object$nodes)
  })
  V <-  Reduce("+",vars)
  return(H_B_prime %*% V %*% H_B_prime)
} 

getVarReplicate <- function(object, H_B_prime, repWeight, jkSumMultiplier=1, returnVecs=FALSE) {
  X <- object$X
  B0  <- object$coefficients
  B_j <- lapply(repWeight, FUN=function(x){ #restimate with each weight 
    fn2B <- fn.regression(X_=X, wv=x, rr1=object$rr1, stuDat=object$stuDat, nodes=object$nodes)
    return(bobyqa(B0, fn2B)$par)
  })
  # for composite
  if(returnVecs) {
    return(B_j)
  }
  rep <- lapply(B_j, function(x){(x-B0) %*% t(x-B0)})
  return(jkSumMultiplier * Reduce("+", rep))
} 

getVarTaylor <- function(object, H_B_prime, strataVar, PSUVar,
                         singletonFix=c("drop", "use mean"),
                         returnVecs=FALSE) {
  #find PSU per strata, and warn about dropping strata with one PSU
  singletonFix <- match.arg(singletonFix)
  stuDat <- object$stuDat
  X <- object$X
  snames <- sort(unique(stuDat[[strataVar]]))
  strata <- lapply(snames, FUN=function(x) {
    list(strat=x,
         psu=sort(unique(stuDat[stuDat[,strataVar]==x, PSUVar])))
  })
  n_psu <- lapply(strata, function(x) { length(x$psu)}) 
  if (any(n_psu==1)){
    if(singletonFix == "drop") {
      warning(paste0("Of the ", length(n_psu)," strata, ", sum(n_psu<2) ," strata have only one PSU. All strata with only one PSU are excluded from variance estimation. See the ", dQuote("singletonFix"), " argument for other options."))
      strata <- strata[n_psu>1] #variance estimation can only happen for Strata with more than one PSU 
    }
    if(singletonFix == "use mean") {
      warning(paste0("Of the ", length(n_psu)," strata, ", sum(n_psu<2) ," strata have only one PSU. All strata with only one PSU have their value compared to the mean. See the ", dQuote("singletonFix"), " argument for more details and other options."))
    }
  }
  #only keep snames in strata 
  snames <- lapply(strata, function(x){x$strat}) 
  #split X based on psu for access later
  # loop through strata 
  str <- lapply(strata, FUN=function(st) {
    # number of PSUs in this stratum
    n_a <- length(st$psu)
    # PSU index for units in this stratum and PSU
    group_index <- lapply(st$psu, FUN=function(x) {
      which(stuDat[[PSUVar]]==x & stuDat[[strataVar]]==st$strat)
    })
    # extract data for this stratum
    X_strata <- X[stuDat[[strataVar]] %in% st$strat,,drop=FALSE]
    stuDat_strata <- stuDat[stuDat[[strataVar]] %in% st$strat,,drop=FALSE]
    #split up data by PSU, lapply after the split, making each one a matrix
    x_groups <- lapply(split(X_strata, stuDat_strata[[PSUVar]]), matrix, ncol=ncol(X))
    #vector of scores per psu
    s_p <- lapply(c(1:length(group_index)),FUN=function(k) {
      gradInd(location=object$coefficients,
              ii=group_index[[k]],
              X_subset=x_groups[[k]],
              weightVar=object$weightVar,
              rr1=object$rr1,
              stuDat=object$stuDat,
              nodes=object$nodes)
    })
    st$s_p <- s_p 
    
    if(n_a > 1) {
      #average score across as psu in strata
      s_a_bar <- Reduce("+",s_p)/n_a
      #(s_p - s_a_bar)*(s_p - s_a_bar)' 
      if(returnVecs) {
        s <- lapply(s_p, FUN=function(s){
          (s - s_a_bar) 
        })
        st$s_p <- NULL
        names(s) <- st$psu
        st$s <- s
      } else {
        v_a <- lapply(s_p, FUN=function(s){
          (s - s_a_bar) %*% t(s - s_a_bar)
        })
        st$V_a <- (n_a/(n_a-1))*Reduce("+",v_a)
      }
    }
    return(st)
  }) # end lapply(strata, FUN=function(st) {
  if(singletonFix %in% c("use mean")) {
    # get all strata's PSUs to find mean
    s_p_all <- list()
    for(stri in str) {
      s_p_all <- c(s_p_all, stri$s_p)
    }
    # this is the overall average, across strata, should be zero
    n_all <- length(s_p_all)
    s_a_barOverall <- Reduce("+", s_p_all)/n_all
  }
  if(singletonFix=="drop") {
    # when we reduce these, we will need a zero matrix
    # so grab a valid V_a and multiply it by 0
    zeroV_a <- NULL
    zeros <- NULL
    i <- 1
    while(all(is.null(zeroV_a), is.null(zeros))) {
      if(returnVecs) {
        if(!is.null(str[[i]]$s)) {
          zeros <- 0 * str[[i]]$s[[1]]
        }
      }
      else {
        if(!is.null(str[[i]]$V_a)) {
          zeroV_a <- 0 * str[[i]]$V_a
        }
      }
      i <- i + 1
    }
  }
  if(returnVecs) {
    # aggregate V_a
    s <- lapply(str, FUN=function(st) {
      npsu <- length(st$psu)
      if(npsu > 1) {
        return(st$s)
      }
      if(singletonFix %in% c("use mean")) {
        #(s_p - s_a_barOverall)*(s_p - s_a_barOverall)' 
        s <- st$s_p[[1]] # there is only one element
        s <- 2*(s - s_a_barOverall) 
        return(s)
      }
      if(singletonFix=="drop") {
        return(zeros)
      }
    }) #end aggregate V_a lapply(str, FUN=function(st)
    names(s) <- snames
    return(s)
  }
  # aggregate V_a
  V_a <- lapply(str, FUN=function(st) {
    npsu <- length(st$psu)
    if(npsu > 1) {
      return(st$V_a)
    }
    if(singletonFix %in% c("use mean")) {
      #(s_p - s_a_barOverall)*(s_p - s_a_barOverall)' 
      s <- st$s_p[[1]] # there is only one element
      v_a <- 1*(s - s_a_barOverall) %*% t(s - s_a_barOverall)
      return(v_a)
    }
    if(singletonFix=="drop") {
      return(zeroV_a)
    }
  })
  #sum variance across over all strata
  V <- Reduce("+",V_a)
  return(H_B_prime %*% V %*% H_B_prime)
}

# from EdSurvey
# author: Paul Bailey
pasteItems <- function(vector, final="and") {
  # no need to do anything if there is one or fewer elements
  if(length(vector) <= 1) {
    return(vector)
  }
  if(length(vector) == 2) {
    return(paste0(vector[1], " ", final, " ", vector[2]))
  }
  v <- vector[-length(vector)]
  f <- vector[length(vector)]
  return(paste0(paste(v, collapse=", "), ", ", final, " ", f))
}

#' @importFrom stats vcov
#' @method vcov mmlMeans
#' @export
vcov.mmlMeans <- function(object, ...){
  vcov(summary(object, ...))
}

#' @method vcov summary.mmlMeans
#' @export
vcov.summary.mmlMeans <- function(object, ...){
  object$VC
}

#' @method vcov mmlCompositeMeans
#' @export
vcov.mmlCompositeMeans <- function(object, ...){
  vcov(summary(object, ...))
}

#' @method coef mmlCompositeMeans
#' @export
coef.mmlCompositeMeans <- function(object, ...) {
  M <- nrow(object$coefficients)
  k <- ncol(object$coefficients)
  rawCoef <- object$coefficients
  td <- object$testScale
  tdWeight <- c()
  tdScale <- c()
  scaledCoef <- rawCoef
  for(i in 1:M) {
    tdi <- td[i, ]
    scaledCoef[i, ] <- mml.remap.coef(rawCoef[i, ], tdi$location, tdi$scale)
    tdWeight <- c(tdWeight, tdi$subtestWeight)
    tdScale <- c(tdScale, tdi$scale)
  }
  # remap to weighted levels
  compositeCoef <- t(scaledCoef * tdWeight)
  compositeCoef <- rowSums(compositeCoef)
  # compute SD
  # v is the map applied to the covariance matrix
  v <- object$testScale$scale * object$testScale$subtestWeight
  # find the quadratic form of v and subscaleVC, which has the variances on the diagonal.
  compositeCoef[length(compositeCoef)] <- sqrt(v %*% object$SubscaleVC %*% v)
  names(compositeCoef) <- colnames(object$coefficients)
  return(compositeCoef)
}

#' @method coef mmlMeans
#' @export
coef.mmlMeans <- function(object, ...){
  co <- mml.remap.coef(object$coefficients, object$location, object$scale)
  co
}
