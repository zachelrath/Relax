public class CaseEscalator extends BatchableProcessStep implements Schedulable {

	public override Database.Querylocator start(Database.BatchableContext btx) {
		// Find all Cases that have been open		
		return Database.getQueryLocator([
			select	Priority
			from	Case 
			where	Status = 'New'
			and		Priority not in ('High','Critical')
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