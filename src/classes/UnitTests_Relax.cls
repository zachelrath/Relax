// Unit tests of the Relax functionality

@isTest
private class UnitTests_Relax {

	// Test the behavior of the Job trigger
	private static testMethod void TestJobTrigger() {
		// Load up our test jobs
		List<Job__c> jobs = new List<Job__c>{
			CreateTestJob1(false), 
			CreateTestJob2(false)
		};
		// Insert the jobs. Neither should be scheduled.
		insert jobs;
		jobs = [select Name, JobSchedulerId__c, Apex_Class__c, IsActive__c from Job__c where Name like 'UnitTestJob%' order by Name];
		System.assertEquals(2,jobs.size());
		for (Job__c j : jobs) {
			System.assertEquals(null,j.JobSchedulerId__c);
			System.assertEquals(false,j.IsActive__c);
		}
		// Now update the jobs to be scheduled. A Relax Job Scheduler should be created.
		Test.startTest();
		for (Job__c j : jobs) {
			j.IsActive__c = true;
		}
		update jobs;
		Test.stopTest();
		// Requery for our jobs
		jobs = [select Name, JobSchedulerId__c, Apex_Class__c, IsActive__c, Status__c from Job__c where Name like 'UnitTestJob%' order by Name];
		System.assertEquals(2,jobs.size());
		// Both should be active and have non-null job scheduler ids,
		// and should be Queued
		for (Job__c j : jobs) {
			System.assertEquals('Queued',j.Status__c);
			System.assertEquals(true,j.IsActive__c);
			System.assertNotEquals(null,j.JobSchedulerId__c);
		}
		
		// Get the Job Scheduler id for the 1st job
		String schedulerId = jobs[0].JobSchedulerId__c;
		// It should be the same as Jobs[1]'s scheduler id
		System.assertEquals(jobs[1].JobSchedulerId__c,schedulerId);
		// Query for a crontrigger record associated with this scheduler
		List<CronTrigger> cronJobs = [select Id, NextFireTime from CronTrigger where Id = :schedulerId];
		System.assertEquals(1,cronJobs.size());
		
	}	
	
	// Create a SimpleProcess using our test jobs
	private static testMethod void TestSimpleProcessMethods() {
		// Load up our test jobs
		List<Job__c> jobs = new List<Job__c>{
			CreateTestJob1(true), 
			CreateTestJob2(true)
		};
		insert jobs;
		// Get the scheduled job that was created
		jobs = [select Name, JobSchedulerId__c, Apex_Class__c, IsActive__c, Status__c from Job__c where Name like 'UnitTestJob%' order by Name];
		System.assertEquals(2,jobs.size());
		for (Job__c j : jobs) {
			System.assertEquals('Queued',j.Status__c);
			System.assertEquals(true,j.IsActive__c);
			System.assertNotEquals(null,j.JobSchedulerId__c);
		}
		List<CronTrigger> cronJobs = [select Id, NextFireTime from CronTrigger where Id = :jobs[0].JobSchedulerId__c];
		System.assertEquals(1,cronJobs.size());
		
		// Create BatchableRunnables from our jobs
		List<Runnable> runnables = new List<Runnable>{
			new BatchableRunnable(jobs[0]),
			new BatchableRunnable(jobs[1])
		};
		
		// Create a new SimpleProcess
		Process p = new SimpleProcess(runnables,jobs[0].JobSchedulerId__c);
		
		// Test some of its properties
		System.assertEquals(jobs[0].JobSchedulerId__c,p.getTriggerId());
		System.assertNotEquals(null,p.getTempJobs());
		System.assertEquals(0,p.getTempJobs().size());
		System.assertEquals(true,p.hasNext());
		
		// Simulate adding a temp job to it (we'll add our job scheduler as the temp job)
		p.addTempJob(p.getTriggerId());
		Test.startTest();
		// Simulate aborting the temp job
		p.abortTempJobs();
		Test.stopTest();
	}	
	
	// Create a SimpleProcess using our test jobs, and advance it
	private static testMethod void TestSimpleProcessAdvancement() {
		// Create some test accounts with Industry set to null
		List<Account> accs = CreateTestAccounts();
		insert accs;
		
		// Load up our test jobs
		List<Job__c> jobs = new List<Job__c>{
			CreateTestJob1(true), 
			CreateTestJob2(true)
		};
		insert jobs;
		// Get the scheduled job that was created
		jobs = [
			select	Name, JobSchedulerId__c, Apex_Class__c, 
					IsActive__c, Status__c, Last_Run__c, Next_Run__c,
					Run_Increment__c, Run_Units__c,
					Run_Individually__c 
			from	Job__c 
			where 	Name like 'UnitTestJob%' 
			order by Name
		];
		System.assertEquals(2,jobs.size());
		
		List<Runnable> runnables = new List<Runnable>();
		
		// Start out with a Process with no runnables
		Process p = new SimpleProcess(runnables,jobs[0].JobSchedulerId__c);
		System.assertEquals(false,p.hasNext());
		
		// Now create a process that actually has runnables
		runnables = new List<Runnable>{
			new BatchableRunnable(jobs[0]),
			new BatchableRunnable(jobs[1])
		};
		
		// Create a new SimpleProcess
		p = new SimpleProcess(runnables,jobs[0].JobSchedulerId__c);
		System.assertEquals(true,p.hasNext());
		// Advance the process (e.g. run the first runnable)
		Test.startTest();
		p.advance();
		Test.stopTest();
		// Verify that our Accounts had their Industries set to 'Retail'
		accs = [select Industry from Account where ((Id = :accs[0].Id) or (Id = :accs[1].Id)) order by Name];
		System.assertEquals(2,accs.size());
		System.assertEquals('Retail',accs[0].Industry);
		System.assertEquals('Retail',accs[1].Industry);
		
		// Finish the process
		p.finish();
		
	}
	
	// Excersize methods of SimpleProcessStep  
	private static testMethod void TestSimpleProcessStep() {
		
		// Load up our test jobs
		List<Job__c> jobs = new List<Job__c>{
			CreateTestJob1(true), 
			CreateTestJob2(true)
		};
		insert jobs;
		// Get the scheduled job that was created
		jobs = [
			select	Name, JobSchedulerId__c, Apex_Class__c, 
					IsActive__c, Status__c, Last_Run__c, Next_Run__c,
					Run_Increment__c, Run_Units__c,
					Run_Individually__c 
			from	Job__c 
			where 	Name like 'UnitTestJob%' 
			order by Name
		];
		System.assertEquals(2,jobs.size());
		
		List<CronTrigger> cronJobs = [select Id, NextFireTime from CronTrigger where Id = :jobs[0].JobSchedulerId__c];
		System.assertEquals(1,cronJobs.size());
		
		// Create 2 Runnables
		List<Runnable> runnables = new List<Runnable>{
			new BatchableRunnable(jobs[0]),
			new BatchableRunnable(jobs[1])
		};
		
		// Create a new Process using our Runnables
		Process p = new SimpleProcess(runnables,cronJobs[0].Id);
		
		// Create a SimpleProcessStep
		ProcessStep step = new SimpleProcessStep();
		// Initialize the step
		step.init(p,runnables[0]);
		Test.startTest();
		// Run the runnable
		runnables[0].setProcess(p);
		runnables[0].run();
		Test.stopTest();
		// Complete the step
		step.complete();
		
	}
	
	// Tests the Job Scheduler's behavior
	private static testMethod void TestJobScheduler() {
		
		// Create 3 test jobs
		// JOB 1: Chained, status of 'Completed'
		Job__c job1 = CreateTestJob1(true);
		// JOB 2: Chained, status of 'Queued'
		Job__c job2 = CreateTestJob2(true);
		// JOB 3: Run Individually
		Job__c job3 = CreateTestJob3(true);
		
		List<Job__c> jobs = new List<Job__c>{job1,job2,job3};
		insert jobs;
		
		// Update job1 to simulate setting its status to 'Completed'
		job1.Next_Run__c = Datetime.now().addMinutes(-5);
		job1.Last_Run__c = Datetime.now().addMinutes(-30);
		job1.Status__c = 'Completed';
		update job1;
		
		// Get the scheduled jobs that were created
		jobs = [
			select	Name, JobSchedulerId__c, Apex_Class__c, 
					IsActive__c, Status__c, Last_Run__c, Next_Run__c,
					Run_Increment__c, Run_Units__c,
					Run_Individually__c 
			from	Job__c 
			where 	Name like 'UnitTestJob%' 
			order by Name
		];
		System.assertEquals(3,jobs.size());
		System.assertEquals('Completed',jobs[0].Status__c);
		System.assertEquals('Queued',jobs[1].Status__c);
		System.assertEquals('Queued',jobs[2].Status__c);
		
		List<CronTrigger> cronJobs = [select Id, NextFireTime from CronTrigger where Id = :jobs[0].JobSchedulerId__c];
		System.assertEquals(1,cronJobs.size());
		
		// Instantiate a new JobScheduler, and run it
		JobScheduler js = new JobScheduler();
		// Set the process that this Job Scheduler is a part of
		Process p = new SimpleProcess(
			new List<Runnable>{
				new BatchableRunnable(jobs[0]),
				new BatchableRunnable(jobs[1])
			},cronJobs[0].Id
		);
		// Add some bogus temp jobs
		p.addTempJob('hocuspocus');
		p.addTempJob('bogusbogus');
		js.setProcess(p);
		System.assertEquals(p,js.getProcess());
		
		// Verify that the admin email equals the running user's email
		System.assertEquals([select Email from user where Id = :UserInfo.getUserId()].Email,js.getAdminEmail());
		
		Test.startTest();
		Database.executeBatch(js);
		Test.stopTest();
		
	}	
	
	
	// Create a test job which defaults account industry to Retail
	private static Job__c CreateTestJob1(Boolean isActive) {
		return new Job__c(
			Name				= 'UnitTestJob1',
			Apex_Class__c 		= 'relax.BatchAccountsUpdater',
			Run_Individually__c = false,
			Run_Increment__c	= 1,
			Run_Units__c		= 'Minutes',
			Order__c			= 1,
			IsActive__c			= isActive
		);
	}
	// Create a test job which swaps SLA's from Gold to Bronze
	private static Job__c CreateTestJob2(Boolean isActive) {
		return new Job__c(
			Name				= 'UnitTestJob2',
			Apex_Class__c 		= 'relax.SwapSLAs',
			Run_Individually__c = false,
			Run_Increment__c 	= 1,
			Run_Units__c 		= 'Minutes',
			Order__c 			= 2,
			IsActive__c			= isActive 
		);
	}
	// Create a Schedulable job to run individually which defaults account industry to retail
	private static Job__c CreateTestJob3(Boolean isActive) {
		return new Job__c(
			Name				= 'UnitTestJob3',
			Apex_Class__c 		= 'relax.BatchAccountsUpdater',
			Run_Individually__c = true,
			CRON_Schedule__c 	= '0 40 * * * ?',
			IsActive__c			= isActive
		);
	}	
	
	private static List<Account> CreateTestAccounts() {
		return new List<Account>{
			new Account(Name = 'UnitTestAccount1',Industry=null,SLA__c='Gold'),
			new Account(Name = 'UnitTestAccount2',Industry=null,SLA__c='Bronze')
		};
	}

}