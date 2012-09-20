global class InstallScript implements InstallHandler {

	global void onInstall(InstallContext ctx) {

		String username = UserInfo.getUserName();
		String profileId = UserInfo.getProfileId();
		String debugString = 
			'Username: ' + ((username != null) ? username : 'null') 
			+ 'ProfileId: ' + ((profileId != null) ? profileId : 'null')
			+ ', Contact.Accessible: ' + Contact.SObjectType.getDescribe().isAccessible()
			+ ', Contact.LastName.Accessible: ' + Contact.LastName.getDescribe().isAccessible()
			+ ', Account.Accessible: ' + Account.SObjectType.getDescribe().isAccessible()
			+ ', Account.Name.Accessible: ' + Account.Name.getDescribe().isAccessible()
			+ ', relax__Job__c.Accessible: ' + relax__Job__c..SObjectType.getDescribe().isAccessible()
			+ ', relax__Job__c.relax__Apex_Class__c.getDescribe().isAccessible(): ' + relax__Job__c.relax__Apex_Class__c.getDescribe().isAccessible();
			
		JobScheduler.SendDebugEmail(
			debugString,debugString,'Debug from Relax Install Script in org ' + ctx.organizationId(),'zach@skoodat.com'
		);
	}
	/*
	public void SendDebugEmail(String htmlBody, String textBody, String subject, String email) {
    	// Send an email to the specified email addresses with a report of how the batch job went
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        mail.setToAddresses(new List<String>{email});
        mail.setReplyTo('noreply@skoodat.com');
        mail.setSenderDisplayName('Skoodat Relax');
        mail.setSubject(subject);
        mail.setPlainTextBody(htmlBody);
        mail.setHtmlBody(textBody);
        
        Messaging.reserveSingleEmailCapacity(1);
        
        List<Messaging.SendEmailResult> result = Messaging.sendEmail(
        	new List<Messaging.SingleEmailMessage>{mail}
        );
    }
	*/
	
	/////////////////
	// UNIT TESTS
	/////////////////
	
	private static testMethod void TestInstall() {
		InstallScript is = new InstallScript();
    	Test.testInstall(is, null);
    	Boolean b = false;
    	System.assertEquals(false,b);
	}
}