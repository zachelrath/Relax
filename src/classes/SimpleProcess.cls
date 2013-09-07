global virtual class SimpleProcess implements Process {

	// A Process for running a sequence of Runnables,
	// which schedules a new process to be spawned 
	// 5 minutes after the current process completes.

	// The Id of the Relax Job Scheduler that spawned this process
	private String triggerId;
	// Any temporary CronTrigger jobs used to move from step to step in the process
	private Set<String> tempJobs;
	private List<Runnable> runnables;
	private Integer index;
	
	public SimpleProcess(List<Runnable> runnables, String triggerId) {
		this.triggerId = triggerId;
		this.runnables = runnables;
		this.index = 0;
		this.tempJobs = new Set<String>();
	}
	
	// Return the Id of the CronTrigger that spawned this process
	global String getTriggerId() {
		return this.triggerId;
	}
	
	global Set<String> getTempJobs() {
		return this.tempJobs;
	}
	
	global void addTempJob(String jobId) {
		if (jobId != null) {
			this.tempJobs.add(jobId);
		}
	}
	
	// Do we have any more runnables to run?
	global boolean hasNext() {
		return (runnables != null && (index < runnables.size()));
	}
	
	// Aborts any temporary jobs associated with this process
	global void abortTempJobs() {
		if (this.tempJobs != null) {
			for (String s : this.tempJobs) {
				try {
					System.abortJob(s);
					//System.debug('*** successfully aborted temp job ' + s + ' (in abortTempJobs method)');
					tempJobs.remove(s);
				} catch (Exception ex) {}
			}	
		}
	}
	
	// Advance to the next runnables in our process,
	// if we have one,
	// run it,
	// and return a reference to the runnables
	global Runnable advance() {
		/**/
		if (!hasNext()) return null;
		else {
			//System.debug('*** in advance method of a SimpleProcess instance'); 
			//System.debug('*** index: ' + index);
			//System.debug('*** System.isBatch(): ' + System.isBatch());
			
			Runnable r = null;
			String balloonId = null;
			
			// If anything goes wrong,
			// we MUST keep the process going
			try {
				// If we are in BATCH APEX...
				//if (System.isBatch()) { 
					
					// PRE WINTER 13 version --- had to postpone to another execution context  
					//System.debug('*** Starting Relax process balloon');
					
					// then postpone our process execution into a different context
					//Datetime later = Datetime.now().addSeconds(5);
					
					//ProcessBalloon balloon = new ProcessBalloon(this);
					//balloonId = System.schedule('Relax Process Balloon '+later.getTime(),JobScheduler.GetCRONExpression(later),balloon);
					
					//System.debug('*** process balloon has been scheduled. balloonId: ' + balloonId);
					
				//} 
				// With Winter 13,
				// as long as our Batch Apex class is in API v26,
				// we can run ANY runnable, including BatchableRunnables,
				// because Database.executeBatch() can now be called
				// from the finish() method of a Batch Apex class
				//else {
					r = runnables.get(index++);
					// Let our runnable know which process is running it
					r.setProcess(this);
					// Run it!
					r.run();
				//}
			} catch (Exception ex) {
				
				// Email system admin
				JobScheduler.SendEmailOnException(ex,
					'Exception during step ' + index + ' of Relax Process ' + triggerId,
					// Get the system admin's email address
					UserInfo.getUserEmail()
				);
				
				// Finish the process!
				this.finish();
				
			}
			return r;
		}
		/**/
		return null;
	}
	
	// Finish the process
	global void finish() {
		
		// Kill any temp jobs associated with this process
		abortTempJobs();
		
		//System.debug('*** In finish() method');
		
		
	}


}