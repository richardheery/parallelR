#' Break an iterable object into a list of equally sized chunks with sequential elements
#' 
#' @param object Any iterable object.
#' @param ncores Integer indicating the number of cores that will be used to process object.
#' @return A list of length ncores with the elements of object divided as evenly as possible across it. 
#' @export
chunk_object = function(object, ncores){
  
  # Get the length of the object and a vector with all the indices for the object
  len = length(object)
  indices = seq_along(object)
  
  # Calculate the quotient and remainder when performing integer division with len and ncores
  quotient = len %/% ncores
  remainder = len %% ncores
  
  # Create a vector with the number of tasks to be assigned to each core.
  # Each core receives a minimum of quotient tasks with remainder cores receiving one additional task
  ntasks_per_core = rep(quotient, ncores)
  ntasks_per_core[seq.int(remainder)] = ntasks_per_core[seq.int(remainder)] + 1
  
  # Create a vector with the indices for the first element in each chunk
  chunk_starts = c(1, cumsum(ntasks_per_core) + 1)
  
  # Create a list with the indices elements from object in each chunk
  chunk_indices = lapply(seq_along(chunk_starts)[-length(chunk_starts)], function(x) 
    indices[seq(chunk_starts[x], chunk_starts[x+1]-1)])
  
  # Return a list with the object split over the required number of chunks
  return(lapply(chunk_indices, function(x) object[x]))
  
}

#' Execute a parallel for loop evaluating a call on each element in an object
#' 
#' @param object Any iterable object.
#' @param ncores Integer indicating the number of cores to use. 
#' @param call A call created with quote() to be executed on each element in object. 
#' Must refer to the element as iterator_element inside the call. Should not use the $ operator.
#' @param packages A vector with the names of packages to export to the cluster cores. Default is NULL.
#' @param exported_objects A vector with the names of objects to export to the cluster nodes. Default is to try to infer them using all.vars(call). 
#' @param combine A function or the name of a function used to combine the results of the for loop. 
#' @return The results of executing the call on each element of object and combining as specified. 
#' @export
parallel_call = function(object, ncores, call, packages = NULL, exported_objects = NULL){
  
  # Check that call is a call object and that it contains a variable called i
  if(!is(call, "call")){stop("call should be a call object")}
  if(!"iterator_element" %in% all.vars(call)){stop(paste("call must contain a parameter called iterator_element"))}
  
  # Make a cluster with the specified number of cores and register it
  cl = parallel::makeCluster(ncores)
  doParallel::registerDoParallel(cl, ncores)
  on.exit(parallel::stopCluster(cl))
  `%dopar%` = foreach::`%dopar%`
  
  # Get the name of all exported objects (excluding the loop index variable and T and F)
  if(is.null(exported_objects)){
    exported_objects = setdiff(all.vars(call), c("i", "T", "F"))
  }
  
  # Loop through the object and evaluate the call
  results = foreach::foreach(iterator_element = object, 
    .packages = packages, .export = exported_objects, .combine = combine) %dopar% {
      eval(call)
    }
  
  # Add names of object to results
  names(results) = names(object)

  # Return results
  return(results)
  
}
