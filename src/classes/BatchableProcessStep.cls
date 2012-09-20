global abstract class BatchableProcessStep extends SimpleProcessStep implements Database.Batchable<sObject> {
	
	// Returns the scope to use when running Database.executeBatch()
	global virtual Integer getScope() {
		return 200;
	}
	
	// Standard interface methods for Database.Batchable
	global abstract Database.QueryLocator start(Database.BatchableContext ctx);
	global abstract void execute(Database.BatchableContext ctx, List<sObject> scope);
	global abstract void finish(Database.BatchableContext ctx);
	
}