// Unit tests of Core Relax functionality

@isTest
private class UnitTests {

	//
	// Test JSR.class
	//
	
	private static testMethod void TestQueryApexClasses() {
		
   		// Query the ApexClass object 
   		List<ApexClass> classes = JSR.queryApexClasses(
   			null,
   			'JobEditController',
   			null,
   			null
   		);
   		
   		// Verify that we returned at least one record
   		System.assert(classes.size() >= 1);
   		
   		// Add in some search and return fields
   		 classes = JSR.queryApexClasses(
   			null,
   			'relax.JobEditController',
   			'NamespacePrefix',
   			'NamespacePrefix'
   		);
   		System.assert(classes.size() >= 1);
   		
   		// Find a schedulable class
   		// Add in some search and return fields
   		 classes = JSR.queryApexClasses(
   			'Schedulable',
   			'relax ProcessBalloon',
   			'NamespacePrefix',
   			'NamespacePrefix'
   		);
   		System.assert(classes.size() >= 1);
   		
   		// Find an Aggregable class (one that implements relax.Process)
   		 classes = JSR.queryApexClasses(
   			'ProcessStep',
   			'MassUpdate rel',
   			'Name,NamespacePrefix',
   			'Name,NamespacePrefix'
   		);
   		
   		
	}

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
		// Create some test data 
		// (we will be using Job records for testing 
		// to avoid referencing any actual objects in customer orgs)
		List<Job__c> dummyData = CreateDummyData();
		insert dummyData;
		AssertInserted(dummyData);
		Set<Id> dummyDataIds = (new Map<Id,Job__c>(dummyData)).keyset();
		
		// Load up our test jobs
		List<Job__c> jobs = new List<Job__c>{
			CreateTestJob1(true), 
			CreateTestJob2(true)
		};
		insert jobs;
		AssertInserted(jobs);
		
		// Get the scheduled job that was created
		jobs = [
			select	Name, JobSchedulerId__c, Apex_Class__c, 
					IsActive__c, Status__c, Last_Run__c, Next_Run__c,
					Run_Increment__c, Run_Units__c,
					Run_Individually__c, Parameters__c
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
		// Verify that all jobs  
		// currently at fewer than 5 Minutes 
		// had their run increment set to be 30 Minutes
		dummyData = [select Run_Increment__c from Job__c where Id in :dummyDataIds order by Name];
		System.assertEquals(4,dummyData.size());
		System.assertEquals(30,dummyData[0].Run_Increment__c); // was 3 minutes, so should now be 30
		System.assertEquals(30,dummyData[1].Run_Increment__c); // was 4 minutes, so should now be 30
		System.assertEquals(25,dummyData[2].Run_Increment__c); // WAS 25 minutes, so no update should have happened
		System.assertEquals(2,dummyData[3].Run_Increment__c); // WAS 2 hours, so no update should have happened
		
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
					Run_Individually__c, Parameters__c 
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
		
		// Create our dummy data
		List<Job__c> dummyData = CreateDummyData();
		insert dummyData;
		AssertInserted(dummyData);
		
		// Create 3 test jobs
		// JOB 1: Chained, status of 'Completed'
		Job__c job1 = CreateTestJob1(true);
		// JOB 2: Chained, status of 'Queued'
		Job__c job2 = CreateTestJob2(true);
		// JOB 3: Run Individually
		Job__c job3 = CreateTestJob3(true);
		
		List<Job__c> jobs = new List<Job__c>{job1,job2,job3};
		insert jobs;
		AssertInserted(jobs);
		
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
					Run_Individually__c, Parameters__c
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
		System.assertEquals(UserInfo.getUserEmail(),js.getAdminEmail());
		
		Test.startTest();
		Database.executeBatch(js);
		Test.stopTest();
		
		
	}	
	private static testMethod void TestMassUpdate_FieldsFromFields() {
		// Create some test data 
		// (we will be using Job records for testing 
		// to avoid referencing any actual objects in customer orgs)
		List<Job__c> dummyData = CreateDummyData();
		insert dummyData;
		AssertInserted(dummyData);
		Set<Id> dummyDataIds = (new Map<Id,Job__c>(dummyData)).keyset();
		
		// Load up test job 2, which runs a FieldsFromFields job
		List<Job__c> jobs = new List<Job__c>{
			CreateTestJob2(true) 
		};
		insert jobs;
		AssertInserted(jobs);
		
		// Get the scheduled job that was created
		jobs = [
			select	Name, JobSchedulerId__c, Apex_Class__c, 
					IsActive__c, Status__c, Last_Run__c, Next_Run__c,
					Run_Increment__c, Run_Units__c,
					Run_Individually__c, Parameters__c
			from	Job__c 
			where 	Name like 'UnitTestJob%' 
			order by Name
		];
		System.assertEquals(1,jobs.size());
		
		List<Runnable> runnables = new List<Runnable>{
			new BatchableRunnable(jobs[0])
		};
		
		// Create a basic process
		Process p = new SimpleProcess(runnables,jobs[0].JobSchedulerId__c);
		System.assertEquals(true,p.hasNext());
		
		// Advance the process (e.g. run the first runnable)
		Test.startTest();
		p.advance();
		Test.stopTest();
		
		// Verify that all of our dummy jobs' names have now been set to their Ids  
		dummyData = [select Id,Name from Job__c where Id in :dummyDataIds];
		System.assertEquals(4,dummyData.size());
		for (Job__c j : dummyData) {
			System.assertEquals(String.valueOf(j.Id),j.Name);
		}
		
		// Finish the process
		p.finish();
		
	}
	
	private static testMethod void TestMassUpdate_FieldsWithValues() {
		// Create some test data 
		// (we will be using Job records for testing 
		// to avoid referencing any actual objects in customer orgs)
		List<Job__c> dummyData = CreateDummyData();
		insert dummyData;
		AssertInserted(dummyData);
		Set<Id> dummyDataIds = (new Map<Id,Job__c>(dummyData)).keyset();
		
		// Load up test job 4, which runs a FieldsWithValues job
		List<Job__c> jobs = new List<Job__c>{
			CreateTestJob4(true) 
		};
		insert jobs;
		AssertInserted(jobs);
		
		// Get the scheduled job that was created
		jobs = [
			select	Name, JobSchedulerId__c, Apex_Class__c, 
					IsActive__c, Status__c, Last_Run__c, Next_Run__c,
					Run_Increment__c, Run_Units__c,
					Run_Individually__c, Parameters__c
			from	Job__c 
			where 	Name like 'UnitTestJob%' 
			order by Name
		];
		System.assertEquals(1,jobs.size());
		
		List<Runnable> runnables = new List<Runnable>{
			new BatchableRunnable(jobs[0])
		};
		
		// Create a basic process
		Process p = new SimpleProcess(runnables,jobs[0].JobSchedulerId__c);
		System.assertEquals(true,p.hasNext());
		
		// Advance the process (e.g. run the first runnable)
		Test.startTest();
		p.advance();
		Test.stopTest();
		
		// Verify that all of our dummy jobs' names have now been set to their Ids  
		dummyData = [select Run_Units__c from Job__c where Id in :dummyDataIds];
		System.assertEquals(4,dummyData.size());
		for (Job__c j : dummyData) {
			System.assertEquals('Hours',j.Run_Units__c);
		}
		
		// Finish the process
		p.finish();
		
	}
	
	//
	// Test MassDelete.cls
	//
	
	private static testMethod void TestMassDelete() {
		// Create some test data 
		// (we will be using Job records for testing 
		// to avoid referencing any actual objects in customer orgs)
		List<Job__c> dummyData = CreateDummyData();
		insert dummyData;
		AssertInserted(dummyData);
		List<Id> dummyDataIds = new List<Id>((new Map<Id,Job__c>(dummyData)).keyset());
		
		// Create a test job which will mass-delete our dummy records
		String query = 
			'select Id from relax__Job__c where Id in (\''
			+String.join(dummyDataIds,'\',\'')
			+'\')';
			
		Job__c massDeleteJob = new Job__c(
			Name				= 'UnitTestMassDeleteJob',
			Apex_Class__c 		= 'relax.MassDelete',
			Run_Individually__c = false,
			Run_Increment__c 	= 1,
			Run_Units__c 		= 'Minutes',
			Order__c 			= 1,
			IsActive__c			= true,
			Parameters__c		= JSON.serialize(new Map<String,Object>{
				'query'			=> query
			})
		);
		insert massDeleteJob;
		AssertInserted(massDeleteJob);
		
		// Re-retrieve the job that was created
		massDeleteJob = [
			select	Name, JobSchedulerId__c, Apex_Class__c, 
					IsActive__c, Status__c, Last_Run__c, Next_Run__c,
					Run_Increment__c, Run_Units__c,
					Run_Individually__c, Parameters__c
			from	Job__c 
			where 	Id = :massDeleteJob.Id 
			order by Name
		];
		System.assertNotEquals(null,massDeleteJob);
		
		List<Runnable> runnables = new List<Runnable>{
			new BatchableRunnable(massDeleteJob)
		};
		
		// Create a basic process
		Process p = new SimpleProcess(runnables,massDeleteJob.JobSchedulerId__c);
		System.assertEquals(true,p.hasNext());
		
		// Advance the process (e.g. run the first runnable)
		Test.startTest();
		p.advance();
		Test.stopTest();
		
		// Verify that all of our dummy jobs were deleted  
		dummyData = [select Id from Job__c where Id in :dummyDataIds];
		System.assertEquals(0,dummyData.size());
		
		// Finish the process
		p.finish();
		
	}
	
	//
	// Utility methods
	//
	
	// Create a test job which sets the Run Units of Jobs 
	// currently at fewer than 5 Minutes to be 30 Minutes 
	private static Job__c CreateTestJob1(Boolean isActive) {
		return new Job__c(
			Name				= 'UnitTestJob1',
			Apex_Class__c 		= 'relax.MassUpdate',
			Run_Individually__c = false,
			Run_Increment__c	= 1,
			Run_Units__c		= 'Minutes',
			Order__c			= 1,
			IsActive__c			= isActive,
			Parameters__c		= JSON.serialize(new Map<String,Object>{
				'mode' 			=> 'FIELD_WITH_VALUE',
				'field' 		=> 'relax__Run_Increment__c',
				'value'			=> 30,
				'query'			=> 'select relax__Run_Increment__c from relax__Job__c where Name like \'DummyTestJob%\' and relax__Run_Units__c = \'Minutes\' and relax__Run_Increment__c <= 5'
			})
		);
	}
	// Create a test job which sets the Name of existing Jobs to be their Ids. 
	private static Job__c CreateTestJob2(Boolean isActive) {
		return new Job__c(
			Name				= 'UnitTestJob2',
			Apex_Class__c 		= 'relax.MassUpdate',
			Run_Individually__c = false,
			Run_Increment__c 	= 1,
			Run_Units__c 		= 'Minutes',
			Order__c 			= 2,
			IsActive__c			= isActive,
			Parameters__c		= JSON.serialize(new Map<String,Object>{
				'mode' 			=> 'FIELDS_FROM_FIELDS',
				'sourceFieldsByTargetField' => new Map<String,String>{
					'Name' => 'Id' 
				},
				'query'			=> 'select Id,Name from relax__Job__c where Name like \'DummyTestJob%\''
			})
		);
	}
	// Create a Schedulable job to run individually 
	// which changes the Run Units of all Jobs that are Minutes to be Hours
	private static Job__c CreateTestJob3(Boolean isActive) {
		return new Job__c(
			Name				= 'UnitTestJob3',
			Apex_Class__c 		= 'relax.MassUpdate',
			Run_Individually__c = true,
			CRON_Schedule__c 	= '0 40 * * * ?',
			IsActive__c			= isActive,
			Parameters__c		= JSON.serialize(new Map<String,Object>{
				'mode' 			=> 'FIELDS_WITH_VALUES',
				'valuesByField' => new Map<String,Object>{
					'relax__Run_Units__c' => 'Hours' 
				},
				'query'			=> 'select relax__Run_Units__c from relax__Job__c where Name like \'DummyTestJob%\' and relax__Run_Units__c = \'Minutes\''
			})
		);
	}	
	// Create a Schedulable job to run aggregably 
	// which changes the Run Units of all Jobs that are Minutes to be Hours
	private static Job__c CreateTestJob4(Boolean isActive) {
		return new Job__c(
			Name				= 'UnitTestJob4',
			Apex_Class__c 		= 'relax.MassUpdate',
			Run_Individually__c = false,
			Run_Increment__c 	= 1,
			Run_Units__c 		= 'Minutes',
			Order__c 			= 4,
			IsActive__c			= isActive,
			Parameters__c		= JSON.serialize(new Map<String,Object>{
				'mode' 			=> 'FIELDS_WITH_VALUES',
				'valuesByField' => new Map<String,Object>{
					'relax__Run_Units__c' => 'Hours' 
				},
				'query'			=> 'select relax__Run_Units__c from relax__Job__c where Name like \'DummyTestJob%\' and relax__Run_Units__c = \'Minutes\''
			})
		);
	}
	
	//
	// DUMMY DATA
	//
	private static List<Job__c> CreateDummyData(){
		return new List<Job__c>{
			// Job A - run every 3 Minutes
			new Job__c(
				Name				= 'DummyTestJob_1_Every3Mins',
				Apex_Class__c 		= 'relax.MassUpdate',
				Run_Individually__c = false,
				Run_Increment__c 	= 3,
				Run_Units__c 		= 'Minutes',
				Order__c 			= 1,
				IsActive__c			= false
			),
			// Job B - run every 4 Minutes
			new Job__c(
				Name				= 'DummyTestJob_2_Every4Mins',
				Apex_Class__c 		= 'relax.MassUpdate',
				Run_Individually__c = false,
				Run_Increment__c 	= 4,
				Run_Units__c 		= 'Minutes',
				Order__c 			= 2,
				IsActive__c			= false
			),
			// Job C - run every 25 Minutes
			new Job__c(
				Name				= 'DummyTestJob_3_Every25Mins',
				Apex_Class__c 		= 'relax.MassUpdate',
				Run_Individually__c = false,
				Run_Increment__c 	= 25,
				Run_Units__c 		= 'Minutes',
				Order__c 			= 3,
				IsActive__c			= false
			),
			// Job D - run every 2 hours
			new Job__c(
				Name				= 'DummyTestJob_4_Every25Mins',
				Apex_Class__c 		= 'relax.MassUpdate',
				Run_Individually__c = false,
				Run_Increment__c 	= 2,
				Run_Units__c 		= 'Hours',
				Order__c 			= 4,
				IsActive__c			= false
			)
		};
	}
	
	public static void AssertInserted(List<Sobject> objs){
		for (Sobject so : objs){
			System.assertNotEquals(null,so.Id);
		}
	}
	
	public static void AssertInserted(Sobject so){
		System.assertNotEquals(null,so.Id);
	}

}