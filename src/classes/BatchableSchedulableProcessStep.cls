global abstract class BatchableSchedulableProcessStep extends BatchableProcessStep implements Schedulable {
	
	// Standard interface methods for Database.Schedulable
	global abstract void execute(SchedulableContext ctx);
	
}