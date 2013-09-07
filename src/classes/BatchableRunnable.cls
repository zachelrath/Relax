global virtual class BatchableRunnable implements Runnable, Database.Stateful {
	
	protected Job__c job;
	protected Process p;
	
	public BatchableRunnable(Job__c job) {
		setJob(job);
	}
	
	global Job__c getJob() {
		return this.job;
	}
	
	global void setJob(Job__c j) {
		this.job = j;
	}
	
	global void setProcess(Process p) {
		this.p = p;
	}
	
	global void run() {
		/**/
		// Get the System.Type for this Job's Apex Class
		System.Type t = JobScheduler.GetTypeForClassName(job.Apex_Class__c);
		// If we could not find a type,
		// then the entire process should fail
		if (t == null) {
			throw new RelaxException(
				'Job \''+ job.Name +'\' could not be run because its Apex Class ('+job.Apex_Class__c+') is invalid.'
			);
		}
        // If our Job's Apex Class is valid, we're good to go!
        else {    
	       	// Instantiate this class into a BatchableProcessStep instance
            BatchableProcessStep step;
            try {
                step = (BatchableProcessStep) JSON.deserialize('{}',t);
            } catch (Exception ex) {
            	throw new RelaxException(
					'Job \''+ job.Name +'\' could not be run because its Apex Class ('
					+job.Apex_Class__c+') does not extend BatchableProcessStep.'
				);
            }
            if (step != null) {
            	
            	// Prepare our ProcessStep
            	step.init(p,this);
            	
            	// Execute the batch, by default with a scope size of 200 
            	// (but each implementation can override this)
            	String batchId = Database.executeBatch(step,step.getScope());
            	
            	// Update the Last_Ran__c time for this Job,
            	// and record the Id of the AsyncApexJob that's running it
            	job.Status__c = 'Started';
            	job.Last_Run__c = Datetime.now();
            	job.AsyncApexJobId__c = batchId;
            	Database.SaveResult sr = Database.update(job,false);
            	//System.debug('*** (In BatchableRunnable run() method): Update of job succeeded: ' + sr.isSuccess());
            }
        }
        /**/
	}  // end method 
	
	// Clean up after the Runnable,
	// and prepare for the next execution
	global void complete() {
		/**/
		//System.debug('*** In complete() method of Runnable for Job: ' + job.Name);
		// Update the Next_Run__c time for this Job,
    	// and remove the Id of the AsyncApexJob that executed it
    	job.Next_Run__c = JobScheduler.GetNextRunTimeForJob(job);
    	
    	//System.debug('*** Next Run set to: ' + job.Next_Run__c);
    	job.Status__c = 'Completed';
    	job.AsyncApexJobId__c = null;
    	Database.SaveResult dsr = Database.update(job,false);
    	//System.debug('*** (In BatchableRunnable complete() method): Update of job succeeded: ' + dsr.isSuccess());
    	/**/
	}
	
}