global abstract class SchedulableProcessStep extends SimpleProcessStep implements Schedulable {
	
	// Standard interface methods for Database.Batchable
	global abstract void execute(SchedulableContext ctx);
	
}