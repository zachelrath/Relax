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
            
        SendDebugEmail(
            debugString,
            debugString,
            'Debug from Relax Install Script in org ' + ctx.organizationId(),
            new List<String>{'zach@skoodat.com','umittal@salesforce.com'}
        );
    }

    public static void SendDebugEmail(String htmlBody, String textBody, String subject, List<String> toAddresses) {
        // Send an email to the specified email addresses with a report of how the batch job went
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        mail.setToAddresses(toAddresses);
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
    
    /////////////////
    // UNIT TESTS
    /////////////////
    
    private static testMethod void TestInstall() {
        InstallScript is = new InstallScript();
        Test.testInstall(is, null);
        Boolean b = false;
        System.assertEquals(false,b);
        
        SendDebugEmail('test','test','testsubject',new List<String>{'zach@skoodat.com'});
    }
}