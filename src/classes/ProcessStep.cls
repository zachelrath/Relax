global virtual interface ProcessStep {
	// Set the Process that we are a part of and the Runnable to execute
	void init(Process p, Runnable r);
	// Retrieve the Runnable associated with this ProcessStep
	Runnable getRunnable();
	// Retrieve the Process associated with this ProcessStep
	Process getProcess();
	// Clean up after this step, 
	// and advance to the next step in our process
	void complete(); 
}