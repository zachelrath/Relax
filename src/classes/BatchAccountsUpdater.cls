global class BatchAccountsUpdater extends BatchableProcessStep implements Schedulable {

	global override Database.Querylocator start(Database.BatchableContext btx) {
		// Insert an SObject just to test that it's possible
		Account a = new Account(
			Name = 'Extravagant Account ' + String.valueOf(Datetime.now().getTime())
		);
		insert a;
		
		return Database.getQueryLocator([select Industry from Account where Industry = null]);
	}
	
	global override void execute(Database.BatchableContext btx, List<SObject> scope) {
		List<Account> accs = (List<Account>) scope;
		for (Account a : accs) {
			// Default the Industry to 'Retail'
			a.Industry = 'Retail';
		}
		update accs;
	}
	
	global override void finish(Database.BatchableContext btx) {
		
		System.debug('*** In BatchAccountsUpdater, about to continue our process!');
		
		// Continue our Batch Process, if we need to
		complete();
	}
	
	// Implements Schedulable interface
	global void execute(SchedulableContext ctx) {
		BatchAccountsUpdater b = new BatchAccountsUpdater();
		Database.executeBatch(b);
	}

}