global virtual class SimpleProcessStep implements ProcessStep, Database.Stateful {
	
	// The process that this job is a part of
	private Process p;
	// The Runnable that should be executed during this Step
	private Runnable r;

	// Initialize and kick off the ProcessStep
	global virtual void init(Process p, Runnable r) {
		
		this.p = p;
		this.r = r;
		
		// Abort any Temporary Jobs associated with the process
		p.abortTempJobs();
	}
	
	// Complete the step
	global virtual void complete() {
		
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