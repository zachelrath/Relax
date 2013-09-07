// A runnable item in an async process
global virtual interface Runnable {
	// Let this Runnable know what Process it is in
	void setProcess(Process p);
	// Set the Job that this Runnable is related to
	void setJob(Job__c j);
	// Get the Job that this Runnable is related to
	Job__c getJob();
	// Run this item
	void run();
	// Clean up after and complete the Runnable
	void complete(); 
}