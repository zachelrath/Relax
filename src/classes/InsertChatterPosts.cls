public class InsertChatterPosts extends BatchableProcessStep {

	// Find all Accounts with the 'Insert Post' flag set,
	// and insert a chatter post with CreatedById set to Zach McElrath
	
	// Also, send emails to Zach McElrath if the Account has a Platinum SLA

	private User zach;

	public override Database.Querylocator start(Database.BatchableContext btx) {
		this.zach = [select Id from User where Name = 'Zach McElrath' limit 1];
		return Database.getQueryLocator([select Name, Insert_Chatter_Post__c, SLA__c from Account where Insert_Chatter_Post__c = true]);
	}
	
	public override void execute(Database.BatchableContext btx, List<SObject> scope) {
		List<Account> accs = (List<Account>) scope;
		List<FeedItem> items = new List<FeedItem>();
		List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
		for (Account a : accs) {
			if (a.Insert_Chatter_Post__c) {
				// Create a new Chatter FeedItem for the Account
				// who is newly-scheduled to attend an Appointment
		        items.add(new FeedItem(
		            Body = 'Awesome account newly created: ' + a.Name,
		            // Post the FeedItem appropriate person's record
		            ParentId = a.Id,
		            // Set the createdbyid to the batch job's running user id
		            CreatedById = zach.Id
		        ));
		        
		        // Reset the insert chatter post flag
		        a.Insert_Chatter_Post__c = false;
			}    
	        
	        if (a.SLA__c == 'Platinum') {
	        	Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
	        	m.setToAddresses(new List<String>{'zach@skoodat.com'});
	        	m.setPlainTextBody('New Platinum SLA account created: ' + a.Name + ', Id: ' + a.Id);
	        	m.setHTMLBody('New Platinum SLA account created: ' + a.Name + ', Id: ' + a.Id);
	        	m.setSubject('New Platinum SLA account created');
	        	m.setSenderDisplayName('Skoodat Relax');
	        	emails.add(m);
	        }
		}
		update accs;
		insert items;
		
		// Send our emails, if we have any
		if (!emails.isEmpty()) {
			Messaging.sendEmail(emails);
		}
	}
	
	public override void finish(Database.BatchableContext btx) {
		
		// Complete this ProcessStep
		complete();
	}

}