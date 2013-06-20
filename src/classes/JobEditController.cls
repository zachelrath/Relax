//
// Controller for EditJob page
//

public with sharing class JobEditController {

    public Job__c job { public get; private set; }
    public String schedulableClassName { 
        public get; 
        public set {
            schedulableClassName = value;
            if (job.Run_Individually__c) {
            	job.Apex_Class__c = value;
            }	
        }
    }
    public String asyncProcessStepClassName { 
        public get; 
        public set {
            asyncProcessStepClassName = value;
            if (!job.Run_Individually__c) {
            	job.Apex_Class__c = value;
            }
        }
    }

    public JobEditController(ApexPages.StandardController ctl) {
        job = (Job__c) ctl.getRecord();
        /*
        getSchedulableClassOptions();
        getAsyncProcessStepClassOptions();
        
        if (!schedulableClassOptions.isEmpty()) {
        	// Are we updating an existing INDIVIDUALLY-scheduled Job?
        	// If so, attempt to find that job in our list of options.
        	if (job.Run_Individually__c && (job.Apex_Class__c != null)) {
        		schedulableClassName = job.Apex_Class__c;
        	} else {
        		schedulableClassName = schedulableClassOptions[0].getValue();
        	}
        }
        if (!asyncProcessStepClassOptions.isEmpty()) {
            // Are we updating an existing AGGREGABLE Job?
        	// If so, attempt to find that job in our list of options.
        	if (!job.Run_Individually__c && (job.Apex_Class__c != null)) {
        		asyncProcessStepClassName = job.Apex_Class__c;
        	} else {
        		asyncProcessStepClassName = asyncProcessStepClassOptions[0].getValue();
        	}   
        }
        */
    }
    
    // On Save, send the user to the Tab for Jobs
    public PageReference save() {
    	try {
    		upsert job;
    		return cancel();
    	} catch (Exception ex) {
    		ApexPages.addMessages(ex);
    	}
    	return null;
    }
    
    // On Save, send the user to the Tab for Jobs
    public PageReference cancel() {
    	return new PageReference('/' + Job__c.SObjectType.getDescribe().getKeyPrefix());
    }
     
    /*
    // Return a list of all Apex class choices 
    private transient List<ApexClass> allApexClasses;
    public List<ApexClass> getAllApexClasses() {    
        if (allApexClasses == null) {
        	allApexClasses = new List<ApexClass>();
        	for (List<ApexClass> classes : [select Name, NamespacePrefix from ApexClass]) {
        		allApexClasses.addAll(classes);
        	}
        }
        return allApexClasses;
    }
    
    private transient List<SelectOption> schedulableClassOptions; 
    
    // Returns a list of all Schedulable Apex Classes
    public List<SelectOption> getSchedulableClassOptions() {    
        if (schedulableClassOptions == null) {
            schedulableClassOptions = buildSchedulableClassOptions();
        }
        return schedulableClassOptions;
    }
    
    // Build a list of all schedulable class options
    private List<SelectOption> buildSchedulableClassOptions() {
    
        List<SelectOption> options = new List<SelectOption>();
    
        // Build a list of Schedulable classes, so that we can sort
        Map<String,ApexClass> schedulableClasses = new Map<String,ApexClass>();
    
        // Loop over our Apex classes, seeing if they are Schedulable
        for (ApexClass cls : getAllApexClasses()) {
            System.Type t;
            try {
                t = System.Type.forName(cls.NamespacePrefix,cls.Name);
            } catch (Exception ex) { continue; }
            Schedulable s;
            try {
                s = (Schedulable) JSON.deserialize('{}',t);
            } catch (Exception ex) { continue; }
            if (s != null) {
                schedulableClasses.put(cls.Name,cls);
            }    
        }
        
        if (!schedulableClasses.isEmpty()) {
            // Sort our class names alphabetically
            List<String> names = new List<String>();
            names.addAll(schedulableClasses.keyset());
            names.sort();
            for (String s : names) {
                ApexClass cls = schedulableClasses.get(s);
                options.add(new SelectOption(
                    // Value --- add in the namespace prefix if it exists
                    ((cls.NamespacePrefix != null) ? cls.NamespacePrefix + '.' : '') + s,
                    // Label
                    s + ((cls.NamespacePrefix != null) ? ' (' + cls.NamespacePrefix + ')' : '')
                ));
            }
        }
        
        return options;
        
    }
    
    // Returns a list of all classes implementing ProcessStep
    private transient List<SelectOption> asyncProcessStepClassOptions; 
    public List<SelectOption> getAsyncProcessStepClassOptions() {    
        if (asyncProcessStepClassOptions == null) {
            asyncProcessStepClassOptions = buildAsyncProcessStepClassOptions();
        }
        return asyncProcessStepClassOptions;
    }
    
    
    // Build a list of all classes that implement ProcessStep
    private List<SelectOption> buildAsyncProcessStepClassOptions() {
    
        List<SelectOption> options = new List<SelectOption>();
    
        // Build a map of classes, so that we can sort
        Map<String,ApexClass> classes = new Map<String,ApexClass>();
    
        // Loop over our Apex classes, seeing if they are Schedulable
        for (ApexClass cls : getAllApexClasses()) {
        	// Ignore our abstract implementations
            if (!cls.Name.toLowerCase().contains('processstep')) {
	        	
	            System.Type t;
	            try {
	                t = System.Type.forName(cls.NamespacePrefix,cls.Name);
	            } catch (Exception ex) { continue; }
	            ProcessStep s;
	            try {
	                s = (ProcessStep) JSON.deserialize('{}',t);
	            } catch (Exception ex) { continue; }
	            if (s != null) {
	                classes.put(cls.Name,cls);
	            }
            }    
        }
        
        if (!classes.isEmpty()) {
            // Sort our class names alphabetically
            List<String> names = new List<String>();
            names.addAll(classes.keyset());
            names.sort();
            for (String s : names) {
                ApexClass cls = classes.get(s);
                options.add(new SelectOption(
                    // Value --- add in the namespace prefix if it exists
                    ((cls.NamespacePrefix != null) ? cls.NamespacePrefix + '.' : '') + s,
                    // Label
                    s + ((cls.NamespacePrefix != null) ? ' (' + cls.NamespacePrefix + ')' : '')
                ));
            }
        }
        
        return options;
        
    }
    
    */
    
    ///////////////////////
    // UNIT TESTS (of JobEditController and Job trigger)
    ///////////////////////
    
    
    private static testMethod void TestIndividuallyScheduledJob() {
    	// Load up our page for a new Job record
    	Job__c j = new Job__c();
    	ApexPages.Standardcontroller stdctl = new ApexPages.Standardcontroller(j);
    	JobEditController ctl = new JobEditController(stdctl);
    	Test.setCurrentPage(System.Page.EditJob);
    	System.assertEquals(false,ApexPages.hasMessages());
    	
    	/*
    	// We should have non-null lists of schedulable and aggregable class options
    	List<ApexClass> classes = ctl.getAllApexClasses();
    	List<SelectOption> aggregables = ctl.getAsyncProcessStepClassOptions();
    	List<SelectOption> schedulables = ctl.getSchedulableClassOptions();
    	System.assertNotEquals(null,classes);
    	System.assertNotEquals(null,aggregables);
    	System.assertNotEquals(null,schedulables);
    	*/
    	
    	// Schedule an individual job
    	j = ctl.job;
    	System.assertNotEquals(null,j);
    	j.Name = 'Unit_Test_Individually_Scheduled_Job';
    	j.Run_Individually__c = true;
    	j.IsActive__c = true;
    	j.Cron_Schedule__c = '0 0 13 * * ?' ;
    	
    	ctl.schedulableClassName = null;
    	PageReference p = ctl.save();
    	
    	// We should have an error
    	System.assertEquals(true,ApexPages.hasMessages());
    	
    	// Reschedule our record, this time specifying a valid schedulable class
    	ctl.schedulableClassName = 'relax.JobScheduler';
    	p = ctl.save();
    	
    	System.assert(p.getURL().contains('/'+Job__c.SObjectType.getDescribe().getKeyPrefix()));
    	
    	// Verify that our record saved
    	List<Job__c> jobs = [
    		select	Id, Apex_Class__c, IsActive__c, CronTriggerId__c, JobSchedulerId__c, Next_Run__c
    		from	Job__c
    		where	Name = 'Unit_Test_Individually_Scheduled_Job' 
    		order by CreatedDate DESC limit 1
    	];
    	System.assertEquals(1,jobs.size());
    	System.assertEquals('relax.JobScheduler',jobs[0].Apex_Class__c);
    	System.assertEquals(true,jobs[0].IsActive__c);
    	System.assertNotEquals(null,jobs[0].CronTriggerId__c);
    	System.assertNotEquals(null,jobs[0].JobSchedulerId__c);
    	System.assertNotEquals(null,jobs[0].Next_Run__c);
    	
    	// Cancel
    	System.assert(ctl.cancel().getURL().contains('/'+Job__c.SObjectType.getDescribe().getKeyPrefix()));
    	  
    }
    
    //
    // Commented out because we do not have any aggregable jobs pre-included in the relax package
    //
    /**/
    private static testMethod void TestAggregableJob() {
    	// Load up our page for a new Job record
    	Job__c j = new Job__c();
    	ApexPages.Standardcontroller stdctl = new ApexPages.Standardcontroller(j);
    	JobEditController ctl = new JobEditController(stdctl);
    	Test.setCurrentPage(System.Page.EditJob);
    	System.assertEquals(false,ApexPages.hasMessages());
    	
    	/*
    	// We should have non-null lists of schedulable and aggregable class options
    	List<SelectOption> aggregables = ctl.getAsyncProcessStepClassOptions();
    	System.assertNotEquals(null,aggregables);
    	*/
    	
    	// Schedule an aggregable job --- we should get an error because no class has been specified
    	j = ctl.job;
    	System.assertNotEquals(null,j);
    	j.Name = 'Unit_Test_Aggregable_Job';
    	j.Run_Individually__c = false;
    	j.IsActive__c = true;
    	j.Run_Increment__c = 1;
    	j.Run_Units__c = 'Minutes';
    	ctl.asyncProcessStepClassName = null;
    	PageReference p = ctl.save();
    	
    	// We should have an error
    	System.assertEquals(true,ApexPages.hasMessages());
    	
    	// Try to create our job again after specifying a valid class name
    	ctl.asyncProcessStepClassName = 'relax.BatchAccountsUpdater';
    	p = ctl.save();
    	
    	// Verify that our record saved
    	List<Job__c> jobs = [
    		select	Id, Apex_Class__c, IsActive__c, JobSchedulerId__c, Next_Run__c
    		from	Job__c
    		where	Name = 'Unit_Test_Aggregable_Job' 
    		order by CreatedDate DESC limit 1
    	];
    	System.assertEquals(1,jobs.size());
    	System.assertEquals('relax.BatchAccountsUpdater',jobs[0].Apex_Class__c);
    	System.assertEquals(true,jobs[0].IsActive__c);
    	System.assertNotEquals(null,jobs[0].JobSchedulerId__c);
    	System.assertNotEquals(null,jobs[0].Next_Run__c);
    	  
    }
    /**/
    
    private static testMethod void TestJobTrigger_Update() {
    	// Load up our page for a new Schedulable job record
    	Job__c j = new Job__c(
    		Name = 'Unit_Test_Individually_Scheduled_Job',
    		Run_Individually__c = true,
    		IsActive__c = true,
    		Cron_Schedule__c = '0 0 13 * * ?',
    		Apex_Class__c = 'relax.JobScheduler'
		);
		
		insert j;
		
    	// Verify that our record saved
    	List<Job__c> jobs = [
    		select	Id, Apex_Class__c, IsActive__c, CronTriggerId__c, Next_Run__c, JobSchedulerId__c
    		from	Job__c
    		where	Name = 'Unit_Test_Individually_Scheduled_Job' 
    		order by CreatedDate DESC limit 1
    	];
    	
    	String triggerId = jobs[0].CronTriggerId__c;
    	
    	System.assertEquals(1,jobs.size());
    	System.assertEquals('relax.JobScheduler',jobs[0].Apex_Class__c);
    	System.assertEquals(true,jobs[0].IsActive__c);
    	System.assertNotEquals(null,jobs[0].CronTriggerId__c);
    	System.assertNotEquals(null,jobs[0].JobSchedulerId__c);
    	System.assertNotEquals(null,jobs[0].Next_Run__c);
    	
    	// Verify that there is BOTH a CronTrigger record corresponding to this record
    	// and a relax Job Scheduler record
    	List<CronTrigger> cronJobs = [select Id from CronTrigger where Id = :triggerId limit 1];
    	System.assertEquals(1,cronJobs.size());
    	
    	// Update our job, setting it to non-active
    	j.IsActive__c = false;
    	
    	Test.startTest();
    	
    	update j;
    	
    	// Force our @future call to finish running
    	Test.stopTest();
    	
    	// Our job should have its JobSchedulerId__c and CronTriggerId fields set to null
    	jobs = [
    		select	Id, Apex_Class__c, IsActive__c, JobSchedulerId__c, CronTriggerId__c, Next_Run__c
    		from	Job__c
    		where	Name = 'Unit_Test_Individually_Scheduled_Job' 
    		order by CreatedDate DESC limit 1
    	];
    	System.assertEquals(null,jobs[0].CronTriggerId__c);
    	System.assertEquals(null,jobs[0].JobSchedulerId__c);
    	System.assertEquals(null,jobs[0].Next_Run__c); 
    	  
    }
    
    private static testMethod void TestJobTrigger_Delete() {
    	// Load up our page for a new Schedulable job record
    	Job__c j = new Job__c(
    		Name = 'Unit_Test_Individually_Scheduled_Job',
    		Run_Individually__c = true,
    		IsActive__c = true,
    		Cron_Schedule__c = '0 0 13 * * ?',
    		Apex_Class__c = 'relax.JobScheduler'
		);
		
		insert j;
		
    	// Verify that our record saved
    	List<Job__c> jobs = [
    		select	Id, Apex_Class__c, IsActive__c, CronTriggerId__c, JobSchedulerId__c, Next_Run__c
    		from	Job__c
    		where	Name = 'Unit_Test_Individually_Scheduled_Job' 
    		order by CreatedDate DESC limit 1
    	];
    	
    	String triggerId = jobs[0].CronTriggerId__c;
    	
    	System.assertEquals(1,jobs.size());
    	System.assertEquals('relax.JobScheduler',jobs[0].Apex_Class__c);
    	System.assertEquals(true,jobs[0].IsActive__c);
    	System.assertNotEquals(null,jobs[0].CronTriggerId__c);
    	System.assertNotEquals(null,jobs[0].JobSchedulerId__c);
    	System.assertNotEquals(null,jobs[0].Next_Run__c);
    	
    	// Verify that there is a CronTrigger record corresponding to this record
    	List<CronTrigger> cronJobs = [select Id from CronTrigger where Id = :triggerId limit 1];
    	System.assertEquals(1,cronJobs.size());
    	
    	// Update our job, setting it to non-active
    	j.IsActive__c = false;
    	
    	Test.startTest();
    	
    	delete j;
    	
    	// Force our @future call to finish running
    	Test.stopTest();
    	
    	// Our job should have its CronTriggerId field set to null
    	jobs = [select Id from Job__c where Name = 'Unit_Test_Individually_Scheduled_Job' limit 1];
    	System.assertEquals(0,jobs.size());
    	  
    }
    
    private static testMethod void TestJobTrigger_Insert() {
    	// Load up our page for a new Schedulable job record
    	Job__c j = new Job__c(
    		Name = 'Unit_Test_Individually_Scheduled_Job',
    		Run_Individually__c = true,
    		IsActive__c = true,
    		Cron_Schedule__c = '0 0 13 * * ?',
    		Apex_Class__c = 'relax.JobScheduler'
		);
		
		Test.startTest();
		
		insert j;
		
		Test.stopTest();
		
    	// Verify that our record saved
    	List<Job__c> jobs = [
    		select	Id, Apex_Class__c, IsActive__c, CronTriggerId__c, JobSchedulerId__c, Next_Run__c
    		from	Job__c
    		where	Name = 'Unit_Test_Individually_Scheduled_Job' 
    		order by CreatedDate DESC limit 1
    	];
    	
    	String triggerId = jobs[0].CronTriggerId__c;
    	
    	System.assertEquals(1,jobs.size());
    	System.assertEquals('relax.JobScheduler',jobs[0].Apex_Class__c);
    	System.assertEquals(true,jobs[0].IsActive__c);
    	System.assertNotEquals(null,jobs[0].CronTriggerId__c);
    	System.assertNotEquals(null,jobs[0].JobSchedulerId__c);
    	System.assertNotEquals(null,jobs[0].Next_Run__c);
    	  
    }
    

}