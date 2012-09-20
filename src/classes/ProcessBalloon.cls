//
// Used to keep Nexus processes 'afloat' asynchronously
//

global class ProcessBalloon implements Schedulable, Database.Stateful {
	
	private Process p;

	public ProcessBalloon(Process p) {
		this.p = p;
	}
	
	global void execute(SchedulableContext ctx) {
		// Just in case someone tries to run this class inappropriately
		// (e.g. using a no-argument constructor)
		if (p != null) {
			// Add this CronTrigger job to our Process' list of temp jobs
			p.addTempJob(ctx.getTriggerId());
			
			// Move along, move along
			p.advance();
		}
	} 
}