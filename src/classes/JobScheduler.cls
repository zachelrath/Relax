// Responsible for handling all Relax Job scheduling operations 

global class JobScheduler implements Schedulable, Database.Stateful, Database.Batchable<sObject> {

	// The CronTrigger job that launched this process
	private String oldTriggerId;
	// A new CronTrigger job that will spawn a new process
	private String newTriggerId;
	// The new JobScheduler that we will be scheduling
	private JobScheduler scheduler;
	// The new Process that we will be instantiating
	private Process asyncProcess;
	// Any temporary CronTrigger records that we need to abort
	private Set<String> tempTriggerIds;
	// The runnables to execute during this Process
	private List<Runnable> runnables; 
	// The email address of the user who scheduled this job
	// (used for sending exception emails)
	private String adminEmail;
	
	// A static flag used to help us avoid certain restrictions,
	// e.g. no @future methods can be called from batch classes.
	// For some reason, System.isBatch() is not working as it should
	public static boolean IsBatch { public get; public set; }

	public String getAdminEmail() { 
		if (adminEmail == null) {
			// Find the email of the user who created the current CronTrigger record
			try {
				if (UserInfo.getUserId() != null) {
					adminEmail = UserInfo.getUserEmail();
				} 
				
				//else if (newTriggerId != null) {
				//	CronTrigger ct = [select OwnerId from CronTrigger where Id = :newTriggerId limit 1];
				//	adminEmail = [select Email from User where Id = :ct.OwnerId limit 1].Email;
				//	System.debug('*** Got admin email from newTriggerId');
				//} else {
				//	String adminName = [select PrimaryContact from Organization limit 1].PrimaryContact;
				//	adminEmail = [select Email from User where Name = :adminName limit 1].Email;
				//	System.debug('*** Got admin email from organization PrimaryContact'); 
				//}	
			} catch (Exception ex) {}
		}
		return adminEmail;
	}
	
	static {
		IsBatch = false;
	}
	
	// Called from arbitrary context
	public JobScheduler() {
		this(null,null,null);
	}
	
	//
	// Called from execute(SchedulableContext ctx) 
	//	
	public JobScheduler(String oldTriggerId, String newTriggerId, Set<String> tempTriggerIds) {
		this.oldTriggerId = oldTriggerId;
		this.newTriggerId = newTriggerId;
		this.tempTriggerIds = tempTriggerIds;
	}
	
	public Database.QueryLocator start(Database.BatchableContext bc) {		
		
		// Set our static flag to avoid running future methods from within a batch context
		IsBatch = true;
		
		// PSEUDO-CODE for what Job Scheduler needs to accomplish:
		
		// ALWAYS: abort the current job
		
		// CONDITIONALS:
		// Are there any Active jobs tied to THIS scheduled job?
		// 		-If NOT, then we want to go find any Jobs tied to this scheduler (there shouldn't be any, but there might be)
		//			and remove their references to this scheduled job.
		//		-If there ARE active jobs tied to THIS scheduled job, 
		//			the question is: what is the STATUS of each of these jobs?
		//
		//			If ALL are 'Completed', and some/all have a Next Run less than now, instantiate a new process to 
		//			AND we need to run Job Scheduler again in 5 minutes.
		//			If NOT all are Completed or some are executing and it's been fewer than 30 minutes since Next Run,
		//			then we just need to run Job Scheduler again in 5 minutes.
		
		// ALWAYS, ALWAYS abort the current scheduler job,
		// plus any temporary trigger ids we were handed
		// (must be done from Batch Apex)
		Set<String> triggersToAbort = new Set<String>();
		if (this.oldTriggerId != null) triggersToAbort.add(this.oldTriggerId);
		if (this.tempTriggerIds != null) triggersToAbort.addAll(this.tempTriggerIds);
		if (this.asyncProcess != null) {
			Set<String> localTempJobs = this.asyncProcess.getTempJobs();
			if (localTempJobs != null && !localTempJobs.isEmpty()) {
				triggersToAbort.addAll(localTempJobs);
			}
		}
		if (!triggersToAbort.isEmpty()) {
			for (String s : triggersToAbort) {
				try {
					System.abortJob(oldTriggerId);
				} catch (Exception ex) {}
			}	
		}
		
		// First of all, check to see whether there are ANY active jobs.
		List<Job__c> activeJobs = [
			select Id from Job__c where IsActive__c = true limit 1
		];
		// If there are NO active jobs,
		// then we do not want this process to continue at all.
		// Rather, we just want to run ourself again in 30 seconds  
		if (!activeJobs.isEmpty()) {
			// Schedule ourself to run again in 30 seconds
			try {
				Datetime timeout = Datetime.now().addSeconds(30);
				this.scheduler = new JobScheduler();
	            this.newTriggerId = System.schedule(
	            	'Relax Job Scheduler ' + timeout.getTime(),
	            	GetCRONExpression(timeout),
	            	this.scheduler
	            );
			} catch (Exception ex) {
				SendEmailOnException(ex, 'Could not perpetuate Job Scheduler Process', getAdminEmail());
			}
			
			this.runnables = new List<Runnable>();
		}	
		
		Integer debug = [select	count()
			from	Job__c
			where	IsActive__c = true];
		
        // Query for all active jobs
        return Database.getQueryLocator([
			select	Id, Name, IsActive__c, Apex_Class__c, JobSchedulerId__c,
					Run_Individually__c, Status__c, 
					Only_Run_Once__c, Delete_Job_After_Run__c,
					Run_Increment__c, Run_Units__c,
					Last_Run__c,Next_Run__c,
					AsyncApexJobId__c, CronTriggerId__c,
					Parameters__c
			from	Job__c
			where	IsActive__c = true
			order by Order__c nulls last
        ]);
	}
	
	public void execute(Database.BatchableContext bc, List<SObject> scope) {
		
		// Reset our static flag
		IsBatch = true;
		
		// Get the ApexClass Ids of any currently executing Batch Apex classes
		List<AsyncApexJob> runningApexJobs = [
			SELECT ApexClassId FROM AsyncApexJob WHERE Status in ('Queued','Processing','Preparing')
		];
		Set<Id> classIds = new Set<Id>();
		for (AsyncApexJob j : runningApexJobs) {
			classIds.add(j.ApexClassId);
		}
		// Get the Names of any ApexClasses corresponding to these ApexClassIds
		List<ApexClass> runningClasses = [
			SELECT Name, NamespacePrefix FROM ApexClass WHERE Id in :classIds
		];
		Map<String,ApexClass> runningClassesByName = new Map<String,ApexClass>();
		for (ApexClass c : runningClasses) {
			runningClassesByName.put(((c.NamespacePrefix != null) ? c.NamespacePrefix + '.' : '') + c.Name,c);
		} 	
		
		List<Job__c> jobs = (List<Job__c>) scope;
		List<Job__c> jobsToDelete = new List<Job__c>();
		
		// Check to see if they're actually still running, or if they've failed.
		Map<String,Job__c> jobsByBatchId = new Map<String,Job__c>();
		Map<String,Job__c> jobsByTriggerId = new Map<String,Job__c>();
		
		for (Job__c j : jobs) {
			// Give this job a reference to ourself
			j.JobSchedulerId__c = newTriggerId;
			
			if (j.Run_Individually__c) {
				jobsByTriggerId.put(j.CronTriggerId__c,j);
			} else {
				if ((j.Status__c == 'Started') && (j.AsyncApexJobId__c != null)) {
					jobsByBatchId.put(j.AsyncApexJobId__c,j);
					
					// If Last Run is less than 5 minutes ago, but this job has been completed,
					// then this job must have completed in the last 5 minutes,
					// so update Last Run to NOW
					//if ((j.Last_Run__c == null) || (j.Last_Run__c < Datetime.now().addMinutes(-5))) {
					//	j.Last_Run__c = Datetime.now();
					//}
					//j.Next_Run__c = JobScheduler.GetNextRunTimeForJob(j);
				} 
				if (j.Status__c == 'Queued') {
					// Nothing more to do
				} else if (j.Status__c == 'Completed') {
					
					// If Last Run is null,
					// or if the difference between Last Run and NOW
					// is greater than the computed Run Increment,
					// then set Last Run to NOW,
					// as it apparently didn't get updated properly during batch execution
					if (LastRunNeedsReset(j)) {
						j.Last_Run__c = Datetime.now();
					}
					
					// TODO: should we be checking on Run Individually here?
					
					if (j.Only_Run_Once__c) {
						// Deactivate this Job
						j.IsActive__c = false;
						// If this Job is set to be auto-deleted after its run,
						// tee it up for deletion.
						if (j.Delete_Job_After_Run__c) {
							jobsToDelete.add(j);
							continue;
						}
					} else {
						
						// Get the Next Run time for this Job, if needed
						if ((j.Last_Run__c == null) 
						|| ((j.Next_Run__c != null) && (j.Next_Run__c <= j.Last_Run__c))) {
							j.Next_Run__c = GetNextRunTimeForJob(j);
						}
						
						// Queue this job up to be run!
						j.Status__c = 'Queued';
						// Eliminate references to any past process
						j.AsyncApexJobId__c = null;
						j.CronTriggerId__c = null;
					}
				}
				
				// If the Next Run time (perhaps newly-updated)
				// is less than now, then this job is due to be run!
				if (j.IsActive__c 
				&& (j.Status__c == 'Queued') 
				&& (j.Next_Run__c <= Datetime.now())
				// Do NOT run the Job if it is already queued to be run or currently running.
				// That would just clog up our Batch Apex queue.
				&& !runningClassesByName.containsKey(j.Apex_Class__c)) {
					// TODO: use Type__c field to determine what kind of runnable to instantiate,
					// if (j.Type__c == 'Batch Apex') {
					// Instantiate a new BatchableRunnable for each of the non-individual Jobs
						runnables.add(new BatchableRunnable(j));
					// else if (j.Type__c == 'Schedulable Apex') {
					// 	runnables.add(new SchedulableRunnable(j));
					// }
				}
			}	
		}	

		if (!jobsByBatchId.isEmpty()) {
			for (List<AsyncApexJob> batchJobs : [
				select Status from AsyncApexJob where Id in :jobsByBatchId.keyset() and Status in ('Failed','Aborted')
			]) {
				for (AsyncApexJob batchJob : batchJobs) {
					Job__c j = jobsByBatchId.get(batchJob.Id);
					if (j == null) j = jobsByBatchId.get(String.valueOf(batchJob.Id).substring(0,15));
					if (j != null) {
						j.Status__c = 'Failed';
					}
				}	
			}
		}	
		
		// See if any of the CronTrigger records associated with our Run-Individually jobs
		// have just been run
		if (!jobsByTriggerId.isEmpty()) { 
			for (List<CronTrigger> cronJobs : [
				select	Id, NextFireTime, PreviousFireTime, State
				from	CronTrigger
				where	Id in :jobsByTriggerId.keyset()
				and 	PreviousFireTime != null
				and		PreviousFireTime <= :Datetime.now()
			]) {
				for (CronTrigger ct : cronJobs) {
					// Update the Last Run and Next Run fields on these Individually-scheduled Job__c records
					Job__c j = jobsByTriggerId.get(String.valueOf(ct.Id).substring(0,15));
					j.Last_Run__c = ct.PreviousFireTime;
					j.Next_Run__c = ct.NextFireTime;
					
					if ((ct.State == 'ACQUIRED') || (ct.State == 'EXECUTING') || (ct.State == 'PAUSED') || (ct.State == 'PAUSED_BLOCKED')) {
						j.Status__c = 'Started';
					} else if ((ct.State == 'COMPLETE') || (ct.State == 'DELETED')) {
						j.IsActive__c = false;
					} else if ((ct.State == 'ERROR') || (ct.State == 'BLOCKED')) {
						j.Status__c = 'Failed';
					}
				}
			}
		}
		
		if (!jobs.isEmpty()) {
			Database.update(jobs,false);
		}
		
		if (!jobsToDelete.isEmpty()) {
			Database.delete(jobsToDelete,false);
		}
	}
	
	public void finish(Database.BatchableContext bc) {
		
		// Reset our static flag
		IsBatch = true;
		
		// If we have runnables, we need to build a Process, and then get it going 
		if (!runnables.isEmpty()) {
			// Instantiate a new process
			Process p = new SimpleProcess(runnables,newTriggerId);
			// Associate our JobScheduler with this Process
			this.scheduler.setProcess(p);
			
			// To get our process going, we'll need to launch a ProcessBalloon,
			// which will begin the process in a new execution context
			Datetime later = Datetime.now().addSeconds(5);
			ProcessBalloon balloon = new ProcessBalloon(p);
			String balloonJobId;
			try {
				balloonJobId = System.schedule('Relax Process Balloon '+later.getTime(),GetCRONExpression(later),balloon);
			} catch (Exception ex) {
				SendEmailOnException(ex, 'Could not launch Job Scheduler Process ' + newTriggerId, getAdminEmail());
			}	
		}
		
	}
	
	//
	// Used for retaining access to the previous process,
	// so that we can guarantee that we'll be able to abort its temp jobs
	// 
	public void setProcess(Process asyncProcess) {
		this.asyncProcess = asyncProcess;
	}
	
	public Process getProcess() {
		return this.asyncProcess;
	}


	//
	// Schedulable interface
	//
	public void execute(SchedulableContext ctx) {
		// If we have been handed an Async Process (through the setProcess() method),
		// then populate this process in our Batch Job
		Process oldProcess = this.getProcess();
		
		// Launch our JobScheduler batch process ASAP
		JobScheduler js = new JobScheduler(ctx.getTriggerId(),null,null);
		if (oldProcess != null) {
			js.setProcess(oldProcess);
		}
		Database.executeBatch(js);
	}
	
	//
	// Job Scheduling/Aborting utilities
	//
	
    // For all Aggregable Jobs (those where Run_Individually__c is FALSE),
    // we ONLY want to abort the Relax Job Scheduler if there are NO other still-active Jobs
    // with the same CronTrigger Id.
    // For all Individual Jobs (those where Run_Individually__c is TRUE),
    // we have full permission to abort them.
    @future
    public static void AbortJobs(Set<String> cronTriggerIds) {
    	
    	// Query for any remaining Active Jobs tied to any of these Relax Job Scheduler processes
    	for (List<Job__c> jobs : [
    		select	JobSchedulerId__c
			from	Job__c
			where	IsActive__c = true
			and		JobSchedulerId__c in :cronTriggerIds
			and		IsDeleted = false
    	]) {
    		for (Job__c job : jobs) {
    			// If cronTriggerIds still contains this Job's associated Relax Job Scheduler process, remove it,
    			// so that we will NOT abort this job
    			if (cronTriggerIds.contains(job.JobSchedulerId__c)) {
    				cronTriggerIds.remove(job.JobSchedulerId__c);
    			}
    		}
    	}
    	// If we have any leftover CronTriggerIds, abort them
    	if (!cronTriggerIds.isEmpty()) {
    		for (String s : cronTriggerIds) {
    			try {
					System.abortJob(s);
    			} catch (Exception ex) {
    				//SendEmailOnException(ex,'Could not abort cron trigger: ' + s,'zach@skoodat.com');
    			}
	    	}
    	}
    }
    
    // (Called from the Relax__Job__c trigger)
    // Attempt to schedule a new Scheduled Apex Job
    // corresponding to each of the Job__c records
    public static void ScheduleJobs(List<Job__c> jobs) {
    	
    	// Map of Individually-scheduled jobs by their CronTriggerId
    	Map<String,Job__c> individualJobsByTriggerId = new Map<String,Job__c>();
    	// The Id of the current Relax Scheduler process
    	String schedulerId; 
    	
        // If the Job needs to be run individually,
        // then its Apex Class must implement Schedulable
        for (Job__c j : jobs) {
        	
        	// Record whether or not we need to launch the Relax Job Scheduler process
        	boolean runJobScheduler = false;
        	
        	// First, ensure that this Job's Apex Class name is valid.
            System.Type t = GetTypeForClassName(j.Apex_Class__c);
            if (t == null) {
                j.addError('\'' + j.Apex_Class__c + '\' is not a valid Apex Class.');
            }
            // If our Job's Apex Class is valid, we're good to go!
            else {    
	        	
	        	if (j.Run_Individually__c) {
	        		// See if we can schedule this class individually
	                Schedulable cls;
	                
	                try {
	                    cls = (Schedulable) JSON.deserialize('{}',t);
	                } catch (Exception ex) {}
	                
	                if (cls == null) {
	                    j.addError('\'' + j.Apex_Class__c + '\' is not a valid Schedulable Apex Class.');
	                } else {
	                    // Try to schedule the Job
	                    try {
	                        j.CronTriggerId__c = System.schedule(j.Name,j.Cron_Schedule__c,cls);
	                        if (j.CronTriggerId__c != null) {
	                        	// Keep a record of this newly-scheduled Job by its CronTriggerId
	                        	individualJobsByTriggerId.put(j.CronTriggerId__c,j);
	                        	// We have a go-ahead to run the Relax Job Scheduler
	                        	runJobScheduler = true;
	                        }
	                    } catch (Exception e) { 
	                        j.addError('The Job could not be scheduled: ' + e.getMessage());
	                    }
	                }
	        	} 
	        	// Otherwise, we need to ensure that this Job implements Database.Batchable.
	        	// And, if there are no other Jobs with Run_Individually__c set to FALSE,
	        	// then we need to instantiate the Relax JobScheduler.
	        	else {

	        		// Ensure that this job's Apex Class implements ProcessStep
	                ProcessStep cls;
	                
	                try {
	                    cls = (ProcessStep) JSON.deserialize('{}',t);
	                } catch (Exception ex) {}
	                
	                if (cls == null) {
	                    j.addError('\'' + j.Apex_Class__c + '\' does not implement ProcessStep, and therefore cannot be added to a Relax process.');
	                } else {
	                	// We have a go-ahead to run the Relax Job Scheduler 
	                    runJobScheduler = true;
	                }
	        	}
        	} // end Apex Class existence verification
        	
        	if (runJobScheduler) {
        		// Launch the Relax Job Scheduler process, if it has not been run yet
        		if (schedulerId == null) {
            		try {
                        schedulerId = GetJobScheduler();
                    } catch (Exception e) { 
                        j.addError('The Job could not be scheduled: ' + e.getMessage());
                    }
        		} 
                // Associate our Job with the Relax Job Scheduler
            	if (schedulerId != null) {
            		j.JobSchedulerId__c = schedulerId;
            		j.Status__c = 'Queued';
            	}	
        	}
        	
        } // end for (Job__c j : jobs)
        
        if (!individualJobsByTriggerId.isEmpty()) {
        	// Query for the newly-scheduled CronTrigger records associated with each individually-run job
        	for (List<CronTrigger> cronJobs : [
        		select Id, NextFireTime 
        		from CronTrigger 
        		where Id in :individualJobsByTriggerId.keyset()
		    ]) {
        		for (CronTrigger ct : cronJobs) {
        			individualJobsByTriggerId.get(String.valueOf(ct.Id).substring(0,15)).Next_Run__c = ct.NextFireTime;
        		}
        	}
        }
        
    } // end method
    
    // The Id of the CronTrigger currently responsible for scheduling Relax Jobs.
    private static String JobScheduler;
    
    // Returns the Id of the CronTrigger currently responsible for scheduling Relax Jobs.
    // If no such CronTrigger record exists yet,
    // this method will schedule it.
    private static String GetJobScheduler() {
    	if (JobScheduler == null) {
        	// First, attempt to query for the Id of the Relax Job Scheduler
        	List<Job__c> jobs = [
        		select	JobSchedulerId__c 
        		from	Job__c 
        		where	IsActive__c = true
        		and		JobSchedulerId__c != null
        		limit 1
        	];
        	// If no records are returned, then we need to schedule the Relax Job Scheduler.
        	// Otherwise, grab the JobSchedulerId of the first returned record
        	if (!jobs.isEmpty()) {
        		JobScheduler = jobs[0].JobSchedulerId__c;
        	} else {
        		Datetime thirtySeconds = Datetime.now().addSeconds(30);
        		try {
                    JobScheduler = System.schedule(
                    	'Relax Job Scheduler ' + thirtySeconds.getTime(),
                    	GetCRONExpression(thirtySeconds),
                    	new JobScheduler()
                    );
                } catch (Exception e) { 
                    throw new RelaxException(String.format(
                    	Label.Scheduler_Could_Not_Be_Run,
                    	new List<String>{e.getMessage()}
                    ));
                }
        	}
    	}
    	return JobScheduler;
    }
    
    // Get the next time that a Job should be run,
    // starting with the last time that the Job was run,
    // or starting NOW if their is no Last Run time
    public static Datetime GetNextRunTimeForJob(Job__c j) {
    	return GetNextRunTimeForJob(j,((j.Last_Run__c == null) ? Datetime.now() : j.Last_Run__c));
    }
    // Calculate the next time that a job should be run
    // relative to a given starting point.
	// To do this, Run Units and Run Increment must be non-null
    public static Datetime GetNextRunTimeForJob(Job__c j, Datetime start) {
		Datetime nextRun = null;
		if (j.Run_Units__c != null && j.Run_Increment__c != null && j.Run_Increment__c >= 1) {
			Integer increment = Integer.valueOf(j.Run_Increment__c);
			if (j.Run_Units__c == 'Minutes') nextRun = start.addMinutes(increment);
			else if (j.Run_Units__c == 'Hours') nextRun = start.addHours(increment);
			else if (j.Run_Units__c == 'Days') nextRun = start.addDays(increment);
			else if (j.Run_Units__c == 'Weeks') nextRun = start.addDays(increment * 7);
			else if (j.Run_Units__c == 'Months') nextRun = start.addMonths(increment);
		}
		return nextRun;
    }
    
    // Convenience method for quickly scheduling a one-time (temp) Job
    global static Job__c CreateOneTimeJob(String className) {
    	return CreateOneTimeJob(className, Datetime.now().addMinutes(-5), true);
    }
    
    // Convenience method for quickly scheduling a one-time (temp) Job
    global static Job__c CreateOneTimeJob(String className, boolean deleteAfterRun) {
    	return CreateOneTimeJob(className, Datetime.now().addMinutes(-5), deleteAfterRun);
    }
    
    // Convenience method for quickly scheduling a one-time (temp) Job
    global static Job__c CreateOneTimeJob(String className, Datetime runTime, boolean deleteAfterRun, String parameters) {
    	Job__c temp = new Job__c(
    		IsActive__c = true,
    		Run_Individually__c = false,
    		Only_Run_Once__c = true,
    		Delete_Job_After_Run__c = deleteAfterRun,
    		Next_Run__c = runTime,
    		Apex_Class__c = className,
    		Parameters__c = parameters,
    		Name = className + ' ' + runTime.getTime()
    	);
    	insert temp;
    	return temp;
    }
    
    // Convenience method for quickly scheduling a one-time (temp) Job
    global static Job__c CreateOneTimeJob(String className, Datetime runTime, boolean deleteAfterRun) {
    	return CreateOneTimeJob(className, runTime, deleteAfterRun,null);
    }
    // If Last Run is null,
	// or if the difference between Last Run and NOW
	// is greater than the run interval (the time between Next Run and NOW if Last Run = NOW),
	// then Last Run needs to be reset to NOW,
	// as it apparently didn't get updated properly during batch execution
    public static boolean LastRunNeedsReset(Job__c j) {
    	if (j.Last_Run__c != null) {
    		Long n = Datetime.now().getTime();
    		try {	
				return ((n - j.Last_Run__c.getTime()) > (GetNextRunTimeForJob(j,Datetime.now()).getTime() - n));
    		} catch (Exception ex) {}
    	}
    	return true;
    }
    
    // Get the System.Type for a string representation of an Apex Class name
    // such as 'namespace.MyClassName.MyInnerClassName'
    public static System.Type GetTypeForClassName(String name) {
        System.Type t;
        
        try {
            t = System.Type.forName(name);
        } catch (Exception exc) {
        	try {
                // attempt to strip off a namespace prefix from our class name,
                // and try again. If we fail the 2nd time, then we seriously failed.
            	if (name.contains('.')) {
            		String sansNamespace = name.substring(name.indexOf('.')+1);
            		t = System.Type.forName(sansNamespace);
            	}
        	} catch (Exception exc2) {}
        }
		return t;
    }
    
    public static void SendDebugEmail(String htmlBody, String textBody, String subject, String email) {
    	// Send an email to the specified email addresses with a report of how the batch job went
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        mail.setToAddresses(new List<String>{email});
        mail.setReplyTo('zach@skuidify.com');
        mail.setSenderDisplayName('Relax');
        mail.setSubject(subject);
        mail.setPlainTextBody(htmlBody);
        mail.setHtmlBody(textBody);
        
        Messaging.reserveSingleEmailCapacity(1);
        
        List<Messaging.SendEmailResult> result = Messaging.sendEmail(
        	new List<Messaging.SingleEmailMessage>{mail}
        );
    }
    
    // Send an email to a specified person describing an exception that occurred
    public static void SendEmailOnException(Exception ex, String subject, String email) {
    	String htmlBody = 'Message: ' + ex.getMessage() + '<br/>'
        	+ 'Line Number: ' + ex.getLineNumber() + '<br/>'
        	+ 'Stack Trace:' + ex.getStackTraceString();
        String plainTextBody = 'Message: ' + ex.getMessage() + '\n'
        	+ 'Line Number: ' + ex.getLineNumber() + '\n'
        	+ 'Stack Trace:' + ex.getStackTraceString();
    	SendDebugEmail(htmlBody,plainTextBody,subject,email);
    }
    
    // Return a CRON Expression corresponding to a Datetime
	global static String GetCRONExpression(Datetime dt) {
		return ('' + dt.second() + ' ' + dt.minute() + ' ' + dt.hour() + ' ' + dt.day() + ' ' + dt.month() + ' ? ' + dt.year());
	}

}