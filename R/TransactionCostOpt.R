library(xts)
library(quadprog)
library(corpcor)




#generic quadratic utility maximization
UtilityMaximization <- function(returns,lambda,long.only = FALSE){
  nassets <- ncol(returns)
  cov.mat <- cov(returns)
  Dmat <- 2*cov.mat*lambda 
  mu <- apply(returns,2,mean)
  dvec <- -mu #linear part is to maximize mean return
  
  #left hand side of constraints
  constraint.weight.sum <- rep(1,nassets)
  Amat <- cbind(constraint.weight.sum)
  
  #right hand side of constraints
  bvec <- c(-1)
  
  #optional long only constraint
  if(long.only == TRUE){
    constraint.long.only <- -diag(nassets)
    Amat <- cbind(Amat, constraint.long.only)
    bvec <- c(bvec,rep(0,nassets))
    print("LONG ONLY")
  }
  
  solution <- solve.QP(Dmat,dvec,Amat,bvec,meq=1)
  w <- -solution$solution
  port.var <- w%*%cov.mat%*%w
  port.mu <- w%*%mu
  list(w = w, port.var=port.var, port.mu=port.mu)  
}


#lambda - risk aversion paramter
#c - proportional transaction cost
#TODO - fix long only constraint
TransactionCostOpt <- function(returns,lambda,w.initial,c,long.only = FALSE){
  nassets <- ncol(returns)
  if(length(c)==1){
    c = rep(c,nassets)
  }
  if(length(c)!=nassets){
    stop("c must either be a single value, or the same length as the number of assets")
  }
  #step 1: optimize without constraints to determine buys vs sells
  #if w*>w.initial c = c
  #if w* < w.initial c = -c
  unconstrained <- UtilityMaximization(returns,lambda,long.only)
  w.unconstrained <- unconstrained$w
  diff <- w.unconstrained-w.initial 
  
  sign.vec <- rep(1,nassets)
  sign.vec[diff<0] <- -1
  c <- c*sign.vec
  
  #TODO fix this part
  #step 2: optimize with fixed c from step 1
  #this solution will be good as long as no buys or sells flip
  cov.mat <- cov(returns)
  Dmat <- 2*cov.mat*lambda
  mu <- apply(returns,2,mean)
  dvec <- -(mu-c) #linear part is to maximize mean return
  
  #left hand side of constraints
  constraint.weight.sum <- rep(1,nassets)
  constraint.weight.buysell <- -diag(sign.vec)
  Amat <- cbind(constraint.weight.sum,constraint.weight.buysell)
  
  #right hand side of constraints
  bvec <- c(-1,(w.initial*sign.vec))
  
  #optional long only constraint
  if(long.only == TRUE){
    if ( length(w.initial[w.initial<0]) > 0 ){
      stop("Long-Only specified but some initial weights are negative")
    }
    constraint.long.only <- -diag(nassets)
    Amat <- cbind(Amat, constraint.long.only)
    bvec <- c(bvec,rep(0,nassets))
  }
  
  solution <- solve.QP(Dmat,dvec,Amat,bvec,meq=1)
  w <- -solution$solution
  port.var <- w%*%cov.mat%*%w
  port.mu <- w%*%mu
  list(w = w, port.var=port.var, port.mu=port.mu)
}


#TODO add documentation
TransCostFrontier <- function(returns,npoints = 10, min.lambda, max.lambda,
                              w.initial,c,long.only = FALSE)
{
  p = ncol(returns)
  efront = matrix(rep(0,npoints*(p+2)),ncol = p+2)
  dimnames(efront)[[2]] = c("MU","SD",dimnames(returns)[[2]])
  lambda.vals = seq(min.lambda,max.lambda,length.out = npoints)
  for(i in 1:npoints)    {
    opt <- TransactionCostOpt(returns,lambda = lambda.vals[i],w.initial,c,long.only)
    #opt <- UtilityMaximization(returns,lambda = lambda.vals[i])
    efront[i,"MU"] <- opt$port.mu
    efront[i,"SD"] <- sqrt(opt$port.var)
    efront[i,3:ncol(efront)] <- opt$w
  }
  
  efront
}
