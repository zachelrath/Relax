trigger Job on Job__c (before insert, before update, before delete) {

    // See if any Jobs need to be aborted
    // or be individually Scheduled
    if (Trigger.isBefore) {
    
    	List<Job__c> jobsToSchedule = new List<Job__c>();
        Set<String> jobsToAbort = new Set<String>();
    
        for (Job__c job : (Trigger.isDelete ? Trigger.old : Trigger.new)) {
            // The old version of the Job (only populated if Trigger.isUpdate)
            Job__c old;
            if (Trigger.isUpdate) {
            	old = Trigger.oldMap.get(job.Id);
            }
            
            // If the Run Increment or Run Units has been changed / set for the first time,
            // and this Job is set to be aggregated,
            // then we need to (re)calculate its Next Run time
            if (!job.Run_Individually__c && job.IsActive__c && (job.Next_Run__c == null)
            && (Trigger.isInsert 
            || (Trigger.isUpdate && (!old.IsActive__c || old.Run_Individually__c
            						|| (job.Run_Increment__c != old.Run_Increment__c)
            						|| (job.Run_Units__c != old.Run_Units__c))))) {
            	// Calculate the next time for this Aggregable Job to be run (may return null)
        		job.Next_Run__c = JobScheduler.GetNextRunTimeForJob(job);
            }
             
            // If this Job is new, or is newly Activated,
            // attempt to schedule it
            if (job.IsActive__c && (job.JobSchedulerId__c == null) 
            && (Trigger.isInsert 
            	|| (Trigger.isUpdate 
            		&& ((old.IsActive__c == false) || (old.Run_Individually__c != job.Run_Individually__c))
            ))) {
            	jobsToSchedule.add(job);
            }
             
            // If this Job is currently scheduled (i.e. its JobSchedulerId__c field is NON-null),
            // and we are either deleting it, or updating its IsActive__c field from TRUE to FALSE,
            // then we need to unschedule this Job
            if ((job.JobSchedulerId__c != null)
            && (Trigger.isDelete || (Trigger.isUpdate && !job.IsActive__c && old.IsActive__c))) {
            	
            	// Add the Job's CronTriggerId to a set of those we need to abort
            	if (job.Run_Individually__c && (job.CronTriggerId__c != null)) {
	                jobsToAbort.add(job.CronTriggerId__c);
            	}
            	// Add the Relax Job Scheduler Id to a set of those we need to abort
            	if (job.JobSchedulerId__c != null) {
	                jobsToAbort.add(job.JobSchedulerId__c);
            	}    
                // Erase the reference to this Job's CronTrigger, AsyncApexJob, and/or Relax Job Scheduler record
                //  (if we're not deleting the record),
                // and reset the next and last run times
                if (!Trigger.isDelete) {
                	job.Status__c = null;
                	job.CronTriggerId__c = null;
                	job.AsyncApexJobId__c = null;
                	job.JobSchedulerId__c = null;
                	//job.Last_Run__c = null;
                	job.Next_Run__c = null;
                }	
            }
            
        } // end for loop
        
        if (!jobsToSchedule.isEmpty()) {
            JobScheduler.ScheduleJobs(jobsToSchedule);
        }
        
        // If we have Jobs to abort, and we're not in a Batch or Future method,
        // do a @future call to abort these jobs
        // (that is, we're assuming that this action is being initiated from the UI)
        if (!jobsToAbort.isEmpty() && !JobScheduler.IsBatch) {
            JobScheduler.AbortJobs(jobsToAbort);
        }
        
    } // end before insert/update branch
    
}