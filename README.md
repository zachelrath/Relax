Skoodat Relax
=============

Taking all the pain out of Force.com Batch and Scheduled Job management.

What is it?
-------

For a comprehensive overview of Relax, check out this blog post:

[Relax: Your Batch Scheduling Woes are Over](http://zachelrath.wordpress.com/2012/06/28/relax-your-batch-scheduling-woes-are-over/)

Using Relax
------------

There are several sample Batch / Scheduled Apex classes that work with the Relax framework included in the source. I'll be moving these over to an 'examples' folder soon:

1. BatchAccountsUpdater.cls (finds all Accounts with a null Industry and gives them an Industry)
2. CaseEscalator.cls (finds all New Cases created more than 2 days ago whose Accounts have a Platinum/Gold SLA that are NOT High/Critical priority, and escalates them    

Here's what CaseEscalator looks like:

	global class CaseEscalator extends BatchableProcessStep implements Schedulable {
	
		global override Database.Querylocator start(Database.BatchableContext btx) {
			// Find all Cases that have been open		
			return Database.getQueryLocator([
				select	Priority
				from	Case 
				where	Status = 'New'
				and		Priority not in ('High','Critic
				
				al')
				and		Account.relax__SLA__c in ('Platinum','Gold') 
				and		AccountId != null
				and		CreatedDate < :Date.today().addDays(-2) 
			]);
		}
	
		global override void execute(Database.BatchableContext btx, List<SObject> scope) {
			List<Case> cases = (List<Case>) scope;
			for (Case c : cases) {
				// Set the Priority to 'High'
				c.Priority = 'High';
			}
			update cases;
		}
	
		global override void finish(Database.BatchableContext btx) {
	
			// Continue our Batch Process, if we need to
			complete();
		}
	
		// Implements Schedulable interface
		global void execute(SchedulableContext ctx) {
			CaseEscalator b = new CaseEscalator();
			Database.executeBatch(b);
		}
	
	}

Installation
-----------

Latest versions:

[Beta 4](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tE0000000HWiT)


Unit Tests
-------

All Relax Unit Tests are currently stored in UnitTests_Relax.cls. To run, navigate to this class and click 'Run Tests'. Additional tests should be added to this file.


Contributing
------------

1. Fork Relax.
2. Create a branch (`git checkout -b my_markup`)
3. Commit your changes (`git commit -am "Modified batch scheduling engine."`)
4. Push to the branch (`git push origin my_markup`)
5. Open a [Pull Request][1]

Licensing
------------

Relax is distributed under the Apache 2.0 License -- see LICENSE.txt for details. 