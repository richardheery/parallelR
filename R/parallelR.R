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
  if(remainder > 0){ntasks_per_core[seq.int(remainder)] = ntasks_per_core[seq.int(remainder)] + 1}
  
  # Create a vector with the indices for the first element in each chunk
  chunk_starts = c(1, cumsum(ntasks_per_core) + 1)
  
  # Create a list with the indices elements from object in each chunk
  chunk_indices = lapply(seq_along(chunk_starts)[-length(chunk_starts)], function(x) 
    indices[seq(chunk_starts[x], chunk_starts[x+1]-1)])
  
  # Return a list with the object split over the required number of chunks
  return(lapply(chunk_indices, function(x) object[x]))
  
}

#' Call a function on each element in an object in parallel
#' 
#' @param object Any iterable object.
#' @param ncores Integer indicating the number of cores to use. 
#' @param parallel_function Any function which takes a single argument and returns a result. 
#' @param packages A vector with the names of packages to export to the cluster cores. Default is NULL.
#' @param exported_objects A vector with the names of objects to optionally export to the cluster nodes. 
#' @param combine_function A function or the name of a function used to combine the results of the for loop. Default is c. 
#' @return The results of executing parallel_function on each element of object and combining as specified. 
#' @export
parallelize = function(object, ncores, parallel_function, packages = NULL, 
  exported_objects = NULL, combine_function = c){
  
  # Check that both parallel_function and combine_function are functions
  parallel_function = match.fun(parallel_function)
  combine_function = match.fun(combine_function)
  
  # Make a cluster with the specified number of cores and register it
  cl = parallel::makeCluster(ncores)
  doParallel::registerDoParallel(cl, ncores)
  on.exit(parallel::stopCluster(cl))
  `%dopar%` = foreach::`%dopar%`
  
  # Loop through the object and execute the function
  results = foreach::foreach(iterator_element = object, 
    .packages = packages, .export = exported_objects, .combine = combine_function) %dopar% {
      parallel_function(iterator_element)
    }
  
  # Add names of object to results
  names(results) = names(object)

  # Return results
  return(results)
  
}
