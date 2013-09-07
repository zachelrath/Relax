global virtual class SimpleProcessStep implements ProcessStep, Database.Stateful {
	
	// The process that this job is a part of
	private Process p;
	// The Runnable that should be executed during this Step
	private Runnable r;
	
	// Return any custom parameters set for this Job
	global String getParameters(){
		Runnable r = getRunnable();
		if (r != null) {
			// Return the Job associated with our Runnable
			Job__c j = r.getJob();
			if (j != null) {
				return j.Parameters__c;
			}	
		}	
		return null;
	}
	
	// Shortcut/convenience method
	global String params(){
		return getParameters();
	}
	
	// Retrieve the Runnable associated with this ProcessStep
	global Runnable getRunnable() {
		return this.r;
	}
	// Retrieve the Process associated with this ProcessStep
	global Process getProcess() {
		return this.p;
	}

	// Initialize and kick off the ProcessStep
	global virtual void init(Process p, Runnable r) {
		
		this.p = p;
		this.r = r;
		
		// Abort any Temporary Jobs associated with the process
		p.abortTempJobs();
	}
	
	// Complete the step
	global virtual void complete() {
		//system.debug('**** In SimpleProcessStep complete() method');
		// Complete/finish our runnable
		if (r != null) {
			r.complete();
		}	
		
		// When done, see if our process has more to do,
		// and if not, finish it
		if (p != null) {
			if (p.hasNext()) p.advance();
			else p.finish();
		}
	}

}