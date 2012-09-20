global virtual interface Process {
	// Return the Id of the CronTrigger that initiated this process
	String getTriggerId();
	// Get the Ids of any temp jobs used by the process
	Set<String> getTempJobs();
	// Add the Id of a temp job used by the process
	void addTempJob(String jobId);
	// Abort any temporary jobs that exist for this process
	void abortTempJobs();
	// Advance to the next runnable in the process, and run it
	Runnable advance();
	// Do we have more jobs/tasks to complete in this process?
	boolean hasNext();
	// Finish the process 
	void finish();
}