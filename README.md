Relax
=============

Taking all the pain out of Force.com Batch and Scheduled Job management.

What Relax lets you do:
-------

 1. Run multiple batch/scheduled Apex jobs as often as every 1 MINUTE, every day
 2. Mass activate, unschedule, and change ALL of your Scheduled and Batch Apex jobs at once --- minimizing the hassle of code deployments involving Scheduled Apex
 3. Mix-and-match your Batch Apex routines into "chains" of jobs that run sequentially on a scheduled basis, without hard-coding the sequences into your code
 4. Define string/JSON parameters to pass into Relax jobs you create, allowing for massive reuse of your Batch/Scheduled Apex.
 5. Bonus: powerful 'MassUpdate' and 'MassDelete' Apex Classes that can be run as Relax Jobs are pre-included! Never write another line of Scheduled Apex just to do mass-update a million records!

For an intro to Relax, check out this blog post:

[Relax: Your Batch Scheduling Woes are Over](http://zachelrath.wordpress.com/2012/06/28/relax-your-batch-scheduling-woes-are-over/)

Installation
-----------

Latest versions:

[v1.1](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tE0000000ISIu)



Using Relax
------------

Relax is available as a managed *released* package (coming to AppExchange before Dreamforce 2013!), click [here](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tE0000000ISIu) to install v1.1. now!

There are several sample Batch / Scheduled Apex classes that work with the Relax framework included in the src/classes directory. MassUpdate.cls and MassDelete.cls are included in the Relax managed package, while BatchAccountsUpdater.cls and CaseEscalator.cls are just some other examples:

1. [MassUpdate.cls](/src/classes/MassUpdate.cls)
2. [MassDelete.cls](/src/classes/MassDelete.cls)
3. BatchAccountsUpdater.cls (finds all Accounts with a null Industry and gives them an Industry)
4. CaseEscalator.cls (finds all New Cases created more than 2 days ago whose Accounts have a Platinum/Gold SLA that are NOT High/Critical priority, and escalates them

Here's what MassDelete looks like --- it's very simple:

    global class MassDelete extends relax.BatchableSchedulableProcessStep implements Database.Stateful {

		global String parameters;

		public String query;

		global override Database.QueryLocator start(Database.BatchableContext btx){

			// Attempt to retrieve parameters from our Job record
			// if we do not have parameters yet.
			if (parameters == null) parameters = params();
			if (parameters != null) {
				// We expect our parameters to be a JSON object,
				// so deserialize it
				Map<String,Object> paramsObj;
				try {
					paramsObj = (Map<String,Object>) JSON.deserializeUntyped(parameters);
					query = (String) paramsObj.get('query');
				} catch (Exception ex) {
					// Complete our batch process
					complete();
					throw ex;
				}	

			}

			if (query != null) {
				return Database.getQueryLocator(query);
			} else {
				// Return a dummy query locator
				return Database.getQueryLocator([select Id from User where Id = :UserInfo.getUserId() limit 0]);

			}	
		}

		global override void execute(Database.BatchableContext btx, List<SObject> scope) {
			if (scope != null && !scope.isEmpty()){
				Database.delete(scope,false);
			}	
		}

		global override void finish(Database.BatchableContext btx) {
			// Continue our Batch Process, if we need to
			complete();
		}

		// Implements Schedulable interface
		global override void execute(SchedulableContext ctx) {
			Database.executeBatch(new MassDelete());
		}

    }

Here's what CaseEscalator looks like:

	public class CaseEscalator extends BatchableProcessStep implements Schedulable {
	
		public override Database.Querylocator start(Database.BatchableContext btx) {
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
	
		public override void execute(Database.BatchableContext btx, List<SObject> scope) {
			List<Case> cases = (List<Case>) scope;
			for (Case c : cases) {
				// Set the Priority to 'High'
				c.Priority = 'High';
			}
			update cases;
		}
	
		public override void finish(Database.BatchableContext btx) {
	
			// Continue our Batch Process, if we need to
			complete();
		}
	
		// Implements Schedulable interface
		public void execute(SchedulableContext ctx) {
			CaseEscalator b = new CaseEscalator();
			Database.executeBatch(b);
		}
	
	}

Unit Tests
-------

All Relax Unit Tests are currently stored in UnitTests.cls and JobEditController.cls, and should pass in any org. To run these tests, navigate to "Apex Test Execution" in your org and select the "relax" namespace, then select both of the above classes and Run Tests.

Using the pre-included MassUpdate class in a Relax Job:
-------
The MassUpdate class makes use of Relax Job Parameters. Basically, when creating a new Aggregable Relax Job, you'll see a text box called "Parameters". MassUpdate expects you to provide some JSON here defining what kind of Mass Updates you want to do. For instance, putting the following JSON into the Parameters box will find all `Account` records whose `Name` field starts with 'Extravagant', and set their `relax__SLA__c` field to 'Platinum':

    {
      "mode":"FIELD_WITH_VALUE",
      "query":"select relax__SLA__c from Account where Name like 'Extravagant%'",
      "field":"relax__SLA__c",
      "value":"Platinum"
    }

Here's what it looks like to create this Job from within Relax:

![Sample Relax Job: Change SLA of Extravagant Accounts](/images/ChangeSLAOfExtravagantAccounts.png)

(Activate the Job and change its Run Increment as desired, of course).

Here are all supported Relax operation modes:

 - `FIELD_WITH_VALUE` mode: updates a particular field with a particular value. Example given above.
 
 - `FIELDS_WITH_VALUES` mode: updates a set of fields with corresponding values. Example: finds all Cases that have been Open for over 30 days, and sets their Priority to Critical and Escalates them:
 
    {
      "mode":"FIELDS_WITH_VALUES",
      "query":"select Priority, IsEscalated from Case where Status = 'Open' and CreatedDate < LAST_N_DAYS:30",
      "valuesByField":{
         "Priority":"Critical",
         "IsEscalated":true
      }
    }
    
 - `FIELD_FROM_FIELD` mode: for each row, copies the value of a source field into a target field. Example: copies the value of the OwnerId field of each Opportunity into a custom Owner2__c field:
 
    {
      "mode":"FIELD_FROM_FIELD",
      "query":"select OwnerId, Owner2__c from Opportunity where Owner2__c = null",
      "sourceField":"OwnerId",
      "targetField":"Owner2__c"
    }    
 
 - `FIELDS_FROM_FIELDS` mode: same as Field from Field, but for multiple source-to-target field pairings: Example: 
 
     {
      "mode":"FIELDS_FROM_FIELDS",
      "query":"select OwnerId, Owner2__c, CloseMonthFormula__c, CloseMonth__c from Opportunity",
      "sourceFieldsByTargetField":{
         "CloseMonth__c":"CloseMonthFormula__c",
         "Owner2__c":"OwnerId"
      }
    }    

Support / Contributing
------------

Relax is open-source, and we would LOVE it if you would like to contribute some example classes that work with Relax, add features to the code, whatever! Just follow the steps below to contribute:

1. Fork Relax.
2. Create a branch (`git checkout -b my_markup`)
3. Commit your changes (`git commit -am "Modified batch scheduling engine."`)
4. Push to the branch (`git push origin my_markup`)
5. Open a [Pull Request][1]

Licensing
------------

Relax is distributed under the GNU General Public License v3 -- see LICENSE.md for details. If you want to use Relax or a modified version of it in your own organization, that is okay, but code from Relax may not be redistributed or sold for profit in another product. 